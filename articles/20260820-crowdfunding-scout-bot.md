---
title: "Firecrawl で海外クラファン製品を自動スカウトする"
emoji: "🔍"
type: "tech"
topics: ["claude", "claudeapi", "firecrawl", "python", "ai"]
pattern: "implementation"
published: true
published_at: "2026-08-20 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260820-crowdfunding-scout-bot_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事](https://zenn.dev/liatris/articles/20260701-zenn-kickoff)にまとめています。
:::

## クラファン製品リサーチの現実

Kickstarter・Indiegogo には毎日数百のプロジェクトが立ち上がる。EC で仕入れ候補を探す場合、気になるカテゴリをブラウザで巡回するだけで数時間が溶ける。しかも評価基準が感覚に依存するので、候補を並べても「なんとなく良さそう」の壁を越えられない。

この記事では、Firecrawl でクラファンページのデータを取得し、Claude API で市場適合性・差別化度・価格妥当性・トレンド整合の 4 軸でスコアリングするパイプラインを作る。出力は CSV なので、好きなツールで絞り込める。

## アーキテクチャ

```
Kickstarter カテゴリページ
      ↓ Firecrawl（scrape → LLM 向け Markdown に変換）
      ↓ プロジェクト URL を正規表現で抽出
      ↓ 各 URL を個別 scrape → Markdown 取得
      ↓ Claude Haiku（評価プロンプト → JSON スコア）
      ↓ pandas 集計 → CSV 出力
```

Firecrawl が HTML → Markdown 変換を担うことで、Claude への入力トークンが大幅に減る。1 ページあたり 6000 文字に切り詰めて渡すと、10 件処理しても Claude Haiku のコストは数円程度に収まる。

## セットアップ

```bash
pip install firecrawl-py anthropic pandas
```

```bash
export FIRECRAWL_API_KEY="fc-..."      # https://firecrawl.dev
export ANTHROPIC_API_KEY="sk-ant-..."  # https://console.anthropic.com
```

Firecrawl はフリープランで月 500 クレジット。カテゴリページ 1 回 + 各プロジェクト 10 件で合計 11 クレジット消費するので、毎日回しても月 200 クレジット程度で済む。

## Firecrawl でページを取得する

```python:scout.py
import os, re, time, json
import pandas as pd
from firecrawl import FirecrawlApp
import anthropic

KICKSTARTER_URLS = [
    "https://www.kickstarter.com/discover/categories/technology/gadgets?sort=magic",
]
MAX_PROJECTS = 10
MARKDOWN_LIMIT = 6000

def collect_project_urls(firecrawl, category_url):
    result = firecrawl.scrape_url(category_url, params={"formats": ["markdown"]})
    markdown = result.get("markdown", "")
    urls = re.findall(r"https://www\.kickstarter\.com/projects/[^\s\)\]\"#?]+", markdown)
    seen, deduped = set(), []
    for url in urls:
        if url not in seen:
            seen.add(url)
            deduped.append(url)
    return deduped[:MAX_PROJECTS]

def scrape_project(firecrawl, url):
    try:
        result = firecrawl.scrape_url(url, params={"formats": ["markdown"]})
        return result.get("markdown", "")
    except Exception as exc:
        print(f"  ⚠ scrape 失敗: {exc}")
        return ""
```

最初は `firecrawl.crawl_url()` でサイト全体を取得しようとした。ところが Kickstarter はログイン状態によってレンダリング結果が変わる部分が多く、カテゴリ一覧で完走しないことがあった。`scrape_url()` を URL リストにループする方がレスポンスが安定したので切り替えた。

## Claude API で評価・スコアリング

```python:scout.py（続き）
EVAL_PROMPT = """\
次のクラウドファンディングプロジェクトのページ(Markdown)を分析し、
EC 仕入れ候補として評価してください。

---
{markdown}
---

以下の JSON 形式だけで回答してください:
{{
  "product_name": "製品名",
  "category": "カテゴリ",
  "scores": {{
    "market_fit_jp": 日本市場に受け入れられやすいか 0-10,
    "differentiation": Amazon/楽天にない差別化があるか 0-10,
    "price_viability": 利益余地があるか 0-10,
    "trend_alignment": 現在のトレンドとの一致度 0-10
  }},
  "total_score": 総合評価 0-10,
  "summary": "製品概要 1 文（日本語）",
  "market_fit_reason": "日本市場適合性の根拠 1 文",
  "risk": "主なリスク 1 点"
}}
"""

def evaluate_product(claude_client, markdown):
    if len(markdown) < 200:
        return None
    message = claude_client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=512,
        messages=[{"role": "user", "content": EVAL_PROMPT.format(markdown=markdown[:MARKDOWN_LIMIT])}],
    )
    text = message.content[0].text.strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{[\s\S]+\}", text)
        return json.loads(m.group()) if m else None
```

プロンプトの最初のバージョンでは「日本語で回答してください」とだけ書いていた。JSON の外に余計な説明文を付けてくるケースがあり、パースが落ちた。「以下の JSON 形式だけで回答してください」に変えたら安定した。`re.search` でのフォールバックは念のため残している。

## 出力と絞り込み

```python:scout.py（続き）
def main():
    firecrawl = FirecrawlApp(api_key=os.environ["FIRECRAWL_API_KEY"])
    claude = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    all_urls = []
    for cat_url in KICKSTARTER_URLS:
        urls = collect_project_urls(firecrawl, cat_url)
        all_urls.extend(urls)

    rows = []
    for i, url in enumerate(all_urls, 1):
        print(f"[{i}/{len(all_urls)}] {url}")
        md = scrape_project(firecrawl, url)
        result = evaluate_product(claude, md)
        if not result:
            continue
        scores = result.get("scores", {})
        rows.append({
            "product_name":      result.get("product_name", ""),
            "category":          result.get("category", ""),
            "market_fit_jp":     scores.get("market_fit_jp", 0),
            "differentiation":   scores.get("differentiation", 0),
            "price_viability":   scores.get("price_viability", 0),
            "trend_alignment":   scores.get("trend_alignment", 0),
            "total_score":       result.get("total_score", 0),
            "summary":           result.get("summary", ""),
            "market_fit_reason": result.get("market_fit_reason", ""),
            "risk":              result.get("risk", ""),
            "url":               url,
        })
        time.sleep(1)

    df = pd.DataFrame(rows).sort_values("total_score", ascending=False)
    df.to_csv("scout_results.csv", index=False, encoding="utf-8-sig")
    print(df[["product_name", "total_score", "summary"]].head(5).to_string(index=False))

if __name__ == "__main__":
    main()
```

CSV の文字コードを `utf-8-sig` にしているのは、Excel で開いた時に文字化けしないようにするため。`sort_values("total_score", ascending=False)` で高スコア順に並ぶので、上から眺めるだけで候補が絞れる。

## データアナリスト視点

製品評価の 4 軸（市場適合性・差別化度・価格妥当性・トレンド整合）は、分析業務のスコアリングモデルと構造が同じだ。評価軸を定義して数値に落とし、重みを付けて集計して意思決定に使う。Claude のレスポンスを JSON で受け取ることで、pandas での集計がそのまま使える点が気に入っている。

スコアの分布を眺めると「総合スコアが高くても特定軸が極端に低い製品」が浮かび上がる。たとえば `market_fit_jp` が 3 以下なら日本市場ではほぼ動かない。`total_score × price_viability` の散布図を出すと、利益余地があってかつ総合評価が高い候補が視覚的に見つかる。

## 制限と今後

現状の制限：

- Kickstarter の動的レンダリング部分（バッカー数のリアルタイム更新）が取れないケースがある
- 評価は Claude の知識ベース時点の相場感なので、直近の Amazon/楽天価格とは乖離する
- Indiegogo は URL 構造が異なるため `collect_project_urls` の正規表現調整が必要

カテゴリ URL と `MAX_PROJECTS` を変えるだけで別カテゴリに転用できる。定期実行（cron や GitHub Actions）と組み合わせると、毎週の新着トレンドを差分で追える。成果物コードは GitHub に公開予定。
