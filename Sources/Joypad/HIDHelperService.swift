import AppKit
import Foundation
import ServiceManagement

enum OpenEmuHIDState: Equatable {
    case live
    case needsKarabiner
    case needsApproval
    case helperOff

    var chipTitle: String {
        switch self {
        case .live: return "OpenEmu keyboard live"
        case .needsKarabiner: return "Install Karabiner driver"
        case .needsApproval: return "Allow HID helper"
        case .helperOff: return "OpenEmu HID helper off"
        }
    }

    var isLive: Bool { self == .live }
}

enum HIDHelperService {
    static let plistName = "com.joypad.iphone.hid.plist"
    static let karabinerURL = URL(string: "https://karabiner-elements.pqrs.org/")!

    static var daemon: SMAppService {
        SMAppService.daemon(plistName: plistName)
    }

    static var karabinerInstalled: Bool {
        let paths = [
            "/Applications/Karabiner-Elements.app",
            "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    static var helperStatus: SMAppService.Status {
        daemon.status
    }

    static func state(client: HIDHelperClient) -> OpenEmuHIDState {
        if client.isReady { return .live }
        if !karabinerInstalled { return .needsKarabiner }
        switch helperStatus {
        case .enabled:
            return .helperOff
        default:
            return .needsApproval
        }
    }

    static func ensureRegistered() {
        let service = daemon
        if service.status == .notFound {
            try? service.unregister()
        }
        guard service.status != .enabled else { return }
        do {
            try service.register()
        } catch {
            NSLog("joypad hid helper register: \(error.localizedDescription)")
        }
    }

    static func openKarabinerDownload() {
        NSWorkspace.shared.open(karabinerURL)
    }

    static func openLoginItems() {
        if #available(macOS 13.0, *) {
            SMAppService.openSystemSettingsLoginItems()
        }
        ensureRegistered()
    }
}
