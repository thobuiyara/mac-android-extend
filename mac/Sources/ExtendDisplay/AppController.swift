import CoreMedia
import CoreVideo
import Foundation

/// Nối các mảnh: server <-> màn hình ảo -> capture -> encoder -> server.
final class AppController {
    // Không dùng 7000: macOS dùng cổng này cho AirPlay Receiver (ControlCenter).
    static let port: UInt16 = 27183

    private let server = StreamServer(port: AppController.port)
    private let adb = ADBManager(port: Int(AppController.port))
    private let virtualDisplay = VirtualDisplay()
    private let pipeline = DispatchQueue(label: "pipeline", qos: .userInteractive)
    private lazy var capturer = ScreenCapturer(queue: pipeline)

    // Chỉ truy cập trên `pipeline`
    private var encoder: VideoEncoder?
    private var lastPixelBuffer: CVPixelBuffer?

    // Ghi trên main, đọc trên queue của server (đủ dùng cho bản cá nhân)
    private var injector: InputInjector?

    var onStatus: ((String) -> Void)?

    func start() {
        server.onHello = { [weak self] hello in
            DispatchQueue.main.async {
                self?.startSession(width: hello.width, height: hello.height, dpi: hello.dpi)
            }
        }
        server.onInput = { [weak self] event in self?.injector?.handle(event) }
        server.onKeyframeRequest = { [weak self] in self?.requestKeyframe() }
        server.onCongestion = { [weak self] in self?.requestKeyframe() }
        server.onDisconnect = { [weak self] in
            DispatchQueue.main.async {
                self?.stopSession()
                self?.onStatus?("Mất kết nối – đang chờ thiết bị…")
            }
        }
        adb.onStatus = { [weak self] s in self?.onStatus?(s) }

        do {
            try server.start()
            onStatus?("Đang chờ thiết bị trên cổng \(AppController.port)…")
        } catch {
            onStatus?("Không mở được cổng \(AppController.port): \(error)")
        }
        adb.start()
    }

    /// Gọi trên main thread.
    /// stream = false: chỉ tạo màn hình ảo để test giai đoạn 1.
    func startSession(width: Int, height: Int, dpi: Int, stream: Bool = true) {
        stopSession()
        let w = width & ~1, h = height & ~1

        let hiDPI = h >= 1200 // tablet: HiDPI cho chữ nét; điện thoại: dùng full pixel
        guard let id = virtualDisplay.create(pixelWidth: w, pixelHeight: h, dpi: dpi, hiDPI: hiDPI) else {
            onStatus?("Không tạo được màn hình ảo")
            return
        }
        injector = InputInjector(displayID: id)
        onStatus?("Màn hình ảo #\(id) \(w)×\(h)")
        guard stream else { return }

        pipeline.sync {
            do {
                let enc = try VideoEncoder(width: w, height: h)
                enc.onConfig = { [weak self] data in
                    self?.server.send(Packet(type: .config, pts: 0, payload: data))
                }
                enc.onFrame = { [weak self] data, pts, isKey in
                    self?.server.send(Packet(type: .frame, pts: pts, payload: data), droppable: !isKey)
                }
                encoder = enc
            } catch {
                logInfo("Lỗi tạo encoder: \(error)")
            }
        }

        capturer.onFrame = { [weak self] sb in self?.encode(sb) }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.capturer.start(displayID: id, width: w, height: h)
                self.onStatus?("Đang stream \(w)×\(h) → Android")
            } catch {
                self.onStatus?("Lỗi capture (đã cấp quyền Screen Recording chưa?): \(error.localizedDescription)")
            }
        }
    }

    /// Gọi trên main thread.
    func stopSession() {
        Task { [capturer] in await capturer.stop() }
        pipeline.sync {
            encoder?.invalidate()
            encoder = nil
            lastPixelBuffer = nil
        }
        injector = nil
        virtualDisplay.destroy()
    }

    // MARK: - Pipeline

    private func encode(_ sb: CMSampleBuffer) {
        guard let pb = CMSampleBufferGetImageBuffer(sb) else { return }
        lastPixelBuffer = pb
        encoder?.encode(pb)
    }

    /// Màn hình đứng yên thì SCStream không gửi frame mới,
    /// nên encode lại frame cuối để client nhận keyframe ngay.
    private func requestKeyframe() {
        pipeline.async { [self] in
            encoder?.requestKeyframe()
            if let pb = lastPixelBuffer { encoder?.encode(pb) }
        }
    }
}
