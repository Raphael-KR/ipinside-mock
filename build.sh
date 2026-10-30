#!/bin/bash
# IPinside Mock 메뉴바 앱 빌드 스크립트

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/src/main.swift"
ICON_FILE="$SCRIPT_DIR/AppIcon.icns"
APP_NAME="IPinsideMock"
OUTPUT_DIR="$SCRIPT_DIR"
INSTALL_APP=true
MACOS_SDK=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-install) INSTALL_APP=false; shift ;;
        --output-dir|--sdk)
            if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
                echo "오류: $1 에 경로가 필요합니다." >&2
                exit 2
            fi
            if [[ "$1" == --output-dir ]]; then OUTPUT_DIR="$2"; else MACOS_SDK="$2"; fi
            shift 2 ;;
        --help)
            echo "사용법: $0 [--no-install] [--output-dir 경로] [--sdk 경로]"
            exit 0 ;;
        *) echo "오류: 알 수 없는 옵션: $1" >&2; exit 2 ;;
    esac
done
mkdir -p "$OUTPUT_DIR" "$SCRIPT_DIR/build/module-cache"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

echo "빌드 중..."

if [[ ! -f "$ICON_FILE" ]]; then
    echo "아이콘 생성 중..."
    swift "$SCRIPT_DIR/generate_icon.swift"
fi

# 1. Swift 컴파일
SWIFT_OPTIONS=(-target "$(uname -m)-apple-macosx12.0" -module-cache-path "$SCRIPT_DIR/build/module-cache")
if [[ -n "$MACOS_SDK" ]]; then SWIFT_OPTIONS+=(-sdk "$MACOS_SDK"); fi
swiftc -O \
    "${SWIFT_OPTIONS[@]}" \
    -o "$SCRIPT_DIR/build/$APP_NAME" \
    -framework Cocoa \
    -framework Network \
    "$SOURCE_FILE" \
    "$SCRIPT_DIR/src/Shared/PythonServerProcess.swift" \
    "$SCRIPT_DIR/TouchEnxKey-mock/TouchEnNxKeyServer.swift"

# 2. .app 번들 구조 생성
rm -rf "$APP_DIR"
mkdir -p "$MACOS"
mkdir -p "$CONTENTS/Resources"
cp "$SCRIPT_DIR/build/$APP_NAME" "$MACOS/"
cp "$ICON_FILE" "$CONTENTS/Resources/"
cp "$SCRIPT_DIR/TouchEnxKey-mock/touchen_nxkey_server.py" "$CONTENTS/Resources/"
cp "$SCRIPT_DIR/LICENSE" "$CONTENTS/Resources/"

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
    <string>1.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
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
if [[ "$INSTALL_APP" == true ]]; then
    echo "설치 중..."
    cp -R "$APP_DIR" /Applications/
    echo "완료! /Applications/$APP_NAME.app 에 설치되었습니다."
    echo "Spotlight 또는 Launchpad에서 'IPinside Mock'으로 실행하세요."
else
    echo "빌드 완료: $APP_DIR (설치하지 않음)"
fi
