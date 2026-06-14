#!/usr/bin/env bash
# 乐土仙尊（其二）
# 面朝黄土背朝天，万千生灵系心间。
# 纷争难解天下事，干戈易结百年身。
# 来源：蛊真人 · 《蛊真人》全诗词整理（完整版） · kairos-dao-header
set -euo pipefail

# ─────────────────────────────────────────────
# FileLens Clean Script
# 删除本地构建产物（不碰源码与 xcodeproj）
#
# Usage:
#   ./Scripts/clean.sh
# ─────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${PROJECT_ROOT}"

ARTIFACTS=(
  .dev-build
  .release
  .test-build
  .test-update-build
  dist
  build
  DerivedData
)

echo "── Cleaning FileLens build artifacts ──"
for dir in "${ARTIFACTS[@]}"; do
  if [ -e "${dir}" ]; then
    rm -rf "${dir}"
    echo "  removed ${dir}/"
  fi
done

echo ""
echo "── Done ──"
