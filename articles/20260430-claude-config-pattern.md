---
title: "Claude Code の .claude/ を育てる ─ 4ファイルの役割分担と設計指針"
emoji: "🗂️"
type: "tech"
topics: ["claude", "claudecode", "ai", "automation"]
published: false
published_at: "2026-05-06 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260430-claude-config-pattern_thumbnail.png
---

<!-- Day 1 下書き: 構成案レベル。コード・詳細実装は Day 2 で記述 -->

`.claude/` ディレクトリを初めて見た時、何から始めれば良いか分からなかった。
CLAUDE.md / settings.json / hooks / skills ─ それぞれ「Claude Code の設定」を担うが、
どこに何を書けば Claude がどう動くかの境界線が、公式ドキュメントだけでは掴みにくい。

3ヶ月ほど運用してみて、4ファイルの役割分担が自分の中で整理された。その整理を書く。

---

## 4ファイルの役割分担

`.claude/` 配下のファイルは、Claude Code に対する「伝達の手段」として以下のように機能する。

### CLAUDE.md ─ お願い事項

<!-- Day 2 で詳述 -->
<!-- ポイント: CLAUDE.md は「守られるべき指示」ではなく「コンテキストの注入」。
     違反しても Claude は止まらない。「絶対に守らせたい」は hooks に書く。 -->

CLAUDE.md はセッション開始時に自動でコンテキストに読み込まれるドキュメント。
「プロジェクトの目的」「命名規則」「守ってほしいルール」を書く場所だが、
これを破っても Claude は止まらない。「お願い」と理解しておくと使い方が整理される。

### settings.json ─ 権限の境界線

<!-- Day 2 で詳述 -->
<!-- ポイント: allow/deny リストで Claude が触れるツール・コマンドを制限する。
     セキュリティの観点から「許可一覧」として管理するのが基本。 -->

settings.json は Claude Code が実行できるツール・コマンドの許可/拒否リスト。
「npm run test は許可するが、git push はユーザー確認を必須にする」のような制御ができる。

### hooks/ ─ 強制執行スクリプト

<!-- Day 2 で詳述 -->
<!-- ポイント: PreToolUse / PostToolUse / SessionStart / Stop の4タイミング。
     CLAUDE.md に書いたルールを「自動で強制」するのが hooks の役割。
     例: Edit ツールが走る前に「.env を編集しようとしていないか」チェックする。 -->

hooks は特定イベントに反応して自動実行されるシェルスクリプト。
「CLAUDE.md に書いたルールが守られない」と気づいた時に hooks 化するのが正しい運用タイミング。

### skills/ ─ 呼び出し式の手順書

<!-- Day 2 で詳述 -->
<!-- ポイント: /skill-name で呼び出せる SKILL.md ファイルを skills/ に置く。
     「繰り返す手順が固まった」ものだけを skills 化する。手順が揺れている間は CLAUDE.md に書く。 -->

skills は `/skill-name` で呼び出せる手順書。
毎週実行するルーティン、フォーマットが決まった作業 ─ 「手順が固まったもの」だけ skills 化する。

---

## どこから始めるか

<!-- Day 2 で詳述 -->
<!-- ポイント: 最初は CLAUDE.md だけでいい。hooks・skills は「繰り返しミスが出てから」追加する。
     0から全部揃えようとすると過設計になる。 -->

空のリポジトリに `.claude/` を整備するなら、以下の順番で育てるのが現実的だった。

1. まず CLAUDE.md だけ作る
2. 「Claude が繰り返し破るルール」が出てきたら hooks に昇格させる
3. 「毎回同じ手順を書いている」作業が出てきたら skills にする
4. 「禁止したいコマンド」が明確になったら settings.json に書く

---

## 実際の構成例

<!-- Day 2 で Mermaid 図 + ファイルツリーを追加 -->
<!-- ポイント: このリポジトリの .claude/ 構成を例として使う(業務文脈は出さない) -->

```
.claude/
├── CLAUDE.md             ← プロジェクト共通ルール
├── settings.json         ← 権限設定
├── hooks/
│   ├── pre-edit.sh       ← Edit 実行前チェック
│   └── session-start.sh  ← セッション開始時の初期化
└── skills/
    ├── day1-kickoff/
    │   └── SKILL.md
    └── day2-implementation/
        └── SKILL.md
```

<!-- Day 2 で各ファイルのサンプルコードを追加 -->

---

## データアナリスト視点

<!-- Day 2 で詳述 -->
<!-- ポイント: 設定の階層化(お願い→権限→強制→手順書)はデータ基盤のガバナンスレイヤーと相似。
     CLAUDE.md = ドキュメント / settings.json = アクセス制御 / hooks = row-level security 相当。 -->

Claude Code の設定を「どこに何を書くか」整理する作業は、
データ基盤でのアクセス制御設計と同じ問いを持っている。

「誰が」「何を」「どの条件で」実行できるかを、ドキュメント・設定・スクリプトの3層に分けて管理する発想。
CLAUDE.md がドキュメント層で、settings.json がポリシー層、hooks が強制実行層にあたる。

---

## 運用を続けるとどうなるか

<!-- Day 2 で詳述 -->
<!-- ポイント: 「育てた .claude/ は転用できる」という話。
     別プロジェクトに .claude/ ごとコピーして最小編集で使えるようになる。
     これがリポジトリをまたぐ「知識の外部化」になっている。 -->

半年運用してみると、`.claude/` は「プロジェクトの記憶」として機能するようになった。
最初からは設計できない。繰り返しミスから hooks が増え、手順が固まって skills になる。
この順序を逆にしようとするとうまくいかない。

<!-- 自然な終わり: 「ぜひ試してみてください」は使わない。
     「この構成がどう育つかはプロジェクト次第。最初の1ファイルは CLAUDE.md だけでいい」で締める。 -->
