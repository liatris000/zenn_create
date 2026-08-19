---
title: "Claude APIで商談準備とフォローを一気通貫にする"
emoji: "🧭"
type: "tech"
topics: ["claude", "claudeapi", "python", "automation", "ai"]
pattern: "implementation"
published: true
published_at: "2026-09-10 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260910-sales-prep-followup-ai_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、Liatrisが動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事](https://zenn.dev/liatris/articles/20260701-zenn-kickoff)にまとめています。
:::

商談前の準備に毎回30分〜1時間かけている、という話をよく聞く。準備の型はだいたい決まっているのに、毎回ゼロから同じ情報収集と整理をやり直している。準備だけでなく、商談後の「次に何をするか」の整理も同様に毎回ゼロから考えがちだ。この2つを1本のCLIとして実装できないか試した。

## アーキテクチャ(ざっくり)

- `brief` サブコマンド: 会社名 / URL / 商談の目的 を渡すと、想定論点・質問リスト・懸念点を含むブリーフィングを返す
- `followup` サブコマンド: 商談後の自由記述メモを渡すと、決定事項・ネクストアクション・フォローメールの下書きを返す
- どちらも Claude API の構造化出力(tool use を `tool_choice` で強制する方式)を使い、モデルの応答をそのまま Pydantic モデルにデシリアライズする

```bash
# 商談前ブリーフィング
python3 sales_prep_followup.py brief \
  --company "Acme Inc." \
  --url "https://example.com" \
  --purpose "新規提案"

# 商談後フォロー
python3 sales_prep_followup.py followup --notes-file notes.txt
```

## 実装: 2つのPydanticモデルと共通のtool化ヘルパー

最初は「商談前と商談後を1つのスキーマで扱えないか」を考えていた。どちらも「相手の状況を構造化して次のアクションに変換する」という点は共通しているからだ。実際にフィールドを書き出してみると、`talking_points`(想定論点)と `next_actions`(ネクストアクション)のように意味が近いようで粒度が違うフィールドが混在し、1つのモデルに無理やり詰め込むと `Optional` だらけの緩いスキーマになった。そこで方針を変え、モデルは分けたまま、モデルを tool 定義(JSON Schema)に変換する部分だけ共通化することにした。

```python:sales_prep_followup.py
class Briefing(BaseModel):
    company_summary: str = Field(description="会社概要(事業内容・規模感など事実ベースで3〜5文)")
    talking_points: list[str] = Field(description="想定される商談の論点(3〜5個)")
    questions: list[str] = Field(description="先方に投げる質問リスト(3〜5個)")
    risks: list[str] = Field(default_factory=list, description="事前に把握しておくべき懸念点(あれば)")


class FollowupPlan(BaseModel):
    decisions: list[str] = Field(description="商談メモから抽出した決定事項")
    next_actions: list[str] = Field(description="ネクストアクション(担当・期限がメモにあれば含める)")
    followup_email_subject: str = Field(description="フォローメールの件名")
    followup_email_body: str = Field(description="フォローメールの本文(挨拶〜締めまで)")


def _model_to_tool(model: type[BaseModel], name: str, description: str) -> dict[str, Any]:
    schema = model.model_json_schema()
    schema.pop("title", None)
    return {"name": name, "description": description, "input_schema": schema}
```

`BaseModel.model_json_schema()` がそのまま JSON Schema を返すので、Pydantic のフィールド定義とAPIに渡す tool 定義の二重管理をしなくて済む。`title` キーだけは Pydantic がクラス名を勝手に入れてくるので、tool 定義としては不要なため pop している。

呼び出し側も共通化した。`tool_choice` に `{"type": "tool", "name": ...}` を指定してその tool の呼び出しを強制し、返ってきた `tool_use` ブロックの `input` をそのまま拾う。

```python:sales_prep_followup.py
def _call_structured(client: Any, *, system: str, user: str, tool: dict[str, Any]) -> dict[str, Any]:
    """構造化出力を1つの tool_use ブロックとして強制取得する共通処理。"""
    response = client.messages.create(
        model=MODEL,
        max_tokens=1024,
        system=system,
        tools=[tool],
        tool_choice={"type": "tool", "name": tool["name"]},
        messages=[{"role": "user", "content": user}],
    )
    for block in response.content:
        if getattr(block, "type", None) == "tool_use" and block.name == tool["name"]:
            return block.input
    raise RuntimeError("tool_use ブロックが返らなかった(モデル or プロンプトを確認)")
```

`generate_briefing` / `extract_followup` は、この2つのヘルパーにプロンプトとモデルを渡すだけの薄い関数になった。

```python:sales_prep_followup.py
def generate_briefing(client: Any, *, company_name: str, url: str, purpose: str = "") -> Briefing:
    tool = _model_to_tool(Briefing, "submit_briefing", "商談前ブリーフィングを提出する")
    user = (
        f"次の商談相手について、Web検索の結果と一般知識をもとにブリーフィングを作成して。\n"
        f"会社名: {company_name}\nURL: {url}\n商談の目的: {purpose or '(未指定)'}\n"
        "事実と推測は分けて書くこと。不明な点は無理に埋めず risks に書く。"
    )
    data = _call_structured(
        client,
        system="あなたはB2B営業の商談準備を支援するアシスタントです。事実ベースで簡潔に書きます。",
        user=user,
        tool=tool,
    )
    return Briefing.model_validate(data)
```

## テスト: APIキーなしでスキーマ変換の経路だけ確認する

CLI 自体を毎回本物の Claude API に投げてテストするのは、API キーが要るし応答も非決定的なので確認が安定しない。今回検証したいのは「LLMの文章センス」ではなく「tool 定義の組み立てと `tool_use` のパースが壊れていないか」なので、`anthropic.Anthropic` クライアントを丸ごとモックして `tool_use` ブロックだけ差し込むテストにした。

```python:test_sales_prep_followup.py
class FakeToolUseBlock:
    def __init__(self, name: str, input_: dict):
        self.type = "tool_use"
        self.name = name
        self.input = input_


class FakeMessages:
    def __init__(self, tool_name: str, payload: dict):
        self._tool_name = tool_name
        self._payload = payload
        self.last_kwargs: dict | None = None

    def create(self, **kwargs):
        self.last_kwargs = kwargs
        return SimpleNamespace(content=[FakeToolUseBlock(self._tool_name, self._payload)])


def test_generate_briefing_parses_structured_output():
    payload = {
        "company_summary": "SaaS企業。従業員規模は非公開。",
        "talking_points": ["導入目的", "既存ツールとの棲み分け"],
        "questions": ["決裁フローを教えてください"],
        "risks": ["競合ツールを既に検証済みの可能性"],
    }
    client = FakeClient("submit_briefing", payload)

    result = generate_briefing(client, company_name="Acme Inc.", url="https://example.com", purpose="新規提案")

    assert isinstance(result, Briefing)
    assert result.company_summary == payload["company_summary"]
    # tool_choice で強制していることを確認(自由テキスト応答に倒れないため)
    assert client.messages.last_kwargs["tool_choice"] == {"type": "tool", "name": "submit_briefing"}
```

`last_kwargs` を保存しておいて `tool_choice` の中身までアサートしているのがポイントで、これがないと「モデルが tool を無視して普通のテキストで返してきた」ケースに気づけない。`python3 -m pytest test_sales_prep_followup.py -v` で3件とも通ることを確認した。

## データアナリスト視点

構造化出力のスキーマ設計は、テーブル設計とほぼ同じ発想で決められる。今回 `talking_points` と `next_actions` を同じモデルに詰めずに分けたのも、正規化されていないテーブルに無理やり2つの意味の異なる列を押し込まないのと同じ判断基準だった。「後からこのフィールドで何を集計・フィルタしたいか」から逆算してフィールドの型(単一値かリストか、必須かoptionalか)を決める作業は、SQLのテーブル設計と地続きだと感じる。

もう1つ、`Field(description=...)` に書いた日本語の説明文が、そのままモデルへの指示(プロンプト)としても機能する点が面白かった。スキーマのドキュメンテーションと生成品質を上げるための指示が同じ場所に書けるので、「スキーマは正しいがモデルが期待通りに埋めてくれない」というズレが起きにくい。

## 成果物

@[github](https://github.com/liatris000/liatris-20260910-sales-prep-followup-ai)

デモ: https://liatris000.github.io/liatris-20260910-sales-prep-followup-ai/
