#!/usr/bin/env bash
# Zennのslug仕様 (12〜50文字、英小文字/数字/ハイフン/アンダースコア) を検証する
#
# 使い方:
#   ./scripts/validate-slug.sh "20260428-slack-bot"
#
# 終了コード:
#   0: OK
#   1: 形式エラー
#
# 参考: https://zenn.dev/zenn/articles/what-is-slug

set -euo pipefail

SLUG="${1:-}"

if [[ -z "${SLUG}" ]]; then
  echo "❌ slugが指定されていません" >&2
  echo "使い方: $0 <slug>" >&2
  exit 1
fi

LENGTH=${#SLUG}

# 文字数チェック (12-50文字)
if (( LENGTH < 12 )) || (( LENGTH > 50 )); then
  echo "❌ slugの文字数が範囲外です: ${LENGTH}文字 (許容: 12-50)" >&2
  echo "   slug: ${SLUG}" >&2
  echo "   ヒント: THEME_SLUGを最低3文字以上にしてください (YYYYMMDD = 8文字 + - + 3文字 = 12文字)" >&2
  exit 1
fi

# 形式チェック (英小文字/数字/ハイフン/アンダースコアのみ)
if [[ ! "${SLUG}" =~ ^[a-z0-9_-]+$ ]]; then
  echo "❌ slugに使えない文字が含まれています" >&2
  echo "   slug: ${SLUG}" >&2
  echo "   許容: 英小文字 (a-z) / 数字 (0-9) / ハイフン (-) / アンダースコア (_)" >&2
  exit 1
fi

echo "✅ slug OK: ${SLUG} (${LENGTH}文字)"
exit 0
