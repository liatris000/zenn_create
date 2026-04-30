# zenn_create

Liatris の Zenn 記事管理リポジトリ。GitHub連携で `zenn.dev/liatris` に自動デプロイされる。

## ディレクトリ構成

```
zenn_create/
├── articles/         # Zenn記事 (.md)
├── books/            # Zenn本 (現状未使用)
├── images/           # 記事内画像とサムネイル
├── scripts/          # 記事生成補助スクリプト
├── templates/        # 記事テンプレート (冒頭文・サムネHTML)
├── docs/             # 運用ドキュメント (サイクル設計・運用・文体ガイド)
├── business-profile/ # liatris-business-profile (Private) の submodule
├── .claude/          # Claude Code 用の設定 (権限・skill)
├── .github/          # PRテンプレート
└── CLAUDE.md         # Claude Code が常時参照するリポジトリガイド
```

### submodule について

`business-profile/` は [`liatris000/liatris-business-profile`](https://github.com/liatris000/liatris-business-profile)(Private)の submodule。題材選定や公開可否判定の根拠として参照される。

初回 clone 時:

```bash
git clone https://github.com/liatris000/zenn_create.git
cd zenn_create
git submodule update --init --recursive  # Private なのでアクセス権が必要
```

submodule の中身は外部からは見えない(Private リポ)。リポ名のみ公開される。
更新運用は [`docs/operations.md`](./docs/operations.md) のメンテナンスルール参照。

## ローカル開発

```bash
npm ci
npx zenn preview   # http://localhost:8000 で確認
```

## Claude Code Web Routine 用 setup

このリポジトリは Claude Code Web の Routine から起動される。Routine 環境設定で:

- **Setup script**: 環境キャッシュ用(npm ci + Chromium ダウンロード等の重い処理)
  - cwd は `/home/user`、リポジトリは `/home/user/zenn_create` に clone 済み
  - スクリプト内で `cd /home/user/zenn_create` してから操作
- **Environment variables**: GITHUB_TOKEN, CHATWORK_API_TOKEN, CHATWORK_ROOM_ID, CHATWORK_ACCOUNT_ID, DESIGN_ARTICLE_URL

setup script の内容は別途管理(GitHub には含めない、Routine 環境固有のため)。

毎セッション実行される処理(submodule 同期、作業ディレクトリ初期化等)は
`.claude/settings.json` の SessionStart hook で実行され、`scripts/session-start.sh` が呼ばれる。
hook の cwd はリポジトリルート(`/home/user/zenn_create`)。

ローカル開発時は `CLAUDE_CODE_REMOTE` 環境変数が未設定なので、SessionStart hook は何もしない。

## Routine (3日サイクル運用)

`zenn-day1` / `zenn-day2` / `zenn-day3` の 3 本のルーティンが平日朝に順次起動し、週 1 本のペースで記事を生成する。詳細は [`docs/cycle-overview.md`](./docs/cycle-overview.md) を参照。

### 各ルーティンの責務

- **zenn-day1**(月曜朝): 題材選定 + 下書き作成 + PR (WIP) 作成
- **zenn-day2**(火曜朝): 実装 + 推敲 + PR 追記
- **zenn-day3**(水曜朝): フィードバック反映 + サムネ生成 + Ready for Review

### 週末の手動作業

- 金 or 土: Liatris が PR を最終チェック
- 日曜夜: `published_at` を翌週月曜 7:00 にセット → マージ
- 翌月曜 7:00: Zenn が自動公開 + 同じ朝に `zenn-day1` が次サイクルを開始

各 Routine の詳細プロンプトは Claude Code Web 側で管理。内部処理は `.claude/skills/day1-kickoff/SKILL.md` 等の skill ファイルが定義。スクリプト類は `scripts/*.sh` のヘッダを参照。

## 環境変数

`.env.example` を参照。`.env` はgitignore対象。

## デプロイ仕様

- `articles/*.md` がmainにマージされるとZennが自動検知して数分後に公開
- frontmatter の `published: true` + `published_at: "YYYY-MM-DD HH:MM"` で予約公開
- コミットメッセージに `[ci skip]` を含めるとデプロイがスキップされる (通常使わない)

## License

このリポジトリは2種類のライセンスを適用しています:

- **scripts / templates / 設定ファイル**: MIT License
- **記事コンテンツ (articles/, images/, books/)**: All Rights Reserved (無断転載・改変を禁じます)

詳細は [LICENSE](./LICENSE) を参照してください。

## 関連リンク

- Zenn: https://zenn.dev/liatris
- Zenn CLI ガイド: https://zenn.dev/zenn/articles/zenn-cli-guide
- slug仕様: https://zenn.dev/zenn/articles/what-is-slug
