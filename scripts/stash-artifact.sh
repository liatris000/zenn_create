#!/usr/bin/env bash
# 成果物を公開する前に、退避ブランチ artifact-stash/<リポジトリ名> へ保存する
#
# 使い方:
#   ./scripts/stash-artifact.sh <リポジトリ名> <ローカル成果物ディレクトリ> <記事タイトル> [enable_pages]
#
# ─── 何のためのスクリプトか ──────────────────────────────────────
# 成果物は Day 2 セッションの /tmp/zenn_artifact にしか無い。公開スクリプトが起動前に
# 権限判定で拒否されると一時ブランチ artifact/<name> も作られず、セッション終了で成果物が
# 消える。Day 3 は再試行できず、2026-11-03 (#114) と 2026-11-10 (#134) の 2 週続けて
# 人が対話セッションで作り直すことになった。
#
# 公開の前にここで保存しておけば、Day 3 の retry-artifact-publish.sh がこのブランチから
# 公開をやり直せる。退避ブランチの名前は artifact/** に当たらないので、push しても
# 公開のワークフローは起動しない。公開に成功すると publish-artifact.sh が消す。
#
# GitHub API は使わず、git push だけを使う。

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
if [[ ! -d "${LOCAL_DIR}" ]]; then
  echo "❌ ローカルディレクトリが存在しません: ${LOCAL_DIR}" >&2
  exit 1
fi

# shellcheck source=scripts/lib/artifact-publish.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/artifact-publish.sh"
ap_init "${REPO_NAME}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

mkdir -p "${WORK}/_artifact"
cp -R "${LOCAL_DIR}/." "${WORK}/_artifact/"
rm -rf "${WORK}/_artifact/.git"
jq -n --arg title "${ARTICLE_TITLE}" --arg pages "${ENABLE_PAGES}" \
  '{article_title:$title, enable_pages:$pages}' > "${WORK}/.artifact-stash.json"

git -C "${WORK}" init -q
git -C "${WORK}" add -A
if [[ -z "$(git -C "${WORK}" ls-files -- _artifact)" ]]; then
  echo "❌ 成果物が空です: ${LOCAL_DIR}" >&2
  exit 1
fi
git -C "${WORK}" -c user.email=noreply@anthropic.com -c user.name=Claude \
  commit -q -m "stash: ${REPO_NAME}"
git -C "${WORK}" push -q -f "${AP_REMOTE}" "HEAD:refs/heads/${AP_STASH_BRANCH}"

echo "✅ 成果物を退避しました: ${AP_STASH_BRANCH} ($(git -C "${WORK}" ls-files -- _artifact | wc -l | tr -d ' ') ファイル)"
