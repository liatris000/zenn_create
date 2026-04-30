#!/usr/bin/env bash
#
# session-start.sh
#
# Claude Code Web Routine の SessionStart hook で毎セッション実行される。
# 公式仕様: https://code.claude.com/docs/en/hooks#sessionstart
#
# 実行時 cwd: /home/user/zenn_create (リポジトリルート)
# - Claude Code 起動後に実行されるため cwd はリポジトリルート
# - 軽量で高速な処理だけを置く (重い処理は Routine 環境設定の Setup script 側へ)
# - ローカル開発環境では実行しない (CLAUDE_CODE_REMOTE で判定)
#

set -euo pipefail

# ローカル実行時はスキップ (公式推奨パターン)
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "════════════════════════════════════════"
echo "  zenn_create session start"
echo "════════════════════════════════════════"

# ========================================
# 1. business-profile submodule 同期
# ========================================
echo ""
echo "[1/2] business-profile submodule..."

if [ ! -f .gitmodules ]; then
  echo "  ⚠️⚠️⚠️ 致命的状態: .gitmodules が存在しません ⚠️⚠️⚠️"
  echo "      business-profile submodule が未登録のため、Day 1 の題材選定が実行できません。"
  echo "      以下のコマンドで submodule を登録してください:"
  echo ""
  echo "        git submodule add https://github.com/liatris000/liatris-business-profile.git business-profile"
  echo "        git config -f .gitmodules submodule.business-profile.branch main"
  echo "        git add .gitmodules business-profile && git commit -m \"chore: add business-profile submodule\""
  echo ""
  exit 0
fi

# 初回 init (実体未取得の場合のみ)
if [ ! -d "business-profile/.git" ] && [ ! -f "business-profile/.git" ]; then
  git submodule update --init --recursive -q || \
    echo "  ⚠️ submodule init 失敗 (セッション内で再試行可)"
fi

# main の最新に追従 (.gitmodules で branch=main 設定がある前提)
git submodule update --remote --merge business-profile -q || \
  echo "  ⚠️ submodule 更新失敗 (セッション内で再試行可)"

echo "  ✅ business-profile 同期完了"

# ========================================
# 2. 作業ディレクトリ初期化
# ========================================
echo ""
echo "[2/2] /tmp/zenn_artifact 初期化..."

rm -rf /tmp/zenn_artifact
mkdir -p /tmp/zenn_artifact/images

echo "  ✅ /tmp/zenn_artifact 用意"

echo ""
echo "✨ session start 完了"
