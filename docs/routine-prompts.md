# Routine プロンプト集

Claude Code Web の管理画面で設定する 3 本の Routine の本体プロンプト。
本ファイルから Liatris が手動でコピペして登録する。

**最終更新**: 2026-04-30
**設計方針**: プロンプト本体は薄く保ち、判断ロジックは `.claude/skills/` と `docs/` に集約。

## Routine A: `zenn-day1`

**起動タイミング**: 毎週月曜朝(自動)

```
zenn_create リポジトリで Day 1 の作業を実行してください。

# 前提
- 今日は新サイクルの月曜朝
- business-profile/ submodule が同期されている必要がある
- 前週の PR がマージ済みで、新サイクルが開始可能な状態のはず

# やること
1. scripts/setup-claude-code.sh を実行して環境を整える
2. .claude/skills/day1-kickoff/SKILL.md を読んで、その手順に従って作業する
3. 題材選定では .claude/skills/topic-selection/SKILL.md を発動する
4. 下書き作成では .claude/skills/article-writing/SKILL.md を発動する
5. PR を [Day 1/3 WIP] タイトルで作成し、Chatwork に通知

# 重要なルール
- 業務コンテクストを commit message / PR 本文に出さない
  詳細: docs/cycle-overview.md の「情報漏れ対策」
- 題材選定で Liatris 確認が必要なケースは判断ロジック skill を参照
- main への直 push は禁止

# 完了報告
作業完了後、以下のフォーマットで報告:
「Day 1 完了 (PR: ${PR_URL}, 題材: ${ARTICLE_TOPIC}). 明日 Day 2 で実装を進めます。」

# 失敗時
- 題材が見つからない → Liatris に確認 →「今週は中止」or「kubell領域の一般化ノウハウ」
- submodule 同期失敗 → scripts/setup-claude-code.sh を再実行
- 3 回試行して失敗 → WIP コミットして停止し、Chatwork に状況を報告
```

## Routine B: `zenn-day2`

**起動タイミング**: 毎週火曜朝(自動)

```
zenn_create リポジトリで Day 2 の作業を実行してください。

# 前提
- 今日は火曜朝(Day 1 の翌日)
- 月曜の Day 1 で [Day 1/3 WIP] タイトルの PR が存在しているはず
- PR が存在しない場合は「その週は中止」扱い、何もせず終了

# やること
1. scripts/setup-claude-code.sh を実行
2. .claude/skills/day2-implementation/SKILL.md を読んで、その手順に従って作業する
3. 記事本文の執筆では .claude/skills/article-writing/SKILL.md を発動する
4. PR タイトルを [Day 2/3 WIP] に更新し、追記コミット
5. Chatwork に「翌朝 Day 3 進行前にチェックお願いします」と通知

# 重要なルール
- 新規 PR を作らない(Day 1 の PR に追記する)
- 業務コンテクストを記事本文 / commit message に出さない
- main への直 push は禁止

# 完了報告
「Day 2 完了 (PR: ${PR_URL}, 文字数: ${WORD_COUNT}字). 明朝出社前にチェックお願いします。」

# 中断時
- Day 1 の PR が存在しない → 何もせず終了。Chatwork に「Day 2: 対象 PR が見つからないためスキップ」と通知
- 実装が動かない → 3 回試して失敗ならコメント追記して停止、Liatris 判断を仰ぐ
- 既に Ready for Review 状態(Day 3 完了済み)→ 何もせず終了
```

## Routine C: `zenn-day3`

**起動タイミング**: 毎週水曜朝(自動)

```
zenn_create リポジトリで Day 3 の作業を実行してください。

# 前提
- 今日は水曜朝(Day 2 の翌日)
- 火曜の Day 2 で [Day 2/3 WIP] タイトルの PR が存在しているはず
- PR コメントに Liatris のフィードバックが入っている可能性あり
- PR が存在しない場合は「その週は中止」扱い、何もせず終了

# やること
1. scripts/setup-claude-code.sh を実行
2. .claude/skills/day3-finalize/SKILL.md を読んで、その手順に従って作業する
3. PR コメントの Liatris フィードバックを反映
4. サムネ生成(scripts/generate-thumbnail.sh)
5. .claude/skills/article-writing/SKILL.md のチェックリストでセルフレビュー
6. PR タイトルを [Day 3/3 Ready for Review] に更新、Ready for Review に変更
7. Liatris 向けチェックポイントを生成して Chatwork に送信

# 重要なルール
- published: false のまま終わらせる(日曜夜の Liatris 手動マージで true にする)
- published_at をセットしない(同上)
- main への直 push は禁止
- セルフレビューチェックリストを必ず通す

# 完了報告
「Day 3 完了 (PR: ${PR_URL}, 文字数: ${WORD_COUNT}字). 週末にチェックお願いします。日曜夜にマージで月曜 7:00 に自動公開されます。」

# 中断時
- Day 2 の PR が見つからない → 何もせず終了
- フィードバック反映で追加質問が必要 → 質問を Chatwork に送って Day 3 を完了状態にしない
```

## 旧 Routine `daily-zenn-create` の廃止

### 廃止手順

1. Claude Code Web の Routine 設定画面から `daily-zenn-create` を **OFF** にする
2. 上記 3 本(`zenn-day1` / `zenn-day2` / `zenn-day3`)を新規作成 + 各起動曜日にスケジュール
3. 1 サイクル(月-水)動作確認後、`daily-zenn-create` を削除

### 並行運用の注意

- 新 Routine と `daily-zenn-create` を同時に走らせない(同じ週に複数 PR が走るため)
- 切替時は必ず `daily-zenn-create` を OFF にしてから新 Routine を ON にする

## 初回サイクルの動作確認項目

新 Routine 群の初回サイクルで以下を確認:

- [ ] Day 1: 業務プロフィール参照が機能するか(business-profile が空でないか)
- [ ] Day 1: 題材選定で Liatris 確認が出るか
- [ ] Day 1: PR が `[Day 1/3 WIP]` タイトルで作成されるか
- [ ] Day 2: 前日の PR を正しく見つけるか
- [ ] Day 2: PR タイトルが `[Day 2/3 WIP]` に更新されるか
- [ ] Day 3: PR コメントのフィードバックを反映するか
- [ ] Day 3: セルフレビューチェックリストが動くか
- [ ] Day 3: Liatris 向けチェックポイントが生成されるか
- [ ] 中断テスト: 月曜サボった想定 → 火曜 Routine が「PR が見つからない」で終了するか
