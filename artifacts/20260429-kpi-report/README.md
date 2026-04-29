# Claude Opus 4.7 × Anthropic SDK — マーケティングKPIレポート自動生成

Zenn記事「Claude Opus 4.7でマーケKPIレポートを自動HTML生成してみた」の成果物リポジトリです。

## デモ

👉 **[HTMLレポートをブラウザで見る](https://liatris000.github.io/liatris-20260429-kpi-report/report.html)**

## 使い方

```bash
npm install @anthropic-ai/sdk

# ANTHROPIC_API_KEY を環境変数にセット
export ANTHROPIC_API_KEY="sk-ant-..."

# CSVデータを用意して実行
node generate_report.js
# → report.html が生成されます
```

## ファイル構成

| ファイル | 内容 |
|---|---|
| `generate_report.js` | Claude Opus 4.7 API呼び出しスクリプト |
| `sample_data.csv` | サンプルKPIデータ（週次・チャネル別） |
| `report.html` | 生成されたHTMLレポート（デモ用） |

## カスタマイズ

`generate_report.js` のプロンプト部分を書き換えることで、自社のKPI定義や出力フォーマットに合わせられます。

```js
const prompt = `以下のCSVデータを分析して...`;
```

## 関連記事

- Zenn記事: https://zenn.dev/liatris/articles/20260429-kpi-report
- 設計記事(note): https://note.com/liatris000
