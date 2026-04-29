#!/usr/bin/env bash
# 記事PRを作成する (ブランチ切り → push → PR API)
#
# 使い方:
#   ./scripts/create-article-pr.sh <article_slug> <article_md_path> <article_title> <repo_url> <pages_url> <published_at>
#
# 例:
#   ./scripts/create-article-pr.sh \
#     "20260428-slack-bot" \
#     "/tmp/zenn_artifact/article_draft.md" \
#     "Claude CodeでSlack Botを作る" \
#     "https://github.com/liatris000/liatris-20260428-slack-bot" \
#     "https://liatris000.github.io/liatris-20260428-slack-bot/" \
#     "2026-04-29 07:00"
#
# 出力:
#   PR_URL  - 作成したPRのURL
#   BRANCH  - 作成したブランチ名
#
# 必要な環境変数:
#   GITHUB_TOKEN (またはGITHUB_ACCESS_TOKEN)

set -euo pipefail

ARTICLE_SLUG="${1:-}"
ARTICLE_MD_PATH="${2:-}"
ARTICLE_TITLE="${3:-}"
REPO_URL="${4:-}"
PAGES_URL="${5:-}"
PUBLISHED_AT="${6:-}"

if [[ -z "${ARTICLE_SLUG}" || -z "${ARTICLE_MD_PATH}" || -z "${ARTICLE_TITLE}" ]]; then
  echo "❌ 引数が足りません" >&2
  echo "使い方: $0 <slug> <md_path> <title> <repo_url> <pages_url> <published_at>" >&2
  exit 1
fi

if [[ ! -f "${ARTICLE_MD_PATH}" ]]; then
  echo "❌ 記事ファイルが見つかりません: ${ARTICLE_MD_PATH}" >&2
  exit 1
fi

TOKEN="${GITHUB_TOKEN:-${GITHUB_ACCESS_TOKEN:-}}"
if [[ -z "${TOKEN}" ]]; then
  echo "❌ GITHUB_TOKEN (または GITHUB_ACCESS_TOKEN) が未設定です" >&2
  exit 1
fi

GITHUB_USER="${GITHUB_USER:-liatris000}"
REPO_NAME="${ZENN_REPO_NAME:-zenn_create}"

# slugを検証
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/validate-slug.sh" "${ARTICLE_SLUG}"

# zenn_createリポジトリの場所 (環境変数で上書き可能)
ZENN_REPO_DIR="${ZENN_REPO_DIR:-${HOME}/zenn_create}"

if [[ ! -d "${ZENN_REPO_DIR}/.git" ]]; then
  echo "❌ zenn_createリポジトリが見つかりません: ${ZENN_REPO_DIR}" >&2
  echo "   ZENN_REPO_DIR 環境変数で場所を指定できます" >&2
  exit 1
fi

cd "${ZENN_REPO_DIR}"

BRANCH="article/${ARTICLE_SLUG}"

echo "🌿 ブランチ作成: ${BRANCH}"
git checkout main -q
git pull -q origin main

# 既存ブランチがあれば削除して切り直し
git branch -D "${BRANCH}" 2>/dev/null || true
git push origin --delete "${BRANCH}" 2>/dev/null || true
git checkout -q -b "${BRANCH}"

# 記事ファイルをコピー
mkdir -p articles
cp "${ARTICLE_MD_PATH}" "articles/${ARTICLE_SLUG}.md"

git add "articles/${ARTICLE_SLUG}.md"

# images/ もあればpush対象に
if [[ -n "$(git status --porcelain images/ 2>/dev/null)" ]]; then
  git add images/
fi

if git diff --cached --quiet; then
  echo "❌ commit対象なし (記事ファイルが既存と同一?)" >&2
  exit 1
fi

git -c user.name="Liatris Bot" -c user.email="liatris-bot@users.noreply.github.com" \
  commit -q -m "記事追加: ${ARTICLE_TITLE}"

# pushにトークン埋め込み (履歴に残らないよう pushURL を一時的に上書き)
PUSH_URL="https://${TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"
git push -q "${PUSH_URL}" "${BRANCH}"
echo "✅ push完了"

# PR本文を組み立て
PR_BODY=$(cat <<BODY_EOF
## 概要
題材: ${ARTICLE_TITLE}

## 成果物
- リポジトリ: ${REPO_URL}
- 公開URL: ${PAGES_URL}

## 公開設定
- published: true
- published_at: ${PUBLISHED_AT}（JST、この時刻まで未公開で待機）
- slug: ${ARTICLE_SLUG}（公開後変更不可）

## ローカルプレビュー
\`\`\`
git checkout ${BRANCH}
npx zenn preview
# http://localhost:8000 で確認
\`\`\`

## 確認事項
- [ ] 記事の内容確認
- [ ] 成果物の動作確認
- [ ] サムネイル画像の確認
- [ ] 記事内スクリーンショットの確認
- [ ] published_at の日時確認（必要なら修正）
- [ ] slug が変更不要であることの確認
- [ ] OK ならマージ → 指定時刻に自動公開
BODY_EOF
)

# PR API
echo "📋 PR作成中..."
PR_TITLE="[$(date +%Y%m%d)] ${ARTICLE_TITLE}"
PR_PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({
    'title': sys.argv[1],
    'body': sys.argv[2],
    'head': sys.argv[3],
    'base': 'main'
}))
" "${PR_TITLE}" "${PR_BODY}" "${BRANCH}")

PR_RESPONSE=$(curl -sS -X POST \
  -H "Authorization: token ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/pulls" \
  -d "${PR_PAYLOAD}")

PR_URL=$(echo "${PR_RESPONSE}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('html_url', ''))
except Exception:
    print('')
")

if [[ -z "${PR_URL}" ]]; then
  echo "❌ PR作成失敗:" >&2
  echo "${PR_RESPONSE}" | head -20 >&2
  exit 1
fi

echo "✅ PR作成完了: ${PR_URL}"
echo ""
echo "─── 結果 ───────────────────────────"
echo "PR_URL=${PR_URL}"
echo "BRANCH=${BRANCH}"
echo "────────────────────────────────────"
