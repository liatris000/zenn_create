---
name: day3-finalize
description: Zenn 記事生成の Day 3(水曜朝)の作業手順。Day 2 のフィードバックを反映し、サムネを生成し、セルフレビューを行い、PR を Ready for Review 状態に移行する。水曜の Routine 起動時、記事を完成させる時に発動する。
---

# Day 3: 完成 + Ready for Review

3 日サイクルの最終日。Day 2 で書いた本文を磨き上げ、サムネを生成し、レビュー可能な状態にする。

## 前提

- Day 2 の PR が存在し、`[Day 2/3 WIP]` タイトルになっている
- Liatris から翌朝チェックでフィードバックが入っている可能性あり

## 作業手順

### Step 1: 前日の PR を探す + フィードバック確認

```bash
cd ~/zenn_create
git pull origin main -q

LATEST_BRANCH=$(git branch -r | grep "origin/article/" | sort | tail -1 | sed 's|origin/||' | xargs)
git checkout "${LATEST_BRANCH}"
git pull origin "${LATEST_BRANCH}" -q
```

PR コメントを確認:

```bash
gh pr view "${PR_URL}" --comments
```

Liatris のコメントがあれば、その内容を踏まえて反映する。

### Step 2: フィードバック反映

PR コメントの指摘を本文に反映する。

反映後にコミット:

```bash
git add articles/${ARTICLE_SLUG}.md
git commit -m "Day 3: フィードバック反映"
```

### Step 3: サムネ生成

```bash
./scripts/generate-thumbnail.sh "${ARTICLE_TITLE}" "./images/${ARTICLE_SLUG}_thumbnail.png"
```

成果物が HTML ならスクリーンショットも撮影:

```bash
# Puppeteer でスクショ取得 → ./images/${ARTICLE_SLUG}_screenshot.png
```

### Step 4: frontmatter 確認

`articles/${ARTICLE_SLUG}.md` の frontmatter を確認:

```yaml
---
title: "..."
emoji: "🤖"
type: "tech"
topics: [...]
published: false  # ← 必ず false のまま、日曜夜に true にする
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/${ARTICLE_SLUG}_thumbnail.png
---
```

注意:

- `published_at` はまだ設定しない(日曜夜の Liatris 手動マージ時にセットする)
- `published: false` を維持(マージ後の自動公開を防ぐため)

### Step 5: セルフレビュー

以下のチェックリストで自己レビュー:

- [ ] リード文がテンプレ的でない(「〜と感じたことはないでしょうか」等を多用していない)
- [ ] 業務コンテクストが出ていない(`docs/cycle-overview.md` の情報漏れ対策参照)
- [ ] 本名「平野翔斗」が記事本文内に出ていない(プロフィール表示は OK)
- [ ] コードブロックの言語指定が正しい
- [ ] 画像パスが正しい(`https://raw.githubusercontent.com/liatris000/zenn_create/main/images/...`)
- [ ] 内部リンクが切れていない
- [ ] サムネ画像が生成されている(`images/${ARTICLE_SLUG}_thumbnail.png`)
- [ ] スクショ画像が生成されている(HTML 成果物の場合)
- [ ] 文字数が 1500〜3000 字の範囲(極端に短い / 長い場合は要調整)

詳細は `.claude/skills/article-writing/SKILL.md` のチェックリスト参照。

### Step 6: PR タイトル更新と Ready for Review

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

### Step 7: Liatris 向けチェックポイント生成

週末の Liatris チェックで見るべきポイントを Chatwork で送る。テンプレ:

```
[Day 3 完了] ${ARTICLE_TITLE}

【今週の差別化ポイント】
- (Day 2 で発見した重要な点を 1〜2 行で)

【先行記事との違い】
- (供給シグナル判定で発見した「先行記事の弱点」と「本記事の補完点」)

【データアナリスト視点】
- (記事内に入れたデータ視点・他の人があまり書かない切り口)

【セルフチェック結果】
- (Step 5 のチェックリストで気になった点があれば)

PR: ${PR_URL}
週末に最終チェックお願いします。
```

### Step 8: Chatwork 通知

```bash
./scripts/notify-chatwork.sh \
  "Day 3 完了 (Ready for Review): ${ARTICLE_TOPIC}" \
  "${ARTICLE_TITLE}" \
  "${WORD_COUNT}" \
  "未定 (来週月曜公開予定)" \
  "${PAGES_URL}" \
  "${REPO_URL}" \
  "${PR_URL}"
```

### Step 9: 完了報告

```
Day 3 完了 (PR: ${PR_URL}, 文字数: ${WORD_COUNT}字)
週末にチェックお願いします。
日曜夜にマージすると、月曜 7:00 に自動公開されます。
```

## 中断時の挙動

- Day 2 の PR が見つからない → 何もせず終了(その週中止)
- フィードバック反映で Liatris に追加質問が必要 → 質問を Chatwork に送って Day 3 完了状態にしない

## 絶対 NG(Day 3 特有)

- `published: true` にしない(これは日曜夜の Liatris 手動マージで実施)
- `published_at` をセットしない(同上)
- main へ直 push しない
- セルフレビューをスキップしない
- 業務コンテクストが残っていないか必ずチェック
