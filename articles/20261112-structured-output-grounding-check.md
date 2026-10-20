---
title: "形式は合格なのに中身が違う出力を、原文照合で弾く"
emoji: "🔎"
type: "tech"
topics: ["claudecode", "llm", "python", "validation", "ai"]
pattern: "comparison"
published: false
published_at: "2026-11-12 07:00"
---

:::message
この記事は、Claude Codeを執筆支援に使った "毎朝1本書く" 取り組みの一環で書いています。

- 目的: 自分のAI活用キャッチアップ。仕組み自体も毎月アップデートしていきます
- 体制: 題材選定・実装・下書きをClaude Codeで補助、平野が動作確認と編集を経て公開判断
- 方針: Zennのガイドラインに真摯に向き合い、運営から指摘や警告があれば即座に取り組みを停止します

仕組みの全貌は[こちらの設計記事](https://zenn.dev/liatris/articles/20260701-zenn-kickoff)にまとめています。
:::

構造化出力でスキーマを強制すると、JSON が壊れることはなくなる。ただし保証されるのは形で、値が原文に書かれているかどうかは別の話になる。型も必須項目も日付の書式も満たしたまま、原文にない会場名や金額が入ることはある。この記事では、原文から項目を抜き出した出力に対して、検査を3段階に重ねたとき何が弾けて何が残るかを、手作りのケースで数えた。

## 比べるもの

- A: スキーマ検証だけ（型・必須項目・日付の書式）
- B: A + 原文照合（抜き出した値が原文に実在するか）
- C: B + 項目間の整合（開始日 ≦ 終了日、内訳の合計 = 合計金額）

B の照合は、原文と値の両方を NFKC 正規化し、空白とカンマを除いてから部分一致で見る。日付は `2026年11月21日`・`2026/11/21`・`2026-11-21` の3表記、金額は `3,000円` と `3000円` の両方を許した。

## 検証手順

原文は2種類（勉強会の案内文と写真展の案内文）を自分で書いた。出力側は、正しい出力2件と、誤りを1か所だけ混ぜた12件を手で作った。**実際のモデル出力ではない**ので、「モデルがどのくらい間違えるか」は何も言えない。見ているのは、検査器が既知の誤りをどこで弾くかだけ。

誤りの種類は次のとおり。

- `schema`: 型違い（`"3000"` の文字列）・書式違い（`4月10日`）・null
- `invented_value`: 原文にない会場名・金額・日付・イベント名
- `order`: 終了日が開始日より前
- `sum`: 内訳の合計と合計金額が合わない
- `wrong_place_value`: 値は原文に実在するが、別の項目の値を入れている
- `paraphrase`: 意味は合っているが原文の表記と違う

検査器は Python 3.11 の標準ライブラリだけで書いた。

```python:grounding_check.py
#!/usr/bin/env python3
"""grounding_check.py: 構造化出力を A(スキーマ)/ B(+原文照合)/ C(+項目間整合)で検査する。標準ライブラリのみ。"""
import json
import re
import sys
import unicodedata
from datetime import date

SCHEMA = {
    "event": str,
    "start_date": str,
    "end_date": str,
    "venue": str,
    "fee_yen": int,
    "items": list,
    "total_yen": int,
}
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def norm(s):
    """全角半角・空白・カンマを揃える。"""
    s = unicodedata.normalize("NFKC", s)
    return re.sub(r"[\s,]", "", s)


def check_a(out):
    errs = []
    for key, typ in SCHEMA.items():
        if key not in out:
            errs.append(f"missing:{key}")
        elif not isinstance(out[key], typ) or isinstance(out[key], bool):
            errs.append(f"type:{key}")
    for key in ("start_date", "end_date"):
        if isinstance(out.get(key), str) and not DATE_RE.match(out[key]):
            errs.append(f"format:{key}")
    return errs


def date_forms(d):
    y, m, dd = (int(x) for x in d.split("-"))
    return [f"{y}年{m}月{dd}日", f"{y}/{m}/{dd}", f"{y}-{m:02d}-{dd:02d}"]


def check_b(out, source):
    errs = []
    src = norm(source)
    for key in ("event", "venue"):
        if norm(out[key]) not in src:
            errs.append(f"ungrounded:{key}")
    for key in ("start_date", "end_date"):
        if not any(norm(f) in src for f in date_forms(out[key])):
            errs.append(f"ungrounded:{key}")
    for key in ("fee_yen",):
        if not any(norm(f) in src for f in (f"{out[key]:,}円", f"{out[key]}円")):
            errs.append(f"ungrounded:{key}")
    for i, it in enumerate(out["items"]):
        if norm(it["name"]) not in src:
            errs.append(f"ungrounded:items[{i}].name")
        if not any(norm(f) in src for f in (f"{it['price_yen']:,}円", f"{it['price_yen']}円")):
            errs.append(f"ungrounded:items[{i}].price_yen")
    return errs


def check_c(out):
    errs = []
    y1, m1, d1 = (int(x) for x in out["start_date"].split("-"))
    y2, m2, d2 = (int(x) for x in out["end_date"].split("-"))
    try:
        if date(y2, m2, d2) < date(y1, m1, d1):
            errs.append("order:end_date<start_date")
    except ValueError:
        errs.append("invalid_date")
    if sum(it["price_yen"] for it in out["items"]) != out["total_yen"]:
        errs.append("sum:total_yen")
    return errs


def run(cases):
    """各ケースが A/B/C のどれで弾かれたかを返す。"""
    rows = []
    for c in cases:
        out, src = c["output"], c["source"]
        a = check_a(out)
        b = check_b(out, src) if not a else []
        cc = check_c(out) if not a else []
        rows.append({
            "id": c["id"], "kind": c["kind"],
            "A": bool(a), "B": bool(a or b), "C": bool(a or b or cc),
            "reasons": a + b + cc,
        })
    return rows


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "data/cases.json"
    with open(path, encoding="utf-8") as f:
        cases = json.load(f)
    rows = run(cases)
    for r in rows:
        mark = lambda x: "弾く" if x else "通す"
        print(f"{r['id']:<4}{r['kind']:<18}A:{mark(r['A'])} B:{mark(r['B'])} C:{mark(r['C'])}  {','.join(r['reasons'])}")
    bad = [r for r in rows if r["kind"] != "correct"]
    ok = [r for r in rows if r["kind"] == "correct"]
    print(f"\n誤り入りケース {len(bad)} 件 / 正常ケース {len(ok)} 件")
    for k in "ABC":
        print(f"{k}: 誤りを弾いた {sum(r[k] for r in bad)}/{len(bad)}, 正常を誤って弾いた {sum(r[k] for r in ok)}/{len(ok)}")
```

ケースは `data/cases.json` に配列で14件入れてある。`invented_value` の1件（会場名だけ差し替え）を抜粋する。

```json:data/cases.json
{
  "id": "c06",
  "kind": "invented_value",
  "source": "第12回データ勉強会を2026年11月21日(土)から2026年11月22日(日)まで、港南コミュニティホールで開催します。参加費は3,000円です。資料代800円、懇親会費2,200円は参加費に含まれます。",
  "output": {
    "event": "第12回データ勉強会",
    "start_date": "2026-11-21",
    "end_date": "2026-11-22",
    "venue": "港南市民センター",
    "fee_yen": 3000,
    "items": [{"name": "資料代", "price_yen": 800}, {"name": "懇親会費", "price_yen": 2200}],
    "total_yen": 3000
  }
}
```

`python3 grounding_check.py data/cases.json` で全件の判定が出る。

## 結果

| 検査 | 誤りを弾いた | 正常を誤って弾いた |
|---|---|---|
| A | 3 / 12 | 0 / 2 |
| B | 8 / 12 | 0 / 2 |
| C | 10 / 12 | 0 / 2 |

A が弾いたのは `schema` の3件だけで、`invented_value` の4件は全部通した。会場名を `港南市民センター` に差し替えた出力は、型も書式も正しいのでスキーマ上は何の問題もない。B はこの4件を `ungrounded:venue` などで弾いた。C はさらに `order` と `sum` の2件を弾いた。この2件は値が原文に実在するため B では見つからず、項目間の関係を見て初めて分かる。

残った2件は `wrong_place_value` で、C でも通った。終了日に開始日と同じ `2026-11-21` を入れた出力は、日付としては原文に実在し、順序も `≦` を満たす。懇親会費を 0 にして資料代 800 円と合わせた出力も、内訳と合計が一致してしまう。この種類は、項目ごとに「どの文脈で出てきた値か」まで見ないと拾えない。

逆方向の失敗もあった。`paraphrase` の `北館のギャラリー` は意味として正しいのに、原文の `北館ギャラリー` と部分一致しないので B が弾いた。正規化を強めれば減らせるが、緩めるほど `invented_value` を通し始める。この2つはトレードオフで、今回の件数ではどちらの閾値が良いかは決められない。14件ではそこまで言えない。

## データアナリスト視点

抽出結果を集計に流す前の検査は、ロード時の参照整合性チェックや件数突合と同じ位置にある。スキーマ検証は「列の型が合っているか」、原文照合は「元データに存在する値か」、項目間整合は「合計列が明細の和と一致するか」に対応する。そして `wrong_place_value` は、外部キーが存在するだけで正しい行を指しているとは限らない、という問題とよく似ている。検査を重ねても残る誤りを、どの段で受け持つかを決めておく必要がある。

## 手元で動かす

<!-- ARTIFACT_LINKS -->
