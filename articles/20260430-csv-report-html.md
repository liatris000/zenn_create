---
title: "Claude Codeで8分、CSVからマーケレポートHTMLを自動生成"
emoji: "📊"
type: "tech"
topics: ["claude", "claudecode", "ai", "automation"]
published: false
---

:::message
この記事はClaude Codeが自律的に生成しました。内容は平野が確認・公開判断しています。
:::

「月次レポート、またExcelで手打ちしてる……」そんなルーティンをClaude Codeに丸投げしてみました。やったことはシンプルで、**CSVを渡して「ダッシュボードHTMLを作って」と指示するだけ**。8分後にはChart.js製のレポートページが手元にありました。

なぜやろうと思ったか——月次マーケレポートの作成で毎回同じグラフを手で作り直すのが地味にしんどかったからです。「どうせ毎回同じ構成なら、Claudeに一度コードを書いてもらえばいいのでは」と思い立ちました。

結論から言うと、**Python標準ライブラリのみで動くスクリプトが1本できあがり、外部サービスへの依存ゼロで使い回せる**ようになりました。

## Step1: CSVの列設計をClaudeに相談する

まず手元のデータ構造をClaudeに見せて、どんな列があればレポートとして成立するかを相談しました。

```
私: 月次マーケデータをCSVで持っています。
    PV・セッション・CV数・CV率・広告費・CPAあたりです。
    1ページのHTMLダッシュボードを作りたいのですが、
    CSV の列設計を提案してもらえますか？
```

Claudeが提案してきた列構成がこちらです。

```csv:sample_data.csv
month,pv,sessions,cv,cv_rate,cost,cpa
2025-11,12400,8200,41,0.50,248000,6049
2025-12,15800,10500,63,0.60,315000,5000
2026-01,13200,8800,44,0.50,264000,6000
2026-02,14600,9700,68,0.70,291000,4279
2026-03,18200,12100,97,0.80,363000,3742
2026-04,21500,14300,129,0.90,429000,3326
```

:::message
このデータはデモ用のフィクションです。実際の数値ではありません。
:::

列の少なさがポイントです。「必要最小限にして、Pythonで全部計算させましょう」という提案でした。MoM成長率・累計・平均CPAなどは全部スクリプト側で導出できるので、CSVに入れる必要がないわけです。

## Step2: Pythonスクリプトをほぼ丸投げで生成する

次に「このCSVからChart.js製のHTMLを生成するPythonスクリプトを書いて」と依頼しました。条件として伝えたのは3つだけです。

```
・ Python標準ライブラリのみ（pipインストール不要）
・ ダークテーマで見た目をリッチに
・ KPIカード4枚 + グラフ4枚
```

Claudeが生成したスクリプトの骨格はこうなっています。

```python:generate_dashboard.py
import csv
import json
from pathlib import Path

def load_csv(path: str) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))

def build_dashboard(rows: list[dict]) -> str:
    # データ集計
    total_cv   = sum(int(r["cv"]) for r in rows)
    total_cost = sum(int(r["cost"]) for r in rows)
    avg_cpa    = total_cost // total_cv
    last_month = rows[-1]
    prev_month = rows[-2]
    pv_growth  = round((int(last_month["pv"]) / int(prev_month["pv"]) - 1) * 100, 1)

    # HTMLテンプレートにデータを埋め込んで返す
    data_json = json.dumps({...}, ensure_ascii=False)
    return f"""<!DOCTYPE html>..."""

if __name__ == "__main__":
    rows = load_csv("sample_data.csv")
    html = build_dashboard(rows)
    Path("index.html").write_text(html, encoding="utf-8")
    print(f"✅ index.html を生成しました ({len(html):,} bytes)")
```

:::details 全コードを見る（177行）

```python:generate_dashboard.py
#!/usr/bin/env python3
import csv
import json
from pathlib import Path

def load_csv(path: str) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))

def build_dashboard(rows: list[dict]) -> str:
    months   = [r["month"] for r in rows]
    pvs      = [int(r["pv"]) for r in rows]
    sessions = [int(r["sessions"]) for r in rows]
    cvs      = [int(r["cv"]) for r in rows]
    cv_rates = [float(r["cv_rate"]) for r in rows]
    costs    = [int(r["cost"]) for r in rows]
    cpas     = [int(r["cpa"]) for r in rows]

    total_cv   = sum(cvs)
    total_cost = sum(costs)
    avg_cpa    = total_cost // total_cv
    last_month = rows[-1]
    prev_month = rows[-2]
    pv_growth  = round((int(last_month["pv"]) / int(prev_month["pv"]) - 1) * 100, 1)
    cv_growth  = round((int(last_month["cv"]) / int(prev_month["cv"]) - 1) * 100, 1)

    data_json = json.dumps({
        "months": months, "pvs": pvs, "sessions": sessions,
        "cvs": cvs, "cv_rates": cv_rates, "costs": costs, "cpas": cpas
    }, ensure_ascii=False)

    return f"""<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8">
<title>マーケティングダッシュボード</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.4/dist/chart.umd.min.js"></script>
<style>
  :root {{ --bg: #0f172a; --card: #1e293b; --border: #334155;
           --text: #f1f5f9; --muted: #94a3b8;
           --blue: #3b82f6; --green: #22c55e; --amber: #f59e0b; --rose: #f43f5e; }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: var(--bg); color: var(--text); padding: 24px; }}
  .kpi-grid {{ display: grid; grid-template-columns: repeat(auto-fit,minmax(180px,1fr)); gap:16px; margin-bottom:28px; }}
  .kpi {{ background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 20px; }}
  .charts {{ display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }}
  @media (max-width:680px) {{ .charts {{ grid-template-columns: 1fr; }} }}
  .chart-card {{ background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 20px; }}
</style></head>
<body>
<h1>📊 マーケティングダッシュボード</h1>
<div class="kpi-grid">
  <div class="kpi"><div class="label">直近月 PV</div>
    <div class="value">{int(last_month['pv']):,}</div>
    <span class="badge up">+{pv_growth}% MoM</span></div>
  <div class="kpi"><div class="label">直近月 CV</div>
    <div class="value">{int(last_month['cv'])}</div>
    <span class="badge up">+{cv_growth}% MoM</span></div>
  <div class="kpi"><div class="label">累計 CV</div>
    <div class="value">{total_cv}</div></div>
  <div class="kpi"><div class="label">平均 CPA</div>
    <div class="value">¥{avg_cpa:,}</div></div>
</div>
<div class="charts">
  <div class="chart-card"><canvas id="trafficChart" height="200"></canvas></div>
  <div class="chart-card"><canvas id="cvChart" height="200"></canvas></div>
  <div class="chart-card"><canvas id="costChart" height="200"></canvas></div>
  <div class="chart-card"><canvas id="cpaChart" height="200"></canvas></div>
</div>
<p class="footer">⚠️ デモ用フィクションデータ · Generated by Claude Code</p>
<script>
const d = {data_json};
const opt = (y2) => ({{ responsive:true,
  plugins:{{ legend:{{ labels:{{ color:'#94a3b8',boxWidth:12 }} }} }},
  scales:{{ x:{{ ticks:{{color:'#94a3b8'}},grid:{{color:'#1e293b'}} }},
            y:{{ ticks:{{color:'#94a3b8'}},grid:{{color:'#334155'}} }},
            ...(y2?{{y2:{{type:'linear',position:'right',ticks:{{color:'#94a3b8'}},grid:{{drawOnChartArea:false}}}}}}:{{}})
  }}
}});
new Chart(document.getElementById('trafficChart'),{{type:'bar',data:{{labels:d.months,datasets:[{{label:'PV',data:d.pvs,backgroundColor:'rgba(59,130,246,0.7)',borderRadius:4}},{{label:'セッション',data:d.sessions,backgroundColor:'rgba(99,102,241,0.7)',borderRadius:4}}]}},options:opt(false)}});
new Chart(document.getElementById('cvChart'),{{type:'bar',data:{{labels:d.months,datasets:[{{label:'CV数',data:d.cvs,backgroundColor:'rgba(34,197,94,0.7)',borderRadius:4,yAxisID:'y'}},{{label:'CV率(%)',data:d.cv_rates,type:'line',borderColor:'#f59e0b',backgroundColor:'rgba(245,158,11,0.15)',yAxisID:'y2',tension:0.4,fill:true}}]}},options:opt(true)}});
new Chart(document.getElementById('costChart'),{{type:'line',data:{{labels:d.months,datasets:[{{label:'広告費',data:d.costs,borderColor:'#f43f5e',backgroundColor:'rgba(244,63,94,0.1)',tension:0.4,fill:true}}]}},options:opt(false)}});
new Chart(document.getElementById('cpaChart'),{{type:'line',data:{{labels:d.months,datasets:[{{label:'CPA',data:d.cpas,borderColor:'#a78bfa',backgroundColor:'rgba(167,139,250,0.1)',tension:0.4,fill:true}}]}},options:opt(false)}});
</script></body></html>"""

if __name__ == "__main__":
    rows = load_csv("sample_data.csv")
    html = build_dashboard(rows)
    Path("index.html").write_text(html, encoding="utf-8")
    print(f"✅ index.html を生成しました ({len(html):,} bytes)")
```

:::

## Step3: 実際に動かしてみる

```bash
python3 generate_dashboard.py
# ✅ index.html を生成しました (5,380 bytes)
```

コマンド1本、1秒以内に完了しました。生成された `index.html` をブラウザで開くと、KPIカード4枚とChart.jsのグラフ4本が表示されるダッシュボードが動きます。

生成物はセルフコンテインド（自己完結型）のHTMLなので、ファイルを渡すだけでどこでも表示できます。社内Slackに添付してもいいし、S3やGitHub Pagesに置いてもOKです。

## 成果物

コード一式をGitHubで公開しています。

https://github.com/liatris000/zenn_create/tree/main/artifacts/20260430-csv-report-html

```bash
# クローンして試す
git clone https://github.com/liatris000/zenn_create.git
cd zenn_create/artifacts/20260430-csv-report-html
python3 generate_dashboard.py
open index.html   # macOS の場合
```

## やってみた感想

**良かった点**

一番助かったのは「何を列に入れるべきか」の設計相談ができたことです。Excelで作るとデータと計算が混在しがちですが、「CSVはナマデータだけ、計算はPythonに任せる」という分離をClaudeが提案してくれたおかげで、後からCSVを差し替えるだけでレポートが更新される設計になりました。

また、pipインストール不要（Python標準ライブラリのみ）という条件を初めに伝えたことで、環境を選ばないスクリプトになりました。クライアントのマシンで動かす場面でも余計な説明が不要になります。

**惜しかった点**

HTMLが1ファイルに全部詰まっているため、CSSやJSの修正をするときはPythonコードの中のf-stringを直接触ることになります。慣れていない人には少し見通しが悪いです。改善するなら、HTMLテンプレートファイルを別に切り出す設計にするとよいでしょう。

また今回は Chart.js を CDN で読み込んでいるため、オフライン環境では表示されません。社内レポートとして配布する場合はChart.jsをローカルに含める必要があります（Claudeに「オフライン対応で」と追加指示すればすぐ対応できます）。

**業務で使えるか？**

十分使えます。Liatrisのマーケ支援文脈では毎月同じ構成のレポートを出す場面があり、「CSVを更新して1コマンド叩く」だけで最新のHTMLが出てくる仕組みは、作業時間の削減というより**ミスの防止**に大きく貢献します。手打ち・コピペミスが構造的に起きなくなるからです。

クライアントにGoogle スプレッドシートからCSVエクスポートしてもらって渡すだけ、という運用でも使えます。

## まとめ

一言で言うと、「**Claudeはコードを書くのではなく、設計から一緒に考えてくれる**」です。

今回うまくいったのは、要件（標準ライブラリのみ・ダークテーマ・KPI4枚+グラフ4枚）を最初に整理して伝えられたからで、あいまいな依頼だと何往復かかかります。設計の叩き台を作ってもらってから細かい調整、という流れが一番スムーズでした。

こんな人に試してほしいです：
- 毎月同じ構成のレポートをExcelで手作りしている方
- グラフ作成ツールの有料プランをもったいないと感じている方
- 社内ツールをノーコードで作りたいが、HTMLには少し抵抗がある方（Claudeに全部書いてもらえばOKです）
