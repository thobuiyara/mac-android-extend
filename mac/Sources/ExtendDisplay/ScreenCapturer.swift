import CoreMedia
import Foundation
import ScreenCaptureKit

enum CaptureError: Error {
    case displayNotFound
}

/// Giai đoạn 2: quay riêng màn hình ảo bằng ScreenCaptureKit.
final class ScreenCapturer: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let queue: DispatchQueue

    /// Gọi trên `queue` cho mỗi frame mới (đã bỏ qua frame idle khi màn hình đứng yên).
    var onFrame: ((CMSampleBuffer) -> Void)?

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func start(displayID: CGDirectDisplayID, width: Int, height: Int, fps: Int = 60) async throws {
        await stop()

        // Màn hình ảo mới tạo có thể mất một chút mới xuất hiện trong SCShareableContent.
        var scDisplay: SCDisplay?
        for _ in 0..<25 {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            scDisplay = content.displays.first { $0.displayID == displayID }
            if scDisplay != nil { break }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        guard let scDisplay else { throw CaptureError.displayNotFound }

        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange // '420v'
        config.queueDepth = 4
        config.showsCursor = true

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
        logInfo("Bắt đầu capture display #\(displayID) \(width)x\(height)@\(fps)")
    }

    func stop() async {
        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus),
              status == .complete else { return }
        onFrame?(sampleBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logInfo("Capture dừng: \(error.localizedDescription)")
    }
}
