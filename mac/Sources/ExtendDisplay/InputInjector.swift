import ApplicationServices
import CoreGraphics
import Foundation

/// Giai đoạn 6: chuyển sự kiện chạm thành chuột trên màn hình ảo. Cần quyền Accessibility.
final class InputInjector {
    private let displayID: CGDirectDisplayID
    private var isDown = false

    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
    }

    /// Hiện hộp thoại xin quyền Accessibility nếu chưa có.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func handle(_ e: InputEvent) {
        let p = point(e.x, e.y)
        switch e.action {
        case .down:
            post(.leftMouseDown, p, .left)
            isDown = true
        case .move:
            post(isDown ? .leftMouseDragged : .mouseMoved, p, .left)
        case .up:
            post(.leftMouseUp, p, .left)
            isDown = false
        case .scroll:
            post(.mouseMoved, p, .left) // đưa con trỏ vào màn hình ảo trước khi cuộn
            // Android gửi pixel; với HiDPI thì 1 point = 2 pixel.
            CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                    wheel1: Int32(e.dy / 2), wheel2: Int32(e.dx / 2), wheel3: 0)?
                .post(tap: .cghidEventTap)
        case .rightClick:
            post(.rightMouseDown, p, .right)
            post(.rightMouseUp, p, .right)
        }
    }

    private func point(_ x: Float, _ y: Float) -> CGPoint {
        let b = CGDisplayBounds(displayID)
        let cx = min(max(CGFloat(x), 0), 1)
        let cy = min(max(CGFloat(y), 0), 1)
        return CGPoint(x: b.minX + cx * (b.width - 1), y: b.minY + cy * (b.height - 1))
    }

    private func post(_ type: CGEventType, _ p: CGPoint, _ button: CGMouseButton) {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: button)?
            .post(tap: .cghidEventTap)
    }
}
