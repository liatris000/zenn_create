---
name: day1-kickoff
description: Zenn 記事生成の Day 1(月曜朝)の作業手順。題材選定→実装方針→下書き作成→PR 作成までを行う。月曜の Routine 起動時、新サイクルを始める時、「Day 1 として進めて」と指示された時に発動する。
---

# Day 1: 題材選定 + 下書き作成

3 日サイクルの初日。題材を決め、実装方針を立て、PR を WIP 状態で作成するまでが責務。

## 前提

- 月曜朝の Routine 起動を想定
- `business-profile/` submodule が同期済み(SessionStart hook `scripts/session-start.sh` で毎セッション同期される)
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

#### Step 1.5: business-profile submodule 存在チェック (必須ゲート)

題材選定は `business-profile/` の中身を参照して行うため、submodule が存在しない場合は **Day 1 を続行できない**。以下のチェックを必ず実行する:

```bash
# .gitmodules が存在するか
test -f ~/zenn_create/.gitmodules || { echo "FATAL: .gitmodules がありません"; exit 1; }

# business-profile/ が空でないか (実体が取得済みか)
test -n "$(ls -A ~/zenn_create/business-profile 2>/dev/null)" || { echo "FATAL: business-profile/ が空です"; exit 1; }

# 中身が読めるか (代表ファイル)
test -f ~/zenn_create/business-profile/policies/disclosure-rules.md || { echo "FATAL: 業務プロフィールの代表ファイルが見えません"; exit 1; }
```

いずれかが NG の場合は Step 2 に進まず、Liatris に submodule 登録を依頼して **Day 1 を中止**する:

```
🛑 business-profile submodule が利用できないため Day 1 を中止します。
以下を実行してください:

  cd ~/zenn_create
  git submodule add https://github.com/liatris000/liatris-business-profile.git business-profile
  git config -f .gitmodules submodule.business-profile.branch main
  git add .gitmodules business-profile
  git commit -m "chore: add business-profile submodule"
  git push

登録完了後に Day 1 を再起動してください。Routine 起動時に SessionStart hook
(`scripts/session-start.sh`) が submodule を自動同期します。
```

このチェックを合格しない限り Step 2(題材選定)に進んではならない。

### Step 2: 題材選定

`topic-selection` skill を発動して題材候補を選ぶ。
**Liatris 対話確認待ちで停止しない**。`topic-selection` skill の「自動採用ロジック」に従って自動的に採用 / 中止を判断する:

- ★★★ または ★★ 候補が見つかった場合 → 自動採用 → Step 3 に進む
- ★ / △ のみ または候補ゼロ → Day 1 を自動中止 → 失敗時のフォールバックへ

採用された題材情報(題材名、業務プール、判定、disclosure 等)は Step 6 (PR 本文) で使う。

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
- **採用判定の根拠**: topic-selection skill が出力した判定情報(★★★/★★、需要、供給、キャッチアップ価値、実装規模、公開可否、理由)を本文に貼る
- **候補リスト**: topic-selection skill が出力した候補リスト(採用候補 + 検討して落ちた候補)を本文に貼る
  - 業務プール内候補と業務プール外候補を分けて記載
  - 不採用候補にも理由を 1 行ずつ書く
  - これにより Liatris レビュー時に「なぜこれが選ばれたか」が透明化される
- **Liatris レビュー依頼文**: 以下を必ず PR 本文の冒頭に記載

  > 🔍 **Liatris レビューお願いします(Day 2 起動前の火曜朝までに)**
  >
  > Day 1 ルーティンが自動採用した題材です。NG の場合はこの PR を close すれば、Day 2 ルーティンは PR を見つけられず自動的にスキップされます。
  > 採用判定の根拠は下記の通り:

- **disclosure: careful の場合の警告**: 採用題材が careful なら、上記レビュー依頼の直後に **「⚠️ disclosure: careful 題材につき、レビュー必須」** を追記
- **★★ 自動採用の場合の警告**: 採用題材が ★★ なら、上記レビュー依頼の直後に **「⚠️ ★★ 自動採用のため、題材として弱い可能性あり」** を追記

### Step 7: Chatwork 通知

`./scripts/notify-chatwork.sh` を実行して Day 1 完了を通知。
Day 1 段階では成果物 URL や記事公開URLが存在しないため、空文字を渡す:

```bash
./scripts/notify-chatwork.sh \
  "Day 1 完了: ${ARTICLE_TOPIC}" \
  "${ARTICLE_TITLE}" \
  "下書き段階" \
  "未定 (来週月曜公開予定)" \
  "" \
  "" \
  "${PR_URL}"
```

通知本文には自動的に「内容を確認してマージすると...」が含まれる(スクリプト側のフォーマット)。
Day 1 段階の通知は Liatris の火曜朝レビュー依頼を兼ねるので、PR_URL が確実に通知に入っていれば OK。

### Step 8: 完了報告

```
Day 1 完了 (PR: ${PR_URL}, 題材: ${ARTICLE_TOPIC})
明日 Day 2 で実装を進めます。
```

## 失敗時のフォールバック

- **submodule 未登録 (`.gitmodules` 不在 / `business-profile/` が空)** → Liatris に登録依頼して **Day 1 を中止**(Step 1.5 参照)
- **題材が見つからない (★/△ のみまたは候補ゼロ)** → 自動中止。Chatwork に「今週は中止: 採用可能な候補がありません(★/△ のみ)」と通知して終了。Liatris の対話確認は求めない(ルーティン完走前提のため)。
- submodule 同期失敗 (登録済みだが取得失敗) → 手動で `git submodule update --remote --merge business-profile` を実行
- slug 検証失敗 → `THEME_SLUG` を 12〜50 文字、英小文字 / 数字 / ハイフン / アンダースコアに修正

## 絶対 NG(Day 1 特有)

- 業務プロフィール内のファイル(`business-profile/`)を編集しない
- kubell 領域の具体実装を題材化しない(Liatris 確認なしの自動判定 NG)
- 業務コンテクストを commit message / PR 本文に出さない
