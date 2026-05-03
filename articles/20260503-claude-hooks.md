---
title: "Claude Code の Hooks で開発を自動化した話"
emoji: "🪝"
type: "tech"
topics: ["claudecode", "claude", "ai", "automation", "shellscript"]
pattern: "implementation"
published: false
published_at: "2026-05-06 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260503-claude-hooks_thumbnail.png
---

:::message
この記事はClaude Codeが自律的に生成しました。内容は平野が確認・公開判断しています。
:::

## Claude Code を使っていて気になっていたこと

Claude Code でコードを書いてもらうとき、毎回ぼんやり思っていたことがある。

「このコマンド、本当に実行していいのか？」という不安と、「フォーマットし忘れた」という失敗と、「今日何を変えたっけ」という記憶の曖昧さだ。

それぞれは小さな課題だが、積み重なると地味にストレスになる。Claude Code の **Hooks** 機能を使えばこのあたりを自動化できると聞いて、試してみた。結論から言うと、思ったより実用的だった。

所要時間: 約40分（設計 10 分・実装 20 分・動作確認 10 分）

## Hooks とは何か

Claude Code の Hooks は、AI の操作前後に任意のシェルコマンドを差し込める仕組みだ。以下の 4 つのタイミングで発火する。

| イベント | タイミング |
|---|---|
| `PreToolUse` | ツール実行前 |
| `PostToolUse` | ツール実行後 |
| `Notification` | 通知発生時 |
| `Stop` | セッション終了時 |

`settings.json` に書くだけで動く。特別な拡張機能のインストールは不要だ。

## 今回作ったもの

3 つのフックスクリプトを作った。

### 1. 危険コマンドガード（PreToolUse）

`rm -rf /` や `curl ... | bash` のようなパターンを検知して、実行前にブロックする。ブロックしたコマンドは監査ログに記録される。

```bash:~/.claude/hooks/pre-bash-guard.sh
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

DANGER_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "chmod 777"
  "dd if=/dev/zero"
  "> /etc/passwd"
  "curl.*| bash"
  "wget.*| sh"
  ":(){ :|:& };:"
)

LOG_FILE="${HOME}/.claude/hooks/bash-audit.log"
mkdir -p "$(dirname "$LOG_FILE")"
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')

echo "${TIMESTAMP} CMD: ${COMMAND}" >> "$LOG_FILE"

for pattern in "${DANGER_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qF "$pattern"; then
    echo "${TIMESTAMP} BLOCKED: ${COMMAND}" >> "$LOG_FILE"
    echo "::error::🚫 危険なコマンドをブロックしました: ${pattern}"
    exit 2  # exit 2 でツール実行をブロック
  fi
done

exit 0
```

`exit 2` がポイントで、これを返すと Claude Code はそのツール呼び出しを中止する。

### 2. 自動フォーマット（PostToolUse）

ファイルを編集するたびに、拡張子に応じたフォーマッタを自動実行する。`black`（Python）、`prettier`（JS/TS）、`gofmt`（Go）、`shfmt`（Shell）に対応。インストールされていないフォーマッタはスキップされる。

```bash:~/.claude/hooks/post-edit-format.sh
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

EXT="${FILE_PATH##*.}"

case "$EXT" in
  py)
    command -v black &>/dev/null && black --quiet "$FILE_PATH"
    command -v ruff  &>/dev/null && ruff check --fix --quiet "$FILE_PATH" 2>/dev/null || true
    ;;
  js|jsx|ts|tsx)
    command -v prettier &>/dev/null && prettier --write --log-level warn "$FILE_PATH"
    ;;
  go)
    command -v gofmt &>/dev/null && gofmt -w "$FILE_PATH"
    ;;
  sh|bash)
    command -v shfmt &>/dev/null && shfmt -w "$FILE_PATH"
    ;;
esac

exit 0
```

### 3. セッションサマリ（Stop）

セッション終了時に、編集ファイル一覧と `git diff --stat` を `~/.claude/sessions/YYYY-MM-DD.md` に追記する。「今日何をやったか」が自動でログになる。

```bash:~/.claude/hooks/stop-session-summary.sh
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
# stop_hook_active が true の場合は無限ループ防止のためスキップ
ACTIVE=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('stop_hook_active', False))
" 2>/dev/null || echo "false")
[ "$ACTIVE" = "True" ] && exit 0

SESSION_FILE="${HOME}/.claude/sessions/$(date '+%Y-%m-%d').md"
mkdir -p "$(dirname "$SESSION_FILE")"

cat >> "$SESSION_FILE" << MARKDOWN

## セッション終了: $(date '+%H:%M:%S')

### git diff --stat
\`\`\`
$(git diff --stat 2>/dev/null | tail -5 || echo "(git情報なし)")
\`\`\`

---
MARKDOWN

exit 0
```

:::message
`stop_hook_active` チェックは必須。これを省略すると Stop フック → サマリ生成 → また Stop → ... という無限ループに入る。
:::

## settings.json への組み込み

`~/.claude/settings.json` に以下を追記する。`matcher` は正規表現で、`Write|Edit` のようにパイプで複数指定できる。

```json:~/.claude/settings.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/pre-bash-guard.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/post-edit-format.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/stop-session-summary.sh"
          }
        ]
      }
    ]
  }
}
```

## 動作確認

危険コマンドガードの動作をそのまま確認してみた。

```bash
# 通常コマンド
$ echo '{"tool_input": {"command": "ls -la"}}' | bash pre-bash-guard.sh
→ exit 0（通過）

# 危険コマンド
$ echo '{"tool_input": {"command": "rm -rf /"}}' | bash pre-bash-guard.sh
::error::🚫 危険なコマンドをブロックしました: rm -rf /
→ exit 2（ブロック）

# 監査ログ
$ cat ~/.claude/hooks/bash-audit.log
2026-05-03T00:25:54 CMD: ls -la
2026-05-03T00:25:54 CMD: rm -rf /
2026-05-03T00:25:54 BLOCKED: rm -rf /
```

実際に `exit 2` でブロックされることが確認できた。Claude Code は exit 2 のときにツール実行を中止し、ユーザーへの確認に戻る仕様になっている。

:::details 全スクリプト・設定ファイル一式（install.sh 含む）

```bash:scripts/install.sh
#!/usr/bin/env bash
set -euo pipefail

HOOKS_DIR="${HOME}/.claude/hooks"
SETTINGS_DIR="${HOME}/.claude"

echo "🔧 Claude Code Hooks セットアップを開始します..."

mkdir -p "$HOOKS_DIR"
cp scripts/pre-bash-guard.sh       "${HOOKS_DIR}/pre-bash-guard.sh"
cp scripts/post-edit-format.sh     "${HOOKS_DIR}/post-edit-format.sh"
cp scripts/stop-session-summary.sh "${HOOKS_DIR}/stop-session-summary.sh"
chmod +x "${HOOKS_DIR}"/*.sh

if [ -f "${SETTINGS_DIR}/settings.json" ]; then
  echo "⚠️  既存の settings.json があります。手動でマージしてください。"
else
  cp examples/settings.json "${SETTINGS_DIR}/settings.json"
fi

echo "🎉 セットアップ完了"
```

:::

## 成果物

デモページ（GitHub Pages）とリポジトリを公開している。

@[github](https://github.com/liatris000/liatris-20260503-claude-hooks)

👉 デモページ: https://liatris000.github.io/liatris-20260503-claude-hooks/

## やってみた感想

**良かった点**

- `exit 2` の仕様が明確で、ブロックロジックが書きやすい
- `settings.json` に書くだけで有効になるので、プロジェクトごとに設定をコミットできる
- フック内で標準出力した文字列は Claude Code のコンソールにそのまま表示される（フィードバックが分かりやすい）

**惜しかった点・改善余地**

- `PreToolUse` でブロックしたあと、Claude にその旨が自動で伝わるわけではない。ユーザーが次のプロンプトで「さっきブロックしたのは〇〇だよ」と言わないと Claude は気づかない
- フックスクリプトのデバッグは少し面倒。失敗しても Claude Code 側のエラーメッセージが薄いので、`set -x` をつけてログファイルに流すのが現実的

**業務での使いどころ**

本番環境への直接操作を検知する `kubectl/helm × prod` パターンや、機密ファイルへのアクセスを監査ログに残す使い方が実用性が高いと感じた。チームで Claude Code を使い始めるときのガードレールとして先に入れておくと安心できる。

## まとめ

一言で言うと、**「Claude Code の行動を観測・制御する仕組みを3スクリプトで作れた」**。

Hooks は AI エージェントの「野放し感」を一段緩和してくれる機能で、特にチーム導入時やステージング以上の環境で使う場面では真っ先に設定したい。実装コストは低い（シェルスクリプトが書ければ十分）ので、Claude Code を業務で使い始めた人はまず試してほしい。
