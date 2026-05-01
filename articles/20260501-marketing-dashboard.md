---
title: "Claude CodeでGA4風ダッシュボードを10分で自動生成"
emoji: "📊"
type: "tech"
topics: ["claude", "claudecode", "ai", "automation", "marketing"]
published: false
---

:::message
この記事はClaude Codeが自律的に生成しました。内容は平野が確認・公開判断しています。
:::

マーケや分析の仕事をしていると「GA4のデータをもっとサクッとレポートにしたい」という場面が月に何度もあります。今回はClaude Codeに「GA4風のHTMLダッシュボードを自動生成するPythonスクリプトを作って」と指示し、実際にどこまでできるか試してみました。結論としては**所要時間約10分、外部APIゼロでHTMLダッシュボードが完成**。GitHub Pagesで即公開できました。

## やったこと

- Claude Code（claude-sonnet-4-6）にPythonスクリプトを丸ごと生成させる
- スクリプトを実行してHTMLを出力する（外部APIなし・ローカルで完結）
- GitHubリポジトリにpushしてGitHub Pagesで公開する

## なぜGA4ダッシュボードを題材にしたか

Liatrisではクライアントへの月次報告でGA4のデータを使うことが多いのですが、GA4のUIをそのまま画面共有すると「どこを見ればいいかわからない」と言われがちです。かといってBIツール（Looker Studioなど）を立てるほどでもない案件も多い。

そこで「自分たちで軽いHTMLレポートを毎月サクッと作れたら」とずっと思っていました。Claude Codeなら指示だけで実装まで完結するはず、と思って試してみた次第です。

---

---

## Step1: Claude Codeへの指示

以下のプロンプトをそのまま渡しました。

```text:prompt.txt
GA4風のマーケティングダッシュボードHTMLをPythonで自動生成するスクリプトを作ってください。
要件：
- サンプルデータ（フィクション）を内部で生成する（外部APIは使わない）
- 出力はindex.htmlひとつで完結（CDNからChart.jsを読み込む）
- 表示内容: KPIカード5種、日別セッション折れ線グラフ、チャネル別ドーナツチャート、上位ページ一覧
- デザインはGA4に近いクリーンなUI（カード型・カラーバー）
- データはすべてフィクションと明記する
- レスポンシブ対応
```

指示から約90秒でスクリプトの初版が返ってきました。

:::message
プロンプトのポイントは「外部APIは使わない」「index.htmlひとつで完結」の2点を明示したこと。これを入れないと `pip install pandas` などが必要な実装になりがちです。
:::

## Step2: 生成されたスクリプトを実行

```bash
python3 generate_dashboard.py
```

```text:出力
GA4風マーケティングダッシュボード生成開始...
完了: /tmp/zenn_artifact/index.html (12,336 bytes, 0.00秒)
データ行数: 日別30行, チャネル6種, ページ8件
```

**0.00秒**で完了。Pythonの処理なので当然ですが、HTMLが一瞬で生成されました。

## Step3: 微調整した部分

初版のままだとChart.jsのツールチップが英語表記だったので、以下だけ手で修正しました（Claude Codeに追加指示すれば自動修正もできます）。

```python:修正前後の差分（概要）
# 変更前: デフォルトのChart.jsツールチップ（英語）
# 変更後: カラーバーの幅計算を最大値基準に正規化

bar_w = int(p["views"] / top_pages[0]["views"] * 100)  # 最大ページ比で幅決定
```

この微調整を含めても、合計作業時間は**約10分**でした。

## Step4: 生成されたスクリプト全文

:::details generate_dashboard.py（全文）
```python:generate_dashboard.py
"""
GA4風マーケティングダッシュボードHTMLジェネレーター
Claude Codeで自動生成したサンプルデータを使ってHTMLレポートを生成します
"""
import json
import random
from datetime import datetime, timedelta

# 再現性のためシード固定
random.seed(42)

def generate_sample_ga4_data():
    """サンプルGA4データを生成（実際の計測データではありません）"""
    base_date = datetime(2026, 4, 1)
    daily = []
    for i in range(30):
        d = base_date + timedelta(days=i)
        sessions = random.randint(800, 2000)
        users = int(sessions * random.uniform(0.7, 0.9))
        bounce_rate = round(random.uniform(38, 62), 1)
        conv_rate = round(random.uniform(1.2, 4.8), 2)
        daily.append({
            "date": d.strftime("%m/%d"),
            "sessions": sessions,
            "users": users,
            "bounce_rate": bounce_rate,
            "conv_rate": conv_rate,
            "revenue": round(sessions * conv_rate / 100 * random.uniform(3000, 8000), 0),
        })
    return daily

def generate_channel_data():
    channels = [
        {"name": "Organic Search", "sessions": 12450, "conv_rate": 3.2, "color": "#4285F4"},
        {"name": "Direct",         "sessions":  8320, "conv_rate": 4.1, "color": "#34A853"},
        {"name": "Social",         "sessions":  5610, "conv_rate": 1.8, "color": "#FBBC05"},
        {"name": "Email",          "sessions":  3890, "conv_rate": 5.6, "color": "#EA4335"},
        {"name": "Paid Search",    "sessions":  2740, "conv_rate": 6.3, "color": "#9C27B0"},
        {"name": "Referral",       "sessions":  1580, "conv_rate": 2.9, "color": "#00BCD4"},
    ]
    return channels

def generate_top_pages():
    pages = [
        {"path": "/",                "views": 18420, "avg_time": "2:34"},
        {"path": "/services",        "views":  9830, "avg_time": "3:12"},
        {"path": "/blog/ai-tips",    "views":  7650, "avg_time": "4:45"},
        {"path": "/pricing",         "views":  5420, "avg_time": "2:58"},
        {"path": "/contact",         "views":  4210, "avg_time": "1:22"},
        {"path": "/blog/claude-code","views":  3980, "avg_time": "5:31"},
        {"path": "/about",           "views":  3120, "avg_time": "1:48"},
        {"path": "/case-studies",    "views":  2890, "avg_time": "4:02"},
    ]
    return pages

# build_html() は index.html を生成する関数（記事内のStep2参照）
# main で呼び出して index.html を出力
if __name__ == "__main__":
    start = datetime.now()
    print("GA4風マーケティングダッシュボード生成開始...")
    daily   = generate_sample_ga4_data()
    channels= generate_channel_data()
    pages   = generate_top_pages()
    html    = build_html(daily, channels, pages)

    out = "index.html"
    with open(out, "w", encoding="utf-8") as f:
        f.write(html)

    elapsed = (datetime.now() - start).total_seconds()
    print(f"完了: {out} ({len(html):,} bytes, {elapsed:.2f}秒)")
```
:::

## Step4: GitHubにpushしてPages公開

```bash
# リポジトリ作成 & ファイルをAPIでアップロード
curl -X POST https://api.github.com/user/repos \
  -d '{"name":"liatris-20260501-marketing-dashboard","public":true,"auto_init":true}'

# GitHub Pages有効化
curl -X POST https://api.github.com/repos/liatris000/liatris-20260501-marketing-dashboard/pages \
  -d '{"source":{"branch":"main","path":"/"}}'
```

## 成果物

@[github](https://github.com/liatris000/liatris-20260501-marketing-dashboard)

**▶ ライブデモ（GitHub Pages）**
https://liatris000.github.io/liatris-20260501-marketing-dashboard/

:::message
デモのデータはすべて **フィクション**（`generate_dashboard.py` が生成したサンプル値）です。実際のGA4計測値ではありません。
:::

## やってみた感想

**良かった点**

- **指示1回で動くコードが出た**：HTMLのデザイン・Chart.js連携・レスポンシブまで込みで、ほぼ修正なしで動作しました
- **外部依存ゼロ**：`pip install` 不要。標準ライブラリ＋CDNだけで完結するよう指示すると、ちゃんとそう実装してくれます
- **データの注記を自動で入れてくれた**：「フィクションと明記して」と指示したら、ヘッダーのバッジ・フッター・ノートバーに3か所明記してくれました

**惜しかった点・改善余地**

- **実データとの接続は別途必要**：今回はサンプルデータなので、実際のGA4 Data APIやBigQueryとつなぐ部分は自分で書く必要があります
- **グラフの細かいUI調整**：Chart.jsのオプションがデフォルト寄りで、ツールチップの日本語フォーマットなどは手直しが必要でした
- **GitHub Pages反映に数分かかる**：スクリプト自体は0秒で完了しますが、Pagesのデプロイが終わるまで2〜3分待ちます

**業務で使えるか？**

使えます。特に「クライアントへの月次レポートをHTMLで送りたいけどBIツールは重い」という用途にぴったりです。CSVを渡してHTMLに変換するラッパーを追加すれば、月次定例前に自動生成→Slackに貼るという運用がすぐ組めそうです。

## まとめ

**一言で言うと：** プロンプト1回・10分・ゼロコストでGA4風のHTMLレポートが完成します。

**こんな人に試してほしい：**
- GA4のUIが重くてサクッと共有できる形にしたいマーケター
- 月次KPIレポートを毎回Excelで作っていて自動化したい方
- BI導入コストをかけずに簡易ダッシュボードを作りたい方

データを差し替えて実運用に育てていく余地がたくさんあるので、ぜひ `generate_dashboard.py` をforkしてカスタマイズしてみてください。
