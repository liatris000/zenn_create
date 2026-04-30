# zenn_create 運用ガイド

3 日サイクル運用の起動方法・トラブルシューティング・メンテナンスルールを集約する文書。
サイクル設計そのものは [`./cycle-overview.md`](./cycle-overview.md) を参照。

**最終更新**: 2026-04-30

## Routine の起動方法

### 自動起動(通常運用)

| Routine | 起動タイミング | 役割 |
|---|---|---|
| `zenn-day1` | 毎週月曜朝 | 題材選定 + 下書き作成 |
| `zenn-day2` | 毎週火曜朝 | 実装 + 推敲 |
| `zenn-day3` | 毎週水曜朝 | 完成 + Ready for Review |

### 手動起動(必要時)

- Liatris が「今週はスキップしたい」と判断したら、Routine を OFF にする
- 後から書きたい場合は手動でトリガーする
- 並行運用は避ける(同じ週に複数の PR が走らないようにする)

## トラブルシューティング

### Day 1 が起動したが題材が選べなかった

- business-profile の業務プールに「未着手」の種が枯れている可能性
- 対処: 業務プロフィール側を更新するか、kubell 領域からの題材化を Liatris に確認
- 「今週は中止」を選んでも構わない(Day 2/3 は PR が無いので自動的に走らない)

### Day 2 / Day 3 が起動したが PR が見つからない

- 前日の Routine が失敗している、またはその週は中止扱い
- 対処: 何もせず終了。必要なら手動で巻き戻す
- Chatwork に「対象 PR が見つからないためスキップ」と通知して終了する

### published_at の時刻を変えたい

- PR 本文の `published_at` を直接編集してマージ
- マージ前なら任意の時刻に変更可
- マージ後の変更は記事ファイルを直接編集して再 push(Zenn は再検知する)

### サムネ生成が失敗する

- Puppeteer の Chromium が壊れている可能性
- 対処: `npx puppeteer browsers install chrome` で再インストール
- それでもダメなら `templates/` の HTML を直接ブラウザで開いて手動スクショ

### submodule が古い状態のまま

- Routine 起動時に `git submodule update --remote --merge` が走るはずだが、失敗した可能性
- 対処: 手動で実行 + `GITHUB_TOKEN` の有効性を確認
  ```bash
  cd ~/zenn_create
  git submodule update --remote --merge business-profile
  ```
- `GITHUB_TOKEN` が無効だと submodule の Private リポにアクセスできない

## メンテナンスルール

### business-profile を更新した時

zenn_create 側でも次の Routine 実行時に submodule pointer が更新される。
明示的に zenn_create 側で commit したい場合:

```bash
cd ~/zenn_create
git submodule update --remote --merge business-profile
git add business-profile
git commit -m "submodule 更新: business-profile"
git push origin main  # ※ 通常は PR 経由
```

### 記事スタイルを変更したい

- `docs/article-style-guide.md` と `.claude/skills/article-writing/SKILL.md` を更新
- 1〜2 サイクル試行してから本採用
- 過去記事への遡及適用は不要(差分は新しい記事で表現する)

### 既存記事のメンテナンス

- 削除は禁止(`CLAUDE.md` ルール)
- 軽微な修正(タイポ、リンク切れ修正)は記事追加と同じ流れで PR
- frontmatter の `slug` 相当部分(ファイル名)も変更不可

### Routine プロンプトを変更したい

- Claude Code Web の管理画面で編集する
- リポジトリ内の skill ファイル(`.claude/skills/*/SKILL.md`)を更新するだけで多くの挙動が変わるので、
  Routine プロンプト本体の編集は最小限に留める
- 大きな構造変更を入れるときは `cycle-overview.md` を先に更新
