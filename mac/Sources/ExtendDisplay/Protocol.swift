import Foundation

// Gói tin: [type 1B][length 4B BE][pts 8B BE][payload]
enum PacketType: UInt8 {
    case hello = 1           // Android -> Mac: width, height, dpi (3 x UInt32)
    case config = 2          // Mac -> Android: SPS/PPS (Annex B)
    case frame = 3           // Mac -> Android: 1 frame H.264 (Annex B)
    case input = 4           // Android -> Mac: sự kiện chạm
    case keyframeRequest = 5 // Android -> Mac: xin keyframe
}

struct Packet {
    static let headerSize = 13
    let type: PacketType
    let pts: Int64
    let payload: Data

    func encoded() -> Data {
        var d = Data(capacity: Packet.headerSize + payload.count)
        d.append(type.rawValue)
        d.appendBE(UInt32(payload.count))
        d.appendBE(UInt64(bitPattern: pts))
        d.append(payload)
        return d
    }
}

struct Hello {
    let width: Int
    let height: Int
    let dpi: Int

    init?(_ p: Data) {
        guard p.count >= 12 else { return nil }
        width = Int(p.uint32BE(at: 0))
        height = Int(p.uint32BE(at: 4))
        dpi = Int(p.uint32BE(at: 8))
    }
}

enum InputAction: UInt8 {
    case down = 0, move = 1, up = 2, scroll = 3, rightClick = 4
}

// payload: [action 1B][x f32][y f32][dx f32][dy f32]; x, y chuẩn hoá 0..1
struct InputEvent {
    let action: InputAction
    let x: Float, y: Float, dx: Float, dy: Float

    init?(_ p: Data) {
        guard p.count >= 17, let a = InputAction(rawValue: p[p.startIndex]) else { return nil }
        action = a
        x = p.float32BE(at: 1)
        y = p.float32BE(at: 5)
        dx = p.float32BE(at: 9)
        dy = p.float32BE(at: 13)
    }
}

extension Data {
    func uint32BE(at offset: Int) -> UInt32 {
        let i = startIndex + offset
        return (UInt32(self[i]) << 24) | (UInt32(self[i + 1]) << 16) | (UInt32(self[i + 2]) << 8) | UInt32(self[i + 3])
    }

    func int64BE(at offset: Int) -> Int64 {
        var v: UInt64 = 0
        for k in 0..<8 { v = (v << 8) | UInt64(self[startIndex + offset + k]) }
        return Int64(bitPattern: v)
    }

    func float32BE(at offset: Int) -> Float {
        Float(bitPattern: uint32BE(at: offset))
    }

    mutating func appendBE<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }
}
