#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="SPlayer 菜单栏歌词"
APP_DIR="build/${APP_NAME}.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
DMG_PATH="build/${APP_NAME} ${VERSION}.dmg"

./scripts/build.sh release

echo "==> 准备 DMG 内容"
STAGING="$(mktemp -d)"
trap 'rm -rf "${STAGING}"' EXIT
cp -R "${APP_DIR}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"
# 卷图标（SetFile 属于可选命令行工具，缺失时忽略）
if command -v SetFile >/dev/null 2>&1; then
    cp Support/AppIcon.icns "${STAGING}/.VolumeIcon.icns"
    SetFile -a C "${STAGING}" || true
fi

echo "==> 生成 ${DMG_PATH}"
rm -f "${DMG_PATH}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING}" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "${DMG_PATH}" >/dev/null

hdiutil verify "${DMG_PATH}" >/dev/null
echo "打包完成：${DMG_PATH}"
ls -lh "${DMG_PATH}"
