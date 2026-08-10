#!/usr/bin/env bash
# 公開コンテンツ (articles/, books/) にNGワード(実勤務先名など、記事に出してはいけない
# 固有名詞)が含まれていないかスキャンする。
#
# 背景: origin/article/20260429 ブランチに実勤務先名がリークした事案の再発防止
# (zenn_create Issue #50)。
#
# NGワードリストはこのスクリプト・リポジトリ内に平文で置かない。
# GitHub Actions の Secrets (NG_WORDS, カンマ区切り) 経由で環境変数として渡す。
# これは以下の理由による:
#   - リポジトリは Public。ワードリストをファイルに書くと、CI導入の目的である
#     「勤務先名を公開リポから漏らさない」に自己矛盾する
#   - ハッシュ化してリポジトリに置く案も検討したが、実勤務先名のような短い固有名詞は
#     辞書攻撃・レインボーテーブルで容易に逆引きされるため、salt を別管理しない限り
#     実質的な秘匘性がない。salt も結局 Secrets 管理が必要になり、素直に平文を
#     Secrets に置く方式より複雑になるだけで安全性が上積みされない
#   - GitHub Actions の Secrets はリポジトリの git 履歴に一切残らず、ログにも
#     自動マスキングされる。今回の要件(リポジトリ内に平文を置かない)を満たす
#     最小構成として Secrets 経由の受け渡しを採用する
#
# 注意 (ログ露出対策):
#   GitHub Actions の自動マスキングは「Secretsに登録した文字列そのもの」にしか
#   効かない。NG_WORDS をカンマ分割して個々の単語として扱うと、分割後の単語は
#   自動マスキングの対象外になる。そのため本スクリプトは各単語を読み込んだ直後に
#   `::add-mask::` でランタイムマスク登録し、かつ検出時もマッチした行内容そのものは
#   ログに出力せず、ファイルパスと行番号のみを報告する。
#
# 使い方:
#   NG_WORDS="ワード1,ワード2" bash scripts/ng-word-scan.sh
#
# 終了コード:
#   0: NGワード検出なし
#   1: NGワード検出、または NG_WORDS 未設定 (fail-closed)

set -euo pipefail

# 検査対象の決定
#
# 既定は「追跡ファイル全体」。以前は articles/ books/ だけを見ていたため、
# .claude/ docs/ scripts/ に固有名詞が入り込んでも検出できなかった
# (実際、本スクリプト自身の使用例に実勤務先名が平文で入っていた)。
#
# business-profile は Private submodule。中身は公開されないので対象外にする。
# 対象に含めると、この Public リポの CI ログに Private 側のパスが出てしまう。
SCAN_PATHS=()
SCAN_LABEL=""
if [[ $# -gt 0 ]]; then
  # 引数指定: 成果物リポジトリの公開前検査などで使う
  #   例: bash scripts/ng-word-scan.sh artifact
  SCAN_PATHS=("$@")
  SCAN_LABEL="$*"
elif git rev-parse --git-dir > /dev/null 2>&1; then
  while IFS= read -r f; do
    [[ -n "${f}" ]] && SCAN_PATHS+=("${f}")
  done < <(git ls-files -- . ':!business-profile')
  SCAN_LABEL="追跡ファイル全体 (${#SCAN_PATHS[@]} 件, business-profile を除く)"
else
  # git 管理外で実行された場合のフォールバック
  SCAN_PATHS=("articles" "books")
  SCAN_LABEL="articles books"
fi

if [[ "${#SCAN_PATHS[@]}" -eq 0 ]]; then
  echo "::error::検査対象が 1 件もありません。"
  exit 1
fi

if [[ -z "${NG_WORDS:-}" ]]; then
  echo "::error::NG_WORDS が設定されていません。リポジトリの Settings > Secrets and variables > Actions で NG_WORDS (カンマ区切り) を設定してください。"
  exit 1
fi

IFS=',' read -ra RAW_WORDS <<< "${NG_WORDS}"

WORDS=()
for raw_word in "${RAW_WORDS[@]}"; do
  # 前後の空白をトリム
  word="$(echo -n "${raw_word}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -z "${word}" ]] && continue
  # 以後のログ出力に紛れ込んでもマスクされるよう登録する
  echo "::add-mask::${word}"
  WORDS+=("${word}")
done

if [[ "${#WORDS[@]}" -eq 0 ]]; then
  echo "::error::NG_WORDS は設定されていますが、有効な単語が1つも抽出できませんでした。"
  exit 1
fi

FOUND=0
REPORT=""

# 実在する対象だけに絞る (ディレクトリ・ファイルのどちらでもよい)
EXISTING=()
for path in "${SCAN_PATHS[@]}"; do
  [[ -e "${path}" ]] && EXISTING+=("${path}")
done

if [[ "${#EXISTING[@]}" -eq 0 ]]; then
  echo "NGワードスキャン: 対象が存在しないため skip (${SCAN_LABEL})"
  exit 0
fi

for word in "${WORDS[@]}"; do
  # -R: 再帰, -F: 固定文字列 (正規表現として解釈しない), -I: バイナリ除外,
  # -l: ファイル名のみ, -i: 大小無視
  # 対象をまとめて渡す (追跡ファイル全体だと数百件になるため 1 語 1 回の grep に抑える)
  while IFS= read -r file; do
    [[ -z "${file}" ]] && continue
    # マッチした行番号だけを集める (行内容自体はログに出さない)
    lines="$(grep -Fni -- "${word}" "${file}" | cut -d: -f1 | paste -sd, -)"
    REPORT+=$'\n'"  - ${file} (行: ${lines})"
    FOUND=1
  done < <(grep -RFIli -- "${word}" "${EXISTING[@]}" 2>/dev/null || true)
done

if [[ "${FOUND}" -eq 1 ]]; then
  echo "::error::公開コンテンツ (${SCAN_LABEL}) にNGワードを検出しました。該当ファイルを確認し、修正してください。"
  echo "検出箇所 (ファイル名・行番号のみ表示。ワード自体はログに出しません):"
  echo "${REPORT}"
  exit 1
fi

echo "NGワードスキャン: 問題なし (対象: ${SCAN_LABEL})"
exit 0
