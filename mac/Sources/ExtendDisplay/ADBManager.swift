import Foundation

/// Giai đoạn 7: tự phát hiện máy Android cắm vào và chạy `adb reverse tcp:PORT tcp:PORT`.
final class ADBManager {
    private let port: Int
    private let queue = DispatchQueue(label: "adb")
    private var timer: DispatchSourceTimer?
    private var knownDevices: Set<String> = []

    var onStatus: ((String) -> Void)?

    /// Ưu tiên adb của Android SDK (cùng bản với Android Studio).
    /// Nếu dùng adb của Homebrew khác phiên bản, hai bên sẽ liên tục kill adb server của nhau
    /// và thiết bị bị "offline" trong Android Studio.
    private lazy var adbPath: String? = [
        NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb",
        "/opt/homebrew/bin/adb",
        "/usr/local/bin/adb",
    ].first { FileManager.default.isExecutableFile(atPath: $0) }

    init(port: Int) {
        self.port = port
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 2.0)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    private func poll() {
        guard let adb = adbPath else {
            onStatus?("Không tìm thấy adb (brew install android-platform-tools)")
            return
        }
        let output = run(adb, ["devices"])
        let devices = Set(output.split(separator: "\n").dropFirst().compactMap { line -> String? in
            let parts = line.split(separator: "\t")
            return parts.count == 2 && parts[1] == "device" ? String(parts[0]) : nil
        })
        for serial in devices.subtracting(knownDevices) {
            run(adb, ["-s", serial, "reverse", "tcp:\(port)", "tcp:\(port)"])
            logInfo("adb reverse tcp:\(port) -> \(serial)")
            onStatus?("Đã nối USB với \(serial) – mở app trên Android")
        }
        knownDevices = devices
    }

    @discardableResult
    private func run(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
