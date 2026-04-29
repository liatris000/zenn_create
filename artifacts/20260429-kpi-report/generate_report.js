const Anthropic = require("@anthropic-ai/sdk");
const fs = require("fs");
const path = require("path");

const client = new Anthropic();

const csvData = fs.readFileSync(
  path.join(__dirname, "sample_data.csv"),
  "utf-8"
);

const prompt = `以下は2026年4月のマーケティングKPIデータ（CSV形式）です。

${csvData}

このデータを分析して、以下の条件を満たす完全なHTMLレポートを生成してください：

**要件**：
1. 単独で動作するHTMLファイル（外部CDN不使用、インラインCSS/JS）
2. ヘッダー: タイトル「2026年4月 マーケティングKPIレポート」、生成日時
3. KPIサマリーカード: 総セッション数・総CV数・平均CVR・総売上の4枚
4. チャネル別パフォーマンステーブル（週次集計）
5. 週次トレンドをチャートで可視化（SVGを使ったシンプルな折れ線グラフ）
6. インサイトセクション: データから読み取れる3つの重要な発見
7. 推奨アクションセクション: 具体的なネクストアクション2〜3件
8. デザイン: ダークネイビー基調のモダンなビジネスダッシュボード風、レスポンシブ対応

**重要**: HTMLタグの外側に説明文やコードブロック記号は一切含めず、<!DOCTYPE html>から始まり</html>で終わる完全なHTMLのみを返してください。`;

async function generateReport() {
  console.log("Claude Opus 4.7 にHTMLレポート生成を依頼中...");
  const startTime = Date.now();

  const message = await client.messages.create({
    model: "claude-opus-4-7",
    max_tokens: 16000,
    messages: [
      {
        role: "user",
        content: prompt,
      },
    ],
  });

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`生成完了: ${elapsed}秒`);

  const htmlContent = message.content[0].text;

  // Validate it starts with HTML
  const trimmed = htmlContent.trim();
  const reportPath = path.join(__dirname, "report.html");

  if (trimmed.startsWith("<!DOCTYPE") || trimmed.startsWith("<html")) {
    fs.writeFileSync(reportPath, trimmed);
    console.log(`レポート保存: ${reportPath}`);
  } else {
    // Extract HTML if wrapped in code block
    const match = trimmed.match(/```html?\n?([\s\S]+?)\n?```/);
    if (match) {
      fs.writeFileSync(reportPath, match[1]);
      console.log(`レポート保存（コードブロックから抽出）: ${reportPath}`);
    } else {
      fs.writeFileSync(reportPath, trimmed);
      console.log(`レポート保存（そのまま）: ${reportPath}`);
    }
  }

  console.log(`使用トークン: input=${message.usage.input_tokens}, output=${message.usage.output_tokens}`);
  return elapsed;
}

generateReport().catch(console.error);
