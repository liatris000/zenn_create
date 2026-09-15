---
title: "ブレークポイントの間の幅で崩れるレイアウトを自動検出する"
emoji: "📐"
type: "tech"
topics: ["playwright", "css", "frontend", "claudecode", "ai"]
pattern: "implementation"
published: false
published_at: "2026-10-08 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20261008-responsive-width-sweep_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事](https://zenn.dev/liatris/articles/20260701-zenn-kickoff)にまとめています。
:::

375 / 768 / 1280px。レスポンシブ対応の確認は、だいたいこの3点で行う。だが実際の画面幅は連続していて、確認していない850pxのような半端な幅で崩れていても気づけない。

固定ビューポートのスクリーンショット比較(VRT)も前提は同じで、あらかじめ決めた幅でしか撮らない。回避策として案内されているのは「ビューポートを少しずつ広げて、崩れ始める箇所を目で探す」という手作業だった。手順が明文化されているということは、自動化できる余地があるということでもある。

## ざっくりとしたアーキテクチャ

やることはシンプルで、幅を掃引しながらページを評価し、崩れ始める境界を特定する。

- 入力: 対象URLと掃引する幅の範囲
- 掃引: 幅を一定の刻みで変えながらページを評価する
- 判定: スクリーンショット差分ではなく、DOMのレイアウト計測値で判定する
  - `document.documentElement.scrollWidth > clientWidth`(横スクロールの発生)
  - 各要素の `getBoundingClientRect().right` が `clientWidth` を超えていないか
- 出力: 崩れ始めた幅(境界)と、原因になった要素

スクショ比較にしなかったのは、ベースラインがないと「崩れているか」ではなく「前と違うか」しか分からないからだ。今回のように初回の掃引で答えを出したい用途には向かない。

## 実装

サンプルとして、3点チェックでは気づけない崩れ方をするページを用意した。サイドバー(固定260px)とメインの2カラムに加えて、`@media (min-width: 800px)` で幅280pxの「インサイトパネル」が追加表示される。タブレット以上なら余白があるはずという前提で足した要素だが、800px台の前半はまだその余白がない。

掃引スクリプトは Playwright(1.56.1)で書いた。粗い刻みで壊れ/壊れないの遷移点を探し、そこだけ二分探索で1px単位に詰める構成にしている。全幅を1pxずつ見ると遅く、かといって刻みを粗くしたままでは境界がぼやけるため、この2段構成に落ち着いた。

```js
async function checkBreakage(page, width) {
  await page.setViewportSize({ width, height: 900 });
  return page.evaluate(() => {
    const doc = document.documentElement;
    const horizontalOverflow = doc.scrollWidth > doc.clientWidth;
    let elementOverflow = false;
    for (const el of document.querySelectorAll("body *")) {
      const rect = el.getBoundingClientRect();
      if (rect.width > 0 && rect.right > doc.clientWidth + 1) {
        elementOverflow = true;
        break;
      }
    }
    return { horizontalOverflow, elementOverflow, broken: horizontalOverflow || elementOverflow };
  });
}

async function refineBoundary(page, lo, hi, loBroken) {
  while (hi - lo > 1) {
    const mid = Math.floor((lo + hi) / 2);
    const result = await checkBreakage(page, mid);
    if (result.broken === loBroken) lo = mid; else hi = mid;
  }
  return hi;
}
```

320〜1440pxを40px刻みで掃引したところ、実際に次の結果が出た。

```json
{
  "boundaries": [
    { "type": "崩れ開始", "boundaryWidth": 800, "overflowingSelector": "aside.insights" },
    { "type": "崩れ解消", "boundaryWidth": 912, "overflowingSelector": "aside.insights" }
  ]
}
```

375 / 768 / 1280pxを個別に見ると全部「問題なし」で、850pxだけ横スクロールが発生する。3点チェックが構造的に見逃す帯域が、数字として出てきた。

最初はスクリーンショット差分で判定しようとしていた。だがベースラインがない初回の掃引では「差分がある」としか言えず、それが崩れなのか単なる表示のばらつきなのかを判別できないことに気づいて、レイアウト計測値による判定に切り替えた。誤検知の扱いも同様で、意図的なはみ出し(横スクロールを前提にしたカルーセル等)は今回のスクリプトでは区別できない。対象を絞ってから流すか、要素単位で除外リストを持たせる必要がある。

## データアナリスト視点

「375 / 768 / 1280pxで確認した」は、連続量である画面幅を3標本で代表させているということだ。標本の取り方を決めずに「確認済み」と言うと、標本と標本のあいだの挙動を暗黙に外挿していることになる。今回のように掃引して境界を実測すると、それまで外挿に頼っていた区間が実測値に置き換わる。800〜912pxという範囲は、標本を増やさない限り検証も反証もできなかった領域だった。

## 成果物

<!-- ARTIFACT_LINKS -->

サンプルページと掃引スクリプトは上記リポジトリに置いてある。`npm install` して `npm run serve` でサンプルを立ち上げ、`npm run sweep` で掃引を実行できる。
