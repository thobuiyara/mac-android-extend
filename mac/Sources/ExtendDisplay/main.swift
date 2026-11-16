import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller = AppController()
    private let statusLine = NSMenuItem(title: "Đang khởi động…", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle",
                                           accessibilityDescription: "Extend Display")

        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Tạo màn hình ảo thử (2000×1200)", action: #selector(createTestDisplay), keyEquivalent: "t").target = self
        menu.addItem(withTitle: "Gỡ màn hình ảo", action: #selector(removeDisplay), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "Xin quyền Accessibility", action: #selector(askAccessibility), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Thoát", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        controller.onStatus = { [weak self] text in
            DispatchQueue.main.async { self?.statusLine.title = text }
        }
        controller.start()
        InputInjector.ensureAccessibility()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stopSession()
    }

    /// Giai đoạn 1: kiểm tra màn hình ảo mà không cần Android.
    @objc private func createTestDisplay() {
        controller.startSession(width: 2000, height: 1200, dpi: 220, stream: false)
    }

    @objc private func removeDisplay() {
        controller.stopSession()
        statusLine.title = "Đã gỡ màn hình ảo"
    }

    @objc private func askAccessibility() {
        InputInjector.ensureAccessibility()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
