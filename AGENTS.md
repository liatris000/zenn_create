# zenn_create

Zenn 記事の管理リポジトリ。`articles/*.md` が main にマージされると Zenn が自動検知して数分後に
公開される。公開設定は frontmatter の `published` と `published_at`。**このリポジトリは Public。**

## 命名規則

- 記事 slug: `YYYYMMDD-テーマ名`（例: `20260428-slack-bot`）。12〜50文字、英小文字/数字/ハイフン/アンダースコアのみ
- **slug は公開後変更不可**（URL が変わり被リンクが死ぬ）
- 画像: `{記事slug}_thumbnail.png`, `{記事slug}_screenshot.png`

## frontmatter

```yaml
---
title: "（30字以内）"
emoji: "🤖"
type: "tech"
topics: ["claude", "claudecode", "ai", "automation"]  # 最大5つ、すべて小文字
pattern: "implementation"  # implementation / comparison / concept / other
published: true
published_at: "2026-04-29 07:00"  # ダブルクオート必須、JST、空白区切り
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/{slug}_thumbnail.png
---
```

`pattern` は記事の実構成と一致させる（ラベルだけ変えない）。各値の構成定義は
[`docs/article-style-guide.md`](./docs/article-style-guide.md) の「構成パターン」。

## やってはいけない

- `published: true` の既存記事を削除・大幅に書き換える（タイポ修正等の軽微な編集は OK）
- 記事ファイル名（slug 相当）の変更
- `[ci skip]` をコミットメッセージに含める（Zenn デプロイがスキップされる）
- main への直 push。記事追加は必ず PR

## 情報漏れ対策（必須）

- commit message に題材の固有名詞・業務コンテクストを出さない
- 記事本文に業務文脈・関係者・取引先・パートナー・提携先を出さない
- 本名「平野翔斗」を記事本文内に出さない（プロフィール表示は OK）
- フィクションの数値（未計測の改善値等）を書かない

詳細は [`docs/cycle-overview.md`](./docs/cycle-overview.md) の「情報漏れ対策」。

## プレビュー

```bash
npx zenn preview   # http://localhost:8000
```

## 参照先

3日サイクル × 週1本投稿で運用する。各日の手順は `.claude/skills/` の day1〜day3 skill にある。

| 知りたいこと | 参照先 |
|---|---|
| サイクル全体 | [`docs/cycle-overview.md`](./docs/cycle-overview.md) |
| トラブル対応・メンテナンス | [`docs/operations.md`](./docs/operations.md) |
| 文体・構成 | [`docs/article-style-guide.md`](./docs/article-style-guide.md) |
| 公開していい題材か | `business-profile/policies/disclosure-rules.md` |
| 業務プールの種 | `business-profile/companies/<X>/README.md` |
| 題材選定ロジック | `business-profile/companies/personal/ai-articles/topic-selection.md` |
| 副業申請状態 | `business-profile/policies/disclosure-rules.md`（横断テーブル） |

`business-profile/` は `liatris-business-profile`(Private) の submodule。
