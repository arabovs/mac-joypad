import Foundation

enum USBInterface {
    static func iPhoneBSDName() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-listnetworkserviceorder"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let pattern = #"Hardware Port: iPhone USB,\s*Device:\s*([a-zA-Z0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let deviceRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[deviceRange])
    }

    static func isUSBAddress(_ ip: String, interface: String, iPhoneDevice: String?) -> Bool {
        if ip.hasPrefix("192.168.2.") { return true }
        if ip.hasPrefix("172.20.10.") { return true }
        if interface.hasPrefix("bridge") && interface != "bridge0" { return true }
        if let iPhoneDevice, interface == iPhoneDevice { return true }
        return false
    }
}
