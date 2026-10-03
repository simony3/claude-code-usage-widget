#!/bin/bash
# Xcode 未登录 Apple 账号，自动签名不可用：先无签名编译，再用钥匙串里的 Apple Development 证书手动签
set -euo pipefail
cd "$(dirname "$0")"
ID=F5C64C7791B2645C3CD22C35F6742BE32FAA06A9
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
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP"
  pluginkit -r "$APP/Contents/PlugIns/ClaudeUsageWidget.appex" 2>/dev/null || true
  open /Applications/ClaudeUsage.app
  echo "已安装到 /Applications 并启动"
fi
