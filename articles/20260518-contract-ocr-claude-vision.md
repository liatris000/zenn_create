---
title: "Claude Vision で契約書フォームを自動解析する"
emoji: "📋"
type: "tech"
topics: ["claude", "python", "ocr", "ai"]
pattern: "implementation"
published: false
published_at: "2026-05-25 07:00"
cover_image: https://raw.githubusercontent.com/liatris000/zenn_create/main/images/20260518-contract-ocr-claude-vision_thumbnail.png
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事(note)](https://note.com/liatris000)にまとめています。
:::

## なぜこれを作ったか

紙の契約書をスキャンして手入力するフローは、転記ミスが起きやすい上に単純作業として時間を食う。Claude の Vision 機能を使えば、スキャン画像から記入済みフィールドを読み取り、そのまま構造化データとして出力できる。

この記事では、Python から Claude API を呼んで「画像 → JSON」の変換パイプラインを動かすところまでを実装する。

## アーキテクチャ

<!-- Day 2 で Mermaid フロー図を追加 -->

入力画像(PDF 変換 or スキャン JPEG) を base64 エンコードし、Claude Vision API に渡す。レスポンスは自然言語テキストだが、JSON 出力を明示的に指示することで pydantic モデルに落とし込める。

```
画像ファイル → base64 エンコード → Claude API (claude-sonnet-4-6)
  → JSON テキスト → pydantic モデル → CSV / DB 書き込み
```

## 実装

### 1. 環境準備

<!-- Day 2 で requirements.txt + セットアップ手順を記載 -->

使用ライブラリ: `anthropic`, `pydantic`, `Pillow`

### 2. 画像の前処理

スキャン画像の向きや解像度が揃っていないと OCR 精度が落ちる。Pillow で回転補正とリサイズを行い、base64 に変換する。

<!-- Day 2 で前処理コードを追加 -->

### 3. プロンプト設計

「空欄を埋める」ではなく「記入済みの値を読み取る」ことをシステムプロンプトで明確にする。フィールド名のリストを渡し、不明な項目には `null` を返すよう指示する設計にした。

<!-- Day 2 でプロンプトコードを追加 -->

### 4. Claude API 呼び出し

<!-- Day 2 で完全な Python コードを追加 -->

レスポンスに JSON スキーマを強制するため、tool_use の仕組みを使う方法と、単純にプロンプトで `output: JSON only` と指示する方法の 2 案を試した。後者の方が実装がシンプルで、精度も遜色なかった。

### 5. pydantic でバリデーション

<!-- Day 2 でコードを追加 -->

Claude の出力テキストを JSON パースした後、pydantic モデルでバリデーションを通す。型エラーが出た行は別ファイルに退避して手動確認フローに回す。

## データアナリスト視点

OCR で抽出した文字列を構造化するプロセスは、生ログを集計前に正規化する ETL 工程と同じ発想をしている。どの列が信頼できるか、どの列は人手確認が必要かをスキーマ定義の段階で決めておかないと、後段のクエリで毎回 CASE 式が増えていく。pydantic のバリデーションエラーを「要確認フラグ」として DB に保持する設計は、データ基盤の null 扱いポリシーそのものだ。

## 成果物

<!-- Day 2 で GitHub リポジトリ URL とスクリーンショットを追加 -->

動くコードは GitHub で公開予定。サンプル画像(公開可能なフォーマット)と出力 JSON の例も合わせて掲載する。
