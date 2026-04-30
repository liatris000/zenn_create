# 3日サイクル運用ガイド

zenn_create リポジトリの記事生成サイクルを定義する文書。
全 Routine とドキュメントは本ファイルに記述された前提に従って動作する。

**最終更新**: 2026-04-30

## サイクル全体像

zenn_create は **3日サイクル × 週1本投稿** で運用される。

```
月 (Day 1): 題材選定 + 実装方針 + 下書き → PR作成 (WIP)
火 (Day 2): 実装 + 推敲 → 同PRに追記 → 翌朝チェック依頼通知
水 (Day 3): Day 2 フィードバック反映 + サムネ + 完成 → Ready for Review
木:         バッファ
金 or 土:   Liatris 最終チェック (手動、15-30分)
日曜夜:     published_at を月曜7:00にセット → マージ (手動)
月曜 7:00:  Zenn 自動公開 + 同時に Routine A 起動 → 次サイクル Day 1
```

平日朝に Routine A/B/C(`zenn-day1` / `zenn-day2` / `zenn-day3`)が自動起動して
作業を進め、週末のチェックとマージは Liatris が手動で行う。

## Liatris チェックポイント

Liatris が PR をレビューする回数は **週 2 回**(火曜朝、週末)。それ以外は完全自動。

### ① 火曜朝(Day 2 起動前): 題材レビュー

- 月曜の Day 1 ルーティンが自動採用した題材を確認
- PR タイトル `[Day 1/3 WIP] ...` の本文を見て、題材として OK か判断
- **NG の場合**: PR を close する → Day 2 ルーティンは PR を見つけられず、自動的に「その週は中止」となる
- **OK の場合**: 何もしない → Day 2 ルーティンが翌朝走って実装を進める
- 所要時間: 1〜3 分

### ② 水曜朝(Day 3 起動前): 実装レビュー(任意)

- 火曜の Day 2 ルーティンが書いた本文を確認
- PR コメントで指摘 → Day 3 が反映する
- スキップしても OK(Day 3 がそのまま完成させて Ready for Review にする)
- 所要時間: 0〜10 分

### ③ 週末(金 or 土): 最終チェック

- `[Day 3/3 Ready for Review]` の PR を最終確認
- 文体、コード動作、サムネ、業務コンテクスト漏れがないか
- 必要なら自分で修正コミット
- 所要時間: 15〜30 分

### ④ 日曜夜: マージ

- `published_at` を翌週月曜 7:00 にセット
- `published: true` に変更
- マージ → 翌月曜 7:00 に Zenn が自動公開

### Liatris 介入の優先度

- ① は **必須**(題材 NG を翌朝までに止めないと、Day 2 が無駄走りする)
- ② は **任意**(スキップしても回る)
- ③ は **必須**(品質保証)
- ④ は **必須**(自動マージはしない)

### NG 題材の判定基準(① で見るべきポイント)

- ⚠️ disclosure: careful の警告が出ているか → 内容を慎重に確認
- ⚠️ ★★ 自動採用の警告が出ているか → 題材として弱くないか確認
- 業務コンテクストが PR 本文に漏れていないか
- kubell 領域に踏み込んでいないか
- 既出題材ではないか(`articles/` 内の既存記事と重複)

## 各日の責務

### Day 1(月曜朝、Routine A: zenn-day1)

- 業務プロフィール(submodule)の最新状態を pull
- 業務プールから題材候補を抽出(status: 未着手 のもの)
- 公開可否チェック(`business-profile/policies/disclosure-rules.md` 参照)
- 需要×供給シグナル判定(`business-profile/companies/personal/ai-articles/topic-selection.md` 参照)
- **自動採用**(★★★/★★ 候補があれば最上位を自動採用)→ 採用題材を決定
- 採用不可(★/△ のみ)の場合は自動中止
- 実装方針 + 下書き作成
- PR を WIP 状態で作成(タイトル: `[Day 1/3 WIP] ...`)
- Chatwork に Day 1 完了通知

### Day 2(火曜朝、Routine B: zenn-day2)

- 月曜の WIP PR を探す → なければスキップ(その週は中止)
- 実装をコードレベルで進める
- 文章を整える
- 同 PR に追記コミット(タイトル: `[Day 2/3 WIP] ...`)
- Chatwork に Day 2 完了通知(翌朝チェック依頼)

### Day 3(水曜朝、Routine C: zenn-day3)

- 火曜の PR を探す + Liatris のフィードバック確認
- フィードバック反映
- サムネ生成
- セルフレビュー(冗長表現チェック・リンク確認)
- PR を Ready for Review 状態に変更(タイトル: `[Day 3/3 Ready for Review] ...`)
- Chatwork に Day 3 完了通知(週末チェック依頼)

### 木〜土(バッファ + Liatris チェック)

- Routine は走らない
- Liatris が金 or 土に最終チェック(15-30 分目安)
- 必要ならコメント追記 → 翌週 Day 1 に持ち越す or 自分で修正

### 日曜夜(Liatris 手動マージ)

- `published_at` を翌週月曜 7:00 にセット
- `published: true` に変更
- PR をマージ

### 翌月曜 7:00(自動公開 + 次サイクル開始)

- Zenn が予約公開を実行
- 同じ朝に Routine A(zenn-day1)が起動 → 次サイクル Day 1

## 中断時の挙動

- Day 2 / Day 3 の Routine が起動した時、対象 PR が見つからなければ **何もしない**
- 自動的に「その週は中止」となる
- 月曜が祝日等で Day 1 が走らなかった場合も同様(その週は中止)
- 状態管理ファイルは持たない(PR の存在と状態が事実上の状態管理)

具体的な判定ロジック:

| 起動日 | 探す PR | 見つからない時の挙動 |
|---|---|---|
| Day 1 (月) | (新規) | 新サイクル開始 |
| Day 2 (火) | PR タイトル `[Day 1/3 WIP]` を含む open PR | 何もせず終了 + Chatwork 通知 |
| Day 3 (水) | PR タイトル `[Day 2/3 WIP]` を含む open PR | 何もせず終了 + Chatwork 通知 |

注: Routine 環境では Claude Code が自動的に `claude/<random>` プレフィックスのブランチを切るため、
ブランチ名規約ベースの検索は使えない。PR タイトル(Day 1: `[Day 1/3 WIP]`、Day 2: `[Day 2/3 WIP]`、
Day 3: `[Day 3/3 Ready for Review]`)が事実上の状態管理として機能する。

## 情報漏れ対策(必須)

zenn_create は **Public リポジトリ**。以下を厳守する。

### commit message

- 題材の固有名詞や業務コンテクストを出さない
- 一般的な記述に統一する
- ❌ NG 例: 「家業の OCR 契約書自動化を題材に Day 1 着手」
- ✅ OK 例: 「Day 1: 題材選定 + 下書き作成」

### 記事本文

- 業務文脈・関係者・取引先・パートナー・提携先は出さない
- 本名「平野翔斗」は記事本文内に出さない(プロフィール欄での表示は OK)
- フィクションの数値(「実行時間が 1.5 秒から 0.3 秒に改善」のような未計測の値)を書かない
- 詳細は `business-profile/policies/disclosure-rules.md` を参照

### PR 本文

- 題材は記載してよい(レビュー時に必要)、ただし業務コンテクストは出さない
- ❌ NG 例: 「家業で必要な機能を実装」
- ✅ OK 例: 「OCR で契約書をパースする UI」

### submodule の存在

- `business-profile/` という名前のディレクトリが Public リポに見える状態は許容
- リポ名(`liatris-business-profile`)が `.gitmodules` から読める状態も許容
- submodule 内のファイル中身は Private リポなので外部からは見えない

## 関連ファイル

| 役割 | パス |
|---|---|
| 業務プロフィール(submodule) | `./business-profile/` |
| 公開可否ルール | `./business-profile/policies/disclosure-rules.md` |
| 題材選定ロジック | `./business-profile/companies/personal/ai-articles/topic-selection.md` |
| Day 1 作業手順 | `./.claude/skills/day1-kickoff/SKILL.md` |
| Day 2 作業手順 | `./.claude/skills/day2-implementation/SKILL.md` |
| Day 3 作業手順 | `./.claude/skills/day3-finalize/SKILL.md` |
| 題材選定 skill | `./.claude/skills/topic-selection/SKILL.md` |
| 文体ガイド | `./docs/article-style-guide.md` |
| 運用ガイド | `./docs/operations.md` |
| 記事執筆 skill | `./.claude/skills/article-writing/SKILL.md` |
