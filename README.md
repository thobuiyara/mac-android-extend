# mac-android-extend

Biến máy Android thành **màn hình mở rộng (extend)** cho Mac qua cáp USB. Giống spacedesk, nhưng tự làm để dùng cá nhân.

```
Mac: CGVirtualDisplay → ScreenCaptureKit → VideoToolbox (H.264) → TCP 127.0.0.1:27183
                                                                       │ adb reverse (USB)
Android: localhost:27183 → MediaCodec → SurfaceView      cảm ứng → INPUT → CGEvent (chuột)
```

## Cấu trúc

```
mac/       App menu bar (Swift Package, macOS 13+)
  Sources/CGVirtualDisplayPrivate/   khai báo private API màn hình ảo
  Sources/ExtendDisplay/             VirtualDisplay, ScreenCapturer, VideoEncoder,
                                     StreamServer, InputInjector, ADBManager, AppController
  scripts/build-app.sh               build + đóng gói .app
android/   App Android (Kotlin, minSdk 26, không dùng thư viện ngoài)
docs/      PLAN.md (kế hoạch theo giai đoạn), PROTOCOL.md (định dạng gói tin)
```

## Chuẩn bị

```bash
brew install android-platform-tools   # adb
```
Trên Android: bật **Developer options → USB debugging**, cắm cáp và chấp nhận máy Mac.

## Chạy

**1. App Mac**
```bash
cd mac
./scripts/build-app.sh
open build/ExtendDisplay.app
```
- Lần đầu macOS sẽ xin quyền **Screen Recording** và **Accessibility**: cấp cho `ExtendDisplay` rồi mở lại app.
- Ký ad-hoc thì mỗi lần build lại quyền sẽ bị reset. Để tránh, ký bằng chứng chỉ Apple Development:
  `SIGN_IDENTITY="Apple Development: <tên>" ./scripts/build-app.sh`
- Test giai đoạn 1 không cần Android: menu bar → **Tạo màn hình ảo thử**.
- Muốn sửa code bằng Xcode: `open Package.swift`.

**2. App Android**
- Trong Android Studio chọn **File → Open** và chọn đúng thư mục `android/` (không mở thư mục gốc `mac-android-extend`). Sync xong thì Run lên máy.
- Hoặc build bằng dòng lệnh: `cd android && ./gradlew installDebug`
- App Mac tự chạy `adb reverse tcp:27183 tcp:27183` khi thấy máy cắm vào. Làm tay nếu cần:
  `adb reverse tcp:27183 tcp:27183`

Khi Android kết nối, nó gửi kích thước màn hình; Mac tạo màn hình ảo đúng kích thước đó và bắt đầu stream.
Rút cáp hoặc tắt app thì màn hình ảo tự gỡ, cửa sổ quay về màn hình chính.

## Thao tác chạm

| Cử chỉ | Trên Mac |
|---|---|
| Chạm nhanh | Click trái |
| Giữ 500ms | Click phải |
| Một ngón kéo | Cuộn (khi đang zoom: pan màn hình phóng to) |
| Hai ngón kéo | Cuộn |
| Hai ngón chụm / mở | Zoom 1×–4× (chỉ trên Android) |

## Lưu ý
- `CGVirtualDisplay` là private API, có thể hỏng sau khi cập nhật macOS. Khi đó chỉ cần sửa `Sources/CGVirtualDisplayPrivate`.
- Bản này dùng HiDPI (1 point = 2 pixel). Muốn không gian rộng hơn thì đặt `hiDPI: false` trong `VirtualDisplay.create`.
- Bitrate mặc định 20 Mbps, chỉnh trong `VideoEncoder`.
