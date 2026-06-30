#!/usr/bin/env bash
#
# next-publish-slot.sh
#
# 週刊連載キューの「次の空きスロット」を算出する。
#
# 方針:
#   - articles/*.md の frontmatter `published_at` の最大日付 + 7 日 を次スロットとする
#     (キューが毎週木 07:00 なので +7 日で木曜のまま末尾に積み上がる)
#   - 既存の published_at が 1 件も無い場合は、今日以降の次の木曜 07:00 にフォールバック
#
# 出力 (eval して使う想定):
#   SLUG_DATE=YYYYMMDD
#   PUBLISHED_AT="YYYY-MM-DD 07:00"
#
# 使用例 (day1-kickoff):
#   eval "$(./scripts/next-publish-slot.sh)"
#   export ARTICLE_SLUG="${SLUG_DATE}-${THEME_SLUG}"
#
set -euo pipefail

PUBLISH_TIME="07:00"
PUBLISH_DOW=4   # 木曜 (date +%u: 1=月 ... 7=日)

# $1=YYYY-MM-DD, $2=加算日数 -> YYYY-MM-DD (Linux / macOS 両対応)
add_days() {
  date -d "$1 + $2 days" +%Y-%m-%d 2>/dev/null \
    || date -j -v+"$2"d -f "%Y-%m-%d" "$1" +%Y-%m-%d
}

# $1=YYYY-MM-DD -> 曜日番号 (1=月 ... 7=日)
dow_of() {
  date -d "$1" +%u 2>/dev/null \
    || date -j -f "%Y-%m-%d" "$1" +%u
}

# 既存 published_at の最大日付 (YYYY-MM-DD)。文字列ソートで OK (固定桁フォーマット)
MAX_DATE=$(grep -rhoE 'published_at:[[:space:]]*"[0-9]{4}-[0-9]{2}-[0-9]{2}' articles/*.md 2>/dev/null \
  | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' \
  | sort \
  | tail -1)

if [ -n "${MAX_DATE}" ]; then
  NEXT_DATE=$(add_days "${MAX_DATE}" 7)
else
  # 予約が 1 件も無い → 今日以降の次の木曜
  TODAY=$(date +%Y-%m-%d)
  DOW=$(dow_of "${TODAY}")
  DIFF=$(( (PUBLISH_DOW - DOW + 7) % 7 ))
  [ "${DIFF}" -eq 0 ] && DIFF=7   # 今日が木曜なら来週へ
  NEXT_DATE=$(add_days "${TODAY}" "${DIFF}")
fi

SLUG_DATE=$(printf '%s' "${NEXT_DATE}" | tr -d '-')

printf 'SLUG_DATE=%s\n' "${SLUG_DATE}"
printf 'PUBLISHED_AT="%s %s"\n' "${NEXT_DATE}" "${PUBLISH_TIME}"
