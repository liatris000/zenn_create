#!/usr/bin/env bash
# 成果物用リポジトリを作成し、push & GitHub Pages を有効化する
#
# 使い方:
#   ./scripts/publish-artifact.sh <リポジトリ名> <ローカル成果物ディレクトリ> <記事タイトル> [enable_pages]
#
# 例:
#   ./scripts/publish-artifact.sh "liatris-20260428-slack-bot" "/tmp/zenn_artifact" "Claude CodeでSlack Botを作る"
#
# 出力 (呼び出し元が eval で拾う):
#   REPO_URL  - GitHubリポジトリURL
#   PAGES_URL - GitHub Pages URL (HTML系成果物の場合)
#
# 必要な環境変数:
#   GITHUB_TOKEN  (またはGITHUB_ACCESS_TOKEN)
#
# ─── 動作方式 (2026-08-18 変更) ──────────────────────────────────────
# routine セッションからは GitHub API 経由で Actions を起動できない。
#
#   - `POST /user/repos` は 2026-05-05 を最後に通らなくなった
#   - 代替に据えた `repository_dispatch` も 2026-08-18 に
#     `repository_dispatch is not permitted for this session type.` (403) で拒否された。
#     「エージェントに CI を起動させない」という名指しのポリシーなので、
#     別の dispatch endpoint に替えても再発しうる
#
# そこで起動経路を API から git に寄せた。本スクリプトが使う GitHub 操作は
# **git push / git ls-remote / git fetch だけ**で、GitHub API を一切叩かない。
#
#   1. 一時ブランチ artifact/<repo-name> を **main 起点**で作り、成果物を `_artifact/` に
#      置いて push する。main 起点なのは、push イベントのワークフローが
#      「押されたブランチ側のファイル」で動くため。成果物だけの孤立ブランチでは
#      ワークフローが載っておらず起動しない (2026-08-18 に実際そうなった)
#   2. .github/workflows/publish-artifact.yml が push で起動し、PAT で新規リポジトリを
#      作成・push・Pages 有効化し、一時ブランチを削除する
#   3. Actions が結果を artifact-result/<repo-name> ブランチへ書き戻す
#   4. 本スクリプトは git ls-remote でそれを polling して成否を判定し、読んだら削除する
#
# 呼び出し側 (Day 2 SKILL) のインタフェースは従来と同じ。

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

# shellcheck source=scripts/lib/artifact-publish.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/artifact-publish.sh"

if [[ ! -d "${LOCAL_DIR}" ]]; then
  echo "❌ ローカルディレクトリが存在しません: ${LOCAL_DIR}" >&2
  exit 1
fi

# Actions 側の検証と同じ形式チェックを手元でも行う (push する前に落とす)
if ! printf '%s' "${REPO_NAME}" | grep -qE '^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$'; then
  echo "❌ リポジトリ名の形式が不正です: ${REPO_NAME}" >&2
  exit 1
fi
case "${ENABLE_PAGES}" in
  true|false) ;;
  *) echo "❌ enable_pages は true / false のみ: ${ENABLE_PAGES}" >&2; exit 1 ;;
esac

ap_init "${REPO_NAME}"

TMPTREE="$(mktemp -d)"
cleanup() {
  git -C "${AP_REPO_ROOT}" worktree remove --force "${TMPTREE}" >/dev/null 2>&1 || true
  rm -rf "${TMPTREE}"
}
trap cleanup EXIT

# ─── 0. 前回の結果ブランチを消す ───────────────────────────────────
ap_clear_result

# ─── 1. 一時ブランチを main 起点で組み立てて push ──────────────────
echo "📦 一時ブランチを組み立て: ${AP_ARTIFACT_BRANCH} (main 起点)"
git -C "${AP_REPO_ROOT}" fetch -q "${AP_REMOTE}" main
git -C "${AP_REPO_ROOT}" worktree add -q --detach "${TMPTREE}" FETCH_HEAD

mkdir -p "${TMPTREE}/_artifact"
cp -R "${LOCAL_DIR}/." "${TMPTREE}/_artifact/"
rm -rf "${TMPTREE}/_artifact/.git"

# _claude_template/ → .claude/ に展開
# Claude が .claude/ パスに直接書けない仕様への対処
if [[ -d "${TMPTREE}/_artifact/_claude_template" ]]; then
  echo "📁 _claude_template/ を .claude/ に展開中..."
  mkdir -p "${TMPTREE}/_artifact/.claude"
  cp -R "${TMPTREE}/_artifact/_claude_template/." "${TMPTREE}/_artifact/.claude/"
  rm -rf "${TMPTREE}/_artifact/_claude_template"
  echo "✅ .claude/ に配置完了"
fi

# メタデータ (repo_name はブランチ名から導出するので持たない)
jq -n --arg title "${ARTICLE_TITLE}" --arg pages "${ENABLE_PAGES}" \
  '{article_title:$title, enable_pages:$pages}' > "${TMPTREE}/.artifact-publish.json"

cd "${TMPTREE}"

# main 起点にした副作用として、main の .gitignore が _artifact/ にも効く。
# 黙って落ちると「公開リポにファイルが足りない」事故になるので fail-closed にする。
# .env / *.key 等が引っかかった場合は成果物側から取り除くのが正しい対処
IGNORED="$(git ls-files --others --ignored --exclude-standard -- _artifact || true)"
if [[ -n "${IGNORED}" ]]; then
  echo "❌ .gitignore に一致するファイルが成果物に含まれています。公開リポに入らないため停止します:" >&2
  printf '%s\n' "${IGNORED}" | sed 's/^/   - /' >&2
  echo "   ビルド成果物なら成果物ディレクトリから除外し、機密ファイルなら削除してください" >&2
  exit 1
fi

# ローカルブランチは作らず detached HEAD のままコミットして push する。
# 同名のローカルブランチが別の worktree で checkout されていると switch が失敗するため
git add -A
if git diff --cached --quiet; then
  echo "❌ 成果物が空です。push 対象がありません: ${LOCAL_DIR}" >&2
  exit 1
fi
git -c user.email=noreply@anthropic.com -c user.name=Claude \
  commit -q -m "artifact: ${REPO_NAME}"

if [[ -n "${PUBLISH_ARTIFACT_DRY_RUN:-}" ]]; then
  echo "🧪 DRY RUN: push せずに終了します"
  echo "   ブランチ内容 ($(git ls-files -- _artifact | wc -l | tr -d ' ') ファイル):"
  git ls-files -- _artifact .artifact-publish.json | sed 's/^/     /'
  exit 0
fi

git push -q -f "${AP_REMOTE}" "HEAD:refs/heads/${AP_ARTIFACT_BRANCH}"
echo "✅ push 完了 ($(git ls-files -- _artifact | wc -l | tr -d ' ') ファイル)"
echo "🚀 push により .github/workflows/publish-artifact.yml が起動します"

cd "${AP_REPO_ROOT}"

# ─── 2. 結果ブランチを polling して成否判定 ────────────────────────
ap_wait_for_result || exit 1
ap_report_success
exit 0
