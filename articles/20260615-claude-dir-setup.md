---
title: "`.claude/` を一から設計して副業 AI 開発環境を整える"
emoji: "🗂️"
type: "tech"
topics: ["claude", "claudecode", "ai", "automation"]
pattern: "implementation"
published: false
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260615-claude-dir-setup_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事(note)](https://note.com/liatris000)にまとめています。
:::

## セッションのたびに「このプロジェクトのルールは〜」と説明していた

小さな個人プロジェクト(EC サイト)に Claude Code を使い始めたとき、最初はほぼ手ぶらで使っていた。プロジェクト固有の制約や使いたいコマンドをそのつどメッセージで伝えながら進める方式だ。

しばらくするとパターンが見え始める。「この環境変数は触らないで」「force push は禁止」「型チェックは `npm run typecheck`」——毎回同じことを説明している。Claude Code は賢いが、前のセッションのことは覚えていない。

`.claude/` を真剣に設計したのはそのタイミング。**1 セッション目から即戦力になる体制を作る**のが目的だった。

---

## .claude/ の全体像

プロジェクトルートに置く `.claude/` の構成は次の 3 要素に整理できる。

```
.claude/
├── CLAUDE.md          # プロジェクト固有の指示書
├── settings.json      # 権限・フック設定
└── skills/            # 再利用可能なカスタムスキル
    └── <skill-name>/
        └── SKILL.md
```

ユーザー全体設定(`~/.claude/settings.json`)は複数プロジェクトで共有されるグローバル設定として使い、プロジェクト設定でそれを上書きする二層構造が基本設計になる。「チーム共通設定はグローバル、プロジェクト固有の制約はプロジェクト側に閉じる」というレイヤリングだ。

---

## CLAUDE.md の書き方

CLAUDE.md はセッション開始時に最初に読み込まれる。目的は **「知らないと進め方が変わる情報だけ」を文書化すること**。

Next.js の基本的な使い方を書いても価値はない。Claude はすでに知っている。プロジェクト固有の制約・構造・コマンドだけ書く。

```markdown:.claude/CLAUDE.md
# プロジェクト: my-ec-site

## このリポジトリの目的
Next.js + Stripe の個人 EC サイト。
商品データは Supabase、画像は Cloudflare R2 に置く構成。

## 守ること
- main への直 push は禁止。必ず PR 経由
- `.env*` ファイルは絶対に読まない・編集しない
- `npm run build` が通らないコードはコミットしない

## よく使うコマンド
- 開発サーバ: `npm run dev`
- 型チェック: `npm run typecheck`
- テスト: `npm test -- --run`
```

ファイルを最初に書くとき、最も難しいのは「何を書かないか」の判断だ。最初に作った CLAUDE.md は 80 行あった。Zenn CLI の基本的な使い方、ディレクトリの説明、技術選定の経緯まで書いていたが、Claude はすでにその大半を知っている。削ってみると 40 行になり、残った部分が確実に読まれるようになった。

書きすぎると Claude が読まなくなる(長い CLAUDE.md は後半が無視されやすい)。1 ファイル 50 行以内を意識すると読まれる密度が上がる。

---

## settings.json の設計

```json:.claude/settings.json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(git status)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(ls *)"
    ],
    "deny": [
      "Bash(git push --force*)",
      "Bash(rm -rf*)",
      "Bash(git reset --hard*)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "cd $(git rev-parse --show-toplevel) && npm run typecheck --silent 2>&1 | head -20"
          }
        ]
      }
    ]
  }
}
```

`permissions.allow` は「毎回プロンプトが出て煩わしいが安全なコマンド」を登録する。deny は「絶対に走ってほしくない操作」。allow だけでなく deny も置くことで、誤操作のガードになる。

hooks の PostToolUse で Edit/Write の直後に型チェックを走らせる設計は、最初は Pre でやろうとしていた。しかし「編集前のコードを検査しても意味がない」とすぐ気づいた。Post に変えてから、書き損じを即座に検知できるようになった。

---

## skills/ の設計

`skills/<name>/SKILL.md` を置くと、`/<name>` で呼び出せるスラッシュコマンドになる。SKILL.md には Claude に渡す指示を Markdown で書く。

たとえば PR 作成フローを skill 化した例:

```markdown:.claude/skills/create-pr/SKILL.md
# PR 作成

以下の手順で PR を作成する:

1. `git status` で差分確認
2. ファイルをステージング・コミット
3. `git push -u origin <branch>`
4. GitHub MCP ツールで PR 作成
5. PR タイトルは `[WIP] <変更内容の要約>` 形式

## 禁止
- `--force` push は絶対にしない
- commit message に業務固有のコンテキストを出さない
```

毎回「PR を作るときは〜」と説明する代わりに `/create-pr` を呼ぶだけになる。スキルに禁止事項を書いておくと、セッションをまたいでも Claude がその制約を維持する。

スキル化するかどうかの判断基準は「同じ説明を 2 回したかどうか」にしている。2 回目が終わった時点で SKILL.md に書くと、3 回目から消える。CLAUDE.md に書くのは「常時有効な制約」、スキルにするのは「呼び出したときだけ必要な手順」と整理すると混乱しない。

---

## 設計してわかったこと

**CLAUDE.md・settings.json・skills は役割が違う**。

- CLAUDE.md → 「このプロジェクトの世界観」を伝える。状態・構造・大方針
- settings.json → 「やっていいこと / やってはいけないこと」を機械的に定義
- skills → 「よくある作業手順」を再利用可能な形にする

この三者を混同すると、CLAUDE.md が長大な手順書になったり、skills に設定が混入したりする。

---

## データアナリスト視点

`settings.json` の `deny` リストに `rm -rf*` や `git reset --hard*` を入れる発想は、データ基盤の行レベルセキュリティに近い。「できることを許可する」より「できないことを封鎖する」設計で、スキーマ変更をロールで制御する思想と同じだ。

skills の設計も、dbt モデルの docstring やクエリコメントと構造が似ている。「後から来た人(または将来の自分)が迷わないためのコンテキスト設計」という目的が共通している。データを扱う側の視点から見ると、`.claude/` の設計は「データプロセスの権限管理とドキュメント整備」の縮図に見える。

---

## 今の .claude/ の状態

現時点での構成はこうなっている。

```
.claude/
├── CLAUDE.md             # 42 行
├── settings.json         # permissions 8 件, hooks 1 件
└── skills/
    ├── create-pr/
    │   └── SKILL.md      # PR 作成フロー
    ├── env-check/
    │   └── SKILL.md      # 環境変数の確認手順
    └── deploy-check/
        └── SKILL.md      # デプロイ前チェックリスト
```

CLAUDE.md が 60 行を超えそうになったら、関心の低いセクションを別ファイルに分けて `@path/to/file` で include する。skills が増えたら機能別のサブディレクトリに整理する。

`.claude/` を整えることの本質は「設定を管理する」ことではなく、**「Claude との作業契約を文書化する」こと**だと思っている。セッションをまたいで同じ判断基準で動いてもらうための仕組みだ。
