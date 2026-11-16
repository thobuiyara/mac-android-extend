#!/usr/bin/env bash
# Double-click trong Finder: tắt bản cũ, build lại và mở ExtendDisplay.app
cd "$(dirname "$0")/.."
pkill -x ExtendDisplay 2>/dev/null && sleep 1
./scripts/build-app.sh 2>&1 | tee build/last-build.log
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
  open build/ExtendDisplay.app
  echo "✅ Đã mở ExtendDisplay (biểu tượng trên menu bar)"
else
  echo "❌ Build lỗi – xem build/last-build.log"
fi
