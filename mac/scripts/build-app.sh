#!/usr/bin/env bash
# Build và đóng gói thành ExtendDisplay.app (cần bundle để macOS cấp quyền Screen Recording / Accessibility).
# Đặt SIGN_IDENTITY="Apple Development: ..." để quyền không bị reset mỗi lần build (ký ad-hoc "-" sẽ bị reset).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/ExtendDisplay.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ExtendDisplay "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "✅ $APP"
echo "Chạy: open $APP"
