---
title: "相手側の都合で落ちた自動化の証拠を、失敗した瞬間に残す"
emoji: "🧾"
type: "tech"
topics: ["automation", "githubactions", "logging", "debugging", "claudecode"]
pattern: "implementation"
published: true
published_at: "2026-11-05 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20261105-failure-evidence-capture_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事](https://zenn.dev/liatris/articles/20260701-zenn-kickoff)にまとめています。
:::

定期実行が「たまに」落ちる。手で回すと通る。ログに残っているのは `failed` の一語だけで、外部 API の都合らしいが、次に落ちるまで確かめようがない。そこで、落ちた瞬間の応答をその場で保存する小さなラッパーを作った。

## 失敗の後に欲しいもの

欲しいのは、リクエスト・応答ヘッダ・応答本文・ステータス・所要時間・再試行の履歴。このうち本文が真っ先に消える。`curl -f`（`--fail`）は 4xx/5xx で本文を捨てて終了コード 22 を返すだけなので、「503 だった」までしか分からず、`retry_after` のような相手側の説明は残らない。

方針は3つにした。

- 成功した試行は何も残さない。失敗した試行だけ保存する
- 試行ごとに別ディレクトリへ書く。最後の1回で上書きしない
- 認証ヘッダは保存前に潰す

## 実装

@[github](https://github.com/liatris000/liatris-20261105-failure-evidence-capture)

Bash + curl 8.5.0 で書いた。`-D` で応答ヘッダ、`-o` で本文、`-w` でステータスと所要時間を取る。失敗時は `evidence/<UTC日時>-<PID>/attempt-N/` に書き、最終的に失敗なら終了コード 1 を返す。

```bash:capture-on-fail.sh
#!/usr/bin/env bash
# capture-on-fail.sh: 外部 API 呼び出しを包み、失敗した試行だけ証拠を保存する
# 使い方: EVIDENCE_DIR=evidence MAX_ATTEMPTS=3 ./capture-on-fail.sh URL [curl の追加引数...]
set -u

url="${1:?usage: $0 URL [curl args...]}"
shift
evidence_root="${EVIDENCE_DIR:-evidence}"
max_attempts="${MAX_ATTEMPTS:-3}"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
run_dir="${evidence_root}/${run_id}"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# Authorization / Cookie / 各種キーのヘッダ値は保存前に潰す
redact() {
  sed -E 's/([Aa]uthorization|[Cc]ookie|[Xx]-[Aa]pi-[Kk]ey): *[^ ]+( [^ -][^ ]*)?/\1: [REDACTED]/g'
}

attempt=1
while [ "${attempt}" -le "${max_attempts}" ]; do
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # -sS: 進捗は消すがエラーは出す / -D: 応答ヘッダ / -w: ステータスと所要時間
  code_and_time="$(curl -sS --max-time 10 \
      -D "${tmp}/headers" -o "${tmp}/body" \
      -w '%{http_code} %{time_total}' "$@" "${url}" 2>"${tmp}/stderr")"
  curl_rc=$?
  http_code="${code_and_time%% *}"
  elapsed="${code_and_time##* }"

  if [ "${curl_rc}" -eq 0 ] && [ "${http_code}" -ge 200 ] && [ "${http_code}" -lt 300 ]; then
    cat "${tmp}/body"
    exit 0
  fi

  # 失敗した試行ごとに別ディレクトリへ残す(後の試行で上書きしない)
  dir="${run_dir}/attempt-${attempt}"
  mkdir -p "${dir}"
  {
    echo "started_at: ${started}"
    echo "url: ${url}"
    echo "curl_exit: ${curl_rc}"
    echo "http_status: ${http_code}"
    echo "time_total_sec: ${elapsed}"
    echo "curl_args: $(printf '%s ' "$@" | redact)"
  } > "${dir}/meta.txt"
  redact < "${tmp}/headers" > "${dir}/response-headers.txt" 2>/dev/null || true
  cp "${tmp}/body" "${dir}/response-body.txt" 2>/dev/null || true
  cp "${tmp}/stderr" "${dir}/curl-stderr.txt"

  echo "attempt ${attempt}/${max_attempts} failed (status=${http_code}, curl_exit=${curl_rc}) -> ${dir}" >&2
  attempt=$((attempt + 1))
  [ "${attempt}" -le "${max_attempts}" ] && sleep "${RETRY_WAIT:-1}"
done

echo "EVIDENCE_DIR=${run_dir}" >&2
exit 1
```

GitHub Actions で回すなら、`EVIDENCE_DIR` を `actions/upload-artifact` の対象にして `if: failure()` で上げる。ジョブが落ちた後は実行環境ごと消えるので、ファイルに書くだけでは回収されない。

## 動作確認

失敗を再現するため、`/flaky` で 503 を返すローカルサーバーを立てた（Python 3.11.17）。

```python:demo/server.py
"""失敗を再現するローカルサーバー。/flaky は 503 と本文を返し、/ok は 200 を返す。"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/flaky":
            body = json.dumps({"error": "upstream_maintenance", "retry_after": 30}).encode()
            self.send_response(503)
            self.send_header("Retry-After", "30")
        else:
            body = b'{"ok": true}'
            self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", 8765), Handler).serve_forever()
```

```bash
python3 demo/server.py &
EVIDENCE_DIR=evidence RETRY_WAIT=0 ./capture-on-fail.sh \
  http://127.0.0.1:8765/flaky -H "Authorization: Bearer secret-token"
```

3回とも 503 になり、`attempt-1` 〜 `attempt-3` に1回ずつ証拠が残った。`response-body.txt` には `{"error": "upstream_maintenance", "retry_after": 30}`、`response-headers.txt` には `Retry-After: 30` が入っている。ログの `failed` からは出てこない情報だ。接続できない先（`http://127.0.0.1:1/x`）を指すと、本文は空で `curl_exit: 7`（接続失敗）が `meta.txt` に残り、HTTP の失敗と区別できる。`/ok` を指した場合は本文だけが標準出力に出て、`evidence/` には何も作られない。

## 最初の版で漏れたもの

認証ヘッダの除去は、最初は行頭から始まる `Authorization: ...` を潰す正規表現にしていた。応答ヘッダには効いたが、`meta.txt` に書いた `curl_args` は `-H Authorization: Bearer secret-token` と行の途中にあるため素通りし、`grep -r secret-token evidence` で見つかった。行頭アンカーを外し、`Authorization` / `Cookie` / `X-Api-Key` の値を行内のどこでも置換する形に直した。直後に同じ grep をかけて一致が無いことと、`meta.txt` が `-H Authorization: [REDACTED]` になっていることを確認した。

この除去は既知のヘッダ名しか見ない。URL のクエリに入れたトークンや、本文に含まれる秘密は消えないので、そういう API では保存対象から本文を外すか、URL を伏せる処理を足す必要がある。

## データアナリスト視点

欠損の理由が分からないデータは、後から補正できない。失敗ログも同じ構造で、落ちた瞬間に理由を取り損ねると、再現を待つしかなくなる。分析の前に欠損の記録を設計するのと同じで、失敗の記録も先に設計しておく価値がある。
