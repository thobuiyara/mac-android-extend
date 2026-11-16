#!/usr/bin/env bash
# Double-click trong Finder: build và cài app Android lên máy đang cắm cáp, rồi mở app.
cd "$(dirname "$0")/../../android"
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
"$ADB" reverse --remove tcp:7000 2>/dev/null
./gradlew installDebug 2>&1 | tee ../mac/build/android-build.log
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
  "$ADB" reverse tcp:27183 tcp:27183
  "$ADB" shell am start -n com.thobui.extenddisplay/.MainActivity
  echo "✅ Đã cài và mở app trên Android"
else
  echo "❌ Build Android lỗi – xem mac/build/android-build.log"
fi
