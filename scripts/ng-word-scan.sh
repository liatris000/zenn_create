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
#   - ハッシュ化してリポジトリに置く案も検討したが、"kubell" のような短い固有名詞は
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
#   NG_WORDS="kubell,他のNGワード" bash scripts/ng-word-scan.sh
#
# 終了コード:
#   0: NGワード検出なし
#   1: NGワード検出、または NG_WORDS 未設定 (fail-closed)

set -euo pipefail

SCAN_PATHS=("articles" "books")

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

for path in "${SCAN_PATHS[@]}"; do
  [[ -d "${path}" ]] || continue
  for word in "${WORDS[@]}"; do
    # -R: 再帰, -F: 固定文字列 (正規表現として解釈しない), -I: バイナリ除外,
    # -l: ファイル名のみ, -i: 大小無視
    while IFS= read -r file; do
      [[ -z "${file}" ]] && continue
      # マッチした行番号だけを集める (行内容自体はログに出さない)
      lines="$(grep -Fni -- "${word}" "${file}" | cut -d: -f1 | paste -sd, -)"
      REPORT+=$'\n'"  - ${file} (行: ${lines})"
      FOUND=1
    done < <(grep -RFIli -- "${word}" "${path}" 2>/dev/null || true)
  done
done

if [[ "${FOUND}" -eq 1 ]]; then
  echo "::error::公開コンテンツ (${SCAN_PATHS[*]}) にNGワードを検出しました。該当ファイルを確認し、修正してください。"
  echo "検出箇所 (ファイル名・行番号のみ表示。ワード自体はログに出しません):"
  echo "${REPORT}"
  exit 1
fi

echo "NGワードスキャン: 問題なし (対象: ${SCAN_PATHS[*]})"
exit 0
