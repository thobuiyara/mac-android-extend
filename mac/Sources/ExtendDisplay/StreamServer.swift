import Foundation
import Network

/// Giai đoạn 4: TCP server ở 127.0.0.1:<port> (mặc định 27183). Android kết nối qua `adb reverse`.
/// Chỉ phục vụ 1 client; client mới sẽ thay client cũ.
final class StreamServer {
    let port: UInt16
    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "stream.server", qos: .userInteractive)
    private var pendingSends = 0
    private let maxPendingSends = 6

    var onHello: ((Hello) -> Void)?
    var onInput: ((InputEvent) -> Void)?
    var onKeyframeRequest: (() -> Void)?
    var onDisconnect: (() -> Void)?
    /// Bị nghẽn nên đã bỏ frame -> cần keyframe mới.
    var onCongestion: (() -> Void)?

    init(port: UInt16) {
        self.port = port
    }

    func start() throws {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let params = NWParameters(tls: nil, tcp: tcp)
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)

        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        listener.stateUpdateHandler = { state in logInfo("Listener: \(state)") }
        listener.start(queue: queue)
        self.listener = listener
    }

    /// droppable = true cho P-frame: bỏ nếu đang nghẽn.
    func send(_ packet: Packet, droppable: Bool = false) {
        queue.async { [self] in
            guard let conn = connection else { return }
            if droppable && pendingSends >= maxPendingSends {
                onCongestion?()
                return
            }
            pendingSends += 1
            conn.send(content: packet.encoded(), completion: .contentProcessed { [weak self] error in
                self?.pendingSends -= 1
                if let error { logInfo("Lỗi gửi: \(error)") }
            })
        }
    }

    // MARK: - Private (chạy trên `queue`)

    private func accept(_ conn: NWConnection) {
        connection?.cancel()
        connection = conn
        pendingSends = 0
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self, let conn else { return }
            switch state {
            case .ready:
                logInfo("Client đã kết nối")
            case .failed, .cancelled:
                if self.connection === conn {
                    self.connection = nil
                    self.onDisconnect?()
                }
            default:
                break
            }
        }
        conn.start(queue: queue)
        receiveHeader(conn)
    }

    private func receiveHeader(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: Packet.headerSize, maximumLength: Packet.headerSize) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            if error != nil || isComplete { conn.cancel(); return }
            guard let data, data.count == Packet.headerSize else { conn.cancel(); return }

            let type = data[data.startIndex]
            let length = Int(data.uint32BE(at: 1))
            let pts = data.int64BE(at: 5)

            if length == 0 {
                self.dispatch(type, pts, Data())
                self.receiveHeader(conn)
                return
            }
            conn.receive(minimumIncompleteLength: length, maximumLength: length) { payload, _, _, error in
                guard error == nil, let payload, payload.count == length else { conn.cancel(); return }
                self.dispatch(type, pts, payload)
                self.receiveHeader(conn)
            }
        }
    }

    private func dispatch(_ rawType: UInt8, _ pts: Int64, _ payload: Data) {
        switch PacketType(rawValue: rawType) {
        case .hello:
            if let hello = Hello(payload) { onHello?(hello) }
        case .input:
            if let event = InputEvent(payload) { onInput?(event) }
        case .keyframeRequest:
            onKeyframeRequest?()
        default:
            logInfo("Bỏ qua gói tin type \(rawType)")
        }
    }
}
