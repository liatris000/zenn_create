---
title: "Claude Code×GitHub ActionsでIssue自動PR化"
emoji: "🤖"
type: "tech"
topics: ["claude", "claudecode", "githubactions", "ai", "automation"]
published: true
published_at: "2026-05-01 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260430-claude-code-github-actions_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事(note)](https://note.com/liatris000)にまとめています。
:::

「IssueにラベルをつけるとClaude Codeがブランチを切って実装してPRを出してくれる」——そんな話を見かけて、実際に試してみました。

思ったより設定が少なく、**YAMLを1ファイル追加するだけ**で動きました。今回はマーケ支援や社内ツール開発でよく発生する「小さいけど面倒なタスク」をIssueで管理しているチームが使えそうな構成をまとめます。

## Claude Code GitHub Actionsとは

[Claude Code GitHub Actions](https://docs.anthropic.com/ja/docs/claude-code/github-actions) は、GitHub ActionsのワークフローからClaude Codeを呼び出せる公式の仕組みです。`anthropics/claude-code-action@beta` というアクションを使います。

ローカルでClaude Codeを動かすのと異なり、**GitHubのイベント（Issue作成・PRコメントなど）をトリガーに自動実行**できます。

```mermaid
graph LR
    A[Issue作成] -->|claudeラベル付与| B[GitHub Actions起動]
    B --> C[Claude Code実行]
    C --> D[ブランチ作成]
    D --> E[コード実装]
    E --> F[PR作成]
    F --> G[レビュー待ち]
    G -->|@claude review| H[自動レビュー]
    H -->|@claude fix| I[自動修正]
```

## Step1: シークレット登録

GitHubリポジトリの **Settings → Secrets and variables → Actions** で `ANTHROPIC_API_KEY` を登録します。`GITHUB_TOKEN` はActionsが自動で用意してくれるので追加不要です。

:::message
`ANTHROPIC_API_KEY` は [Anthropic コンソール](https://console.anthropic.com/) から取得できます。Claude Maxプランでも利用可能です。
:::

## Step2: ワークフローファイルを追加

`.github/workflows/claude-issue-to-pr.yml` を作成します。今回は3つのジョブを1ファイルにまとめました。

```yaml:.github/workflows/claude-issue-to-pr.yml
name: Claude Code - Issue to PR

on:
  issues:
    types: [opened, labeled]
  issue_comment:
    types: [created]

permissions:
  contents: write
  pull-requests: write
  issues: write

jobs:
  issue-to-pr:
    # Issueに「claude」ラベルが付いたとき
    if: |
      (github.event_name == 'issues' &&
       contains(github.event.issue.labels.*.name, 'claude'))
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Claude Code
        uses: anthropics/claude-code-action@beta
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          prompt: |
            このIssueの内容を実装してPRを作成してください。
            ブランチ名: claude/issue-${{ github.event.issue.number }}
            Issue内容: ${{ github.event.issue.body }}

  review-pr:
    # PRコメントで「@claude review」と書いたとき
    if: |
      github.event_name == 'issue_comment' &&
      github.event.issue.pull_request != null &&
      contains(github.event.comment.body, '@claude review')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: anthropics/claude-code-action@beta
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          prompt: |
            このPRのコードレビューをバグ・セキュリティ・パフォーマンスの観点で行い、
            結果をPRにコメントしてください。
```

## Step3: 試してみる

ワークフローをpushしたら、実際にIssueを作って `claude` ラベルを付けてみます。

1. Issueに「ユーザー一覧を取得するAPIを追加してください」と書く
2. `claude` ラベルを付与
3. **Actionsタブ**でワークフローが起動するのを確認
4. 数分後にPRが自動作成される

PRコメントのレビューも同様に、コメント欄に `@claude review` と書くだけです。

## 成果物

ワークフローYAMLとデモページをGitHubに公開しています。

@[github](https://github.com/liatris000/liatris-20260430-claude-code-github-actions)

デモページ（3つのトリガーと設定方法が一覧できます）：

https://liatris000.github.io/liatris-20260430-claude-code-github-actions/

![デモページのスクリーンショット](https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260430-claude-code-github-actions_screenshot.png)

:::details ワークフロー全文（コピー用）

```bash
# リポジトリをクローンしてワークフローをコピー
git clone https://github.com/liatris000/liatris-20260430-claude-code-github-actions.git
cp -r liatris-20260430-claude-code-github-actions/.github ./
```

:::

## やってみた感想

**良かった点**

- **設定量が少ない**。YAMLとシークレット1つだけで動く。Actionsの知識があれば5分で導入できる。
- **プロンプトが自由に書ける**。`prompt:` の中身を変えるだけでClaude Codeへの指示を細かく調整できる。プロジェクトのコーディング規約をそのまま貼り付けるのが効果的だった。
- **Issue本文をそのまま渡せる**。`${{ github.event.issue.body }}` でIssue内容をClaude Codeに渡せるので、Issueを丁寧に書くほど実装精度が上がる。

**惜しかった点**

- **Actionsの実行時間が長め**。Claude Codeの起動と実装で3〜5分かかる。急ぎのタスクはローカルの方が早い。
- **複雑なタスクは一発でPRにはならない**。「既存クラスを大幅リファクタリング」のような指示は途中で止まることがある。Issue粒度を小さくする運用が必要。
- **beta版**。`anthropics/claude-code-action@beta` はまだbetaなので仕様変更に注意。

**業務での活用イメージ**

Liatrisのマーケ支援・社内ツール文脈で特に使いやすそうだったのは次の3パターンです：

- **定型レポートの自動生成スクリプト追加**: Issueに「〇〇のCSVを読んでサマリーを出すPythonスクリプトを追加」と書いてラベルを付ける
- **データ変換ユーティリティの追加**: コンサル先からのデータ形式変更依頼をそのままIssueに転記して `claude` ラベルで自動実装
- **PRの一次レビュー**: `@claude review` で基本的な問題を先にはじき出し、人のレビューは設計判断に集中する

## まとめ

一言で表すなら「**IssueがPRになるまでのやり取りを自動化する仕組み**」です。

実装精度はIssueの書き方に大きく左右されます。逆に言えば、**Issueを丁寧に書く習慣**があるチームほど恩恵が大きい。「ドキュメントとして残るIssue → AIが読んで実装 → 人がレビュー」という流れが自然に作れます。

まず試すなら `@claude review` だけ使うのをおすすめします。既存のPRに後からレビューを付けるだけなので、ワークフローのリスクを感じずに効果を確認できます。
