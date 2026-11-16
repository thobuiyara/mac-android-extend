import CoreGraphics
import CGVirtualDisplayPrivate
import Foundation

/// Giai đoạn 1: tạo màn hình ảo. Phải giữ reference `display`, nếu bị giải phóng thì màn hình biến mất.
final class VirtualDisplay {
    private var display: CGVirtualDisplay?

    var displayID: CGDirectDisplayID? { display?.displayID }

    /// - pixelWidth/pixelHeight: độ phân giải thật của máy Android (ngang).
    /// - hiDPI: true -> macOS hiển thị ở mức points = pixel / 2 (chữ nét, nhưng không gian nhỏ hơn).
    @discardableResult
    func create(pixelWidth: Int, pixelHeight: Int, dpi: Int = 220,
                hiDPI: Bool = true, refreshRate: Double = 60) -> CGDirectDisplayID? {
        destroy()

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(DispatchQueue.main)
        descriptor.name = "Android Extend"
        descriptor.maxPixelsWide = UInt32(pixelWidth)
        descriptor.maxPixelsHigh = UInt32(pixelHeight)
        let safeDpi = Double(max(dpi, 72))
        descriptor.sizeInMillimeters = CGSize(width: Double(pixelWidth) / safeDpi * 25.4,
                                              height: Double(pixelHeight) / safeDpi * 25.4)
        descriptor.vendorID = 0xEEEE
        descriptor.productID = 0xA0D1
        descriptor.serialNum = 1
        descriptor.terminationHandler = { _, _ in logInfo("Virtual display terminated") }

        guard let display = CGVirtualDisplay(descriptor: descriptor) else {
            logInfo("Không tạo được CGVirtualDisplay")
            return nil
        }

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = hiDPI ? 1 : 0
        let scale = hiDPI ? 2 : 1
        settings.modes = [
            CGVirtualDisplayMode(width: UInt(pixelWidth / scale),
                                 height: UInt(pixelHeight / scale),
                                 refreshRate: refreshRate)
        ]
        guard display.apply(settings) else {
            logInfo("applySettings thất bại")
            return nil
        }

        self.display = display
        logInfo("Đã tạo màn hình ảo #\(display.displayID) \(pixelWidth)x\(pixelHeight) hiDPI=\(hiDPI)")
        return display.displayID
    }

    func destroy() {
        if display != nil { logInfo("Gỡ màn hình ảo") }
        display = nil
    }
}
