# Routine プロンプト集

Claude Code Web の Routine に登録している 3 本の本体プロンプト。**このファイルが正本**で、
Routine 側の設定はこのファイルに合わせる(管理画面へのコピペか、remote-trigger API での更新)。
Routine 側だけを直すと、このファイルとずれて次に直す人が古い版を元にしてしまう。

**最終更新**: 2026-11-07(実際に登録されている版と照合し、Day 1 の前提と Day 3 の pattern 連続時の扱いを直した)
**設計方針**: プロンプト本体は薄く保ち、判断ロジックは `.claude/skills/` と `docs/` に集約。
プロンプトに SKILL の挙動を書き写さない。書き写すと、SKILL を直したときにプロンプトだけ古い挙動を指示する
(2026-11 に、Day 3 のプロンプトが「3 連続でも止めない」と書いたまま残っていた)。

| Routine | 名前 | 起動(UTC) | 起動(JST) |
|---|---|---|---|
| A | `zenn_create_day_1` | `0 0 * * 1` | 月曜 09:00 |
| B | `zenn_create_day_2` | `0 0 * * 2` | 火曜 09:00 |
| C | `zenn_create_day_3` | `0 0 * * 3` | 水曜 09:00 |

振り返りは Routine にしない(`docs/cycle-overview.md` の「振り返り」)。

## Routine A: `zenn_create_day_1`

```
zenn_create リポジトリで Day 1 の作業を実行してください。

# 前提
- 今日は新サイクルの月曜朝
- business-profile/ submodule が同期されている必要がある
- 前週の PR がマージ済みとは限らない。前サイクルの PR の扱いは SKILL の Step 1.6 に従う(マージ済みを前提にしない)

# やること
1. .claude/skills/day1-kickoff/SKILL.md を読んで、その手順に従って作業する
2. 題材選定では .claude/skills/topic-selection/SKILL.md を発動する
3. 下書き作成では .claude/skills/article-writing/SKILL.md を発動する
4. PR を [Day 1/3 WIP] タイトルで作成し、Chatwork に通知。PR 本文に「前の週の結果」を 1 行書く(SKILL の Step 6)

注: 環境準備は Routine 環境設定の Setup script、submodule 同期等は SessionStart hook (scripts/session-start.sh) で自動実行される。Day 1 専用の追加セットアップは不要。

# 重要なルール
- 業務コンテクストを commit message / PR 本文に出さない
  詳細: docs/cycle-overview.md の「情報漏れ対策」
- 題材選定で Liatris 確認が必要なケースは判断ロジック skill を参照
- main への直 push は禁止

# 完了報告
作業完了後、以下のフォーマットで報告:
「Day 1 完了 (PR: ${PR_URL}, 題材: ${ARTICLE_TOPIC}). 明日 Day 2 で実装を進めます。」

# 失敗時
- 題材が見つからない → Liatris に確認 →「今週は中止」or「業務領域の一般化ノウハウ題材」
- submodule 同期失敗 → SessionStart hook (scripts/session-start.sh) を再実行
- 3 回試行して失敗 → WIP コミットして停止し、Chatwork に状況を報告
```

## Routine B: `zenn_create_day_2`

```
zenn_create リポジトリで Day 2 の作業を実行してください。

# 前提
- 今日は火曜朝(Day 1 の翌日)
- 月曜の Day 1 で [Day 1/3 WIP] タイトルの PR が存在しているはず
- PR が存在しない場合は「その週は中止」扱い、何もせず終了

# やること
1. .claude/skills/day2-implementation/SKILL.md を読んで、その手順に従って作業する
2. 記事本文の執筆では .claude/skills/article-writing/SKILL.md を発動する
3. SKILL の順序を守る: 実装 → 記事本文 → PR タイトルを [Day 2/3 WIP] に更新して push → 成果物リポジトリ公開。
   本文とタイトル更新が先なのは、成果物公開が失敗しても翌日の Day 3 が PR を見つけられるようにするため(2026-08-18 変更)
4. Chatwork に「翌朝 Day 3 進行前にチェックお願いします」と通知

注: 環境準備は Routine 環境設定の Setup script、submodule 同期等は SessionStart hook で自動実行される。

# 重要なルール
- 新規 PR を作らない(Day 1 の PR に追記する)
- 業務コンテクストを記事本文 / commit message に出さない
- main への直 push は禁止
- CI / ワークフロー / スクリプトの変更を記事 PR に混ぜない。仕組み側を直す必要が出たら別ブランチで PR を立てる
- 成果物リポジトリの公開が失敗しても停止しない。SKILL の Step 6 に従って PR に未完了コメントを残し、Step 7/8 まで進む

# 完了報告
SKILL の Step 8 の形式に従う。成果物公開が失敗している場合は「完了」と書かず、
「Day 2 完了 / 成果物公開のみ未完了」と明示すること。未完了を完了と報告しない。

# 中断時
- Day 1 の PR が存在しない → 何もせず終了。Chatwork に「Day 2: 対象 PR が見つからないためスキップ」と通知
- 実装が動かない → 3 回試して失敗ならコメント追記して停止、Liatris 判断を仰ぐ
- 既に Ready for Review 状態(Day 3 完了済み)→ 何もせず終了
```

## Routine C: `zenn_create_day_3`

```
zenn_create リポジトリで Day 3 の作業を実行してください。

# 前提
- 今日は水曜朝(Day 2 の翌日)
- 火曜の Day 2 で [Day 2/3 WIP] タイトルの PR が存在しているはず
- PR コメントに Liatris のフィードバックが入っている可能性あり
- PR が存在しない場合は「その週は中止」扱い、何もせず終了
- Day 1 / Day 2 で export した環境変数 (ARTICLE_SLUG / ARTICLE_TITLE 等) はセッション間で引き継がれない前提で動く

# やること
1. .claude/skills/day3-finalize/SKILL.md を読んで、その手順に従って作業する
2. Step 0 で対象 PR ([Day 2/3 WIP]) を探し、PR タイトルと差分ファイル一覧から ARTICLE_TITLE / ARTICLE_SLUG を逆引きして環境変数にセット
3. Step 1 で PR コメントの Liatris フィードバックを確認
4. Step 2 で Day 1 から続いている同一 PR の本文を /tmp/zenn_artifact/day1_pr_body.md に退避(Step 8 で参照)
5. Step 3 でフィードバックを本文に反映してコミット
6. Step 4 でサムネ生成 (scripts/generate-thumbnail.sh)
7. Step 5 で frontmatter の pattern (implementation / comparison / concept / other) を確認し、published: false → true に反転(published_at の Day 1 予約スロットは維持)。Step 5.1 で直近 3 記事との pattern 履歴チェック
8. Step 6 でセルフレビュー(6.1 文体チェック / 6.2 サムネ存在 / 6.3 成果物リポジトリ公開状態 / 6.4 機密文字列スキャン)。6.1 のチェックリストは全部通す(SKILL に見やすさのスクリプトがあれば、それも実行する)
9. Step 7 で PR タイトルを [Day 3/3 Ready for Review] に更新、Ready for Review に変更、最終 push
10. Step 8 で Liatris 向けチェックポイント (CHECKPOINT_BODY) を組み立て、Step 9 で notify-chatwork.sh の --body モードで Chatwork に送信
11. Step 10 の完了報告フォーマットで Liatris に報告

注: 環境準備は Routine 環境設定の Setup script、submodule 同期等は SessionStart hook (scripts/session-start.sh) で自動実行される。Day 3 専用の追加セットアップは不要。

# 重要なルール
- published: false → true に反転する(週刊連載キュー。マージされれば予約日時に自動公開、公開判断はマージで人間が行う)
- published_at は Day 1 で予約済みのスロットを維持する(勝手に変更しない。キューの順序が崩れる)
- main への直 push は禁止
- セルフレビュー(Step 6)を必ず通す。FATAL の自動チェックで exit 1 が出たら停止して修正
- 機密文字列スキャン (Step 6.4) で検出されたら必ずマスクする(published 状態に関わらず。PR は Public リポジトリで履歴に残る)
- 業務コンテクストが記事本文に残っていないか必ず最終確認
- Step 9 の Chatwork 通知は --body モードを使う(CHECKPOINT_BODY をそのまま送る)
- 新規 PR を作らない(Day 1 の PR に追記する)

# 完了報告
「Day 3 完了 (PR: ${PR_URL}, 文字数: ${WORD_COUNT}字, 予約公開: ${PUBLISHED_AT}). 週末にチェックお願いします。レビュー後にマージすると予約スロットに自動公開されます。」

# 中断時
- Day 2 の PR ([Day 2/3 WIP]) が見つからない → 何もせず終了。Chatwork に「Day 3: 対象 PR が見つからないためスキップ」と通知
- Step 0 の環境変数復元 (ARTICLE_TITLE / ARTICLE_SLUG) に失敗 → exit 1 で停止、Chatwork に状況を通知して Liatris に PR の状態確認を依頼
- 既に [Day 3/3 Ready for Review] 状態 → 何もせず終了
- Step 6 のアセット存在チェック / 機密文字列スキャンで FATAL → 修正してから Step 6 を再実行(exit 1 のあと再開)。修正困難なら Chatwork に状況を送って Day 3 を完了状態にしない (Ready for Review にしない)
- Step 5.1 で同一 pattern が 3 回連続 → SKILL の記述に従う。止まった場合は、本文の構成を別パターンに組み替え、frontmatter の pattern を実際の構成に合わせてから Step 5.1 をやり直す(ラベルだけ変えて通さない)
- フィードバック反映で Liatris に追加質問が必要 → 質問を Chatwork に送って Day 3 を完了状態にしない (Ready for Review にしない)
```

## 旧 Routine `daily-zenn-create`

2026-04 に 3 本へ分割して廃止した。Routine 一覧には無効(enabled: false)のまま残っている。
新 Routine と同時に有効にしない(同じ週に複数 PR が走るため)。
