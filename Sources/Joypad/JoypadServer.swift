import CryptoKit
import Foundation
import Network

final class JoypadServer {
    let port: UInt16
    private let queue = DispatchQueue(label: "joypad.server")
    private let injector: KeyInjector
    private let onClientsChanged: @Sendable (Int) -> Void
    private let onKeysChanged: @Sendable (Set<String>) -> Void
    private let onReady: @Sendable (UInt16) -> Void
    private let onError: @Sendable (String) -> Void
    private let onIncoming: @Sendable (String) -> Void

    private var listener: NWListener?
    private var listeners: [NWListener] = []
    private var clients: [ObjectIdentifier: Client] = [:]

    init(
        port: UInt16,
        injector: KeyInjector,
        onClientsChanged: @escaping @Sendable (Int) -> Void,
        onKeysChanged: @escaping @Sendable (Set<String>) -> Void,
        onReady: @escaping @Sendable (UInt16) -> Void,
        onError: @escaping @Sendable (String) -> Void,
        onIncoming: @escaping @Sendable (String) -> Void
    ) {
        self.port = port
        self.injector = injector
        self.onClientsChanged = onClientsChanged
        self.onKeysChanged = onKeysChanged
        self.onReady = onReady
        self.onError = onError
        self.onIncoming = onIncoming
        injector.onHeldChanged = { held in
            onKeysChanged(held)
        }
    }

    private var bindAttempts = 0

    func start() {
        queue.async { [weak self] in
            self?.bind(from: self?.port ?? 7777)
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.listener?.cancel()
            self?.listeners.forEach { $0.cancel() }
            self?.listeners.removeAll()
            self?.clients.values.forEach { $0.connection.cancel() }
            self?.clients.removeAll()
            _ = self?.injector.releaseAll()
        }
    }

    private func bind(from startPort: UInt16) {
        do {
            let tcp = NWProtocolTCP.Options()
            tcp.noDelay = true
            tcp.enableKeepalive = true
            let params = NWParameters(tls: nil, tcp: tcp)
            params.allowLocalEndpointReuse = true
            params.acceptLocalOnly = false
            params.includePeerToPeer = true
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: startPort)!)
            listener.service = NWListener.Service(name: "Joypad", type: "_http._tcp")
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.bindAttempts = 0
                    self?.onReady(startPort)
                case .failed(let error):
                    self?.onError(error.localizedDescription)
                    self?.retryBind(port: startPort)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
            self.listeners = [listener]
        } catch {
            onError(error.localizedDescription)
            retryBind(port: startPort)
        }
    }

    private func retryBind(port: UInt16) {
        bindAttempts += 1
        guard bindAttempts <= 12 else { return }
        listener?.cancel()
        listeners.forEach { $0.cancel() }
        listeners.removeAll()
        queue.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.bind(from: port)
        }
    }

    private func accept(_ connection: NWConnection) {
        let client = Client(connection: connection)
        clients[ObjectIdentifier(client)] = client
        connection.stateUpdateHandler = { [weak self, weak client] state in
            guard let self, let client else { return }
            switch state {
            case .ready:
                self.onIncoming(self.peerDescription(connection))
            case .failed, .cancelled:
                self.drop(client)
            default:
                break
            }
        }
        connection.start(queue: queue)
        receive(on: client)
        let timeout = DispatchWorkItem { [weak self, weak client] in
            guard let self, let client, !client.closed, !client.isSocket else { return }
            self.rejectHTTPS(client)
        }
        client.headerTimeout = timeout
        queue.asyncAfter(deadline: .now() + 0.6, execute: timeout)
    }

    private func drop(_ client: Client) {
        if client.closed { return }
        client.closed = true
        client.headerTimeout?.cancel()
        client.headerTimeout = nil
        client.connection.cancel()
        clients.removeValue(forKey: ObjectIdentifier(client))
        for key in client.held {
            _ = injector.set(key: key, down: false)
        }
        onKeysChanged(injector.currentlyHeld())
        onClientsChanged(clients.values.filter(\.isSocket).count)
    }

    private func receive(on client: Client) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self, weak client] data, _, isComplete, error in
            guard let self, let client else { return }
            if let data, !data.isEmpty {
                client.buffer.append(data)
                self.consume(client)
            }
            if error != nil {
                self.drop(client)
                return
            }
            if isComplete && client.isSocket {
                self.drop(client)
                return
            }
            if !isComplete {
                self.receive(on: client)
            }
        }
    }

    private func consume(_ client: Client) {
        if client.isSocket {
            while let frame = WebSocketFrame.decode(from: &client.buffer) {
                handle(frame: frame, client: client)
            }
            return
        }

        if looksLikeTLS(client.buffer) {
            rejectHTTPS(client)
            return
        }

        guard let range = headerEnd(in: client.buffer) else { return }
        client.headerTimeout?.cancel()
        client.headerTimeout = nil
        let headerData = client.buffer.subdata(in: client.buffer.startIndex..<range.upperBound)
        client.buffer.removeSubrange(client.buffer.startIndex..<range.upperBound)
        guard let header = String(data: headerData, encoding: .utf8) else { return }
        handleHTTP(header, client: client)
    }

    private func looksLikeTLS(_ data: Data) -> Bool {
        guard let first = data.first else { return false }
        return first == 0x14 || first == 0x15 || first == 0x16 || first == 0x17
    }

    private func rejectHTTPS(_ client: Client) {
        drop(client)
    }

    private func handleHTTP(_ header: String, client: Client) {
        let lines = header.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n")
        guard let request = lines.first else { return }
        let parts = request.split(separator: " ")
        let path = parts.count > 1 ? String(parts[1]) : "/"
        let fields = Dictionary(uniqueKeysWithValues: lines.dropFirst().compactMap { line -> (String, String)? in
            guard let idx = line.firstIndex(of: ":") else { return nil }
            let key = line[..<idx].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
            return (key, value)
        })

        if path == "/ws" || fields["upgrade"]?.lowercased() == "websocket" {
            upgrade(client: client, key: fields["sec-websocket-key"] ?? "")
            return
        }

        if path.hasPrefix("/favicon") {
            respond(client, status: "204 No Content", contentType: "image/x-icon", body: Data(), close: true)
            return
        }

        if path == "/status" {
            let body = #"{"ok":true}"#
            respond(client, status: "200 OK", contentType: "application/json", body: Data(body.utf8), close: true)
            return
        }

        respond(client, status: "200 OK", contentType: "text/html; charset=utf-8", body: Data(JoypadHTML.page.utf8), close: true)
    }

    private func upgrade(client: Client, key: String) {
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let hash = Insecure.SHA1.hash(data: Data((key + magic).utf8))
        let accept = Data(hash).base64EncodedString()
        let response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\n\r\n"
        client.connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in })
        client.isSocket = true
        onClientsChanged(clients.values.filter(\.isSocket).count)
    }

    private func handle(frame: WebSocketFrame, client: Client) {
        switch frame.opcode {
        case .close:
            drop(client)
        case .ping:
            client.connection.send(content: WebSocketFrame.encode(opcode: .pong, payload: frame.payload), completion: .contentProcessed { _ in })
        case .text:
            guard let text = String(data: frame.payload, encoding: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                  let key = json["k"] as? String
            else { return }
            if key == "ping" { return }
            let down = ((json["s"] as? Int) ?? 0) == 1
            if down { client.held.insert(key) } else { client.held.remove(key) }
            let held = injector.set(key: key, down: down)
            onKeysChanged(held)
        default:
            break
        }
    }

    private func respond(_ client: Client, status: String, contentType: String, body: Data, close: Bool) {
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store, no-cache\r\nPragma: no-cache\r\nAccess-Control-Allow-Origin: *\r\nReferrer-Policy: no-referrer\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        sendChunks(client, data: data, close: close)
    }

    private func sendChunks(_ client: Client, data: Data, close: Bool, offset: Int = 0) {
        let chunkSize = 4096
        let end = min(offset + chunkSize, data.count)
        let slice = data.subdata(in: offset..<end)
        let last = end >= data.count
        client.connection.send(content: slice, contentContext: .defaultStream, isComplete: close && last, completion: .contentProcessed { [weak self] _ in
            guard let self else { return }
            if !last {
                self.sendChunks(client, data: data, close: close, offset: end)
                return
            }
            if close {
                self.queue.asyncAfter(deadline: .now() + 0.05) {
                    self.drop(client)
                }
            }
        })
    }

    private func headerEnd(in buffer: Data) -> Range<Data.Index>? {
        if let range = buffer.range(of: Data("\r\n\r\n".utf8)) { return range }
        return buffer.range(of: Data("\n\n".utf8))
    }

    private func peerDescription(_ connection: NWConnection) -> String {
        if let remote = connection.currentPath?.remoteEndpoint {
            return "\(remote)"
        }
        return "\(connection.endpoint)"
    }
}

private final class Client {
    let connection: NWConnection
    var buffer = Data()
    var isSocket = false
    var held: Set<String> = []
    var closed = false
    var headerTimeout: DispatchWorkItem?

    init(connection: NWConnection) {
        self.connection = connection
    }
}

private struct WebSocketFrame {
    enum Opcode: UInt8 {
        case continuation = 0x0
        case text = 0x1
        case binary = 0x2
        case close = 0x8
        case ping = 0x9
        case pong = 0xA
    }

    let opcode: Opcode
    let payload: Data

    static func decode(from buffer: inout Data) -> WebSocketFrame? {
        guard buffer.count >= 2 else { return nil }
        let bytes = [UInt8](buffer)
        let opcode = Opcode(rawValue: bytes[0] & 0x0F) ?? .binary
        let masked = (bytes[1] & 0x80) != 0
        var len = Int(bytes[1] & 0x7F)
        var offset = 2
        if len == 126 {
            guard buffer.count >= 4 else { return nil }
            len = Int(bytes[2]) << 8 | Int(bytes[3])
            offset = 4
        } else if len == 127 {
            guard buffer.count >= 10 else { return nil }
            len = 0
            for i in 0..<8 { len = (len << 8) | Int(bytes[2 + i]) }
            offset = 10
        }
        let maskOffset = offset
        if masked { offset += 4 }
        guard buffer.count >= offset + len else { return nil }
        var payload = [UInt8](bytes[offset..<(offset + len)])
        if masked {
            let mask = Array(bytes[maskOffset..<maskOffset + 4])
            for i in payload.indices { payload[i] ^= mask[i % 4] }
        }
        buffer.removeSubrange(0..<(offset + len))
        return WebSocketFrame(opcode: opcode, payload: Data(payload))
    }

    static func encode(opcode: Opcode, payload: Data) -> Data {
        var bytes: [UInt8] = [0x80 | opcode.rawValue]
        if payload.count <= 125 {
            bytes.append(UInt8(payload.count))
        } else if payload.count <= 65535 {
            bytes.append(126)
            bytes.append(UInt8((payload.count >> 8) & 0xFF))
            bytes.append(UInt8(payload.count & 0xFF))
        } else {
            bytes.append(127)
            for shift in stride(from: 56, through: 0, by: -8) {
                bytes.append(UInt8((payload.count >> shift) & 0xFF))
            }
        }
        bytes.append(contentsOf: payload)
        return Data(bytes)
    }
}
