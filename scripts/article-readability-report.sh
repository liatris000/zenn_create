#!/usr/bin/env bash
# 記事の見やすさを数えて表示する(docs/article-style-guide.md の「見やすさ」「全体像の図」「持ち帰れる締め」)。
#
# 判定はせず数えるだけ。直すかどうかは Day 3 のセルフレビューで決める。
# 背景: 2026-11 の振り返りで、文の途中の改行・長い文・地の文のコード表記・図がない・リンクで終わる、
# が繰り返し見つかったが、どれも既存のチェックで拾えていなかった。
#
# 使い方:
#   bash scripts/article-readability-report.sh articles/xxx.md [articles/yyy.md ...]
#
# 終了コード: 常に 0(ファイルが無いときだけ 1)

set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  echo "usage: $0 articles/xxx.md [...]" >&2
  exit 1
fi

for f in "$@"; do
  [[ -f "$f" ]] || { echo "not found: $f" >&2; exit 1; }
done

python3 - "$@" <<'PY'
import re
import sys

for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    body = text.split("---", 2)[2] if text.startswith("---") else text
    body = re.sub(r":::message.*?:::", "", body, flags=re.S)

    diagrams = len(re.findall(r"^```mermaid", body, flags=re.M)) + len(re.findall(r"!\[", body))

    # 地の文の段落を集める(コードブロック・表・見出し・リスト・引用・埋め込みは除く)
    paragraphs, current, in_code = [], [], False
    for line in body.splitlines():
        if line.startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        s = line.strip()
        if not s or s.startswith(("#", "|", "-", "*", ">", "@[", "!", ":::")) or re.match(r"\d+\.", s):
            if current:
                paragraphs.append(current)
            current = []
            continue
        current.append(s)
    if current:
        paragraphs.append(current)

    mid_breaks = sum(
        1 for p in paragraphs for line in p[:-1] if not re.search(r"[。！？」』）):：]$", line)
    )
    joined = ["".join(p) for p in paragraphs]
    sentences = [s for para in joined for s in re.split(r"(?<=[。！？])", para) if len(s) > 3]
    long_sentences = sum(len(s) > 80 for s in sentences)
    long_paragraphs = sum(len(p) > 200 for p in joined)
    inline_code = sum(len(re.findall(r"`[^`]+`", p)) for p in joined)
    dense_paragraphs = sum(len(re.findall(r"`[^`]+`", p)) > 2 for p in joined)

    tail = [l.strip() for l in body.splitlines() if l.strip()]
    ends_with_link = bool(tail) and (tail[-1].startswith("@[") or re.match(r"^(デモ|https?://)", tail[-1]) is not None)

    print(f"== {path}")
    print(f"  図(Mermaid・画像)          : {diagrams}{'  ← 全体像の図がない' if diagrams == 0 else ''}")
    print(f"  文の途中の改行              : {mid_breaks}{'  ← 段落を 1 行にまとめる' if mid_breaks else ''}")
    print(f"  80 字を超える文             : {long_sentences}")
    print(f"  200 字を超える段落          : {long_paragraphs}")
    print(f"  地の文のコード表記          : {inline_code}(3 個以上入った段落 {dense_paragraphs})")
    print(f"  リンクで終わっている        : {'はい  ← 最後の段落を持ち帰れる一言にする' if ends_with_link else 'いいえ'}")
PY
