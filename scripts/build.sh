#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="SPlayer 菜单栏歌词"
APP_DIR="build/${APP_NAME}.app"

BUILD_ARGS=(-c "${CONFIG}")
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi

echo "==> swift build ${BUILD_ARGS[*]}"
swift build "${BUILD_ARGS[@]}"
BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/SPlayerMenuBarLyrics"

echo "==> 组装 ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/SPlayerMenuBarLyrics"
cp Support/Info.plist "${APP_DIR}/Contents/Info.plist"
cp Support/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
cp plugin/favorite-bridge.js "${APP_DIR}/Contents/Resources/favorite-bridge.js"
chmod +x "${APP_DIR}/Contents/MacOS/SPlayerMenuBarLyrics"

echo "==> ad-hoc 签名"
codesign --force --sign - --timestamp=none "${APP_DIR}" >/dev/null 2>&1 || {
    echo "签名失败（应用仍可运行，但每次启动都可能重新询问权限）" >&2
}

echo "构建完成：${APP_DIR}"
echo "运行：open \"${APP_DIR}\""
