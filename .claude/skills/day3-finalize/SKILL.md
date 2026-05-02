---
name: day3-finalize
description: Zenn 記事生成の Day 3(水曜朝)の作業手順。Day 2 のフィードバックを反映し、サムネを生成し、セルフレビューを行い、PR を Ready for Review 状態に移行する。水曜の Routine 起動時、記事を完成させる時に発動する。
---

# Day 3: 完成 + Ready for Review

3 日サイクルの最終日。Day 2 で書いた本文を磨き上げ、サムネを生成し、レビュー可能な状態にする。

## 前提

- Day 2 の PR が存在し、`[Day 2/3 WIP]` タイトルになっている
- Liatris から翌朝チェックでフィードバックが入っている可能性あり
- Day 1 / Day 2 セッションで `export` した環境変数(`ARTICLE_SLUG` / `ARTICLE_TITLE` 等)はセッション間で引き継がれない前提で動く

## 作業手順

### Step 0: 前日の PR 探索 + 環境変数の復元

Routine セッションは Day ごとに使い捨てされるため、Day 1/2 で `export` した
`ARTICLE_SLUG` / `ARTICLE_TITLE` は Day 3 セッションには引き継がれない。
PR タイトルと差分ファイル一覧から逆引きする。

```bash
cd ~/zenn_create
git pull origin main -q

# Day 2 で更新された [Day 2/3 WIP] PR を PR タイトルで検索
PR_INFO=$(gh pr list --state open --search '"[Day 2/3 WIP]" in:title' --json number,headRefName,url --limit 1)
PR_NUMBER=$(echo "${PR_INFO}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d[0]['number'] if d else '')")
LATEST_BRANCH=$(echo "${PR_INFO}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d[0]['headRefName'] if d else '')")
PR_URL=$(echo "${PR_INFO}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d[0]['url'] if d else '')")
export PR_URL PR_NUMBER LATEST_BRANCH

# PR が見つからなければその週は中止
if [ -z "${PR_NUMBER}" ]; then
  echo "Day 3: 対象 PR が見つからないためスキップ"
  exit 0
fi

git checkout "${LATEST_BRANCH}"
git pull origin "${LATEST_BRANCH}" -q

# PR タイトル "[Day 2/3 WIP] ${ARTICLE_TITLE}" から ARTICLE_TITLE を逆引き
ARTICLE_TITLE=$(gh pr view "${PR_NUMBER}" --json title -q '.title' \
  | sed -E 's/^\[Day [0-9]+\/3 [^]]+\] //')
export ARTICLE_TITLE

# PR の差分ファイル一覧から articles/${ARTICLE_SLUG}.md を見つけて逆引き
ARTICLE_SLUG=$(gh pr view "${PR_NUMBER}" --json files -q '.files[].path' \
  | grep -E '^articles/.+\.md$' \
  | head -1 \
  | sed -E 's|^articles/(.+)\.md$|\1|')
export ARTICLE_SLUG

# 必須チェック: 復元失敗時は Day 3 を中止
if [ -z "${ARTICLE_TITLE}" ] || [ -z "${ARTICLE_SLUG}" ]; then
  echo "FATAL: ARTICLE_TITLE / ARTICLE_SLUG の逆引きに失敗"
  echo "  ARTICLE_TITLE='${ARTICLE_TITLE}'"
  echo "  ARTICLE_SLUG='${ARTICLE_SLUG}'"
  exit 1
fi

echo "Restored: ARTICLE_SLUG=${ARTICLE_SLUG}, ARTICLE_TITLE=${ARTICLE_TITLE}"

# 成果物リポジトリの URL を記事本文中の GitHub リンクから抽出 (Step 6.3 で使用)
REPO_URL=$(grep -oE 'https://github\.com/liatris000/liatris-[A-Za-z0-9_-]+' \
  "articles/${ARTICLE_SLUG}.md" \
  | head -1)
export REPO_URL
```

### Step 1: フィードバック確認

```bash
gh pr view "${PR_NUMBER}" --comments
```

Liatris のコメントがあれば、その内容を踏まえて反映する。

### Step 2: Day 1 PR 本文の取得 (採用判定根拠の参照)

Step 8 のチェックポイント生成では、Day 1 PR 本文に書かれた **採用判定の根拠**・**候補リスト**・**先行記事との違い** を参照する。Step 0 で取得した PR は Day 1 から継続している同一 PR なので、現在の PR 本文をそのまま読む。

```bash
DAY1_PR_BODY=$(gh pr view "${PR_NUMBER}" --json body -q '.body')
export DAY1_PR_BODY

# 後続ステップで参照しやすいよう一時ファイルに退避
mkdir -p /tmp/zenn_artifact
echo "${DAY1_PR_BODY}" > /tmp/zenn_artifact/day1_pr_body.md
```

`day1_pr_body.md` から以下を抜き出して Step 8 の文面構築に使う:

- 採用判定セクション(★★★/★★、需要、供給、キャッチアップ価値)
- 候補リスト(採用 + 不採用候補とその理由)
- 先行記事との差別化ポイント(供給シグナルで発見した補完点)

### Step 3: フィードバック反映

PR コメントの指摘を本文に反映する。

反映後にコミット:

```bash
git add "articles/${ARTICLE_SLUG}.md"
git commit -m "Day 3: フィードバック反映"
```

### Step 4: サムネ生成

```bash
./scripts/generate-thumbnail.sh "${ARTICLE_TITLE}" "./images/${ARTICLE_SLUG}_thumbnail.png"
```

成果物が HTML ならスクリーンショットも撮影:

```bash
# Puppeteer でスクショ取得 → ./images/${ARTICLE_SLUG}_screenshot.png
```

### Step 5: frontmatter 確認 (pattern 含む)

`articles/${ARTICLE_SLUG}.md` の frontmatter を確認:

```yaml
---
title: "..."
emoji: "🤖"
type: "tech"
topics: [...]
pattern: "implementation"  # implementation / comparison / concept のいずれか
published: false  # ← 必ず false のまま、日曜夜に true にする
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/${ARTICLE_SLUG}_thumbnail.png
---
```

`pattern` の値は `docs/article-style-guide.md` の「構成パターン」セクションに対応:

- `implementation` ─ 実装編
- `comparison` ─ 比較・検証編
- `concept` ─ 概念解説編

注意:

- `published_at` はまだ設定しない(日曜夜の Liatris 手動マージ時にセットする)
- `published: false` を維持(マージ後の自動公開を防ぐため)

#### Step 5.1: 構成パターンの履歴チェック

毎記事同じパターンが続かないよう、直近 3 記事の `pattern` を確認する:

```bash
CURRENT_PATTERN=$(awk -F: '/^pattern:/ {gsub(/[" ]/, "", $2); print $2; exit}' \
  "articles/${ARTICLE_SLUG}.md")

RECENT_PATTERNS=$(ls -t articles/*.md 2>/dev/null \
  | grep -v "${ARTICLE_SLUG}.md" \
  | head -3 \
  | xargs -I {} awk -F: '/^pattern:/ {gsub(/[" ]/, "", $2); print $2; exit}' {})

echo "今回の pattern: ${CURRENT_PATTERN}"
echo "直近 3 記事の pattern:"
echo "${RECENT_PATTERNS}"

# 直近 2 記事と同じパターンが連続している場合は警告 (3 回連続を検出)
LAST_TWO_UNIQUE=$(echo "${RECENT_PATTERNS}" | head -2 | sort -u | wc -l | tr -d ' ')
LAST_VALUE=$(echo "${RECENT_PATTERNS}" | head -1)
if [ "${LAST_TWO_UNIQUE}" = "1" ] && [ "${CURRENT_PATTERN}" = "${LAST_VALUE}" ] && [ -n "${CURRENT_PATTERN}" ]; then
  echo "⚠️  同じ pattern (${CURRENT_PATTERN}) が 3 回連続。構成を変えることを検討してください"
fi
```

警告が出た場合、本文構成を別パターンに組み替えることを検討する(必須ではないが、Step 8 の通知に「3 回連続 ${CURRENT_PATTERN}」と書いて Liatris の判断を仰ぐ)。

### Step 6: セルフレビュー

以下のチェックリストで自己レビュー:

#### 6.1 文体・構成チェック

- [ ] リード文がテンプレ的でない(「〜と感じたことはないでしょうか」等を多用していない)
- [ ] 業務コンテクストが出ていない(`docs/cycle-overview.md` の情報漏れ対策参照)
- [ ] 本名「平野翔斗」が記事本文内に出ていない(プロフィール表示は OK)
- [ ] コードブロックの言語指定が正しい
- [ ] 画像パスが正しい(`https://raw.githubusercontent.com/liatris000/zenn_create/main/images/...`)
- [ ] 内部リンクが切れていない
- [ ] 冒頭メッセージブロック (`templates/article-header.md` 由来の `:::message` ブロック) が frontmatter 直後に挿入されている
- [ ] 文字数が 1500〜3000 字の範囲(極端に短い / 長い場合は要調整)
- [ ] **定性的な順位主張に計測根拠があるか**: 「最も効いた」「一番効果があった」「劇的に改善」「圧倒的に速い」等の主張は、計測値・比較データが本文中で示されているか。示せないなら表現を弱める(「印象に残った」「個人的に効いた」等)

#### 6.2 アセット存在チェック (自動)

```bash
THUMB_PATH="images/${ARTICLE_SLUG}_thumbnail.png"
if [ ! -f "${THUMB_PATH}" ]; then
  echo "FATAL: サムネ画像が存在しない: ${THUMB_PATH}"
  exit 1
fi

# サイズが小さすぎる(生成失敗の可能性)場合も警告
THUMB_SIZE=$(stat -c %s "${THUMB_PATH}" 2>/dev/null || stat -f %z "${THUMB_PATH}")
if [ "${THUMB_SIZE}" -lt 5000 ]; then
  echo "⚠️  サムネ画像が小さすぎる(${THUMB_SIZE} bytes)。生成失敗の可能性"
fi
echo "✅ サムネ確認: ${THUMB_PATH} (${THUMB_SIZE} bytes)"

# 冒頭メッセージブロックの存在確認
if ! head -30 "articles/${ARTICLE_SLUG}.md" | grep -q ':::message'; then
  echo "FATAL: 冒頭メッセージブロックが見つからない: articles/${ARTICLE_SLUG}.md"
  echo "  templates/article-header.md を frontmatter 直後に挿入してください"
  echo "  Day 2 SKILL の Step 5.0 で挿入される手順になっていますが、漏れている可能性あり"
  exit 1
fi
echo "✅ 冒頭メッセージブロック確認"
```

#### 6.3 成果物リポジトリ公開状態チェック (自動)

`REPO_URL` (Step 0 で抽出) を使って成果物リポジトリの状態を確認する:

```bash
if [ -n "${REPO_URL}" ]; then
  REPO_PATH=$(echo "${REPO_URL}" | sed -E 's|^https://github\.com/||; s|/$||')

  # 公開状態チェック
  VISIBILITY=$(gh api "repos/${REPO_PATH}" --jq '.visibility' 2>/dev/null || echo "")
  if [ "${VISIBILITY}" != "public" ]; then
    echo "FATAL: 成果物リポジトリが公開されていない: ${REPO_PATH} (visibility=${VISIBILITY})"
    exit 1
  fi

  # README 非空チェック
  README_SIZE=$(gh api "repos/${REPO_PATH}/readme" --jq '.size' 2>/dev/null || echo "0")
  if [ "${README_SIZE}" = "0" ] || [ -z "${README_SIZE}" ]; then
    echo "FATAL: 成果物リポジトリの README が空: ${REPO_PATH}"
    exit 1
  fi
  echo "✅ 成果物リポジトリ確認: ${REPO_PATH} (public, README ${README_SIZE} bytes)"
else
  echo "⚠️  REPO_URL 未抽出 — 記事内に成果物リンクがない可能性。Step 0 を再確認"
fi
```

#### 6.4 機密文字列スキャン (自動)

API キー / トークン等が記事本文に平文で残っていないか自動検出する:

```bash
SECRET_PATTERNS='(sk-[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{30,}|gho_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[A-Za-z0-9_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

if grep -E -n "${SECRET_PATTERNS}" "articles/${ARTICLE_SLUG}.md"; then
  echo "FATAL: 機密と思われる文字列が記事本文に含まれている。マスクしてください"
  exit 1
fi
echo "✅ 機密文字列スキャン: クリーン"
```

検出されたら **必ずマスク**(`sk-xxx...xxx` 等)してから先に進む。`exit 1` で Day 3 が止まるので、修正後 Step 6 から再実行。

### Step 7: PR タイトル更新と Ready for Review

PR タイトルを `[Day 3/3 Ready for Review]` に変更:

```bash
gh pr edit "${PR_URL}" --title "[Day 3/3 Ready for Review] ${ARTICLE_TITLE}"
```

PR の draft 状態を解除(draft で作成していた場合):

```bash
gh pr ready "${PR_URL}"
```

最終 push:

```bash
git push origin "${LATEST_BRANCH}"
```

### Step 8: Liatris 向けチェックポイント生成

週末の Liatris チェックで見るべきポイントを Chatwork に送る。Day 1 PR 本文(Step 2 で取得した `DAY1_PR_BODY`)から「採用判定の根拠」「候補リスト」「先行記事との違い」を抽出して文面に組み込む。

```bash
WORD_COUNT=$(wc -m < "articles/${ARTICLE_SLUG}.md" | tr -d ' ')
export WORD_COUNT

CHECKPOINT_BODY=$(cat <<EOF
[Day 3 完了] ${ARTICLE_TITLE}

【今週の差別化ポイント】
- (Day 2 で発見した重要な点を 1〜2 行で)

【先行記事との違い】
- (Day 1 PR 本文の「先行記事との違い」セクションから転記)

【データアナリスト視点】
- (記事内に入れたデータ視点・他の人があまり書かない切り口)

【構成パターン】
- 今回: ${CURRENT_PATTERN}
- 直近 3 記事:
$(echo "${RECENT_PATTERNS}" | sed 's/^/  - /')

【セルフチェック結果】
- 文字数: ${WORD_COUNT} 字
- サムネ: ✅
- 成果物リポジトリ: ✅ (public, README あり)
- 機密文字列スキャン: ✅
- (Step 6 のチェックリストで気になった点があれば)

PR: ${PR_URL}
週末に最終チェックお願いします。
EOF
)
export CHECKPOINT_BODY
```

`DAY1_PR_BODY` の参照箇所(採用判定セクション・候補リスト)は、必要に応じて `CHECKPOINT_BODY` の該当部分に貼り付ける。Liatris が PR を遡らずに判断できる状態にすることが目的。

### Step 9: Chatwork 通知

Step 8 で組み立てた `CHECKPOINT_BODY` をそのまま Chatwork に送る。`notify-chatwork.sh` は `--body` オプションで本文を直接受け取れる:

```bash
./scripts/notify-chatwork.sh --body "${CHECKPOINT_BODY}"
```

Day 3 では **`--body` モードを優先**する(チェックポイント本文が定型フォーマットに収まらないため)。位置引数の従来形式も後方互換のため残っている(Day 1/2 で使用)。

### Step 10: 完了報告

```
Day 3 完了 (PR: ${PR_URL}, 文字数: ${WORD_COUNT}字)
週末にチェックお願いします。
日曜夜にマージすると、月曜 7:00 に自動公開されます。
```

## 中断時の挙動

- Day 2 の PR が見つからない → 何もせず終了(その週中止)
- Step 0 の環境変数復元に失敗 → `exit 1` で停止、Liatris に PR の状態を確認依頼
- Step 6 のアセットチェック / 機密スキャンで FATAL → 修正してから Step 6 を再実行(`exit 1` のあと再開)
- フィードバック反映で Liatris に追加質問が必要 → 質問を Chatwork に送って Day 3 完了状態にしない

## 絶対 NG(Day 3 特有)

- `published: true` にしない(これは日曜夜の Liatris 手動マージで実施)
- `published_at` をセットしない(同上)
- main へ直 push しない
- セルフレビュー(Step 6)をスキップしない
- 機密文字列スキャンで検出された秘密値を「マスクせず published: false だから OK」で済ませない(PR は Public リポジトリで履歴に残る)
- 業務コンテクストが残っていないか必ずチェック
