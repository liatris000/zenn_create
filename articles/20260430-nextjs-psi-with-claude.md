---
title: "PSI MCP × Claude Code で Core Web Vitals を全指標改善した"
emoji: "⚡"
type: "tech"
topics: ["claudecode", "nextjs", "mcp", "performance"]
published: false
published_at: "2026-05-07 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260430-nextjs-psi-with-claude_thumbnail.png
---

## サイトのスコアが崩れていた

Next.js で構築した EC サイトの PageSpeed Insights スコアが、機能追加のたびに少しずつ下がっていた。LCP が 4 秒超、TBT が 800ms 超。「後でまとめて直す」を繰り返した結果だ。

Claude Code に PSI MCP サーバーを接続したら、スコアの取得から改善指示、コード修正まで一気通貫でできることが分かった。この記事では、8つの Lighthouse 指標を 1 サイクルで改善した実装フローを書く。

## PSI MCP サーバーとは

PageSpeed Insights API をラップした MCP サーバー（[ruslanlap/pagespeed-insights-mcp](https://github.com/ruslanlap/pagespeed-insights-mcp)）。Claude Code から自然言語でスコアを要求すると、LCP・INP・CLS・FCP・TTFB・Speed Index・TBT・Performance スコアが構造化データで返ってくる。Google Cloud で API キーを発行すれば動く。

## セットアップ

`.claude/mcp.json` に PSI MCP サーバーを追加する手順。Google Cloud Console での API 有効化とキー発行が前提。Claude Code のプロジェクト設定に組み込むことで、測定が会話の中でシームレスに呼び出せるようになる。

（実装コードは Day 2 で記載）

## 改善ワークフロー

Claude Code が PSI スコアを取得し、Lighthouse の「Opportunities」セクションをバックログとして扱う。優先度順（スコア影響が大きい順）に修正指示を出し、再計測して確認する。このループを全項目が改善するまで回す。

フローを Mermaid で図示する予定（Day 2 で追加）。

## 8指標の実装と思考プロセス

LCP・CLS・TBT・FCP を中心に改善した実装内容。最初に「画像最適化さえすれば済む」と思っていたが、実際は JavaScript の分割とフォントのプリロードが支配的だった、というような実際の試行錯誤を自然に織り込む。

各指標の改善コードは Day 2 で記載する。

## 指標の改善はデータ分析のサイクルと同じ

Web パフォーマンス改善は「現状計測 → ボトルネック仮説 → 施策実施 → 再計測」で回る。SQL チューニングで EXPLAIN を読み、インデックスを張り、再実行する流れと構造が同じだ。PSI MCP によってスコアが Claude の手元に届くと、AI がこのサイクルを自律的に回せる状態になる。測定のコストが下がると、改善頻度が自然に上がる。

## 改善前後のスコア

（Day 2 で計測値を入れる。Performance XX → XX、LCP X.Xs → X.Xs、TBT XXXms → XXXms など実測値のみ記載）
