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

- `scripts/setup-claude-code.sh` で submodule が `--remote --merge` 同期済み
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

## 公開可否チェックの手順

1. `business-profile/policies/disclosure-rules.md` を view する
2. 候補題材に該当する会社・プロジェクトのセクションを確認
3. 「❌ NG」の項目に抵触しないか 1 つずつチェック
4. 抵触の可能性があれば候補から除外、または Liatris に確認

## Liatris 確認の出し方

判断結果は以下のフォーマットで Liatris に提示する:

```
題材候補: [題材名]
業務プール: business-profile/companies/<X>/README.md の <種>
需要: [high/mid/low] / 供給: [空白/部分的/飽和] / 判定: [★★★/★★/★/△]
キャッチアップ価値: [high/mid] / 推定実装規模: [S/M/L]
公開可否: [clean/careful/blocked] / 抵触リスク: [なし/あり]
理由: [1 行]

進めて良いか?(Y/N)
```

## 情報漏れ対策

このスキルを使う時、以下を厳守する:

- 題材選定の commit message に業務コンテクストを出さない
  - ❌「家業の OCR 自動化を題材として採用」
  - ✅「Day 1: 題材選定完了」
- PR 本文の題材説明に業務コンテクストを出さない
  - ❌「家業で必要な機能」
  - ✅「OCR で契約書をパースする UI」

詳細は `docs/cycle-overview.md` の「情報漏れ対策」セクション参照。
