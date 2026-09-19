import Darwin
import Foundation

struct NetworkLink: Identifiable, Equatable {
    let id: String
    let interface: String
    let ip: String
    let kind: Kind

    enum Kind: String {
        case usb = "USB cable"
        case wifi = "Wi‑Fi"
        case other = "Local"
    }
}

enum NetworkAddresses {
    static func links(port: UInt16) -> [NetworkLink] {
        let iPhoneDevice = USBInterface.iPhoneBSDName()
        var results: [NetworkLink] = []
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return bonjour() }
        defer { freeifaddrs(pointer) }

        var current: UnsafeMutablePointer<ifaddrs>? = first
        let skipped = Set(["lo0", "awdl0", "llw0", "gif0", "stf0", "bridge0"])
        while let iface = current {
            defer { current = iface.pointee.ifa_next }
            let flags = Int32(iface.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let addr = iface.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: iface.pointee.ifa_name)
            if skipped.contains(name) || name.hasPrefix("utun") || name.hasPrefix("anpi") || name.hasPrefix("ap") {
                continue
            }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let saLen = socklen_t(addr.pointee.sa_len)
            guard getnameinfo(addr, saLen, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let ip = String(cString: host)
            if ip.hasPrefix("127.") { continue }

            let usb = USBInterface.isUSBAddress(ip, interface: name, iPhoneDevice: iPhoneDevice)
            if ip.hasPrefix("169.254.") && !usb { continue }

            let kind: NetworkLink.Kind
            if usb {
                kind = .usb
            } else if name.hasPrefix("en") {
                kind = .wifi
            } else {
                kind = .other
            }
            results.append(NetworkLink(id: "\(name)-\(ip)", interface: name, ip: ip, kind: kind))
        }

        results.sort { lhs, rhs in
            rank(lhs) < rank(rhs)
        }
        return results + bonjour()
    }

    static func url(for link: NetworkLink, port: UInt16) -> String {
        "http://\(link.ip):\(port)"
    }

    private static func rank(_ link: NetworkLink) -> Int {
        if link.kind == .usb && link.ip.hasPrefix("192.168.2.") { return 0 }
        if link.kind == .usb && link.ip.hasPrefix("172.20.10.") { return 1 }
        if link.kind == .usb { return 2 }
        if link.kind == .wifi { return 3 }
        return 4
    }

    private static func bonjour() -> [NetworkLink] {
        let host = ProcessInfo.processInfo.hostName
        let name = host.hasSuffix(".local") ? host : "\(host).local"
        return [NetworkLink(id: "bonjour", interface: "bonjour", ip: name, kind: .other)]
    }
}
