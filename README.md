# zenn_create

Liatris の Zenn 記事管理リポジトリ。GitHub連携で `zenn.dev/liatris` に自動デプロイされる。

## ディレクトリ構成

```
zenn_create/
├── articles/        # Zenn記事 (.md)
├── books/           # Zenn本 (現状未使用)
├── images/          # 記事内画像とサムネイル
├── scripts/         # 記事生成補助スクリプト
├── templates/       # 記事テンプレート (冒頭文・サムネHTML)
├── .claude/         # Claude Code 用の設定 (権限・ルール)
├── .github/         # PRテンプレート
└── CLAUDE.md        # Claude Code が常時参照するリポジトリガイド
```

## ローカル開発

```bash
npm ci
npx zenn preview   # http://localhost:8000 で確認
```

## Routine (毎朝の記事生成)

`daily-zenn-create` ルーティンが毎朝9時に起動し、以下を自動化:

1. X / Web で題材スキャン
2. Claude Code で実装
3. 成果物を `liatris-YYYYMMDD-{theme}` リポジトリで公開 + GitHub Pages
4. 記事ドラフトを `articles/{slug}.md` に作成し PR
5. Chatwork に通知

スクリプトの詳細は `scripts/*.sh` のヘッダを参照。

## 環境変数

`.env.example` を参照。`.env` はgitignore対象。

## デプロイ仕様

- `articles/*.md` がmainにマージされるとZennが自動検知して数分後に公開
- frontmatter の `published: true` + `published_at: "YYYY-MM-DD HH:MM"` で予約公開
- コミットメッセージに `[ci skip]` を含めるとデプロイがスキップされる (通常使わない)

## 関連リンク

- Zenn: https://zenn.dev/liatris
- Zenn CLI ガイド: https://zenn.dev/zenn/articles/zenn-cli-guide
- slug仕様: https://zenn.dev/zenn/articles/what-is-slug
