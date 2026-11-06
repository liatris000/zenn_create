# yomiyasu-mini の取り込み

このフォルダは [nanaism/yomiyasu-mini](https://github.com/nanaism/yomiyasu-mini) の `skills/yomiyasu-mini/` をそのまま写したもの。中身は書き換えていない。

| 項目 | 値 |
|---|---|
| 取り込んだ commit | `2c3f2b0a62573bdcf3e65277e8b1b0310669615d`(yomiyasu-mini v1.2.0) |
| もとにした本体 | nanaism/yomiyasu v2.5.0(`29d67ccb05e370b5958d72920a9cd1aa829dee80`) |
| 取得日 | 2026-11-07 |
| ライセンス | MIT(`LICENSE.txt`、Copyright (c) 2026 nanaism) |

更新は、2 か月に 1 回の振り返り(`docs/cycle-overview.md` の「振り返り」)のときに upstream の release を見て、必要なら同じ形で写し直す。写し直したら、この表の commit と取得日を書き換える。

## このリポジトリでの使い方

Day 3 の Step 6.1.5 で、本文の地の文を 1 回だけ推敲するのに使う。yomiyasu-mini の規則と、このリポジトリの決まり(`docs/article-style-guide.md` と `.claude/skills/article-writing/SKILL.md`)がぶつかるときは、このリポジトリの決まりを優先する。

| ぶつかる点 | yomiyasu-mini | このリポジトリでの扱い |
|---|---|---|
| 締めの段落 | 本文で言い終えた内容を同じ強さで言い直すだけの締めは削る | 最後の「持ち帰れる一言」の段落は、言い直しに見えても削らない(文体ガイドの「D. 持ち帰れる締め」) |
| 足すこと | 原文にない内容は足さない | 推敲では足さない。全体像の図や測った数字を足すのは、推敲の前の工程(Day 2・Day 3 の 6.1)で行う |
| 範囲 | 渡された文章全体 | frontmatter と冒頭の `:::message` ブロックは対象にしない |

次の点はぶつからず、両方の決まりが同じ向き: 識別子・数値・コードを変えない(文体ガイドの原文保全ルール)、定型の結び(「いかがでしたか」など)を削る、「まとめ」見出しを置かない。
