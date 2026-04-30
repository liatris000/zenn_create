#!/usr/bin/env bash
# 成果物用リポジトリを作成し、push & GitHub Pages を有効化する
#
# 使い方:
#   ./scripts/publish-artifact.sh <リポジトリ名> <ローカル成果物ディレクトリ> <記事タイトル> [enable_pages]
#
# 例:
#   ./scripts/publish-artifact.sh "liatris-20260428-slack-bot" "/tmp/zenn_artifact" "Claude CodeでSlack Botを作る"
#   ./scripts/publish-artifact.sh "liatris-20260428-slack-bot" "/tmp/zenn_artifact" "Claude CodeでSlack Botを作る" "true"
#
# 出力 (環境変数として export):
#   REPO_URL  - GitHubリポジトリURL
#   PAGES_URL - GitHub Pages URL (HTML系成果物の場合)
#
# 必要な環境変数:
#   GITHUB_TOKEN  (またはGITHUB_ACCESS_TOKEN)

set -euo pipefail

REPO_NAME="${1:-}"
LOCAL_DIR="${2:-}"
ARTICLE_TITLE="${3:-}"
ENABLE_PAGES="${4:-true}"

if [[ -z "${REPO_NAME}" || -z "${LOCAL_DIR}" || -z "${ARTICLE_TITLE}" ]]; then
  echo "❌ 引数が足りません" >&2
  echo "使い方: $0 <リポジトリ名> <ローカル成果物ディレクトリ> <記事タイトル> [enable_pages=true]" >&2
  exit 1
fi

# トークン解決 (GITHUB_TOKEN または GITHUB_ACCESS_TOKEN)
TOKEN="${GITHUB_TOKEN:-${GITHUB_ACCESS_TOKEN:-}}"
if [[ -z "${TOKEN}" ]]; then
  echo "❌ GITHUB_TOKEN (または GITHUB_ACCESS_TOKEN) が未設定です" >&2
  exit 1
fi

GITHUB_USER="${GITHUB_USER:-liatris000}"

if [[ ! -d "${LOCAL_DIR}" ]]; then
  echo "❌ ローカルディレクトリが存在しません: ${LOCAL_DIR}" >&2
  exit 1
fi

echo "📦 リポジトリ作成: ${REPO_NAME}"

# リポジトリ作成 (既に存在する場合はskip)
CREATE_RESPONSE=$(curl -sS -X POST \
  -H "Authorization: token ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  "https://api.github.com/user/repos" \
  -d "{
    \"name\": \"${REPO_NAME}\",
    \"description\": $(printf '%s' "${ARTICLE_TITLE}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),
    \"private\": false,
    \"auto_init\": true
  }" 2>&1) || true

if echo "${CREATE_RESPONSE}" | grep -q '"name already exists"'; then
  echo "ℹ️  リポジトリは既に存在: ${REPO_NAME} (続行)"
elif echo "${CREATE_RESPONSE}" | grep -q '"html_url"'; then
  echo "✅ リポジトリ作成完了"
else
  echo "❌ リポジトリ作成失敗:" >&2
  echo "${CREATE_RESPONSE}" >&2
  exit 1
fi

REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}"

# 成果物をpush
echo "📤 成果物をpush中..."
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

cp -R "${LOCAL_DIR}/." "${WORK_DIR}/"
cd "${WORK_DIR}"

# _claude_template/ → .claude/ に展開
# Claude が .claude/ パスに直接書けない仕様への対処
if [[ -d "${WORK_DIR}/_claude_template" ]]; then
  echo "📁 _claude_template/ を .claude/ に展開中..."
  mkdir -p "${WORK_DIR}/.claude"
  cp -R "${WORK_DIR}/_claude_template/." "${WORK_DIR}/.claude/"
  rm -rf "${WORK_DIR}/_claude_template"
  echo "✅ .claude/ に配置完了"
fi

git init -q
git checkout -q -b main 2>/dev/null || git checkout -q main
git remote add origin "https://${TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

# auto_init で初期commitがある場合に備えて pull (失敗してもOK)
git pull --rebase origin main 2>/dev/null || true

git add -A
if git diff --cached --quiet; then
  echo "ℹ️  push対象なし"
else
  git commit -q -m "初回コミット: ${ARTICLE_TITLE}"
  git push -q origin main
  echo "✅ push完了"
fi

# GitHub Pages 有効化
PAGES_URL=""
if [[ "${ENABLE_PAGES}" == "true" ]]; then
  echo "🌐 GitHub Pages 有効化中..."
  PAGES_RESPONSE=$(curl -sS -X POST \
    -H "Authorization: token ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    "https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}/pages" \
    -d '{"source":{"branch":"main","path":"/"}}' 2>&1) || true

  if echo "${PAGES_RESPONSE}" | grep -q '"html_url"'; then
    echo "✅ Pages有効化完了"
  elif echo "${PAGES_RESPONSE}" | grep -qE '(already exists|already_exists)'; then
    echo "ℹ️  Pagesは既に有効"
  else
    echo "⚠️  Pages有効化レスポンス:"
    echo "${PAGES_RESPONSE}" | head -5
  fi
  PAGES_URL="https://${GITHUB_USER}.github.io/${REPO_NAME}/"
fi

# 結果出力 (eval $(./scripts/publish-artifact.sh ...) で取り込める形式)
echo ""
echo "─── 結果 ───────────────────────────"
echo "REPO_URL=${REPO_URL}"
[[ -n "${PAGES_URL}" ]] && echo "PAGES_URL=${PAGES_URL}"
echo "────────────────────────────────────"
