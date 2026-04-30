# CSV → マーケレポート HTML ダッシュボード

Claude Code が生成した、CSVデータから1コマンドでHTMLダッシュボードを作るスクリプトです。

## デモ

`index.html` をブラウザで開くと、Chart.js によるインタラクティブなダッシュボードが表示されます。

## ファイル構成

```
.
├── README.md
├── sample_data.csv          # サンプルデータ（月次マーケ指標）
├── generate_dashboard.py    # HTMLジェネレーター（Claude Code生成）
└── index.html               # 生成済みダッシュボード
```

## 使い方

```bash
# 依存なし（Python 標準ライブラリのみ）
python3 generate_dashboard.py
# → index.html が生成される
```

自分の CSV に置き換える場合は `sample_data.csv` の列名を合わせてください：

```
month,pv,sessions,cv,cv_rate,cost,cpa
```

## カスタマイズ

`generate_dashboard.py` 内の `build_dashboard()` 関数を編集するだけです。

- KPI カードの追加/削除
- グラフの種類変更（bar / line / doughnut）
- カラーテーマの変更（`:root` の CSS 変数）

## 所要時間

Claude Code との対話を含め **約8分** で完成しました。

## 注意

`sample_data.csv` のデータはデモ用のフィクションです。実際の数値ではありません。

## 関連記事

- Zenn 記事: https://zenn.dev/liatris（公開後にURLを追記）
