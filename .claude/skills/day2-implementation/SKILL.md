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

# 直近の article/* ブランチを探す
LATEST_BRANCH=$(git branch -r | grep "origin/article/" | sort | tail -1 | sed 's|origin/||' | xargs)
```

PR が見つからない場合(月曜サボった等):

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

### Step 4: 成果物リポジトリの公開

```bash
./scripts/publish-artifact.sh "${REPO_NAME}" "/tmp/zenn_artifact" "${ARTICLE_TITLE}"
eval $(./scripts/publish-artifact.sh "${REPO_NAME}" "/tmp/zenn_artifact" "${ARTICLE_TITLE}" | grep -E '^(REPO_URL|PAGES_URL)=')
export REPO_URL PAGES_URL
```

### Step 5: 記事本文の追記

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
