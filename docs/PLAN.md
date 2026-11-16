# Kế hoạch

Trạng thái: khung code đã có cho mọi giai đoạn, **chưa build/test trên máy thật**.

- [ ] **1. Màn hình ảo** (`VirtualDisplay.swift`): menu → "Tạo màn hình ảo thử" → System Settings › Displays hiện thêm màn hình, kéo được cửa sổ sang.
- [ ] **2. Capture** (`ScreenCapturer.swift`): nhận `CMSampleBuffer` đều khoảng 60fps khi màn hình có thay đổi.
- [ ] **3. Encode** (`VideoEncoder.swift`): H.264 phần cứng, low-latency, không B-frame, ra Annex B.
- [ ] **4. Truyền USB** (`StreamServer.swift`, `ADBManager.swift`): TCP 127.0.0.1:27183 + `adb reverse`.
- [ ] **5. Android hiển thị** (`StreamClient.kt`, `VideoDecoder.kt`): kéo cửa sổ sang màn hình ảo thì thấy trên Android. ⭐ Mốc quan trọng nhất.
- [ ] **6. Cảm ứng → chuột** (`TouchHandler.kt`, `InputInjector.swift`).
- [ ] **7. Hoàn thiện**
  - [x] Menu bar app
  - [x] Tự phát hiện thiết bị và chạy `adb reverse`
  - [x] Tự kết nối lại, xin keyframe khi kết nối lại
  - [ ] Chọn độ phân giải / bật tắt HiDPI từ menu
  - [ ] Hiển thị FPS và độ trễ
  - [ ] Chọn vị trí màn hình ảo (trái/phải) tự động

## Nếu bị lag, kiểm tra theo thứ tự
1. Encoder: đã bật RealTime và tắt B-frame chưa (xem log `VT property … lỗi`).
2. Buffer phía Android: decoder có trả frame ngay không.
3. Giảm độ phân giải hoặc bitrate.

## Xem log
- Mac: `log stream --predicate 'eventMessage CONTAINS "[ExtendDisplay]"'`
- Android: `adb logcat -s VideoDecoder`
