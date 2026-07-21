#!/usr/bin/env bash
# 記事内リンクの生存確認 (Issue #51)。
#
# - リポジトリ内参照 (https://raw.githubusercontent.com/liatris000/zenn_create/main/...)
#   はローカルのファイル存在チェック。存在しなければエラー。
#   同一 PR 内で追加される画像は main にまだ無いため、HTTP ではなく
#   チェックアウト済みワークツリーで確認する (サムネのパス typo をマージ前に検出)
# - 外部 URL は HTTP ステータス確認。404 / 410 のみエラーにし、
#   403 / 429 等の bot ブロックやタイムアウト (000) は警告に留める
#   (リンク先サイト側の都合で記事 PR を止めない)
#
# 使い方:
#   bash scripts/article-link-check.sh                  # articles/*.md 全部
#   bash scripts/article-link-check.sh articles/xxx.md  # 指定ファイルのみ
#
# 終了コード:
#   0: エラーなし (警告は許容)
#   1: エラーあり

set -euo pipefail

RAW_PREFIX='https://raw.githubusercontent.com/liatris000/zenn_create/main/'
USER_AGENT='Mozilla/5.0 (compatible; zenn-create-link-check)'

FILES=("$@")
if [[ "${#FILES[@]}" -eq 0 ]]; then
  while IFS= read -r f; do
    FILES+=("${f}")
  done < <(find articles -name '*.md' 2>/dev/null | sort)
fi

if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "対象ファイルなし。スキップ"
  exit 0
fi

# 同じ URL が複数記事に登場するため (冒頭メッセージブロック等)、結果をキャッシュする。
# 連想配列 (bash 4+) は macOS 標準の bash 3.2 に無いため、一時ファイルで代用する
CACHE_FILE="$(mktemp)"
trap 'rm -f "${CACHE_FILE}"' EXIT

ERRORS=0
WARNINGS=0

for file in "${FILES[@]}"; do
  [[ -f "${file}" ]] || continue

  # markdown リンク・画像・素の URL を抽出し、文末の句読点を除去。
  # フェンスコードブロックとインラインコード内はサンプル URL / regex リテラルが
  # 多く誤検出になるため除外する (本文のリンクは prose か markdown リンクにある前提)
  urls="$(awk '/^```/{inblock=!inblock; next} !inblock' "${file}" \
    | sed -e 's/`[^`]*`//g' \
    | grep -oE 'https?://[^][:space:])">`]+' \
    | sed -e 's/[.,;:]*$//' | sort -u || true)"
  [[ -z "${urls}" ]] && continue

  while IFS= read -r url; do
    if [[ "${url}" == "${RAW_PREFIX}"* ]]; then
      # リポジトリ内参照 → ワークツリーでファイル存在チェック
      local_path="${url#"${RAW_PREFIX}"}"
      if [[ ! -f "${local_path}" ]]; then
        echo "::error file=${file}::リポジトリ内参照が存在しません: ${url} (期待パス: ${local_path})"
        ERRORS=1
      fi
      continue
    fi

    # 外部 URL → HTTP チェック (キャッシュあり。URL に空白は含まれないため空白区切りで安全)
    status="$(awk -v u="${url}" '$1 == u {print $2; exit}' "${CACHE_FILE}")"
    if [[ -z "${status}" ]]; then
      # curl は失敗時も %{http_code} として 000 を stdout に出すため、
      # `|| echo 000` で連結しない (000000 になる)
      if ! status="$(curl -s -o /dev/null -w '%{http_code}' -L \
        --max-time 15 --retry 1 -A "${USER_AGENT}" "${url}")"; then
        status="000"
      fi
      printf '%s %s\n' "${url}" "${status}" >> "${CACHE_FILE}"
    fi

    case "${status}" in
      404|410)
        echo "::error file=${file}::リンク切れ (HTTP ${status}): ${url}"
        ERRORS=1
        ;;
      2*|3*)
        : # OK
        ;;
      *)
        # bot ブロック (403/429 等) やタイムアウト (000) は警告に留める
        echo "::warning file=${file}::リンク確認できず (HTTP ${status}): ${url}"
        WARNINGS=$((WARNINGS + 1))
        ;;
    esac
  done <<< "${urls}"
done

if [[ "${ERRORS}" -eq 1 ]]; then
  echo "リンク切れチェック: エラーあり"
  exit 1
fi

echo "リンク切れチェック: エラーなし (警告 ${WARNINGS} 件, 対象 ${#FILES[@]} ファイル)"
