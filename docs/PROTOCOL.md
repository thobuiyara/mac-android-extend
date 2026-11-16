# Giao thức

Mọi số nguyên là **big-endian**. Mỗi gói:

```
[type: u8][length: u32][pts: i64 (micro giây)][payload: length byte]
```
Header = 13 byte.

| Type | Giá trị | Hướng | Payload |
|---|---|---|---|
| HELLO | 1 | Android → Mac | `width u32, height u32, dpi u32` (pixel, hướng ngang) |
| CONFIG | 2 | Mac → Android | SPS + PPS dạng Annex B (`00 00 00 01 …`) |
| FRAME | 3 | Mac → Android | Một frame H.264 Annex B |
| INPUT | 4 | Android → Mac | `action u8, x f32, y f32, dx f32, dy f32` |
| KEYFRAME_REQ | 5 | Android → Mac | (rỗng) |

**INPUT action:** 0 = down, 1 = move, 2 = up, 3 = scroll, 4 = right click.
`x`, `y` chuẩn hoá trong 0..1 theo màn hình Android. `dx`, `dy` là pixel, chỉ dùng cho scroll.

## Luồng

1. Android kết nối `127.0.0.1:27183` (qua `adb reverse`) rồi gửi `HELLO`.
2. Mac tạo màn hình ảo, bắt đầu capture và encode. Frame đầu tiên là keyframe: gửi `CONFIG` rồi `FRAME`.
3. Mỗi keyframe đều có `CONFIG` đi trước.
4. Mạng nghẽn: Mac bỏ P-frame và tự ép keyframe. Decoder Android lỗi: gửi `KEYFRAME_REQ`.
5. Mất kết nối: Mac gỡ màn hình ảo. Android thử kết nối lại mỗi giây.
