#!/usr/bin/env bash
# publish-artifact.sh / retry-artifact-publish.sh の共通処理。
#
# 成果物リポジトリ公開フローは GitHub API を一切使わない (routine セッションからは
# Actions を API 経由で起動できないため。経緯は scripts/publish-artifact.sh のヘッダ参照)。
# Actions は結果を artifact-result/<repo-name> ブランチへ書き戻し、呼び出し側は
# git ls-remote でそれを polling する。その polling をここに一本化している。

# ap_init <repo-name>
#   REMOTE / ARTIFACT_BRANCH / RESULT_BRANCH / REPO_ROOT を設定する
ap_init() {
  local repo_name="$1"
  local token="${GITHUB_TOKEN:-${GITHUB_ACCESS_TOKEN:-}}"
  if [[ -z "${token}" ]]; then
    echo "❌ GITHUB_TOKEN (または GITHUB_ACCESS_TOKEN) が未設定です" >&2
    return 1
  fi
  AP_GITHUB_USER="${GITHUB_USER:-liatris000}"
  AP_DISPATCH_REPO="${DISPATCH_REPO:-${AP_GITHUB_USER}/zenn_create}"
  AP_REMOTE="https://${token}@github.com/${AP_DISPATCH_REPO}.git"
  AP_ARTIFACT_BRANCH="artifact/${repo_name}"
  AP_RESULT_BRANCH="artifact-result/${repo_name}"
  AP_REPO_ROOT="$(git rev-parse --show-toplevel)"
  AP_POLL_TIMEOUT="${PUBLISH_ARTIFACT_TIMEOUT:-900}"
  AP_POLL_INTERVAL="${PUBLISH_ARTIFACT_POLL_INTERVAL:-10}"
}

# ap_clear_result
#   前回の結果ブランチを消す。残っていると polling が即座に古い結果を拾って誤判定する
ap_clear_result() {
  git -C "${AP_REPO_ROOT}" push -q "${AP_REMOTE}" --delete "${AP_RESULT_BRANCH}" >/dev/null 2>&1 || true
}

# ap_wait_for_result
#   結果ブランチを polling し、result.json を読んで AP_STATUS / AP_REPO_URL /
#   AP_PAGES_URL / AP_RUN_URL / AP_FILE_COUNT にセットする。
#   成功なら 0、失敗・タイムアウトなら非 0 を返す。
ap_wait_for_result() {
  echo "⏳ Actions の完了を待機中 (最大 $((AP_POLL_TIMEOUT / 60)) 分)..."
  local elapsed=0 found=""
  while (( elapsed < AP_POLL_TIMEOUT )); do
    sleep "${AP_POLL_INTERVAL}"
    elapsed=$(( elapsed + AP_POLL_INTERVAL ))
    if git ls-remote --exit-code --heads "${AP_REMOTE}" "${AP_RESULT_BRANCH}" >/dev/null 2>&1; then
      found="yes"
      break
    fi
  done

  if [[ -z "${found}" ]]; then
    echo "❌ ${elapsed}秒待っても結果が返りませんでした: ${AP_RESULT_BRANCH}" >&2
    echo "   確認: https://github.com/${AP_DISPATCH_REPO}/actions" >&2
    return 1
  fi

  git -C "${AP_REPO_ROOT}" fetch -q "${AP_REMOTE}" "${AP_RESULT_BRANCH}"
  local json
  json="$(git -C "${AP_REPO_ROOT}" show FETCH_HEAD:result.json)"
  # 読んだら消す。残すと次回の polling が誤判定する
  git -C "${AP_REPO_ROOT}" push -q "${AP_REMOTE}" --delete "${AP_RESULT_BRANCH}" >/dev/null 2>&1 || true

  AP_STATUS="$(printf '%s' "${json}" | jq -r '.status')"
  AP_REPO_URL="$(printf '%s' "${json}" | jq -r '.repo_url')"
  AP_PAGES_URL="$(printf '%s' "${json}" | jq -r '.pages_url')"
  AP_RUN_URL="$(printf '%s' "${json}" | jq -r '.run_url')"
  AP_FILE_COUNT="$(printf '%s' "${json}" | jq -r '.file_count')"

  if [[ "${AP_STATUS}" != "success" ]]; then
    echo "❌ 成果物リポジトリの公開に失敗しました" >&2
    echo "   run: ${AP_RUN_URL}" >&2
    echo "   一時ブランチは再試行用に残しています: ${AP_ARTIFACT_BRANCH}" >&2
    return 1
  fi
  return 0
}

# ap_report_success
#   呼び出し元が eval で拾える形式で URL を出力する
ap_report_success() {
  echo "✅ 成果物リポジトリを公開しました (${AP_FILE_COUNT} ファイル)"
  echo "   run: ${AP_RUN_URL}"
  echo "REPO_URL=${AP_REPO_URL}"
  [[ -n "${AP_PAGES_URL}" ]] && echo "PAGES_URL=${AP_PAGES_URL}"
  return 0
}
