#!/usr/bin/env bash
# ChatworkにPR通知を送る
#
# 使い方 (2 モード):
#
# モード A: 定型フォーマット (Day 1 / Day 2 で使用、後方互換)
#   ./scripts/notify-chatwork.sh <article_topic> <article_title> <word_count> <published_at> <pages_url> <repo_url> <pr_url>
#
#   例:
#     ./scripts/notify-chatwork.sh \
#       "Slack Bot" \
#       "Claude CodeでSlack Botを作る" \
#       "2150" \
#       "2026-04-29 07:00" \
#       "https://liatris000.github.io/liatris-20260428-slack-bot/" \
#       "https://github.com/liatris000/liatris-20260428-slack-bot" \
#       "https://github.com/liatris000/zenn_create/pull/12"
#
# モード B: カスタム本文 (Day 3 のチェックポイント等で使用)
#   ./scripts/notify-chatwork.sh --body "<本文文字列>"
#
#   例:
#     ./scripts/notify-chatwork.sh --body "$CHECKPOINT_BODY"
#
#   --body モードでは渡された文字列をそのまま Chatwork に送る (装飾なし)。
#   メンション (CHATWORK_ACCOUNT_ID) があれば先頭に付与する。
#
# 必要な環境変数:
#   CHATWORK_API_TOKEN
#   CHATWORK_ROOM_ID
#   CHATWORK_ACCOUNT_ID  (オプション、メンション用)

set -euo pipefail

if [[ -z "${CHATWORK_API_TOKEN:-}" || -z "${CHATWORK_ROOM_ID:-}" ]]; then
  echo "❌ CHATWORK_API_TOKEN または CHATWORK_ROOM_ID が未設定です" >&2
  exit 1
fi

# メンション (CHATWORK_ACCOUNT_IDがあれば付与)
MENTION=""
if [[ -n "${CHATWORK_ACCOUNT_ID:-}" ]]; then
  MENTION="[To:${CHATWORK_ACCOUNT_ID}]
"
fi

# モード判定: 第 1 引数が --body ならカスタム本文モード
if [[ "${1:-}" == "--body" ]]; then
  CUSTOM_BODY="${2:-}"
  if [[ -z "${CUSTOM_BODY}" ]]; then
    echo "❌ --body モードでは本文文字列が必須です" >&2
    echo "使い方: $0 --body \"<本文文字列>\"" >&2
    exit 1
  fi
  BODY="${MENTION}${CUSTOM_BODY}"
else
  # 定型フォーマットモード (後方互換)
  ARTICLE_TOPIC="${1:-}"
  ARTICLE_TITLE="${2:-}"
  WORD_COUNT="${3:-?}"
  PUBLISHED_AT="${4:-}"
  PAGES_URL="${5:-}"
  REPO_URL="${6:-}"
  PR_URL="${7:-}"

  if [[ -z "${ARTICLE_TITLE}" || -z "${PR_URL}" ]]; then
    echo "❌ 引数が足りません (最低限ARTICLE_TITLEとPR_URLは必須)" >&2
    echo "使い方:" >&2
    echo "  $0 <topic> <title> <word_count> <published_at> <pages_url> <repo_url> <pr_url>" >&2
    echo "  $0 --body \"<本文文字列>\"" >&2
    exit 1
  fi

  DATE_STR="$(date '+%Y-%m-%d')"

  BODY="${MENTION}[info][title]📝 今日のZenn記事草稿 (${DATE_STR})[/title]題材：${ARTICLE_TOPIC}
タイトル：${ARTICLE_TITLE}
文字数：${WORD_COUNT}字
予約公開：${PUBLISHED_AT}（JST）

🔗 成果物：${PAGES_URL}
📦 リポジトリ：${REPO_URL}
📋 PR：${PR_URL}

内容を確認してマージすると、${PUBLISHED_AT} に自動公開されます。
公開タイミングを変更したい場合は published_at を修正してください。
[/info]"
fi

HTTP_CODE=$(curl -sS -o /tmp/chatwork_response.json -w "%{http_code}" \
  -X POST \
  -H "x-chatworktoken: ${CHATWORK_API_TOKEN}" \
  --data-urlencode "body=${BODY}" \
  "https://api.chatwork.com/v2/rooms/${CHATWORK_ROOM_ID}/messages")

if [[ "${HTTP_CODE}" -eq 200 ]]; then
  MESSAGE_ID=$(python3 -c "
import json
try:
    d = json.load(open('/tmp/chatwork_response.json'))
    print(d.get('message_id', ''))
except Exception:
    print('')
")
  echo "✅ Chatwork通知送信完了 (message_id=${MESSAGE_ID})"
else
  echo "❌ Chatwork通知失敗 (HTTP=${HTTP_CODE})" >&2
  cat /tmp/chatwork_response.json >&2 2>/dev/null || true
  exit 1
fi
