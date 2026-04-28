---
title: "Claude CodeでGA4データをHTMLダッシュボード化してみた"
emoji: "📊"
type: "tech"
topics: ["claudecode", "python", "ga4", "データ分析", "ai"]
published: false
---

毎月のWebアクセスレポートをExcelでまとめる作業、正直しんどくないですか。先日、Claude Codeに「GA4（Google Analytics 4）のCSVをそのまま渡したらHTMLダッシュボードにしてくれる？」と頼んだら、**0.1秒以下**でキレイなグラフ付きHTMLが出てきて衝撃を受けました。今日はその全手順を公開します。

:::message alert
本記事で使用したデータはすべてサンプル（架空のフィクション）です。実際の数値ではありません。
:::

---

## やったこと

GA4の管理画面からエクスポートできるCSV形式のデータを使い、Pythonスクリプトでインタラクティブなダッシュボードを生成するまでを、**Claude Codeだけで完結**させました。

**なぜやろうと思ったか**：毎月Excelでレポートを作り直している時間がもったいない。一度スクリプトを作っておけば翌月以降は `python analyze.py` 一発でOKになるはずと思ったから。

**結論**：想像以上にあっさりできました。外部ライブラリも不要で、Python標準ライブラリだけで動きます。所要時間は**約15分**（Claude Codeへの指示〜HTML生成確認まで）。

---

## 手順

### ステップ1：CSVデータを用意する

まずGA4風のCSVを用意します。本記事ではサンプルデータを使います。実際にはGA4の管理画面から「レポート > ページとスクリーン」でCSVをダウンロードします。

CSVの列構成：

```csv
date,page_path,page_title,sessions,pageviews,avg_session_duration,bounce_rate,new_users,conversions,revenue
2026-04-01,/,ホーム,1250,1890,00:02:15,0.62,820,12,48000
2026-04-01,/services,サービス一覧,430,610,00:03:42,0.45,280,8,32000
...（135行）
```

### ステップ2：Claude Codeにスクリプト生成を依頼

Claude Codeに以下のプロンプトを渡しました：

```text
GA4風のCSVデータ（date/page_path/page_title/sessions/pageviews/
avg_session_duration/bounce_rate/new_users/conversions/revenueの列を持つ）
を読み込んで、以下を含むHTMLダッシュボードを生成するPythonスクリプトを作って。

- KPIカード（セッション、PV、CV数、CVR、売上）
- 日別推移の折れ線グラフ（セッション・PV）
- 日別コンバージョン棒グラフ
- ページ別パフォーマンス表
- Chart.jsを使用、ダークテーマ
- Python標準ライブラリのみ（pipなし）
```

Claude Codeが生成したのが `analyze.py`（全410行）です。

### ステップ3：スクリプトを実行

```bash
python3 analyze.py
```

実行結果：

```text
🔍 CSVデータを読み込み中...
   → 135行を読み込みました
📊 データを集計中...
   → 期間: 2026-04-01 〜 2026-04-27
   → 総セッション: 98,063
   → 総PV: 135,666
   → CV数: 1,422 (CVR: 1.45%)
   → 売上合計（架空）: ¥4,552,000
🎨 HTMLダッシュボードを生成中...
   → 保存先: report.html
✅ 完了!

real    0m0.082s
```

**0.082秒**で `report.html` が生成されました。

---

## 成果物

:::details analyze.py（全文）

```python
#!/usr/bin/env python3
"""
GA4風CSVデータからHTMLダッシュボードを自動生成するスクリプト
※ データはすべてサンプル（架空のフィクション）です
"""

import csv
import json
from datetime import datetime
from collections import defaultdict

def load_csv(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    return rows

def parse_duration(s):
    """'00:04:30' -> seconds"""
    parts = s.strip().split(":")
    if len(parts) == 3:
        return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
    return 0

def fmt_duration(seconds):
    m, s = divmod(int(seconds), 60)
    return f"{m}分{s:02d}秒"

def analyze(rows):
    daily = defaultdict(lambda: {"sessions": 0, "pageviews": 0, "conversions": 0, "revenue": 0})
    by_page = defaultdict(lambda: {"sessions": 0, "pageviews": 0, "conversions": 0, "revenue": 0, "duration_sum": 0, "duration_count": 0, "bounce_sum": 0})

    for r in rows:
        d = r["date"]
        daily[d]["sessions"] += int(r["sessions"])
        daily[d]["pageviews"] += int(r["pageviews"])
        daily[d]["conversions"] += int(r["conversions"])
        daily[d]["revenue"] += int(r["revenue"])

        p = r["page_title"]
        by_page[p]["sessions"] += int(r["sessions"])
        by_page[p]["pageviews"] += int(r["pageviews"])
        by_page[p]["conversions"] += int(r["conversions"])
        by_page[p]["revenue"] += int(r["revenue"])
        by_page[p]["duration_sum"] += parse_duration(r["avg_session_duration"]) * int(r["sessions"])
        by_page[p]["duration_count"] += int(r["sessions"])
        by_page[p]["bounce_sum"] += float(r["bounce_rate"]) * int(r["sessions"])

    sorted_dates = sorted(daily.keys())

    totals = {
        "sessions": sum(v["sessions"] for v in daily.values()),
        "pageviews": sum(v["pageviews"] for v in daily.values()),
        "conversions": sum(v["conversions"] for v in daily.values()),
        "revenue": sum(v["revenue"] for v in daily.values()),
    }
    totals["cvr"] = totals["conversions"] / totals["sessions"] * 100 if totals["sessions"] else 0

    return sorted_dates, daily, by_page, totals

def build_html(sorted_dates, daily, by_page, totals):
    dates_json = json.dumps(sorted_dates)
    sessions_json = json.dumps([daily[d]["sessions"] for d in sorted_dates])
    pv_json = json.dumps([daily[d]["pageviews"] for d in sorted_dates])
    conv_json = json.dumps([daily[d]["conversions"] for d in sorted_dates])
    rev_json = json.dumps([daily[d]["revenue"] // 1000 for d in sorted_dates])

    page_rows = ""
    for title, v in sorted(by_page.items(), key=lambda x: -x[1]["sessions"]):
        avg_dur = v["duration_sum"] / v["duration_count"] if v["duration_count"] else 0
        avg_bounce = v["bounce_sum"] / v["duration_count"] if v["duration_count"] else 0
        cvr = v["conversions"] / v["sessions"] * 100 if v["sessions"] else 0
        page_rows += f"""
        <tr>
          <td>{title}</td>
          <td class="num">{v['sessions']:,}</td>
          <td class="num">{v['pageviews']:,}</td>
          <td class="num">{fmt_duration(avg_dur)}</td>
          <td class="num">{avg_bounce*100:.1f}%</td>
          <td class="num">{v['conversions']:,}</td>
          <td class="num">{cvr:.2f}%</td>
          <td class="num">¥{v['revenue']:,}</td>
        </tr>"""

    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # （HTMLテンプレート全文はGitHubで確認できます）
    # https://github.com/liatris000/liatris-20260428-ga4-html-dashboard

    return html

def main():
    print("🔍 CSVデータを読み込み中...")
    rows = load_csv("data/sample_ga4.csv")
    print(f"   → {len(rows)}行を読み込みました")

    print("📊 データを集計中...")
    sorted_dates, daily, by_page, totals = analyze(rows)

    print("🎨 HTMLダッシュボードを生成中...")
    html = build_html(sorted_dates, daily, by_page, totals)

    with open("report.html", "w", encoding="utf-8") as f:
        f.write(html)
    print("✅ 完了!")

if __name__ == "__main__":
    main()
```

:::

スクリプト全文・HTMLテンプレート全文はGitHubで公開しています。

**公開URL（GitHub Pages）**
https://liatris000.github.io/liatris-20260428-ga4-html-dashboard/

**リポジトリ（スクリプト全文）**
https://github.com/liatris000/liatris-20260428-ga4-html-dashboard

---

## やってみた感想

### 良かった点

**①外部ライブラリが一切不要**
`pip install` なしで動きます。Python 3さえあれば社内のどのPCでも即実行できる。これは地味に大事で、社内展開のハードルがぐっと下がります。

**②プロンプト1発でChart.js込みのHTMLが出てきた**
「ダークテーマ、グラフはChart.js」という要件を自然言語で伝えただけで、CSSもJavaScriptも全部込みで出力されました。自分でChart.jsのドキュメントを読む時間がゼロ。

**③構造がシンプルで改造しやすい**
生成されたコードが読みやすく、「売上列をなくしたい」「色を変えたい」といった改造がすぐできました。

### 惜しかった点・改善余地

**GA4の実CSVとは列名が違う**
GA4の実際のエクスポートCSVは、列名が英語ではなく日本語だったり、行数が多かったりします。本記事のスクリプトをそのまま使うには列名のマッピングが必要です（15分くらいの修正で対応できます）。

**グラフがシンプル**
週次でのハイライト（週末に流入が増える・特定記事がバズった日）などは現状では自動で検出・注釈してくれません。「異常値を自動で赤くする」「前月比を自動計算する」といった機能は自分で追加が必要です。

### 業務で使えるか？

**使えます。むしろ積極的に使いたい。**

毎月のレポート作成に30〜60分かけているなら、一度このスクリプトを整備するだけで次月以降は**3分以内**に短縮できます。GA4の列名対応を済ませた社内版を作れば、マーケメンバー全員が使える資産になります。

Liatrisでは今後、このスクリプトにGitHub Actions（自動スケジューラー）を組み合わせて、毎月1日に自動でレポートHTMLを生成してSlackに通知する仕組みも作ってみる予定です。

---

## まとめ

**一言で言うと：「Excelレポート職人からの解放」**

Claude Codeに1つのプロンプトを渡すだけで、データ分析〜HTML生成〜グラフ可視化が0.1秒以内に完結します。データ分析をやってみたいけど「Pythonがわからない」「Chart.jsの書き方がわからない」という方でも全然大丈夫です。コードの意味がわからなくても、Claude Codeに「ここを直して」と伝えれば修正してくれます。

**こんな人に試してほしい**
- 毎月ExcelでWebアクセスレポートを作っている方
- GA4のデータをもっと手軽に可視化したい方
- Python入門として実用的なプロジェクトを探している方
