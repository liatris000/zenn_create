---
name: day2-implementation
description: Zenn 記事生成の Day 2(火曜朝)の作業手順。前日の WIP PR を見つけて実装を進め、文章を整え、同 PR に追記コミットする。火曜の Routine 起動時、Day 1 の続きを進める時に発動する。
---

# Day 2: 実装と推敲

3 日サイクルの中日。Day 1 で立てた実装方針を実コードに落とし込み、文章を整える。

## 前提

- 月曜の Day 1 で WIP 状態の PR が作成されている
- PR タイトルに `[Day 1/3 WIP]` が含まれている

## 作業手順

### Step 1: 前日の PR を探す

```bash
cd ~/zenn_create
git pull origin main -q

# Day 1 で作成された [Day 1/3 WIP] PR を PR タイトルで検索
# (Routine 環境では Claude Code が自動的に claude/* ブランチを切るため、
#  ブランチ名前提の検索ではなく PR タイトル前提の検索にする)
PR_INFO=$(gh pr list --state open --search '"[Day 1/3 WIP]" in:title' --json number,headRefName,url --limit 1)
PR_NUMBER=$(echo "${PR_INFO}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d[0]['number'] if d else '')")
LATEST_BRANCH=$(echo "${PR_INFO}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d[0]['headRefName'] if d else '')")
PR_URL=$(echo "${PR_INFO}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d[0]['url'] if d else '')")
export PR_URL
```

PR が見つからない場合(月曜サボった、Liatris が火曜朝に PR を close した等):

- **何もせず終了する**(その週は中止)
- Chatwork に「Day 2: 対象 PR が見つからないためスキップ」と通知

### Step 2: PR の状態確認

```bash
git checkout "${LATEST_BRANCH}"
git pull origin "${LATEST_BRANCH}" -q
```

PR タイトルが `[Day 1/3 WIP]` であることを確認。
そうでなければ予期しない状態 → Liatris に確認。

### Step 3: 実装(コードレベル)

Day 1 で決めた実装方針に従って、`/tmp/zenn_artifact/` で実コードを書く。

- 動作確認まで完了させる
- HTML 系なら GitHub Pages 用にビルドできる状態に
- スクリプト系なら実行サンプルを用意

### 重要: `.claude/` 配下のファイル配置について

成果物リポジトリの `.claude/mcp.json` 等、最終的に `.claude/` 配下に配置したいファイルは、`/tmp/zenn_artifact/.claude/` ではなく **`/tmp/zenn_artifact/_claude_template/`** に書くこと。

**理由**: Claude Code は `.claude/` 配下への書き込み時に確認ダイアログを出す仕様(v2.1.121 以降固定)。Routine 自動起動では人間が応答できないため詰まる。

**フロー**:
1. Claude は `/tmp/zenn_artifact/_claude_template/mcp.json` 等を書く
2. `scripts/publish-artifact.sh` が push 直前に `_claude_template/` を `.claude/` に自動展開
3. 公開された成果物リポジトリには `.claude/mcp.json` として正しく配置される

**例**:

```bash
# ❌ NG: Claude Code がダイアログで止まる
cat > /tmp/zenn_artifact/.claude/mcp.json <<EOF
{ ... }
EOF

# ✅ OK: 普通のディレクトリ名
mkdir -p /tmp/zenn_artifact/_claude_template
cat > /tmp/zenn_artifact/_claude_template/mcp.json <<EOF
{ ... }
EOF
```

`.claude/` 以外のファイル(README.md, components/*.tsx 等)は通常通り `/tmp/zenn_artifact/` 直下に書いて OK。

### Step 4: 成果物リポジトリの公開

```bash
./scripts/publish-artifact.sh "${REPO_NAME}" "/tmp/zenn_artifact" "${ARTICLE_TITLE}"
eval $(./scripts/publish-artifact.sh "${REPO_NAME}" "/tmp/zenn_artifact" "${ARTICLE_TITLE}" | grep -E '^(REPO_URL|PAGES_URL)=')
export REPO_URL PAGES_URL
```

### Step 5: 記事本文の追記

#### Step 5.0: 冒頭メッセージブロックの挿入

本文を書き始める前に、`templates/article-header.md`(Zenn ガイドライン準拠の冒頭メッセージブロック: Claude Code 補助で書いていることの開示・運営からの指摘で停止する方針・設計記事 note へのリンク)を frontmatter 直後に必ず差し込む。`{{DESIGN_ARTICLE_URL}}` は環境変数 `DESIGN_ARTICLE_URL` で置換する。

```bash
# DESIGN_ARTICLE_URL が未設定の場合のフォールバック
DESIGN_URL="${DESIGN_ARTICLE_URL:-https://note.com/liatris}"

# テンプレを置換した結果を変数に格納
HEADER_BLOCK=$(sed "s|{{DESIGN_ARTICLE_URL}}|${DESIGN_URL}|g" templates/article-header.md)

# frontmatter (--- で挟まれた区間) の直後に挿入
# python ワンライナーで安全に処理する (macOS / Linux 両対応)
python3 - "${HEADER_BLOCK}" "articles/${ARTICLE_SLUG}.md" <<'PY'
import sys, re
header_block, article_path = sys.argv[1], sys.argv[2]

with open(article_path, 'r', encoding='utf-8') as f:
    content = f.read()

# frontmatter (--- で挟まれた最初の区間) を抽出
m = re.match(r'^(---\n.*?\n---\n)', content, re.DOTALL)
if not m:
    print("ERROR: frontmatter が見つかりません", file=sys.stderr)
    sys.exit(1)

frontmatter = m.group(1)
body = content[len(frontmatter):]

# 既に冒頭ブロックがある場合はスキップ (二重挿入防止)
if ':::message' in body[:500] and 'Claude Code' in body[:500]:
    print("INFO: 冒頭ブロックは既に挿入済み、スキップ")
    sys.exit(0)

# frontmatter + 空行 + 冒頭ブロック + 空行 + 既存本文
new_content = frontmatter + '\n' + header_block.rstrip() + '\n\n' + body.lstrip()

with open(article_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("✅ 冒頭ブロックを挿入しました")
PY
```

挿入後、本文の追記に進む。

#### Step 5.1: 本文追記

`articles/${ARTICLE_SLUG}.md` に本文を書く:

- リード(なぜこの題材か、何を作ったか)
- 実装の各 Step
- 成果物の埋め込み(`@[github]` + `:::details` + スクショ)
- 感想(良かった点・惜しかった点・業務での活用イメージ)
- まとめ

文体は `.claude/skills/article-writing/SKILL.md` を厳守。

### Step 6: PR タイトル更新と追記コミット

PR タイトルを `[Day 2/3 WIP]` に変更:

```bash
gh pr edit "${PR_URL}" --title "[Day 2/3 WIP] ${ARTICLE_TITLE}"
```

追記コミット + push:

```bash
git add articles/${ARTICLE_SLUG}.md
git commit -m "Day 2: 実装と推敲"
git push origin "${LATEST_BRANCH}"
```

### Step 7: Chatwork 通知(翌朝チェック依頼)

```bash
./scripts/notify-chatwork.sh \
  "Day 2 完了: ${ARTICLE_TOPIC}" \
  "${ARTICLE_TITLE}" \
  "$(wc -m < articles/${ARTICLE_SLUG}.md | tr -d ' ')" \
  "未定 (来週月曜公開予定)" \
  "${PAGES_URL}" \
  "${REPO_URL}" \
  "${PR_URL}"
```

通知本文に「明朝 Day 3 進行前にチェックお願いします」を含める。

### Step 8: 完了報告

```
Day 2 完了 (PR: ${PR_URL}, 文字数: ${WORD_COUNT}字)
明朝出社前にチェックお願いします。
明日 Day 3 で完成させます。
```

## 中断時の挙動

- Day 1 の PR が存在しない → 何もせず終了(その週中止)
- 実装が動かない → 3 回試して失敗ならコメント追記して停止、Liatris 判断を仰ぐ
- 既に Ready for Review 状態(Day 3 完了済み)→ 何もせず終了

## 絶対 NG(Day 2 特有)

- 新規 PR を作らない(Day 1 の PR に追記する)
- main への直 push 禁止
- 業務コンテクストを記事本文に出さない
- スクリプト失敗で main にマージしない
