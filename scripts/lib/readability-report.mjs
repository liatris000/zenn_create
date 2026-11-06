// 記事の見やすさを数えて表示する。scripts/article-readability-report.sh から呼ばれる。
//
// Markdown を自前の正規表現で分類すると、太字で始まる段落・Markdown のリンク・
// 入れ子のリストなどで判定が漏れる(PR #116 のレビューで 2 回続けて見つかった)。
// そこで Zenn 自身の変換 (zenn-markdown-html) で HTML にしてから数える。
// Zenn に表示されるものと同じものを数えるので、文の途中の改行も Zenn が出す <br> として数えられる。

import fs from "node:fs";
import { load } from "cheerio";
import markdownToHtml from "zenn-markdown-html";

const LONG_SENTENCE = 80;
const LONG_PARAGRAPH = 200;
const DENSE_CODE = 3;

function stripFrontmatter(text) {
  const m = text.match(/^---\n[\s\S]*?\n---\n/);
  return m ? text.slice(m[0].length) : text;
}

// 最後のブロックが「リンクだけ」かどうか。リンクと URL を除いた残りが、句点のない短いラベルならリンク扱い
function isLinkOnly($, el) {
  const node = $(el);
  if (el.type === "text") return true; // @[github](...) などの埋め込みは本文の外側のテキストになる
  if (node.is(".embed-block, .zenn-embedded")) return true;
  const target = node.is("ul, ol") ? node.children("li").last() : node;
  if (target.find("a").length === 0) return false;
  const rest = target
    .clone()
    .find("a")
    .remove()
    .end()
    .text()
    .replace(/https?:\/\/\S+/g, "")
    .trim();
  // 「ラベル: URL」の形(句点のない短い説明 + リンク)はリンクだけの行とみなす
  return !rest.includes("。") && rest.length <= 80;
}

export async function report(path) {
  const markdown = stripFrontmatter(fs.readFileSync(path, "utf8"));
  const html = await markdownToHtml(markdown, { embedOrigin: "https://embed.zenn.studio" });
  const $ = load(`<main>${html}</main>`);
  $("aside.msg").remove(); // 冒頭の案内(:::message)は数えない

  const diagrams = $("img").length + $(".zenn-embedded-mermaid").length;

  // 地の文の段落 = リスト・引用・表・折りたたみの中にない <p>
  const paragraphs = $("p").filter((_, p) => $(p).parents("li, blockquote, table, details").length === 0);

  let midBreaks = 0;
  let longSentences = 0;
  let longParagraphs = 0;
  let inlineCode = 0;
  let denseParagraphs = 0;
  paragraphs.each((_, p) => {
    const node = $(p);
    midBreaks += node.find("br").length;
    const codes = node.find("code").length;
    inlineCode += codes;
    if (codes >= DENSE_CODE) denseParagraphs += 1;
    const text = node.text().replace(/\s*\n\s*/g, "");
    if (text.length > LONG_PARAGRAPH) longParagraphs += 1;
    for (const s of text.split(/(?<=[。！？])/)) {
      if (s.trim().length > LONG_SENTENCE) longSentences += 1;
    }
  });

  const blocks = $("main")
    .contents()
    .toArray()
    .filter((n) => !(n.type === "text" && n.data.trim() === "") && n.type !== "comment");
  const last = blocks.at(-1);
  const endsWithLink = last !== undefined && isLinkOnly($, last);

  return { diagrams, midBreaks, longSentences, longParagraphs, inlineCode, denseParagraphs, endsWithLink };
}

async function main(paths) {
  for (const path of paths) {
    const r = await report(path);
    console.log(`== ${path}`);
    console.log(`  図(Mermaid・画像)          : ${r.diagrams}${r.diagrams === 0 ? "  ← 全体像の図がない" : ""}`);
    console.log(`  文の途中の改行              : ${r.midBreaks}${r.midBreaks ? "  ← 段落を 1 行にまとめる" : ""}`);
    console.log(`  ${LONG_SENTENCE} 字を超える文             : ${r.longSentences}`);
    console.log(`  ${LONG_PARAGRAPH} 字を超える段落          : ${r.longParagraphs}`);
    console.log(`  地の文のコード表記          : ${r.inlineCode}(${DENSE_CODE} 個以上入った段落 ${r.denseParagraphs})`);
    console.log(`  リンクで終わっている        : ${r.endsWithLink ? "はい  ← 最後の段落を持ち帰れる一言にする" : "いいえ"}`);
  }
}

await main(process.argv.slice(2));
