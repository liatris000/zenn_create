---
title: "問い合わせの「誰が返信したか」をSlackに一覧化する"
emoji: "📬"
type: "tech"
topics: ["claude", "claudecode", "ai", "automation", "slack"]
pattern: "implementation"
published: true
published_at: "2026-10-22 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20261022-inquiry-status-visibility_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事](https://zenn.dev/liatris/articles/20260701-zenn-kickoff)にまとめています。
:::

共有の問い合わせ窓口に複数人で対応していると、あるスレッドに返信が付いたかどうかは、返信した本人にしか分からない。他のメンバーはスレッドを開いて初めて知るので、二重に返信するか、誰かが返しただろうと思って放置するかのどちらかになる。これを、スレッドの履歴から状態を機械的に判定して一覧にする小さなスクリプトで潰してみた。

## 何を判定するか

入力はスレッドごとのメッセージ列（時刻・顧客か担当者か・投稿者・本文）で、出力は次の3状態。

- 未対応: 顧客の最後の発言より後に、担当者の発言が無い
- 対応中: 顧客の最後の発言より後に、着手宣言（「確認します」など）だけがある
- 返信済み: 顧客の最後の発言より後に、着手宣言ではない担当者の発言がある

基準を「スレッドの最後」ではなく「顧客の最後の発言」にしたのがポイントで、返信済みのスレッドに顧客が追伸すると、自動的に未対応へ戻る。状態を別カラムに持たず履歴から毎回導出するので、更新し忘れによるズレが起きない。

## 実装

判定にLLMは使っていない。最初は「返信済みかどうか」をClaudeに読ませる案を考えたが、判定の根拠は時刻の前後関係で書き下せたので、ルールベースで足りた。本文の意味を読む必要が出てくるのは、返信が回答になっているかまで見たくなった段階で、今回のスコープには入れていない。

着手宣言の判定だけは文字列に頼っている。最初は「対応中」という語を含むかだけで見ていたが、それだと長い返信文の中に「対応中の案件」と書いてあるだけで着手宣言扱いになる。そこで `len(body) <= 30` の条件を足した。雑だが、短い定型句だけを拾う目的には合っている。

`inquiry_status.py`（Python 3.11.15 で確認、標準ライブラリのみ）:

```python:inquiry_status.py
#!/usr/bin/env python3
"""問い合わせスレッドの対応状況を集計して一覧化する。

使い方:
    python3 inquiry_status.py sample_inquiries.json
    SLACK_WEBHOOK_URL=https://hooks.slack.com/... python3 inquiry_status.py sample_inquiries.json --post

標準ライブラリのみ。Python 3.9 以上で動く。
"""
import argparse
import json
import os
import sqlite3
import sys
import urllib.request
from datetime import datetime

# 「対応中」の宣言とみなす定型句。返信本文ではなく、着手の合図として使う
CLAIM_MARKERS = ("対応中", "確認します", "👀")
# 未対応がこの分数を超えたら警告を付ける
STALE_MINUTES = 60

SCHEMA = """
CREATE TABLE messages (
    thread_id TEXT NOT NULL,
    ts        TEXT NOT NULL,          -- ISO 8601
    role      TEXT NOT NULL,          -- 'customer' or 'staff'
    author    TEXT NOT NULL,
    body      TEXT NOT NULL
);
"""


def load(db: sqlite3.Connection, path: str) -> None:
    with open(path, encoding="utf-8") as f:
        rows = json.load(f)
    db.executemany(
        "INSERT INTO messages VALUES (:thread_id, :ts, :role, :author, :body)", rows
    )


def is_claim(body: str) -> bool:
    return any(m in body for m in CLAIM_MARKERS) and len(body) <= 30


def summarize(db: sqlite3.Connection, now: datetime) -> list[dict]:
    """スレッドごとに状態を判定する。判定の基準は「顧客の最後の発言より後に何があるか」。"""
    threads = []
    for (tid,) in db.execute("SELECT DISTINCT thread_id FROM messages ORDER BY thread_id"):
        msgs = db.execute(
            "SELECT ts, role, author, body FROM messages WHERE thread_id=? ORDER BY ts", (tid,)
        ).fetchall()
        last_customer = max(i for i, m in enumerate(msgs) if m[1] == "customer")
        after = msgs[last_customer + 1:]
        replies = [m for m in after if not is_claim(m[3])]
        claims = [m for m in after if is_claim(m[3])]

        if replies:
            status, owner = "返信済み", replies[-1][2]
        elif claims:
            status, owner = "対応中", claims[-1][2]
        else:
            status, owner = "未対応", "-"

        waited = (now - datetime.fromisoformat(msgs[last_customer][0])).total_seconds() / 60
        threads.append({
            "thread_id": tid,
            "status": status,
            "owner": owner,
            "waited_min": int(waited),
            "subject": msgs[0][3].splitlines()[0][:30],
            "stale": status != "返信済み" and waited > STALE_MINUTES,
        })
    return threads


def render(threads: list[dict]) -> str:
    icon = {"未対応": ":red_circle:", "対応中": ":large_yellow_circle:", "返信済み": ":white_check_mark:"}
    order = {"未対応": 0, "対応中": 1, "返信済み": 2}
    lines = []
    for t in sorted(threads, key=lambda t: (order[t["status"]], -t["waited_min"])):
        warn = f" ⚠️ {t['waited_min']}分経過" if t["stale"] else ""
        lines.append(f"{icon[t['status']]} {t['thread_id']} {t['status']} (担当: {t['owner']}) {t['subject']}{warn}")
    counts = {s: sum(1 for t in threads if t["status"] == s) for s in order}
    header = "問い合わせ対応状況: " + " / ".join(f"{s} {n}" for s, n in counts.items())
    return header + "\n" + "\n".join(lines)


def post_slack(text: str) -> None:
    url = os.environ.get("SLACK_WEBHOOK_URL")
    if not url:
        sys.exit("SLACK_WEBHOOK_URL が未設定です")
    req = urllib.request.Request(
        url, data=json.dumps({"text": text}).encode(), headers={"Content-Type": "application/json"}
    )
    urllib.request.urlopen(req, timeout=10).read()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("--now", default="2026-10-05T12:00:00", help="経過時間の基準時刻 (ISO 8601)")
    ap.add_argument("--post", action="store_true", help="Slack Incoming Webhook に投稿する")
    args = ap.parse_args()

    db = sqlite3.connect(":memory:")
    db.executescript(SCHEMA)
    load(db, args.input)
    text = render(summarize(db, datetime.fromisoformat(args.now)))
    print(text)
    if args.post:
        post_slack(text)


if __name__ == "__main__":
    main()
```

入力の `sample_inquiries.json` は次の形式（先頭2件のみ抜粋。全体は成果物リポジトリにある）:

```json:sample_inquiries.json
[
  {
    "thread_id": "T-101",
    "ts": "2026-10-05T09:00:00",
    "role": "customer",
    "author": "顧客A",
    "body": "請求書の宛名を変更したい\n再発行は可能ですか"
  },
  {
    "thread_id": "T-101",
    "ts": "2026-10-05T09:20:00",
    "role": "staff",
    "author": "佐藤",
    "body": "対応中です"
  }
]
```

## 実行結果

`--now 2026-10-05T12:00:00` を基準に、5スレッドのダミーデータで実行した出力がこれ。

```text
問い合わせ対応状況: 未対応 2 / 対応中 1 / 返信済み 2
:red_circle: T-105 未対応 (担当: -) 領収書が欲しい ⚠️ 200分経過
:red_circle: T-103 未対応 (担当: -) 見積書の有効期限を教えてください ⚠️ 120分経過
:large_yellow_circle: T-102 対応中 (担当: 鈴木) パスワードリセットのメールが届かない ⚠️ 150分経過
:white_check_mark: T-101 返信済み (担当: 佐藤) 請求書の宛名を変更したい
:white_check_mark: T-104 返信済み (担当: 田中) 利用プランの変更方法を知りたい
```

T-105 は担当者が一度返信しているが、その後に顧客が「日付が空欄でした」と追伸しているので未対応に戻っている。並び順は未対応 → 対応中 → 返信済みで、同じ状態の中では待ち時間が長い順。`--post` を付けて `SLACK_WEBHOOK_URL` を渡せば同じテキストがSlackに投稿される（この記事の検証ではWebhookへの投稿は行っていない）。

## データアナリスト視点

状態をカラムで持たず履歴から導出する形は、集計の世界でいう「イベントログから現在のスナップショットを作る」処理と同じ構造をしている。この形にしておけば、`waited_min` を状態別に集めるだけで、未対応の滞留時間の分布や担当者ごとの返信までの時間が同じデータから出せる。次の一歩は通知の精度ではなく、その分布を見て `STALE_MINUTES = 60` が妥当かを決めることだと思う。

@[github](https://github.com/liatris000/inquiry-status)
