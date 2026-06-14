#!/usr/bin/env bash
# 挟山超海
# 负山跨海、挟昆仑越四海；用于极端负重与超距搬运（设定）。
# 来源：天罡三十六法 · https://baike.baidu.com/item/%E5%A4%A9%E7%BD%A1%E4%B8%89%E5%8D%81%E5%85%AD%E6%B3%95/60754650 · kairos-dao-header
set -euo pipefail

# ─────────────────────────────────────────────
# FileLens Pack Script
# Release 编译 + 打 DMG → dist/（不上传 GitHub/Gitee）
#
# Usage:
#   ./Scripts/pack.sh              # project.yml 版本，arm64 + x86_64
#   ./Scripts/pack.sh arm64        # 仅 arm64
#   ./Scripts/pack.sh 1.2.0 arm64  # 指定版本 + 架构
# ─────────────────────────────────────────────

APP_NAME="FileLens"
BUNDLE_ID="com.lifedever.FileLens"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${PROJECT_ROOT}/dist"

read_version() {
  grep MARKETING_VERSION "${PROJECT_ROOT}/project.yml" | head -1 | sed 's/.*"\(.*\)".*/\1/'
}

VERSION="$(read_version)"
ARCHS=(arm64 x86_64)

while [ $# -gt 0 ]; do
  case "$1" in
    arm64|x86_64) ARCHS=("$1") ;;
    all) ARCHS=(arm64 x86_64) ;;
    *) VERSION="$1" ;;
  esac
  shift
done

cd "${PROJECT_ROOT}"
mkdir -p "${DIST_DIR}"

build_arch() {
  local ARCH="$1"
  local BUILD_DIR="${PROJECT_ROOT}/.release/${ARCH}"
  local APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
  local DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-${ARCH}.dmg"

  echo ""
  echo "── Building ${ARCH} (${VERSION}) ──"
  rm -rf "${BUILD_DIR}"
  mkdir -p "${BUILD_DIR}"

  xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    -sdk macosx \
    ARCHS="${ARCH}" \
    ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="${VERSION}" \
    build \
    > "${BUILD_DIR}/build.log" 2>&1 || {
      echo "Build failed (${ARCH}). Last 30 lines:"
      tail -30 "${BUILD_DIR}/build.log"
      exit 1
    }

  [ -d "${APP_PATH}" ] || { echo "Build product missing: ${APP_PATH}" >&2; exit 1; }

  local ACTUAL_ID
  ACTUAL_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${APP_PATH}/Contents/Info.plist")
  if [ "${ACTUAL_ID}" != "${BUNDLE_ID}" ]; then
    echo "Bundle ID mismatch on ${ARCH}: expected ${BUNDLE_ID}, got ${ACTUAL_ID}" >&2
    exit 1
  fi

  echo "  Creating DMG..."
  rm -f "${DMG_PATH}"
  if command -v create-dmg >/dev/null 2>&1; then
    create-dmg \
      --volname "${APP_NAME}" \
      --window-size 500 320 \
      --icon-size 96 \
      --app-drop-link 350 160 \
      --icon "${APP_NAME}.app" 150 160 \
      "${DMG_PATH}" \
      "${APP_PATH}" >/dev/null
  else
    local STAGING="${BUILD_DIR}/dmg-staging"
    rm -rf "${STAGING}"
    mkdir -p "${STAGING}"
    cp -R "${APP_PATH}" "${STAGING}/"
    ln -s /Applications "${STAGING}/Applications"
    hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING}" \
      -ov -format UDZO "${DMG_PATH}" -quiet
  fi
  echo "  ✓ ${DMG_PATH} ($(du -h "${DMG_PATH}" | cut -f1))"
}

echo "══════════════════════════════════════════"
echo "  ${APP_NAME} Pack v${VERSION}"
echo "══════════════════════════════════════════"

for ARCH in "${ARCHS[@]}"; do
  build_arch "${ARCH}"
done

echo ""
echo "Done: ${DIST_DIR}/${APP_NAME}-${VERSION}-*.dmg"
