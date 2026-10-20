#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="SPlayer Menu Bar Lyrics"
APP_DIR="build/${APP_NAME}.app"

SLICES=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  # 分别构建再 lipo 合并。多 --arch 会让 SwiftPM 切到 Xcode 构建后端，
  # 旧版 Xcode（如 16.4）在该路径上会报 SWIFT_VERSION 错误。
  for arch in arm64 x86_64; do
    echo "==> swift build -c ${CONFIG} --arch ${arch}"
    swift build -c "${CONFIG}" --arch "${arch}"
    SLICES+=("$(swift build -c "${CONFIG}" --arch "${arch}" --show-bin-path)/SPlayerMenuBarLyrics")
  done
else
  echo "==> swift build -c ${CONFIG}"
  swift build -c "${CONFIG}"
  SLICES+=("$(swift build -c "${CONFIG}" --show-bin-path)/SPlayerMenuBarLyrics")
fi

echo "==> 组装 ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  lipo -create "${SLICES[@]}" -output "${APP_DIR}/Contents/MacOS/SPlayerMenuBarLyrics"
else
  cp "${SLICES[0]}" "${APP_DIR}/Contents/MacOS/SPlayerMenuBarLyrics"
fi
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
