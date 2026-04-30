# zenn_create リポジトリ ガイド

このファイルは、Claude Codeがこのリポジトリで作業する際の常時参照ルールです。

## このリポジトリの目的

Zenn記事の管理リポジトリ。GitHub連携でZennにデプロイされる。

- デプロイ対象ブランチ: `main`
- デプロイ仕様: `articles/*.md` がmainにマージされると、Zennが自動検知して数分後に公開される
- 記事の公開設定は frontmatter の `published` と `published_at` で制御

## ディレクトリ構成

- `articles/` ─ Zenn記事(.md)の格納先（必須）
- `books/` ─ Zenn本の格納先（現状未使用、空でOK）
- `images/` ─ 記事内画像とサムネイル
- `.claude/` ─ Claude Code向けの権限・コマンド設定
- `.github/` ─ PRテンプレート等

## 命名規則

- 記事slug: `YYYYMMDD-テーマ名` 形式（例: `20260428-slack-bot`）
- slugは **12〜50文字、英小文字/数字/ハイフン/アンダースコアのみ**
- slugは **公開後変更不可**（変更するとURLが変わり被リンクが死ぬ）
- 画像: `{記事slug}_thumbnail.png`, `{記事slug}_screenshot.png`

## frontmatter のルール

```yaml
---
title: "（30字以内）"
emoji: "🤖"
type: "tech"
topics: ["claude", "claudecode", "ai", "automation"]  # 最大5つ、すべて小文字
published: true
published_at: "2026-04-29 07:00"  # ダブルクオート必須、JST、空白区切り
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/{slug}_thumbnail.png
---
```

## 守ること

- 既存記事ファイルは絶対に削除しない
- `[ci skip]` をコミットメッセージに含めない（Zennデプロイがスキップされる）
- mainブランチへの直push禁止。記事追加は必ずPRで
- `published_at` はダブルクオート付き、JST時刻で記述
- 機密ファイルへの編集・読み取りは禁止 (権限設定で別途保護されている)

## やってはいけない

- 機密情報を含むファイル (環境変数ファイル、認証情報、秘密鍵等) の編集・読み取り
- 機密情報を含むディレクトリへのアクセス
- 既存記事の削除や大幅な書き換え（タイポ修正等の軽微な編集はOK）
- frontmatter の `slug` 相当部分（ファイル名）の変更

## 記事追加の典型フロー

1. 別リポジトリで成果物を作成・GitHub公開
2. このリポジトリで `article/YYYYMMDD` ブランチを切る
3. `articles/{slug}.md` を作成
4. PRを作成し、人間がレビュー＆マージ
5. `published_at` の時刻にZennで自動公開

## ローカルプレビュー

```bash
npx zenn preview
# http://localhost:8000 で確認
```

## 3日サイクル運用

このリポジトリは **3日サイクル × 週1本投稿** で運用される。
詳細は [`docs/cycle-overview.md`](./docs/cycle-overview.md) を参照。

各日の作業手順は skills として整備されている:

- Day 1(月): [`.claude/skills/day1-kickoff/SKILL.md`](./.claude/skills/day1-kickoff/SKILL.md)
- Day 2(火): [`.claude/skills/day2-implementation/SKILL.md`](./.claude/skills/day2-implementation/SKILL.md)
- Day 3(水): [`.claude/skills/day3-finalize/SKILL.md`](./.claude/skills/day3-finalize/SKILL.md)

運用上のトラブルシューティング・メンテナンスは [`docs/operations.md`](./docs/operations.md) を参照。

## 業務プロフィール参照

`business-profile/` ディレクトリは `liatris-business-profile`(Private)の submodule。
判断ロジックの根拠として参照する。

| 判断したいこと | 参照先 |
|---|---|
| 公開していい題材か | `business-profile/policies/disclosure-rules.md` |
| 業務プールの種 | `business-profile/companies/<X>/README.md` |
| 題材選定ロジック | `business-profile/companies/personal/ai-articles/topic-selection.md` |
| 副業申請状態 | `business-profile/policies/disclosure-rules.md`(横断テーブル) |

## 情報漏れ対策(必須)

このリポジトリは **Public**。以下を必ず守る:

- commit message に題材の固有名詞・業務コンテクストを出さない
- 記事本文に業務文脈・関係者・取引先・パートナー・提携先を出さない
- 本名「平野翔斗」を記事本文内に出さない(プロフィール表示は OK)
- フィクションの数値(未計測の改善値等)を書かない

詳細は [`docs/cycle-overview.md`](./docs/cycle-overview.md) の「情報漏れ対策」セクション。

## 文体ガイド

記事の文体・構成は [`docs/article-style-guide.md`](./docs/article-style-guide.md) で定義。
記事生成時は [`.claude/skills/article-writing/SKILL.md`](./.claude/skills/article-writing/SKILL.md) を参照。

## 関連リンク

- 設計記事(note): （公開後にここにURLを追記）
- Zenn CLI: https://zenn.dev/zenn/articles/zenn-cli-guide
- Zenn slug仕様: https://zenn.dev/zenn/articles/what-is-slug
