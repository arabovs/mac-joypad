import Darwin
import Foundation

final class HIDHelperClient {
    static let socketPath = "/tmp/joypad-hid.sock"

    private(set) var helperReachable = false
    private(set) var keyboardReady = false
    private(set) var driverConnected = false
    private(set) var runningAsRoot = false

    var isReady: Bool { keyboardReady }

    @discardableResult
    func send(held keys: Set<String>) -> Bool {
        let line = "KEYS " + keys.sorted().joined(separator: " ") + "\n"
        return apply(reply: request(line))
    }

    @discardableResult
    func refreshStatus() -> Bool {
        apply(reply: request("STATUS\n"))
    }

    private func apply(reply: String?) -> Bool {
        guard let reply, !reply.isEmpty else {
            helperReachable = false
            keyboardReady = false
            driverConnected = false
            runningAsRoot = false
            return false
        }
        helperReachable = true
        keyboardReady = reply.contains("keyboard=1")
        driverConnected = reply.contains("driver=1")
        runningAsRoot = reply.contains("uid=0")
        return keyboardReady
    }

    private func request(_ line: String) -> String? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var timeout = timeval(tv_sec: 0, tv_usec: 250_000)
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        _ = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(Self.socketPath.utf8CString)
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            let count = min(raw.count - 1, pathBytes.count)
            pathBytes.withUnsafeBytes { src in
                raw.copyMemory(from: UnsafeRawBufferPointer(start: src.baseAddress, count: count))
            }
        }

        let ok = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard ok == 0 else { return nil }

        let payload = Array(line.utf8)
        let sent = payload.withUnsafeBufferPointer { Darwin.send(fd, $0.baseAddress, $0.count, 0) }
        guard sent == payload.count else { return nil }

        var buffer = [CChar](repeating: 0, count: 256)
        let n = recv(fd, &buffer, buffer.count - 1, 0)
        guard n > 0 else { return nil }
        return String(cString: buffer)
    }
}
