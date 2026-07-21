#!/usr/bin/env bash
# 公開コンテンツ (articles/) に API キー / トークン等の機密文字列が平文で
# 残っていないかスキャンする (Issue #51)。
#
# 検出パターンは day3-finalize SKILL の Step 6.4 にあった regex をここに一本化した。
# SKILL 側もこのスクリプトを呼ぶ (regex の二重管理を防ぐ)。
#
# ログ露出対策: リポジトリも Actions ログも Public のため、検出時は
# ファイルパスと行番号のみを出力し、マッチした行内容そのものは出力しない。
#
# 使い方:
#   bash scripts/article-secret-scan.sh                  # articles/*.md 全部
#   bash scripts/article-secret-scan.sh articles/xxx.md  # 指定ファイルのみ
#
# 終了コード:
#   0: 検出なし
#   1: 検出あり

set -euo pipefail

SECRET_PATTERNS='(sk-[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{30,}|gho_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[A-Za-z0-9_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

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

FOUND=0
for file in "${FILES[@]}"; do
  [[ -f "${file}" ]] || continue
  lines="$(grep -En -- "${SECRET_PATTERNS}" "${file}" | cut -d: -f1 | paste -sd, - || true)"
  if [[ -n "${lines}" ]]; then
    echo "::error file=${file}::機密と思われる文字列を検出しました (行: ${lines})。マスクしてください"
    FOUND=1
  fi
done

if [[ "${FOUND}" -eq 1 ]]; then
  exit 1
fi

echo "機密文字列スキャン: クリーン (${#FILES[@]} ファイル)"
