---
title: "1つの商品データはモール毎にどう化けるか"
emoji: "🛒"
type: "tech"
topics: ["claude", "claudeapi", "ec", "automation", "python"]
pattern: "comparison"
published: false
published_at: "2026-09-03 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260903-marketplace-listing-ai_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、Liatrisが動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事](https://zenn.dev/liatris/articles/20260701-zenn-kickoff)にまとめています。
:::

同じ商品でもAmazonと楽天では出品情報の"形"がまったく違う。タイトルの文字数上限、箇条書きの有無、必須項目——モールごとにフィールド構造がバラバラなので、複数モールに出そうとすると毎回手で書き直すことになる。1つの共通商品データを渡すだけで、モールごとの出品情報を機械的に組み立てられないか試した。

## 比較対象の整理

まず2モールのフィールド構造を並べてみる。

| | Amazon | 楽天 |
|---|---|---|
| タイトル | 簡潔なスペック羅列、絵文字NG | SEO意識、キーワード前方配置 |
| 商品説明 | 箇条書き(bullet)中心、最大5項目 | 長文本文中心、使用シーンの描写 |
| 必須要素 | カテゴリ分類 | ジャンルの手がかり |

同じ「商品説明」でも、Amazonは端的な機能列挙、楽天は購入後の使用シーンを描写する長文、と求められる書き方の方向性そのものが違う。これを1つのプロンプトで両方こなそうとすると中途半端になるので、モールごとに「フィールドの型」と「文体方針」をセットで定義し、Claude API の構造化出力(tool use)でそれぞれ生成する設計にした。

## 検証設計:LLM呼び出しをテスト境界から切り離す

実装を始める前に1つ判断が要った。文字数超過やフィールド欠落といった「後処理ロジック」のテストを、毎回実際にClaude APIを呼んで確認するのは非効率だし、LLMの出力は非決定的なので同じ入力でも毎回同じ結果になるとは限らない。

そこで呼び出し部分を `Protocol` で抽象化し、本番用の `AnthropicListingClient` とオフライン確認用の `MockListingClient` を差し替えられるようにした。

```python:src/llm_client.py
class ListingClient(Protocol):
    def generate(self, product: CommonProduct, spec: MallSpec) -> dict: ...


class AnthropicListingClient:
    """本番用。anthropic SDK 経由で Claude を呼ぶ。"""

    def __init__(self, model: str = "claude-sonnet-4-5"):
        import anthropic

        self._client = anthropic.Anthropic()
        self._model = model

    def generate(self, product: CommonProduct, spec: MallSpec) -> dict:
        tool = build_tool_schema(spec)
        response = self._client.messages.create(
            model=self._model,
            max_tokens=1024,
            tools=[tool],
            tool_choice={"type": "tool", "name": LISTING_TOOL_NAME},
            messages=[{"role": "user", "content": build_prompt(product, spec)}],
        )
        for block in response.content:
            if block.type == "tool_use" and block.name == LISTING_TOOL_NAME:
                return block.input
        raise RuntimeError("Claude がtool_useブロックを返さなかった")
```

こうしておくと、「文字数超過をちゃんと切り詰めるか」のようなロジックのテストはmock側で決定的に確認でき、実際にお金と時間がかかるAPI呼び出しはCLIの `--mock` フラグで明示的に分離できる。

## Step 1: モール仕様をコードで持つ

Amazon・楽天それぞれのフィールド制約は `dataclass` で定義した。文字数上限のような数値は執筆時点の目安であり、実際の出品者アカウントのカテゴリ別制約に合わせて差し替える前提にしている。

```python:src/mall_specs.py
@dataclass(frozen=True)
class MallSpec:
    name: str
    title_max_chars: int
    bullet_max_count: int
    bullet_max_chars: int
    description_max_chars: int
    required_fields: list[str] = field(default_factory=list)
    style_hint: str = ""


MALL_SPECS = {
    "amazon": MallSpec(
        name="Amazon", title_max_chars=200, bullet_max_count=5,
        bullet_max_chars=255, description_max_chars=2000,
        required_fields=["title", "bullets", "description", "category"],
        style_hint="タイトルはブランド名+商品名+主要スペックの簡潔な羅列。誇大表現・絵文字は避ける。",
    ),
    "rakuten": MallSpec(
        name="Rakuten", title_max_chars=127, bullet_max_count=0,
        bullet_max_chars=0, description_max_chars=3000,
        required_fields=["title", "description", "genre_id_hint"],
        style_hint="タイトルはSEOを意識し主要キーワードを前方配置。本文は使用シーンを具体的に描写する。",
    ),
}
```

このスペックから、モールごとに異なるJSON Schema(tool定義)を組み立てる。楽天は `bullets` を持たず、代わりに `genre_id_hint`(ジャンルIDそのものではなく、後で人間かAPIがジャンルを特定するための手がかり文字列)を要求する、といった差分がここに現れる。

## Step 2: 後処理でハードな制約を強制する

ここが一番の気づきだった。tool定義の `maxItems` や `description` に書いた文字数の目安は、Claudeにとってあくまで「努力目標」で、確実に守られる保証はない。実配信で弾かれないためには、出力後にコード側で機械的にチェック・切り詰める層が要る。

```python:src/generate.py
def enforce_hard_constraints(raw: dict, spec, result: EnforcementResult) -> dict:
    enforced = dict(raw)
    title = enforced.get("title", "")
    if len(title) > spec.title_max_chars:
        result.add(f"[{spec.name}] title が {len(title)}字で上限{spec.title_max_chars}字を超過 → 切り詰め")
        enforced["title"] = title[: spec.title_max_chars]
    # bullets / description も同様に切り詰め、required_fields の欠落を警告として記録する
    return enforced
```

これをテストするために、意図的に上限を超える長さの商品名を用意して `MockListingClient` に流し、切り詰めが働くことを確認した。

```python:tests/test_pipeline.py
def test_title_overflow_gets_truncated_not_rejected():
    long_name = "軽量カーボン骨折りたたみ傘" * 10
    product = make_product(name=long_name)
    spec = MALL_SPECS["rakuten"]
    raw = MockListingClient().generate(product, spec)
    assert len(raw["title"]) > spec.title_max_chars  # mock自体は超過を防がない

    enforced = enforce_hard_constraints(raw, spec, EnforcementResult())
    assert len(enforced["title"]) == spec.title_max_chars
```

5件のテストは全て通った。実行例(オフラインmock、架空の折りたたみ傘データ):

```bash
$ python src/generate.py samples/product_umbrella.json --out out/ --mock
✅ Amazon: out/amazon.json
✅ Rakuten: out/rakuten.json
```

## 結果と考察

今回の検証は「Claudeが文章としてどれだけ気の利いた出品コピーを書けるか」ではなく、「モール差分をどこで吸収する設計にするべきか」という構造の部分に絞った。その範囲での結論ははっきりしている。

- **フィールドの型・必須項目はプロンプトではなくtool定義(JSON Schema)で強制する。** テキストで「箇条書きは5個までにしてください」と頼むより、`maxItems` で構造として制約したほうが崩れにくい。
- **ただし数値的なハード制約(文字数上限)はtool定義だけでは信用できない。** 出力後にコード側で切り詰める層が必須で、ここをAIに任せきりにすると実配信時に弾かれるリスクが残る。
- **スタイルの方向性(簡潔な羅列 vs 使用シーンの長文描写)はプロンプト側の役割。** ここは構造で縛れないので、`style_hint` のような自然文の指示に頼るしかない。

つまり「構造で縛れる部分」と「文章表現に頼るしかない部分」が、モール比較を通じてはっきり分離できた。これは最初、全部プロンプトの指示文で解決しようとして混乱していた部分だった。

## データアナリスト視点

モールごとのフィールド差分をマッピングする作業は、データ基盤でのスキーマ変換・ETLのマッピング定義とほぼ同じ構造をしている。ソース側のスキーマは1つ、宛先ごとに型変換ルールと制約が違う、というのはデータパイプラインの典型的な悩みそのものだ。

違うのは、ETLの変換ルールが決定的な関数で書けるのに対し、今回の「文体の書き分け」の部分は決定的に書けず生成AIに委ねるしかない点。どこまでを型で縛り、どこから先を生成に委ねるかの線引きが、そのまま設計の良し悪しに直結する。
