#!/usr/bin/env bash
# Thu thập thông tin chẩn đoán kết nối -> build/diagnose.log
cd "$(dirname "$0")/.."
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
OUT=build/diagnose.log
{
  echo "== adb version"; "$ADB" version
  echo "== which adb (PATH)"; which -a adb
  echo "== adb devices"; "$ADB" devices -l
  echo "== adb reverse --list"; "$ADB" reverse --list
  echo "== cổng 27183 đang listen trên Mac"; lsof -nP -iTCP:27183 -sTCP:LISTEN
  echo "== kết nối tới 27183"; lsof -nP -iTCP:27183
  echo "== ExtendDisplay process"; pgrep -lf ExtendDisplay
  echo "== log ExtendDisplay 10 phút gần nhất"
  log show --last 10m --style compact --predicate 'eventMessage CONTAINS "[ExtendDisplay]"' 2>/dev/null | tail -40
  echo "== app Android đang chạy?"; "$ADB" shell pidof com.thobui.extenddisplay
  echo "== logcat app Android"
  PID=$("$ADB" shell pidof com.thobui.extenddisplay | tr -d '\r')
  [ -n "$PID" ] && "$ADB" logcat -d --pid="$PID" | tail -40
  echo "== logcat lỗi gần nhất"; "$ADB" logcat -d -t 300 '*:E' | grep -iE "extenddisplay|AndroidRuntime" | tail -20
  echo "== test kết nối từ điện thoại tới Mac"
  "$ADB" shell "echo true"
} > "$OUT" 2>&1
echo "Xong, đã ghi $OUT"
