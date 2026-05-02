---
title: "PSI MCP × Claude Code で Core Web Vitals を改善する"
emoji: "⚡"
type: "tech"
topics: ["claudecode", "nextjs", "mcp", "performance"]
pattern: "implementation"
published: false
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260430-nextjs-psi-with-claude_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事(note)](https://note.com/liatris000)にまとめています。
:::

## Claude Code で作ってると、こういうのに出会う

Claude Code で何かを作っていると、本業でも副業でも、自分の専門領域から少しはみ出したツールに触れる場面が来る。私の場合、それが PageSpeed Insights (以下 PSI) だった。

PSI は Google が提供する Web ページ表示速度の計測ツールで、検索順位にも影響する Core Web Vitals (LCP / INP / CLS) を測ってくれる。EC サイトを運用していると無視できない数値だが、私自身は本格的に触ったことがなかった。

「やったほうがいい」と分かっていながら腰が重い領域、というのは Claude Code ユーザーなら他にもあるはずだ。デザインツールの API、SEO 計測、アクセシビリティチェッカー、サードパーティサービスのダッシュボード自動化 ── どれも「専門ではないけど触れたほうがいい」という距離感のもの。

この記事は、そういうツールの 1 つである PSI に Claude Code 経由で MCP サーバーを繋いで、AI と一緒に手探りで進めた記録だ。専門家の解説ではなく、未知のツールを AI と並走で学ぶ段取りの参考になればと思う。

## スコアが崩れていた

Next.js で構築した EC サイトの PageSpeed Insights スコアが、機能追加のたびに少しずつ下がっていた。LCP と TBT (Total Blocking Time、メインスレッドが反応できない時間の合計) がいずれも Lighthouse の「要改善」判定を超えていた。「後でまとめて直す」を繰り返した結果だ。

手動で Lighthouse を回す作業は地味にコストがかかる。URL を開いて、スコアを読んで、「Opportunities」を確認して、コードに戻る。この往復が面倒で後回しになっていた。MCP サーバーを介すと AI が外部 API の計測機能を直接呼べる形にできる、というのを知って試してみた。Claude Code に PSI の MCP サーバーを接続したら、スコアの取得から改善指示、コード修正まで一気通貫でできることが分かった。

## PSI MCP とセットアップ

[ruslanlap/pagespeed-insights-mcp](https://github.com/ruslanlap/pagespeed-insights-mcp) は PageSpeed Insights API をラップした MCP サーバー。チャットから「このURLのスコアを取って」と指示すると、LCP・INP・CLS・FCP・TTFB・TBT・Performance スコアが構造化データで返ってくる。「Opportunities に何がある？」と続けると優先度付きで修正候補が出てくる。

正直なところ Opportunities が何を指すのか最初は分からなかった。Claude Code に聞いたら「PSI が示す改善候補リストで、推定の節約時間つきで返ってきます」と説明され、そこから項目を 1 つずつ意味を確認しながら触っていった。

[Google Cloud Console](https://console.cloud.google.com/) で PageSpeed Insights API を有効化し API キーを発行。次に `.claude/mcp.json` に追記する:

```json:.claude/mcp.json
{
  "mcpServers": {
    "pagespeed": {
      "command": "npx",
      "args": ["-y", "pagespeed-insights-mcp"],
      "env": { "PSI_API_KEY": "<YOUR_API_KEY>" }
    }
  }
}
```

Claude Code を再起動すると `pagespeed` ツールが有効になる。

## 改善の進め方

```mermaid
flowchart TD
    A[PSI スコア取得] --> B{Performance < 90?}
    B -- No --> G[完了]
    B -- Yes --> C[Opportunities 一覧化]
    C --> D[影響が大きい 1 項目を選択]
    D --> E[Claude Code が修正を実装]
    E --> F["再計測 (3〜5回, 中央値)"]
    F --> B
```

「Opportunities を全部直して」と一度に指示すると修正が干渉し合う場合がある。1 項目ずつ修正して再計測するループを回した方が、何が効いたかが明確になる。変数を 1 つに絞って効果を検証する A/B テストの基本と同じ構造だ。

## 主な改善実装

### ヒーロー画像（LCP）

最初の手がかりはここでも対話だった:

> 私: PSI のスコアは取れたけど、どこから直せばいいか分からない
> Claude: Opportunities の上位は LCP 関連で、ヒーロー画像に preload 提案が出ています。`next/image` に置き換えますか?

この一往復で「LCP から触る」と方針が決まった。`<img>` を `next/image` + `priority` に変えると `<link rel="preload">` が生成され LCP 要素の発見が早くなる。最初は `sizes` を省略していたが、モバイルで不必要に大きい画像を送り続けていたため追加した:

```tsx:components/HeroSection.tsx
// Before
<img src="/hero.jpg" alt="hero" style={{ width: '100%' }} />

// After
import Image from 'next/image'
<Image src="/hero.jpg" alt="hero" width={1200} height={600}
  priority sizes="(max-width: 768px) 100vw, 1200px" />
```

### フォント（FCP・LCP）

Google Fonts を `<link>` で読み込むとレンダリングブロッキングが発生する。`next/font` に切り替えるとセルフホスティングされ外部リクエストが消える:

```html
<!-- Before: _document.tsx で <link> 直書き -->
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+JP&display=swap" rel="stylesheet">
```

```tsx:app/layout.tsx
import { Noto_Sans_JP } from 'next/font/google'
const noto = Noto_Sans_JP({ subsets: ['latin'], weight: ['400', '700'], display: 'swap' })
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="ja" className={noto.className}><body>{children}</body></html>
}
```

### サードパーティスクリプト（TBT）

チャット系ウィジェットを直書きしていた。`next/script` の `lazyOnload` に変えると全リソース読み込み後に実行されメインスレッドのブロックがなくなる。Opportunities ではこのスクリプト由来の項目が常に上位に出ていた。最初は `afterInteractive` を試したがウィジェット起動がインタラクションと重なるケースがあったため変えた:

```tsx:app/layout.tsx
import Script from 'next/script'
<Script src="https://example-chat.com/widget.js" strategy="lazyOnload" />
```

### Tailwind CSS の purge（Speed Index）

`app/` ディレクトリ構成に移行した際、`tailwind.config.js` の `content` パスが古いままになっていた。パスが正しくないと purge が効かず未使用スタイルが大量に含まれる。Lighthouse の「Remove unused CSS」が Opportunities に出ていたら真っ先に疑う。

## 計測と再現性について

PSI は Google のサーバーから計測するため数値がぶれる。「1 回計測して改善された」ではなく、複数回取って傾向を見る習慣にした方が信頼性が上がる。SQL チューニング(私が普段関わる業務領域)で EXPLAIN を複数回実行してウォームアップを確認するのと同じ発想で、「1 回の計測値」ではなく「計測値の分布」を見るかどうかで判断の質が変わる。

PSI MCP で計測コストが下がると「実装してすぐ確認」が自然なフローになる。継続的に計測するなら CI に組み込んで PR ごとにスコアを記録していくのが次の方向だ。

Claude Code 経由で MCP を繋いだ結果、PSI は私の中で「触ったほうがいいけど後回しのツール」から「気軽に呼べる相棒」に位置を変えた。冒頭で書いた、専門外で距離を感じているツールを抱えている人は、まず MCP 経由で繋ぐところから始めるのが手っ取り早い。用語を AI に解説させながら触れる環境を作ってしまえば、未知のツールでも数日で「自分の道具」の側に寄ってくる。

## 実装サンプル

@[github](https://github.com/liatris000/liatris-20260430-nextjs-psi-mcp)

ブラウザで Before/After を確認できるショーケース: https://liatris000.github.io/liatris-20260430-nextjs-psi-mcp/

MCP 設定テンプレートと各改善コード例を置いた。
