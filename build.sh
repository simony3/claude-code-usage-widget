#!/bin/bash
# 小组件扩展必须签名才会被系统加载；默认 ad-hoc 签名，不依赖任何证书
set -euo pipefail
cd "$(dirname "$0")"
ID=${SIGN_ID:--}
xcodegen generate >/dev/null
xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Release \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E 'error:|BUILD' | grep -v DVT
APP=build/Build/Products/Release/ClaudeUsage.app
codesign -f -s $ID --options runtime --entitlements Widget/ClaudeUsageWidget.entitlements "$APP/Contents/PlugIns/ClaudeUsageWidget.appex"
codesign -f -s $ID --options runtime --entitlements App/ClaudeUsage.entitlements "$APP"
codesign --verify --deep --strict "$APP" && echo "签名通过"
if [ "${1:-}" = install ]; then
  pkill -x ClaudeUsage || true
  rm -rf /Applications/ClaudeUsage.app
  cp -R "$APP" /Applications/
  # 编译目录里的副本也会被系统登记，注销掉免得小组件列表出现重复项
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true
  pluginkit -r "$APP/Contents/PlugIns/ClaudeUsageWidget.appex" 2>/dev/null || true
  open /Applications/ClaudeUsage.app
  echo "已安装到 /Applications 并启动"
fi
