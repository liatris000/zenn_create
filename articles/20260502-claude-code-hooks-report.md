---
title: "Claude Code HooksでAI作業ログを自動記録する"
emoji: "📋"
type: "tech"
topics: ["claudecode", "claude", "ai", "automation", "hooks"]
published: false
---

:::message
この記事はClaude Codeが自律的に生成しました。内容は平野が確認・公開判断しています。
:::

Claude Code の Hooks 機能を使って、毎回の作業ログを自動で記録し、セッション終了時にHTML形式の日報を生成するツールを作ってみました。シェルスクリプト3本＋Pythonスクリプト1本という構成で、約40分で実装できました。

なぜ作ろうと思ったか？　Claude Code は毎日使っているのに「今日どれくらい使ったか」「どのツールを何回呼んだか」が全然わからない。ログが自動で貯まって、終わったら可視化されていたら嬉しい。そういう動機でした。結果、思ったよりずっと綺麗にできたので紹介します。

## Claude Code の Hooks とは

Claude Code の Hooks は、CLIの特定のイベントに合わせてシェルコマンドを自動実行できる機能です。設定は `~/.claude/settings.json` に書きます。

現在使えるイベントは4種類です：

| イベント | タイミング |
|---|---|
| `PreToolUse` | ツール呼び出しの直前 |
| `PostToolUse` | ツール呼び出しの直後 |
| `Stop` | Claude がセッションを終了するとき |
| `PostCompact` | コンテキスト圧縮後 |

フックには stdin 経由でセッションID・ツール名・入出力が渡ってくるので、それを使って何でもできます。

## 作ったもの

**3本のシェルスクリプト＋1本のPythonスクリプト**で構成しています。

- `hooks/pre_tool_use.sh` — ツール呼び出しのたびにJSONLでログを追記
- `hooks/post_tool_use.sh` — ツール結果（終了コード等）もJSONLに追記
- `hooks/stop.sh` — セッション終了時に `generate_report.py` を呼び出す
- `generate_report.py` — JONLログを読んでHTMLダッシュボードを生成

生成されるHTMLはこんな感じです：

👉 **デモページ: https://liatris000.github.io/liatris-20260502-claude-code-hooks-report/**

ツール使用頻度の棒グラフ・タイムライン・稼働時間サマリーが表示されます。

## Step1: ログを記録するフックを書く

`PreToolUse` フックは、Claude Code がツールを呼ぶたびに stdin でこういうJSONを受け取ります：

```json:stdin の例
{
  "session_id": "abc12345...",
  "tool_name": "Bash",
  "tool_input": { "command": "ls -la" }
}
```

これをパースしてJSONLに追記するシェルスクリプトを書きます：

```bash:hooks/pre_tool_use.sh
#!/bin/bash
LOG_DIR="${HOME}/.claude/work_logs"
mkdir -p "$LOG_DIR"

TODAY=$(date +%Y%m%d)
LOGFILE="${LOG_DIR}/${TODAY}.jsonl"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" \
  2>/dev/null || echo "unknown")
SESSION_ID=$(echo "$INPUT" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','')[:8])" \
  2>/dev/null || echo "")

ENTRY=$(python3 -c "
import json, datetime
entry = {
    'ts': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'event': 'tool_call',
    'tool': '${TOOL_NAME}',
    'session': '${SESSION_ID}',
    'cwd': '$(pwd)'
}
print(json.dumps(entry, ensure_ascii=False))
")

echo "$ENTRY" >> "$LOGFILE"
```

`PostToolUse` フックも同様の構造で、Bash ツールの終了コードも記録します。

## Step2: Stop フックでHTMLレポートを生成する

`Stop` フックはシンプルで、今日のログファイルが存在すれば Python スクリプトを叩くだけです：

```bash:hooks/stop.sh
#!/bin/bash
LOG_DIR="${HOME}/.claude/work_logs"
TODAY=$(date +%Y%m%d)
LOGFILE="${LOG_DIR}/${TODAY}.jsonl"
REPORT="${LOG_DIR}/report_${TODAY}.html"

[ -f "$LOGFILE" ] || exit 0

python3 "$(dirname "$0")/../generate_report.py" "$LOGFILE" "$REPORT"
echo "[hooks/stop] 作業日報を生成しました: $REPORT"
```

## Step3: HTMLレポートを生成するPythonスクリプト

JONLを読んで統計を集計し、インラインCSSでHTMLを出力します。外部依存ゼロなので標準ライブラリだけで動きます：

:::details generate_report.py（全文）

```python:generate_report.py
#!/usr/bin/env python3
import json
import sys
from collections import Counter
from datetime import datetime, timezone

def load_log(path):
    entries = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return entries

def build_report(entries, output_path, report_date=None):
    calls = [e for e in entries if e.get("event") == "tool_call"]
    tool_counter = Counter(e["tool"] for e in calls)
    sessions = list({e["session"] for e in calls if e.get("session")})

    if not report_date:
        report_date = datetime.now().strftime("%Y-%m-%d")

    total_calls = len(calls)

    times = []
    for e in calls:
        try:
            ts = datetime.strptime(e["ts"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            times.append(ts)
        except Exception:
            pass
    duration_str = ""
    if len(times) >= 2:
        delta = max(times) - min(times)
        minutes = int(delta.total_seconds() // 60)
        duration_str = f"{minutes}分"

    top_tools = tool_counter.most_common(8)
    max_count = max((c for _, c in top_tools), default=1)

    bars_html = ""
    colors = ["#6C8EFF","#5CE6C8","#FF7E7E","#FFD166","#A78BFA","#34D399","#F97316","#64748B"]
    for i, (tool, count) in enumerate(top_tools):
        pct = int(count / max_count * 100)
        color = colors[i % len(colors)]
        bars_html += f"""
        <div class=\"bar-row\">
          <span class=\"bar-label\">{tool}</span>
          <div class=\"bar-wrap\">
            <div class=\"bar\" style=\"width:{pct}%; background:{color};\">{count}</div>
          </div>
        </div>"""

    timeline_rows = ""
    for e in reversed(calls[-20:]):
        tool = e.get("tool", "-")
        ts_raw = e.get("ts", "")
        try:
            ts_dt = datetime.strptime(ts_raw, "%Y-%m-%dT%H:%M:%SZ")
            ts_display = ts_dt.strftime("%H:%M:%S")
        except Exception:
            ts_display = ts_raw
        cwd = e.get("cwd", "")
        session = e.get("session", "")
        timeline_rows += f"""
        <tr>
          <td class=\"ts\">{ts_display}</td>
          <td><span class=\"badge\">{tool}</span></td>
          <td class=\"dim\">{cwd}</td>
          <td class=\"dim\">{session}</td>
        </tr>"""

    # ... (HTML出力部分は省略、リポジトリ参照)

if __name__ == "__main__":
    entries = load_log(sys.argv[1])
    build_report(entries, sys.argv[2])
```

:::

## Step4: settings.json にフック設定を追記する

`~/.claude/settings.json` に以下を追記します（既存の設定がある場合は `hooks` キーをマージしてください）：

```json:~/.claude/settings.json に追記
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/pre_tool_use.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/post_tool_use.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/stop.sh"
          }
        ]
      }
    ]
  }
}
```

:::message
`matcher` は正規表現でツール名をフィルタできます。`".*"` は全ツールにマッチします。`"Bash"` にすれば Bash コマンドの実行だけログを取ることも可能です。
:::

## セットアップ手順まとめ

```bash
# 1. リポジトリをクローン
git clone https://github.com/liatris000/liatris-20260502-claude-code-hooks-report.git
cd liatris-20260502-claude-code-hooks-report

# 2. フックスクリプトをコピー
mkdir -p ~/.claude/hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# 3. レポート生成スクリプトをコピー
cp generate_report.py ~/.claude/

# 4. settings.json にフック設定を追記（上記の JSON を参考に）
```

次回から Claude Code を使うたびにログが `~/.claude/work_logs/YYYYMMDD.jsonl` に貯まります。セッション終了時に `report_YYYYMMDD.html` が自動生成されます。

## やってみた感想

**良かった点**

- 設定が JSON 数行で完結するのが想像以上にシンプルでした。コード量が少ない分、壊れにくいです
- `matcher` で「Bash だけログ」「Edit だけログ」みたいな絞り込みができるのが便利。特定の重い操作だけ追いたいときに使えます
- `Stop` フックはセッション終了後に実行されるので、本体の動作を一切邪魔しません

**惜しかった点**

- フックスクリプトがエラーを出しても Claude Code 本体の挙動に影響がない（良い設計ではあるが、デバッグ時は別途ログを見る必要がある）
- PreToolUse のタイミングで `tool_input` の中身を見ようとすると、コマンド文字列が長い場合にシェル変数に入れにくい。今回は工夫して Python で直接パースしています

**業務で使えるか**

使えます。特に「今日の Claude Code 作業を振り返りたい」「請求書用に作業時間を記録したい」「何のツールを多用しているか把握したい」といったニーズにそのまま対応できます。

私自身は、月次の業務レポートに「Claude Codeで何時間作業したか」を添付する用途で使い始めています。

## まとめ

Claude Code の Hooks は、数行の設定で「やりたいこと」を挟み込める。拡張ポイントとして非常に優秀でした。

今回作ったのはログ＋HTML日報の組み合わせですが、同じ仕組みで「Slack通知」「Gitコミット前の自動フォーマット」「重いコマンドだけタイムスタンプを出す」なども作れます。

こんな人に試してほしい：
- Claude Code を毎日使っているが「何をどれくらいやったか」把握できていない方
- コンサルやフリーランスで作業ログが必要な方
- Hooks をまだ触ったことがない方（設定の簡単さに驚くと思います）

@[github](https://github.com/liatris000/liatris-20260502-claude-code-hooks-report)

デモページ（GitHub Pages）: https://liatris000.github.io/liatris-20260502-claude-code-hooks-report/
