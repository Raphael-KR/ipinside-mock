#!/bin/bash
# IPinside Mock 메뉴바 앱 빌드 스크립트

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="IPinsideMock"
APP_DIR="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

echo "빌드 중..."

# 1. Swift 컴파일
swiftc -O \
    -o "/tmp/$APP_NAME" \
    -framework Cocoa \
    -framework Network \
    "$SCRIPT_DIR/IPinsideMock/main.swift"

# 2. .app 번들 구조 생성
rm -rf "$APP_DIR"
mkdir -p "$MACOS"
mkdir -p "$CONTENTS/Resources"
cp "/tmp/$APP_NAME" "$MACOS/"
cp "$SCRIPT_DIR/AppIcon.icns" "$CONTENTS/Resources/"

# 3. Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>IPinside Mock</string>
    <key>CFBundleDisplayName</key>
    <string>IPinside Mock</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.ipinside-mock</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>IPinsideMock</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

# 4. /Applications에 설치
echo "설치 중..."
cp -R "$APP_DIR" /Applications/
echo ""
echo "완료! /Applications/$APP_NAME.app 에 설치되었습니다."
echo "Spotlight 또는 Launchpad에서 'IPinside Mock'으로 실행하세요."
