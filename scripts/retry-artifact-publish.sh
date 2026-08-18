#!/usr/bin/env bash
# 成果物リポジトリ公開の再試行。
#
# 使い方:
#   ./scripts/retry-artifact-publish.sh <リポジトリ名>
#
# 出力 (呼び出し元が eval で拾う):
#   REPO_URL / PAGES_URL
#
# ─── 何のためのスクリプトか ──────────────────────────────────────
# Day 2 は「記事本文を書く」→「成果物リポジトリを公開する」の順で動く(2026-08-18 に
# 順序を入れ替えた)。公開が失敗しても週を落とさない代わりに、成果物が未公開のまま
# Day 3 に渡る状態が生まれる。それを Day 3 が解消するためのスクリプト。
#
# Day 3 は別セッションなので Day 2 の /tmp/zenn_artifact は残っていない。代わりに、
# 公開に失敗したときは一時ブランチ artifact/<repo-name> を消さずに残してあるので、
# そこへ空コミットを push して Actions を再起動する(routine セッションからは API で
# Actions を起動できないため、再起動手段も push しかない)。

set -euo pipefail

REPO_NAME="${1:-}"
if [[ -z "${REPO_NAME}" ]]; then
  echo "❌ 引数が足りません" >&2
  echo "使い方: $0 <リポジトリ名>" >&2
  exit 1
fi

# shellcheck source=scripts/lib/artifact-publish.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/artifact-publish.sh"

ap_init "${REPO_NAME}"

if ! git ls-remote --exit-code --heads "${AP_REMOTE}" "${AP_ARTIFACT_BRANCH}" >/dev/null 2>&1; then
  echo "❌ 一時ブランチが残っていないため再試行できません: ${AP_ARTIFACT_BRANCH}" >&2
  echo "   成果物が失われています。Day 2 の実装からやり直すか、Liatris の判断を仰いでください" >&2
  exit 1
fi

ap_clear_result

TMPTREE="$(mktemp -d)"
cleanup() {
  git -C "${AP_REPO_ROOT}" worktree remove --force "${TMPTREE}" >/dev/null 2>&1 || true
  rm -rf "${TMPTREE}"
}
trap cleanup EXIT

echo "🔁 一時ブランチへ空コミットを push して公開ワークフローを再起動: ${AP_ARTIFACT_BRANCH}"
git -C "${AP_REPO_ROOT}" fetch -q "${AP_REMOTE}" "${AP_ARTIFACT_BRANCH}"
git -C "${AP_REPO_ROOT}" worktree add -q --detach "${TMPTREE}" FETCH_HEAD
git -C "${TMPTREE}" -c user.email=noreply@anthropic.com -c user.name=Claude \
  commit -q --allow-empty -m "retry: republish ${REPO_NAME}"
git -C "${TMPTREE}" push -q -f "${AP_REMOTE}" "HEAD:${AP_ARTIFACT_BRANCH}"
echo "✅ push 完了"

ap_wait_for_result || exit 1
ap_report_success
exit 0
