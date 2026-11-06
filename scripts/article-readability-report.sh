#!/usr/bin/env bash
# 記事の見やすさを数えて表示する(docs/article-style-guide.md の「見やすさ」「全体像の図」「持ち帰れる締め」)。
#
# 判定はせず数えるだけ。直すかどうかは Day 3 のセルフレビューで決める。
# 背景: 2026-11 の振り返りで、文の途中の改行・長い文・地の文のコード表記・図がない・リンクで終わる、
# が繰り返し見つかったが、どれも既存のチェックで拾えていなかった。
#
# 数え方は scripts/lib/readability-report.mjs。Zenn と同じ変換(zenn-markdown-html)で HTML にしてから数える。
# 事前に npm ci が必要(Routine 環境では Setup script で入る)。
#
# 使い方:
#   bash scripts/article-readability-report.sh articles/xxx.md [articles/yyy.md ...]
#
# 終了コード: 数えられたら 0。ファイルが無い・依存が入っていないときは 1

set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  echo "usage: $0 articles/xxx.md [...]" >&2
  exit 1
fi

for f in "$@"; do
  [[ -f "$f" ]] || { echo "not found: $f" >&2; exit 1; }
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -d "${ROOT}/node_modules/zenn-markdown-html" ]]; then
  echo "zenn-markdown-html が入っていない。先に npm ci を実行する" >&2
  exit 1
fi

node "${ROOT}/scripts/lib/readability-report.mjs" "$@"
