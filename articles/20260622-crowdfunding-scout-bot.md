---
title: "Firecrawl で海外クラファン製品を自動スカウトする"
emoji: "🔍"
type: "tech"
topics: ["claude", "claudeapi", "firecrawl", "python", "ai"]
pattern: "implementation"
published: false
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260622-crowdfunding-scout-bot_thumbnail.png
---

## クラファン製品リサーチの現実

海外クラウドファンディング(Kickstarter・Indiegogo)には、毎日数百のプロジェクトが立ち上がる。EC で仕入れ候補を探す場合、気になるカテゴリを手動でチェックするだけで数時間が溶ける。しかも何をどう評価するかの基準がブレる。

この記事では、Firecrawl でクラファンページのデータを取得し、Claude API で「市場適合性・差別化ポイント・競合状況」を評価してスコアを付けるパイプラインを作る。出力は CSV なので、好きなツールで絞り込める。

## アーキテクチャ

```
Kickstarter / Indiegogo の公開ページ
      ↓ Firecrawl（スクレイプ → LLM 向け Markdown に変換）
      ↓ Claude API（製品評価プロンプト → JSON スコア）
      ↓ pandas で集計 → CSV 出力
```

Firecrawl が HTML → Markdown 変換を担うことで、Claude への入力トークンが大幅に減る。100ページ処理しても API コストが現実的な範囲に収まるのがポイント。

## セットアップ

[Day 2 で実装コードを追記]

必要な環境:
- Python 3.11+
- Firecrawl API キー（フリープランあり）
- Anthropic API キー

```bash
# Day 2 で完成形を書く
pip install firecrawl-py anthropic pandas
```

## Firecrawl でページを取得する

[Day 2 で実装コードを追記]

Kickstarter の検索結果ページを Firecrawl に渡し、各プロジェクトの URL を抽出 → 個別ページをスクレイプして Markdown を取得する処理を書く。

最初は `crawl` を使って1サイト全体を取得しようとしたが、クラファンサイトは動的レンダリングが多く、`scrape` を URL リストに対してループする方が安定した。（Day 2 で詳細を書く）

## Claude API で評価・スコアリング

[Day 2 で実装コードを追記]

評価軸（プロンプト設計は Day 2 で詰める）:
- **市場適合性**: その製品カテゴリが日本市場で受け入れられるか
- **差別化度**: 既存 Amazon / 楽天商品と何が違うか
- **価格帯の妥当性**: 仕入れ原価を考慮した利益余地があるか
- **トレンド整合**: 現在の消費トレンドとの一致度

Claude のレスポンスは JSON で受け取り、スコア(0-10)と理由を構造化して保持する。

## 出力と絞り込み

[Day 2 で実装コードを追記]

pandas で CSV に書き出し、「スコア上位 × 目標価格帯」でフィルタすると候補が一覧できる。スコア × 価格帯の散布図を出力するとバランスの良い候補が視覚的に浮かぶ。

## データアナリスト視点

製品評価ロジックは、分析業務の「スコアリングモデル」と構造が同じだ。評価軸を定義して数値に落とし、集計して意思決定に使う。Claude のレスポンスを JSON 化することで、pandas での集計がそのまま使える。

クラファンの「ファンディング達成率」「バッカー数の伸び率」を時系列で追うと、市場の注目度シグナルとして機能する。この発想は時系列データの異常検知と似ている。

## 最後に

完成したパイプラインのコードは GitHub で公開する予定。実装コードは Day 2 で追記する。
