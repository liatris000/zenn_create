#!/usr/bin/env bash
#
# setup-claude-code.sh
#
# Claude Code Web のセッション開始時に呼ばれるセットアップスクリプト。
# zenn_create リポジトリと business-profile (submodule) を最新状態にし、
# Routine A/B/C が稼働できる前提を整える。
#
# 環境変数:
#   GITHUB_TOKEN  必須 (clone, push, submodule の Private リポ取得に使用)
#
# 想定実行環境:
#   Claude Code Web のサンドボックス (Linux, bash 5系)
#

set -euo pipefail

ZENN_REPO_DIR="${HOME}/zenn_create"
SUBMODULE_PATH="business-profile"

echo ""
echo "========================================"
echo " zenn_create setup"
echo "========================================"

# ========================================
# 1. 環境変数チェック
# ========================================
echo ""
echo "[1/5] 環境変数チェック..."

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "  ⚠️ GITHUB_TOKEN 未設定。Private 操作 (clone/push/submodule) はスキップされる可能性"
else
  echo "  ✅ GITHUB_TOKEN 検出"
fi

# ========================================
# 2. Git 設定 (Private リポジトリへのトークン認証)
# ========================================
echo ""
echo "[2/5] Git 設定..."

if [ -n "${GITHUB_TOKEN:-}" ]; then
  # Private リポ (zenn_create / business-profile submodule) にトークン認証で
  # 透過アクセスするための url.insteadOf 設定
  git config --global url."https://${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
  echo "  ✅ url.insteadOf 設定完了 (https://github.com/ → トークン付き URL)"
else
  echo "  ⏭️  GITHUB_TOKEN なしのため url.insteadOf 設定スキップ"
fi

# ========================================
# 3. zenn_create リポジトリ準備
# ========================================
echo ""
echo "[3/5] zenn_create リポジトリ準備..."

if [ -d "${ZENN_REPO_DIR}/.git" ]; then
  cd "${ZENN_REPO_DIR}"
  git fetch origin main -q || echo "  ⚠️ fetch 失敗 (セッション内で再試行可)"
  git checkout main -q || true
  git pull origin main -q || echo "  ⚠️ pull 失敗 (セッション内で再試行可)"
  echo "  ✅ 既存リポジトリを更新"
elif [ -n "${GITHUB_TOKEN:-}" ]; then
  git clone -q "https://${GITHUB_TOKEN}@github.com/liatris000/zenn_create.git" "${ZENN_REPO_DIR}"
  cd "${ZENN_REPO_DIR}"
  echo "  ✅ リポジトリ clone 完了"
else
  echo "  ⚠️ GITHUB_TOKEN 未設定かつ clone なし。セッション内で対応してください"
  exit 0
fi

# ========================================
# 4. business-profile submodule 同期
# ========================================
echo ""
echo "[4/5] business-profile submodule 同期..."

if [ ! -f "${ZENN_REPO_DIR}/.gitmodules" ]; then
  echo "  ⚠️⚠️⚠️ 致命的状態: .gitmodules が存在しません ⚠️⚠️⚠️"
  echo "      business-profile submodule が未登録のため、Day 1 の題材選定が実行できません。"
  echo "      Liatris は以下のコマンドで submodule を登録してください:"
  echo ""
  echo "        git submodule add https://github.com/liatris000/liatris-business-profile.git ${SUBMODULE_PATH}"
  echo "        git config -f .gitmodules submodule.${SUBMODULE_PATH}.branch main"
  echo "        git add .gitmodules ${SUBMODULE_PATH} && git commit -m \"chore: add business-profile submodule\""
  echo ""
  echo "      登録なしでは Day 1 / Day 2 / Day 3 の skill が起動条件を満たしません。"
elif [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "  ⚠️ GITHUB_TOKEN 未設定のため submodule 同期スキップ (セッション内で再試行可)"
else
  # 初回 init (実体未取得の場合のみ)
  if [ ! -d "${ZENN_REPO_DIR}/${SUBMODULE_PATH}/.git" ] && [ ! -f "${ZENN_REPO_DIR}/${SUBMODULE_PATH}/.git" ]; then
    git submodule update --init --recursive -q || \
      echo "  ⚠️ submodule init 失敗 (セッション内で再試行可)"
  fi

  # main の最新に追従 (.gitmodules で branch=main 設定がある前提)
  git submodule update --remote --merge "${SUBMODULE_PATH}" -q || \
    echo "  ⚠️ submodule 更新失敗 (セッション内で再試行可)"

  echo "  ✅ business-profile 同期完了"
fi

# ========================================
# 5. 完了
# ========================================
echo ""
echo "[5/5] セットアップ完了"
echo ""
