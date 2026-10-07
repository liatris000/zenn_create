---
title: "極端な入力でレイアウトが崩れる境界を自動で探す"
emoji: "🧪"
type: "tech"
topics: ["playwright", "css", "frontend", "claudecode", "ai"]
pattern: "implementation"
published: true
published_at: "2026-10-29 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20261029-input-extremes-layout-check_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事](https://zenn.dev/liatris/articles/20260701-zenn-kickoff)にまとめています。
:::

非エンジニアが更新するページは、入力欄が自由なほど見た目が崩れる。入力欄を絞れという話はよく見るが、「どこまで絞れば足りるのか」を決める材料はあまり見かけない。そこで、極端な入力を 1 項目ずつ流し込み、崩れ始める値を二分探索で測るスクリプトを書いた。

## 全体像

動かす軸は入力内容で、画面幅ではない。カード 1 枚のサンプル HTML に対して、タイトルの文字数・本文の行数・画像の高さを 1 つずつ増やし、Playwright で DOM を計測する。スクリーンショット比較は使わず、次の 2 つだけを見る。

- 子要素が親(カード)の矩形からはみ出していないか
- 兄弟要素の矩形が重なっていないか

加えて、`scrollHeight` / `scrollWidth` が `clientHeight` / `clientWidth` を超えたら、箱の中身が溢れたものとして数える。

## サンプル HTML

カードは幅 320px・高さ 420px の固定。可変にすると画像がいくらでも伸びて、何も崩れないからだ。

```html:sample.html
<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<title>sample</title>
<style>
  body { margin: 0; font: 16px/1.6 sans-serif; }
  .card { width: 320px; height: 420px; margin: 16px; border: 1px solid #ccc; overflow: visible; }
  .card h2 { margin: 0; padding: 8px 12px; font-size: 18px; white-space: nowrap; }
  .card .thumb { display: block; width: 100%; }
  .card .body { padding: 8px 12px; height: 120px; overflow: visible; }
  .card .meta { padding: 8px 12px; border-top: 1px solid #eee; }
</style>
</head>
<body>
<article class="card" id="card">
  <h2 id="title">タイトル</h2>
  <img id="thumb" class="thumb" alt="" src="">
  <div id="body" class="body">本文</div>
  <div class="meta" id="meta">2026-10-06</div>
</article>
</body>
</html>
```

最初はカードの高さを固定しておらず、縦長画像を 4000px まで流しても「崩れない」と出た。壊れていないのではなく、カード自体が伸びて吸収していただけだった。実際のページでは親が固定高さのことが多いので、固定にして測り直した。判定ロジックより、測る対象の前提のほうが結果を左右する。

## 計測スクリプト

画像は SVG の data URI で作り、縦横比だけを変える。境界は「1 では崩れず、上限では崩れる」という単調性を仮定して二分探索する。

```javascript:probe.mjs
import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const url = pathToFileURL(resolve('sample.html')).href;

// 画像は data URI の SVG で縦横比だけを変える(幅 320 固定、高さを指定)
const svg = (w, h) =>
  'data:image/svg+xml,' + encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect width="100%" height="100%" fill="#9cf"/></svg>`);

// 1 項目だけ動かす。set(page, n) が入力を流し込む
const axes = {
  title: { unit: '文字', max: 200, set: (p, n) => p.evaluate(n => { document.getElementById('title').textContent = 'あ'.repeat(n); }, n) },
  body: { unit: '行', max: 100, set: (p, n) => p.evaluate(n => { document.getElementById('body').innerHTML = Array(n).fill('行').join('<br>'); }, n) },
  image: { unit: '高さpx', max: 4000, set: (p, n) => p.evaluate(src => { document.getElementById('thumb').src = src; }, svg(320, n)) },
};

// 崩れ判定: 子要素が親の矩形からはみ出す / 兄弟同士が重なる
const measure = (page) => page.evaluate(() => {
  const card = document.getElementById('card').getBoundingClientRect();
  const kids = [...document.getElementById('card').children];
  const rects = kids.map(k => k.getBoundingClientRect());
  const issues = [];
  kids.forEach((k, i) => {
    const r = rects[i];
    if (r.right > card.right + 0.5) issues.push(`overflow-x:${k.id}`);
    if (r.bottom > card.bottom + 0.5) issues.push(`overflow-y:${k.id}`);
    // 本文: テキストが箱より長い
    if (k.scrollHeight > k.clientHeight + 1 && k.id === 'body') issues.push('clip:body');
    if (k.scrollWidth > k.clientWidth + 1 && k.id === 'title') issues.push('clip:title');
  });
  for (let i = 0; i < rects.length; i++)
    for (let j = i + 1; j < rects.length; j++)
      if (rects[i].bottom > rects[j].top + 0.5 && rects[i].top < rects[j].bottom - 0.5
          && rects[i].right > rects[j].left && rects[i].left < rects[j].right
          && rects[i].height > 0 && rects[j].height > 0)
        issues.push(`overlap:${kids[i].id}/${kids[j].id}`);
  return issues;
});

const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
const page = await browser.newPage({ viewport: { width: 400, height: 800 } });
await page.goto(url);

const broken = async (axis, n) => {
  await page.goto(url);
  await axes[axis].set(page, n);
  await page.waitForTimeout(50);
  return (await measure(page)).length > 0;
};

for (const [axis, def] of Object.entries(axes)) {
  // 二分探索で「最初に崩れる値」を探す(単調と仮定。1 は OK 前提)
  if (!(await broken(axis, def.max))) { console.log(`${axis}: ${def.max}${def.unit}まででは崩れない`); continue; }
  let lo = 1, hi = def.max;
  while (hi - lo > 1) {
    const mid = (lo + hi) >> 1;
    (await broken(axis, mid)) ? (hi = mid) : (lo = mid);
  }
  await page.goto(url); await axes[axis].set(page, hi); await page.waitForTimeout(50);
  console.log(`${axis}: ${hi}${def.unit}で崩れ始める (${(await measure(page)).join(', ')})`);
}
await browser.close();
```

実行は Node 22.22.0 / playwright 1.56.1 で、Chromium を指定して行った。

```bash
npm i playwright@1.56.1
node probe.mjs
```

## 測った結果

同じ環境で 2 回実行し、どちらも同じ値になった。

```text
title: 17文字で崩れ始める (clip:title)
body: 6行で崩れ始める (clip:body)
image: 199高さpxで崩れ始める (overflow-y:meta)
```

タイトルは全角の「あ」を並べた場合で、18px のフォントなら 1 文字がほぼ 18px になり、内側の幅 296px に 16 文字までしか入らない。17 文字目で `white-space: nowrap` の箱が溢れる。本文は 120px の箱に 1 行 25.6px なので 4 行半、5 行までは入って 6 行目で溢れる。画像は幅 320px のとき、高さ 199px から下の `.meta` がカードの外に出た。

数値はこのサンプルの CSS とフォントでの値で、別のページにそのまま当てはまるものではない。使うのは値そのものより「どの軸が先に壊れるか」で、このカードならタイトルが最初に壊れる。

## 境界から入力制約を決める

境界が分かると、制約の根拠が書ける。タイトルは全角 16 文字以内、本文は 5 行以内、画像は縦横比を 320:199 より横長に固定してトリミングする、といった具合だ。「長すぎると崩れるので 30 文字まで」のような勘ではなく、再計測で確かめられる値になる。CSS を変えたらもう一度流せば、制約が古くなったかどうかも分かる。

この考え方は、データ分析で外れ値の影響を見る感度分析に近い。入力を 1 軸ずつ振って出力が壊れる点を探すので、制約の閾値は「測れる量」として扱える。一方で今回は 1 軸ずつしか動かしていないため、長いタイトルと多い行数が重なったときの相互作用は見ていない。

## 先に書かれている手法との違い

ビジュアルリグレッションは、変更の前後を比べる。ここでは、同じコードに対して入力だけを変えて比べている。同じ題材の画面幅スイープとは、動かす軸(画面幅か入力内容か)が違う。

なお、LLM に「崩れやすい入力」を提案させる使い方は今回の実装には入れていない。境界値は機械的に作れる範囲で足りたためで、日本語の禁則や絵文字などの癖のある入力を探す段階で必要になりそうだ。

@[github](https://github.com/liatris000/liatris-20261029-input-extremes-layout-check)
