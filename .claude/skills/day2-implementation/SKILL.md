---
name: day2-implementation
description: Zenn 記事生成の Day 2(火曜朝)の作業手順。前日の WIP PR を見つけて実装を進め、文章を整え、同 PR に追記コミットする。火曜の Routine 起動時、Day 1 の続きを進める時に発動する。
---

# Day 2: 実装と推敲

3 日サイクルの中日。Day 1 で立てた実装方針を実コードに落とし込み、文章を整える。

## 前提

- 月曜の Day 1 で WIP 状態の PR が作成されている
- PR タイトルに `[Day 1/3 WIP]` が含まれている

## 作業手順

### Step 1: 前日の PR を探す

```bash
cd ~/zenn_create
git pull origin main -q

# Day 1 で作成された [Day 1/3 WIP] PR を PR タイトルで検索
# (Routine 環境では Claude Code が自動的に claude/* ブランチを切るため、
#  ブランチ名前提の検索ではなく PR タイトル前提の検索にする)
PR_INFO=$(gh pr list --state open --search '"[Day 1/3 WIP]" in:title' --json number,headRefName,url --limit 1)
PR_NUMBER=$(echo "${PR_INFO}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d[0]['number'] if d else '')")
LATEST_BRANCH=$(echo "${PR_INFO}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d[0]['headRefName'] if d else '')")
PR_URL=$(echo "${PR_INFO}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d[0]['url'] if d else '')")
export PR_URL
```

PR が見つからない場合(月曜サボった、Liatris が火曜朝に PR を close した等):

- **何もせず終了する**(その週は中止)
- Chatwork に「Day 2: 対象 PR が見つからないためスキップ」と通知

**対象 PR が無いときは、commit も PR 作成もしない。**
SessionStart hook（`scripts/session-start.sh`）が submodule を同期するため、
何もしないつもりでも作業ツリーに差分が出ていることがある。それを拾って
commit / PR 化しないこと。

> 2026-08-11 に Day 2 が対象 PR 不在の状況で submodule pointer だけの PR（#66）を作り、
> しかもその pointer が古いままだったため巻き戻しになりかけた。

差分が出ている場合は `git checkout -- .` で捨ててから終了する。


### 承認の判定: PR が open であること = 題材承認済み ⚠️ 必読

`docs/cycle-overview.md` の定義どおり、Liatris の承認は **無反応で表される**。

| PR の状態 | 意味 |
|---|---|
| open のまま | **題材は承認済み**。そのまま Day 2 を進める |
| close されている | その週は中止(上の検索でヒットしないので自動的にそうなる) |

**PR 本文のチェックボックスが未チェックであることを停止理由にしてはならない。**
`⚠️ disclosure: careful` の表示も同様で、これは Liatris がレビューするときの注意喚起であって
ルーティンのゲートではない。

> 2026-08 に Day 2 と Day 3 の両方がこれをゲートと解釈して停止し、
> その PR が open のまま残ったため Day 1 も新サイクルを開始できず、
> 3 週にわたってサイクルが止まった。

### 停止してよい条件(これ以外で止まらない)

1. 対象 PR が見つからない(close / merge 済み)
2. 実装が 3 回試して動かない
3. Step 4 の成果物リポジトリ公開が非ゼロ終了した

いずれの場合も **PR にコメントを残してから**停止する。
逆に、停止すると判断したなら記事本文の push もしない。
「停止した」と報告しながら作業を続けるのは禁止(2026-08-04 に実際に発生し、
Day 3 が不整合として検出した)。

### Step 2: PR の状態確認

```bash
git checkout "${LATEST_BRANCH}"
git pull origin "${LATEST_BRANCH}" -q
```

PR タイトルが `[Day 1/3 WIP]` であることを確認。
そうでなければ予期しない状態 → Liatris に確認。

### Step 3: 実装(コードレベル)

Day 1 で決めた実装方針に従って、`/tmp/zenn_artifact/` で実コードを書く。

- 動作確認まで完了させる
- HTML 系なら GitHub Pages 用にビルドできる状態に
- スクリプト系なら実行サンプルを用意

### 重要: `.claude/` 配下のファイル配置について

成果物リポジトリの `.claude/mcp.json` 等、最終的に `.claude/` 配下に配置したいファイルは、`/tmp/zenn_artifact/.claude/` ではなく **`/tmp/zenn_artifact/_claude_template/`** に書くこと。

**理由**: Claude Code は `.claude/` 配下への書き込み時に確認ダイアログを出す仕様(v2.1.121 以降固定)。Routine 自動起動では人間が応答できないため詰まる。

**フロー**:
1. Claude は `/tmp/zenn_artifact/_claude_template/mcp.json` 等を書く
2. `scripts/publish-artifact.sh` が push 直前に `_claude_template/` を `.claude/` に自動展開
3. 公開された成果物リポジトリには `.claude/mcp.json` として正しく配置される

**例**:

```bash
# ❌ NG: Claude Code がダイアログで止まる
cat > /tmp/zenn_artifact/.claude/mcp.json <<EOF
{ ... }
EOF

# ✅ OK: 普通のディレクトリ名
mkdir -p /tmp/zenn_artifact/_claude_template
cat > /tmp/zenn_artifact/_claude_template/mcp.json <<EOF
{ ... }
EOF
```

`.claude/` 以外のファイル(README.md, components/*.tsx 等)は通常通り `/tmp/zenn_artifact/` 直下に書いて OK。

### Step 4: 記事本文の追記

**成果物リポジトリの公開より先に本文を書く**(2026-08-18 に順序を入れ替えた)。
以前は公開が先で、失敗すると本文を書かずに停止していた。その結果 2026-08-18 に
公開経路が塞がれただけでその週の記事が丸ごと消えた。本文が先にあれば、公開が
失敗しても Day 3 が引き継いで再試行できる。

#### Step 4.0: 冒頭メッセージブロックの挿入

本文を書き始める前に、`templates/article-header.md`(Zenn ガイドライン準拠の冒頭メッセージブロック: Claude Code 補助で書いていることの開示・運営からの指摘で停止する方針・設計記事へのリンク)を frontmatter 直後に必ず差し込む。`{{DESIGN_ARTICLE_URL}}` は環境変数 `DESIGN_ARTICLE_URL` で置換する。

```bash
# DESIGN_ARTICLE_URL が未設定の場合のフォールバック
DESIGN_URL="${DESIGN_ARTICLE_URL:-https://zenn.dev/liatris/articles/20260701-zenn-kickoff}"

# テンプレを置換した結果を変数に格納
HEADER_BLOCK=$(sed "s|{{DESIGN_ARTICLE_URL}}|${DESIGN_URL}|g" templates/article-header.md)

# frontmatter (--- で挟まれた区間) の直後に挿入
# python ワンライナーで安全に処理する (macOS / Linux 両対応)
python3 - "${HEADER_BLOCK}" "articles/${ARTICLE_SLUG}.md" <<'PY'
import sys, re
header_block, article_path = sys.argv[1], sys.argv[2]

with open(article_path, 'r', encoding='utf-8') as f:
    content = f.read()

# frontmatter (--- で挟まれた最初の区間) を抽出
m = re.match(r'^(---\n.*?\n---\n)', content, re.DOTALL)
if not m:
    print("ERROR: frontmatter が見つかりません", file=sys.stderr)
    sys.exit(1)

frontmatter = m.group(1)
body = content[len(frontmatter):]

# 既に冒頭ブロックがある場合はスキップ (二重挿入防止)
if ':::message' in body[:500] and 'Claude Code' in body[:500]:
    print("INFO: 冒頭ブロックは既に挿入済み、スキップ")
    sys.exit(0)

# frontmatter + 空行 + 冒頭ブロック + 空行 + 既存本文
new_content = frontmatter + '\n' + header_block.rstrip() + '\n\n' + body.lstrip()

with open(article_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("✅ 冒頭ブロックを挿入しました")
PY
```

挿入後、本文の追記に進む。

#### Step 4.1: 本文追記

`articles/${ARTICLE_SLUG}.md` に本文を書く:

- リード(なぜこの題材か、何を作ったか)
- 実装の各 Step
- 成果物の埋め込み欄。この時点では成果物リポジトリがまだ存在しないので、
  **次の 1 行をそのまま置く**(Step 6.1 が実 URL に置換する):

  ```
  <!-- ARTIFACT_LINKS -->
  ```

- 感想(良かった点・惜しかった点・業務での活用イメージ)
- まとめ

文体は `.claude/skills/article-writing/SKILL.md` を厳守。

### Step 5: PR タイトル更新と追記コミット

**ここまで来たらその週は死なない。** 成果物公開より前にタイトルを `[Day 2/3 WIP]` へ
変えておくことで、以降のステップが失敗しても翌日の Day 3 が PR を見つけられる
(Day 3 の Step 0 は `"[Day 2/3 WIP]" in:title` で検索するため、タイトルが
`[Day 1/3 WIP]` のままだと空振りして週が消える)。

PR タイトルを `[Day 2/3 WIP]` に変更:

```bash
gh pr edit "${PR_URL}" --title "[Day 2/3 WIP] ${ARTICLE_TITLE}"
```

追記コミット + push:

```bash
git add articles/${ARTICLE_SLUG}.md
git commit -m "Day 2: 実装と本文執筆"
git push origin "${LATEST_BRANCH}"
```

### Step 6: 成果物リポジトリの公開

**スクリプトは 1 回だけ実行する**。内部で GitHub Actions を起動して完了まで待つため、
二重に呼ぶと push が 2 本走って待ち時間も倍になる。

```bash
set +e
PUBLISH_LOG=$(./scripts/publish-artifact.sh "${REPO_NAME}" "/tmp/zenn_artifact" "${ARTICLE_TITLE}" 2>&1)
PUBLISH_RC=$?
set -e
echo "${PUBLISH_LOG}"
eval "$(printf '%s' "${PUBLISH_LOG}" | grep -E '^(REPO_URL|PAGES_URL)=')"
export REPO_URL PAGES_URL
```

#### 仕組み(2026-08-18 変更)

routine セッションからは GitHub API 経由で Actions を起動できない。

- `POST /user/repos` は 2026-05-05 を最後に通らなくなった
- 代替に据えた `repository_dispatch` も 2026-08-18 に
  `repository_dispatch is not permitted for this session type.` (403) で拒否された。
  「エージェントに CI を起動させない」という名指しのポリシーなので、
  **別の dispatch endpoint に替えても再発しうる**

そこで起動を API から git に寄せた。スクリプトが使う GitHub 操作は
**git push / git ls-remote / git fetch だけ**で、GitHub API を一切叩かない:

1. 一時ブランチ `artifact/<repo-name>` を **main 起点**で作り、成果物を `_artifact/` に置いて push
   (main 起点なのは、push イベントのワークフローが「押されたブランチ側のファイル」で
   動くため。成果物だけの孤立ブランチではワークフローが載っておらず起動しない)
2. `.github/workflows/publish-artifact.yml` が push で起動し、PAT で新規リポジトリを
   作成・push・Pages 有効化し、一時ブランチを削除する
3. Actions が結果を `artifact-result/<repo-name>` ブランチへ書き戻す
4. スクリプトが `git ls-remote` でそれを polling して成否を判定し、読んだら削除する

#### Step 6.1: 成功したら成果物リンクを本文に差し込む

Step 4 で置いた `<!-- ARTIFACT_LINKS -->` を実 URL に置換する。

```bash
if [ "${PUBLISH_RC}" -eq 0 ] && [ -n "${REPO_URL}" ]; then
  python3 - "articles/${ARTICLE_SLUG}.md" "${REPO_URL}" "${PAGES_URL:-}" <<'PYLINK'
import sys
path, repo_url, pages_url = sys.argv[1], sys.argv[2], sys.argv[3]
block = "@[github](%s)" % repo_url
if pages_url:
    block += "\n\nデモ: %s" % pages_url
src = open(path, encoding="utf-8").read()
if "<!-- ARTIFACT_LINKS -->" not in src:
    print("WARN: プレースホルダが見つかりません。手で差し込んでください", file=sys.stderr)
    sys.exit(0)
open(path, "w", encoding="utf-8").write(src.replace("<!-- ARTIFACT_LINKS -->", block))
print("成果物リンクを差し込みました")
PYLINK
  git add "articles/${ARTICLE_SLUG}.md"
  git commit -m "Day 2: 成果物リポジトリのリンクを追加"
  git push origin "${LATEST_BRANCH}"
fi
```

#### 失敗したときの扱い(2026-08-18 変更)

**記事本文と PR タイトルは Step 4/5 で既に確定している**ので、公開失敗で週を落とさない。
ただし「成果物が無いのに完了扱い」も禁止(2026-08-04 に実際に発生し、Day 3 で
不整合として検出された)。両立させるため、失敗したら **PR に明示コメントを残す**:

```bash
if [ "${PUBLISH_RC}" -ne 0 ]; then
  {
    echo '## ⚠️ 成果物リポジトリ公開が未完了です'
    echo
    echo '記事本文と PR タイトルは Day 2 として確定済みですが、Step 6(成果物リポジトリ公開)が'
    echo '失敗しました。本文の `<!-- ARTIFACT_LINKS -->` は未置換のまま残っています。'
    echo
    echo "- 想定リポジトリ名: \`${REPO_NAME}\`"
    echo '- 成果物の所在: このセッションの `/tmp/zenn_artifact`(セッション終了で消えます)'
    echo
    echo '```'
    printf '%s\n' "${PUBLISH_LOG}"
    echo '```'
    echo
    echo '**Day 3 はこれを検出して再試行してください。**'
  } > /tmp/publish_failure.md
  gh pr comment "${PR_URL}" --body-file /tmp/publish_failure.md
fi
```

このコメントの見出し `## ⚠️ 成果物リポジトリ公開が未完了です` は Day 3 が
検出マーカーとして使うので、文言を変えるときは
`.claude/skills/day3-finalize/SKILL.md` の Step 6.3 も合わせて直すこと。

### Step 7: Chatwork 通知(翌朝チェック依頼)

```bash
./scripts/notify-chatwork.sh \
  "Day 2 完了: ${ARTICLE_TOPIC}" \
  "${ARTICLE_TITLE}" \
  "$(wc -m < articles/${ARTICLE_SLUG}.md | tr -d ' ')" \
  "未定 (来週月曜公開予定)" \
  "${PAGES_URL:-}" \
  "${REPO_URL:-(公開未完了)}" \
  "${PR_URL}"
```

成果物公開が失敗している場合(`PUBLISH_RC` が非 0)は `REPO_URL` / `PAGES_URL` が
未定義なので、上記のとおり必ずデフォルト値付きで展開する。

通知本文に「明朝 Day 3 進行前にチェックお願いします」を含める。
公開が未完了なら「成果物公開は未完了。Day 3 が再試行します」も添える。

### Step 8: 完了報告

成果物公開の成否で報告を出し分ける。**未完了を「完了」と書かない**。

成功時:

```
Day 2 完了 (PR: ${PR_URL}, 文字数: ${WORD_COUNT}字)
成果物: ${REPO_URL}
明朝出社前にチェックお願いします。
明日 Day 3 で完成させます。
```

成果物公開が失敗した場合:

```
Day 2 完了 / 成果物公開のみ未完了 (PR: ${PR_URL}, 文字数: ${WORD_COUNT}字)
記事本文と PR タイトル([Day 2/3 WIP])は確定済みです。
成果物リポジトリの公開に失敗したため、PR にエラー内容をコメントしました。
明日 Day 3 が再試行します。
```

## 中断時の挙動

- Day 1 の PR が存在しない → 何もせず終了(その週中止)
- 実装が動かない → 3 回試して失敗ならコメント追記して停止、Liatris 判断を仰ぐ
- 既に Ready for Review 状態(Day 3 完了済み)→ 何もせず終了
- **成果物リポジトリの公開が失敗した → 停止しない**。本文と PR タイトルは Step 4/5 で
  確定済みなので、Step 6 の失敗コメントを残して Step 7/8 まで進む(2026-08-18 変更)

## 絶対 NG(Day 2 特有)

- 新規 PR を作らない(Day 1 の PR に追記する)
- main への直 push 禁止
- 業務コンテクストを記事本文に出さない
- スクリプト失敗で main にマージしない
- **成果物リポジトリの公開失敗を黙って「Day 2 完了」と報告しない**(2026-08-04 に発生)。
  失敗したら PR コメントと完了報告の両方で未完了であることを明示する
- **CI / ワークフロー / スクリプトの変更を記事 PR に混ぜない**(2026-08-18 に発生)。
  仕組み側を直す必要が出たら、記事 PR とは別のブランチで PR を立てる
