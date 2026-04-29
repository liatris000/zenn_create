---
title: "Claude Code RoutinesでPRを自動レビュー"
emoji: "🤖"
type: "tech"
topics: ["claude", "claudecode", "ai", "automation"]
published: true
published_at: "2026-04-30 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260429-claude-code-routines_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事(note)](https://note.com/liatris000)にまとめています。
:::

「PRを作ったら数分後にClaudeのレビューコメントが届いていた」──そんな体験ができる機能が、2026年4月14日にリサーチプレビューとして公開されました。**Claude Code Routines** です。

Routinesは、プロンプト・リポジトリ・コネクタをまとめてパッケージ化し、スケジュールやGitHubイベントに応じてAnthropicのクラウド上でClaudeを自律実行する仕組みです。ローカルマシンの電源を切っていても動き続けるのが最大の特徴で、今回はその中でも「**GitHub PRが開かれたら自動でコードレビュー**」を試しました。

Liatrisのコンサル・社内ツール開発では、少人数チームで複数プロジェクトを並走させることが多く、「レビュー待ちでPRが塩漬け」という状況が起きがちです。Routinesがファーストレビューを担ってくれれば、人間レビュアーは本当に重要な判断だけに集中できます。結論から言うと、**設定ファイル1つで動き、実用水準のレビューが届きました**。

## Routinesとは

Routinesは次の3つのトリガーをサポートします。

| トリガー | 使いどころ |
|---------|----------|
| Schedule | 毎朝9時にデイリーレポート、週次でコード品質レポートなど |
| GitHub Event | PR作成・push・CI失敗など、WebhookイベントでClaudeを起動 |
| API | 外部サービスからPOSTして任意タイミングに実行 |

複数トリガーを1つのRoutineに組み合わせることもでき、「夜間スケジュール＋PR作成時」のように柔軟に設定できます。

## Step1: Routineの設定ファイルを書く

`.claude/routines/pr-review.yml` を作成します。YAMLでトリガー・プロンプト・コネクタを定義するだけです。

```yaml:.claude/routines/pr-review.yml
name: PR自動レビュー
description: PRが開かれたとき、コードの品質・セキュリティ・パフォーマンスを自動レビュー

triggers:
  github:
    events:
      - pull_request.opened
      - pull_request.synchronize
    filters:
      draft: false        # ドラフトPRはスキップ
      base_branch: main   # main向けのPRのみ

prompt: |
  あなたは経験豊富なコードレビュアーです。
  以下の観点でPRをレビューし、PRコメントとして投稿してください。

  ## レビュー観点
  1. **バグ・ロジックエラー**: 明らかな誤り・エッジケースの漏れ
  2. **セキュリティ**: SQLインジェクション・XSS・認証・認可の問題
  3. **パフォーマンス**: N+1クエリ・不要な計算・メモリリーク
  4. **可読性**: 命名・コメント・複雑すぎる実装
  5. **テスト**: カバレッジが不十分な部分の指摘

  問題がない場合は「LGTM ✅」と投稿。
  重要な問題が見つかった場合は「Changes requested」をリクエスト。

connectors:
  github:
    repo: "{{ github.repository }}"
    permissions:
      - pull_requests:write
      - contents:read
```

:::message
`draft: false` フィルターを入れておくと、作業中のドラフトPRに大量のコメントが届く事故を防げます。
:::

## Step2: Claude Code CLIで登録して動作確認

```bash
# Routineを登録
claude routines add .claude/routines/pr-review.yml

# 登録確認
claude routines list

# dry-runで内容確認 (PRには投稿されない)
claude routines run pr-review --dry-run
```

`--dry-run` フラグが非常に便利で、実際にPRコメントを投稿せずに「Claudeがどんなレビューを書くか」を事前確認できます。本番適用前に必ず実行することをおすすめします。

## Step3: 実際のレビュー結果

JWT認証を導入したPRに対して、Routinesが2分以内に投稿したコメントがこちらです。

**問題として指摘された点：**

1. **JWTシークレットのハードコード** (セキュリティ)
   - `const SECRET = "my-super-secret-key"` → `process.env.JWT_SECRET` に変更を要求
2. **トークン有効期限が長すぎる** (セキュリティ)
   - `expiresIn: "365d"` → `"7d"` 以内を推奨

**良かった点として評価された点：**
- リフレッシュトークンとアクセストークンの分離設計を「適切」と評価

**提案として挙げられた点：**
- 期限切れトークン・無効トークンのテストケース追加

人間のレビュアーが最初にチェックすべき点を的確にピックアップしていました。単なる「問題列挙」ではなく、良い実装を評価しつつ改善点を伝えるトーンも実用的です。

## 成果物

設定サンプル（PR自動レビュー・デイリーレポート・CI失敗自動修正の3種類）をGitHubに公開しています。

@[github](https://github.com/liatris000/liatris-20260429-claude-code-routines)

デモページ（各Routineの設定と出力例を確認できます）：

https://liatris000.github.io/liatris-20260429-claude-code-routines/

:::details 3種類のRoutine設定サンプル

**PR自動レビュー** (`examples/pr-review.yml`)
- トリガー: PR作成・更新時
- 動作: コード品質・セキュリティ・パフォーマンスを5観点でレビュー

**デイリーレポート** (`examples/daily-report.yml`)
- トリガー: 平日朝9時 (JST)
- 動作: 昨日のGit活動をまとめてSlackに投稿

**CI失敗自動修正** (`examples/ci-autofix.yml`)
- トリガー: CI失敗時
- 動作: Lintエラー・型エラーなど自動修正可能なものをコミット

```bash
# サンプルをコピーして使う
mkdir -p .claude/routines
cp examples/pr-review.yml .claude/routines/
claude routines add .claude/routines/pr-review.yml
```

:::

## やってみた感想

**良かった点**

- 設定がYAMLで完結し、追加のコードが一切不要。プロジェクトにファイルを1つ置くだけで全メンバーに適用される。
- `draft: false` や `base_branch: main` などのフィルターが充実しており、「的外れなタイミングで動く」事故を防ぎやすい。
- Lintエラーやセキュリティの初歩的なミスを24時間即座に指摘してくれるため、人間レビュアーの負担が明らかに減った。特に深夜・休日のPRで効果的。

**惜しかった点**

- 2026年4月時点でリサーチプレビューのため、Proプランだと1日5回の実行上限がある。アクティブなチームでは上限に当たりやすい。
- `{{ github.repository }}` などのテンプレート変数のドキュメントがまだ薄く、「どの変数が使えるか」は公式ドキュメントを丁寧に読む必要がある。

**業務での活用イメージ**

Liatrisのコンサル・社内ツール開発文脈では次の使い方が特に実践的です：

- **PR自動レビュー (GitHub Event)**: 少人数チームでのレビュー負担を軽減。SQLを扱う社内ツールでのセキュリティチェックに特に有効。
- **デイリーレポート (Schedule)**: 複数クライアントプロジェクトの進捗を毎朝まとめてSlackに投稿。朝会の準備が不要になる。
- **CI失敗自動修正 (GitHub Event)**: Lintエラー修正の往復コミットが減り、マージまでのリードタイムが短縮される。

## まとめ

Claude Code Routinesを一言で表すと「**プロンプトを書くだけで、GitHubとClaudeが24時間自動連携する仕組み**」です。

GitHub Actionsと比べると、コードを書かずに自然言語のプロンプトで動作を定義できる点が大きな違いです。エンジニアでないメンバーも設定に参加しやすく、チーム全体のAI活用を底上げするポテンシャルがあります。

リサーチプレビュー段階なので仕様変更には注意が必要ですが、「まずPR自動レビューだけ試す」という段階的な導入が無難です。設定ファイルは1つから始められるので、試してみる敷居は低いです。

こんな方に試してほしいです：
- 少人数チームでPRレビューのボトルネックを感じている方
- 深夜・休日のPRにも即座に初動レビューを入れたい方
- GitHub ActionsでAI連携を試みたが、コードのメンテが面倒だった方
