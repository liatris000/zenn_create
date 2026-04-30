---
name: day1-kickoff
description: Zenn 記事生成の Day 1(月曜朝)の作業手順。題材選定→実装方針→下書き作成→PR 作成までを行う。月曜の Routine 起動時、新サイクルを始める時、「Day 1 として進めて」と指示された時に発動する。
---

# Day 1: 題材選定 + 下書き作成

3 日サイクルの初日。題材を決め、実装方針を立て、PR を WIP 状態で作成するまでが責務。

## 前提

- 月曜朝の Routine 起動を想定
- `business-profile/` submodule が同期済み(`scripts/setup-claude-code.sh` で実行)
- 前週の PR がマージ済みで、新サイクルを始められる状態

## 作業手順

### Step 1: 環境確認

```bash
cd ~/zenn_create
git status
git pull origin main -q
```

submodule の同期状態を確認:

```bash
cd ~/zenn_create/business-profile
git log -1 --format="%H %s"
cd ~/zenn_create
```

### Step 2: 題材選定

`topic-selection` skill を発動して題材候補を選ぶ。
選定結果を Liatris に確認依頼。OK が出るまで先に進まない。

### Step 3: 実装方針の決定

採用題材について、実装方針を決める:

- 使用する技術・ライブラリ
- 成果物のタイプ(HTML / JS / Python script / etc)
- GitHub Pages で公開可能か
- 想定される実装規模(S / M / L)

### Step 4: 環境変数の設定

```bash
export THEME_SLUG="..."
export ARTICLE_TITLE="..."
export ARTICLE_TOPIC="..."
export ARTICLE_SLUG="$(date +%Y%m%d)-${THEME_SLUG}"
export REPO_NAME="liatris-${ARTICLE_SLUG}"
```

slug を検証:

```bash
./scripts/validate-slug.sh "${ARTICLE_SLUG}"
```

### Step 5: 下書き作成

`/tmp/zenn_artifact/article_draft.md` に下書きを作成。

下書きの段階では:

- frontmatter は作成するが `published: false` にしておく
- 構成案レベル(各セクションの見出し + 1〜2 文の概要)を書く
- まだコードや具体実装は書かない(Day 2 で書く)

文体は `.claude/skills/article-writing/SKILL.md` を参照。

### Step 6: PR 作成 (WIP 状態)

PR タイトルに `[Day 1/3 WIP]` を付ける。

PR 本文には以下を明記:

- 題材(業務コンテクストは出さない)
- 実装方針(技術スタック等)
- 想定される実装規模
- Day スケジュール

### Step 7: Chatwork 通知

`./scripts/notify-chatwork.sh` を実行して Day 1 完了を通知。

### Step 8: 完了報告

```
Day 1 完了 (PR: ${PR_URL}, 題材: ${ARTICLE_TOPIC})
明日 Day 2 で実装を進めます。
```

## 失敗時のフォールバック

- 題材が見つからない → Liatris 確認 →「今週は中止」or「kubell 領域の一般化ノウハウ」
- submodule 同期失敗 → `scripts/setup-claude-code.sh` 再実行
- slug 検証失敗 → `THEME_SLUG` を 12〜50 文字、英小文字 / 数字 / ハイフン / アンダースコアに修正

## 絶対 NG(Day 1 特有)

- 業務プロフィール内のファイル(`business-profile/`)を編集しない
- kubell 領域の具体実装を題材化しない(Liatris 確認なしの自動判定 NG)
- 業務コンテクストを commit message / PR 本文に出さない
