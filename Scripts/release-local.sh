#!/usr/bin/env bash
# 起死回生
# 起死人、肉白骨；使亡者魂归其身，用于逆转生死。
# 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
set -euo pipefail

# 从 project.yml 读取版本并调用 release.sh（供 VS Code Task 使用）

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(grep MARKETING_VERSION "${ROOT}/project.yml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
exec "${ROOT}/Scripts/release.sh" "${VERSION}"
