---
name: topic-selection
description: Zenn 記事の題材を選定する時に使う。業務プロフィールから候補を抽出し、需要×供給シグナルで判定する。Day 1 の題材選定フェーズで必須。新しい題材を選ぶ時、業務プールから候補を抽出する時、kubell 領域を題材化検討する時に発動する。
---

# 題材選定 skill

AI 記事の題材選定を業務プロフィールベースで行うための判断ロジック。
詳細仕様は `business-profile/companies/personal/ai-articles/topic-selection.md` を参照。

## 判断フロー(7 ステップ)

```
[業務プール] → ① 公開可否 → ② キャッチアップ価値 → ③ 需要シグナル
              → ④ 供給シグナル → ⑤ スイートスポット判定
              → ⑥ Liatris 確認 → ⑦ 採用
```

詳細は `business-profile/companies/personal/ai-articles/topic-selection.md` を直接参照する。

## 発動タイミング

- Day 1 Routine 起動時(必ず)
- Liatris から「題材を考え直したい」と指示された時
- 候補題材が公開可否ルールに抵触するか確認したい時

## 重要: ルーティン完走前提

このスキルは Day 1 ルーティンから呼ばれるため、**Liatris の対話確認待ちで停止してはならない**。判定結果に基づいて自動採用または自動中止のどちらかに必ず分岐する。詳細は下記「自動採用ロジック」セクション参照。

## 前提 ⚠️ 必須

> **`business-profile/` submodule が登録済みかつ同期済みであること。**
> このスキルは `business-profile/` 配下のファイル(README、`disclosure-rules.md`、`topic-selection.md` 等)を読み込んで判断する設計になっており、**submodule なしでは判断フローを 1 ステップも実行できない**。
>
> 確認方法:
>
> ```bash
> test -f ~/zenn_create/.gitmodules \
>   && test -f ~/zenn_create/business-profile/policies/disclosure-rules.md \
>   && echo OK || echo "NG: submodule 未登録 or 未同期"
> ```
>
> NG の場合はこのスキルの判断フローを開始してはいけない。**Day 1 skill (`day1-kickoff`) 側の Step 1.5 で Liatris に submodule 登録を依頼して中止する**運用になっている。間違ってもダミー候補や記憶ベースで題材を提案しないこと。

その他:

- SessionStart hook (`scripts/session-start.sh`) で submodule が `--remote --merge` 同期済み
- Liatris が同じセッション内にいて、確認を返せる状態

## 業務プール参照の手順

1. 以下の README を順に view する:
   - `business-profile/companies/ymn/README.md`
   - `business-profile/companies/onelife/README.md`
   - `business-profile/companies/linkalink/README.md`
   - `business-profile/companies/personal/yamabiko/README.md`

2. 各種のメタデータをチェック:
   - `status: 未着手` のものだけを候補にする
   - `disclosure: blocked` は除外する
   - `catchup_value: high` を優先する

3. **kubell 領域は対象外**(business-profile 側の `topic-selection.md` で明記されている)
   - kubell 関連の題材候補が思い浮かんでも、Liatris に必ず確認する

## 既存記事に引きずられない

`articles/` 内の既存記事を確認するのは「題材被り防止」のためであり、「既存記事の延長線上の題材を選ぶ」ためではない。

### NG パターン

- 既存記事が「Claude Code Hooks」を扱っている → 新記事を「Claude Code の `.claude/` 整備」のような連続性のある題材にする
- 既存記事が「Firecrawl」を扱っている → 新記事も MCP 系で揃える

### 正しい挙動

業務プールから独立に判定する。既存記事との連続性は採用基準に含めない。

業務プールから候補を選んだ後、`articles/*.md` をスキャンして「題材として被っていないか」だけチェックする(被っていれば不採用、それ以外は採用)。

## 業務プール外題材の扱い

業務プールに採用可能な ★★★/★★ 候補がある限り、業務プール外を選んではいけない。

業務プール外を採用してもよい条件:

1. 業務プールから ★/△ または候補ゼロしか出ない
2. 業務プール外候補が AI 駆動開発・Claude Code 運用・MCP・スキル設計等、Liatris の AI 駆動開発キャリア軸に直接関わる題材である

この条件を満たす場合のみ、業務プール外候補を採用候補として PR 本文の「候補リスト」に含める。

業務プール外候補の判定は、業務プール内候補と同じ需要×供給シグナルロジックで行う。

## 公開可否チェックの手順

1. `business-profile/policies/disclosure-rules.md` を view する
2. 候補題材に該当する会社・プロジェクトのセクションを確認
3. 「❌ NG」の項目に抵触しないか 1 つずつチェック
4. 抵触の可能性があれば候補から除外、または Liatris に確認

## 自動採用ロジック

判定が出たら、以下のロジックで自動採用または中止判断する。**Liatris 確認待ちで停止しない**(ルーティンを完走させるため)。

### 採用ルール

| 候補のうち最高判定 | 挙動 |
|---|---|
| ★★★ が 1 つ以上 | **第1候補(★★★)を自動採用**。Day 1 を続行。 |
| ★★ が 1 つ以上、★★★ なし | **第1候補(★★)を自動採用**。Day 1 を続行。ただし PR 本文に「自動採用された ★★ 候補のため、題材として弱い可能性あり」と注意書きを記載。 |
| ★ または △ のみ、または候補ゼロ | **Day 1 を中止**。Chatwork に「今週は中止: 採用可能な候補がありません」と通知。 |

### 自動採用時の出力

skill の出力として、以下のフォーマットを Step 6 (PR 作成) に渡す:

```
題材: [題材名]
業務プール: business-profile/companies/<X>/README.md の <種>
判定: [★★★/★★] / 需要: [high/mid/low] / 供給: [空白/部分的/飽和]
キャッチアップ価値: [high/mid] / 推定実装規模: [S/M/L]
公開可否: [clean/careful] / 抵触リスク: [なし/あり(careful なら Liatris レビュー必須)]
理由: [1〜2 行]

[★★ の場合のみ] 注意: 自動採用された ★★ 候補のため、題材として弱い可能性あり。Liatris レビューで判断してください。
```

### Liatris の介入ポイント

題材の最終判断は、Day 2 起動前の朝(火曜朝)の PR レビューで Liatris が行う。NG の場合は PR を close することで Day 2 が走らなくなる(Day 2 skill は `[Day 1/3 WIP]` PR を探すため)。
詳細は [`docs/cycle-overview.md`](../../../docs/cycle-overview.md) の「Liatris チェックポイント」セクション参照。

### 例外: disclosure: careful の場合

候補が `disclosure: careful` の場合、自動採用しても OK だが、PR 本文の冒頭に **「⚠️ disclosure: careful 題材につき、Liatris レビュー必須」** と明記する。

## `.claude/` 配下のファイル生成を伴う題材の扱い

題材の成果物に `.claude/mcp.json` 等、`.claude/` 配下のファイル生成が含まれる場合は、以下を必ず守る:

- 採用判定自体は通常通り(★★★/★★ 判定でブロックしない)
- ただし PR 本文の実装方針セクションに **「成果物に `.claude/` 配下のファイル含む → publish-artifact.sh の `_claude_template/` 機構を使う」** と明記すること
- Day 2 skill の Step 3 で `_claude_template/` への配置が指示されているため、それに従う

これにより、Claude Code の `.claude/` 書き込み保護と Routine 自動化が両立する。

## 候補リスト公開(必須)

採用判定の前に、検討した候補すべてを列挙して PR 本文に記載する。これにより Liatris レビュー時に「なぜこれが選ばれたか」「他にどんな候補があったか」が分かるようになる。

採用判定を出す前に、以下のフォーマットで候補一覧を整理しておく(Step 6 の PR 本文で使う):

```
## 候補リスト

業務プールから:
- [候補1] (業務プール: <X>) → 判定: ★★★ → 採用
- [候補2] (業務プール: <Y>) → 判定: ★★ → 不採用 (理由: <なぜ第1候補に劣るか>)
- [候補3] (業務プール: <Z>) → 判定: ★ → 不採用 (理由: 採用基準未達)

業務プール外から(検討した場合のみ):
- [候補A] (テーマ: <概念領域>) → 判定: ★★ → 不採用 (理由: 業務プール内に上位候補あり)
```

採用候補だけでなく、検討して落ちた候補も書く。落ちた理由は 1 行で OK。

## 情報漏れ対策

このスキルを使う時、以下を厳守する:

- 題材選定の commit message に業務コンテクストを出さない
  - ❌「家業の OCR 自動化を題材として採用」
  - ✅「Day 1: 題材選定完了」
- PR 本文の題材説明に業務コンテクストを出さない
  - ❌「家業で必要な機能」
  - ✅「OCR で契約書をパースする UI」

詳細は `docs/cycle-overview.md` の「情報漏れ対策」セクション参照。
