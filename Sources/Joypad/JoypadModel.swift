import AppKit
import Foundation

enum ConnectionPath: String, CaseIterable, Identifiable {
    case wifi
    case cable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wifi: return "Wi‑Fi"
        case .cable: return "Cable"
        }
    }
}

@MainActor
@Observable
final class JoypadModel {
    static let shared = JoypadModel()

    var usbConnected = false
    var usbNetworkReady = false
    var hotspotActive = false
    var accessibilityTrusted = false
    var clients = 0
    var pressed: Set<String> = []
    var links: [NetworkLink] = []
    var port: UInt16 = 7777
    var serverError: String?
    var preferredURL: String = ""
    var lastIncoming: String = "No iPhone has reached this Mac yet"
    var lastSend: String = "No keys sent yet"
    var targetName: String = "—"
    var hidReady = false
    var hidState: OpenEmuHIDState = .needsKarabiner
    var karabinerInstalled = false
    var usbSetupReady = false
    var connectionPath: ConnectionPath {
        didSet {
            UserDefaults.standard.set(connectionPath.rawValue, forKey: "joypad.connectionPath")
            refresh()
        }
    }

    static let usbShareURL = "http://192.168.2.1:7777"

    let injector = KeyInjector()
    private var server: JoypadServer?
    private var timer: Timer?

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "joypad.connectionPath"),
           let path = ConnectionPath(rawValue: saved) {
            connectionPath = path
        } else {
            connectionPath = .wifi
        }
        Task { @MainActor in
            self.refresh()
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                Task { @MainActor in
                    JoypadModel.shared.refresh()
                }
            }
        }
    }

    func ensureServer() {
        if server == nil {
            startServer()
        }
    }

    func promptAccessibility() {
        KeyInjector.promptTrust()
        accessibilityTrusted = KeyInjector.isTrusted
    }

    func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]
        for value in urls {
            if let url = URL(string: value) {
                NSWorkspace.shared.open(url)
                break
            }
        }
        promptAccessibility()
    }

    func openInternetSharing() {
        let urls = [
            "x-apple.systempreferences:com.apple.Sharing-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.sharing"
        ]
        for value in urls {
            if let url = URL(string: value) {
                NSWorkspace.shared.open(url)
                break
            }
        }
    }

    func openKarabinerDownload() {
        HIDHelperService.openKarabinerDownload()
    }

    func allowHIDHelper() {
        HIDHelperService.openLoginItems()
        refresh()
    }

    func copyPreferredURL() {
        guard !preferredURL.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preferredURL, forType: .string)
    }

    private func startServer() {
        let injector = injector
        let server = JoypadServer(
            port: 7777,
            injector: injector,
            onClientsChanged: { count in
                Task { @MainActor in
                    JoypadModel.shared.clients = count
                }
            },
            onKeysChanged: { keys in
                Task { @MainActor in
                    let model = JoypadModel.shared
                    model.pressed = keys
                    model.lastSend = model.injector.lastStatus
                    model.targetName = model.injector.targetName
                    model.hidReady = model.injector.hidReady
                    model.hidState = HIDHelperService.state(client: model.injector.hid)
                    model.karabinerInstalled = HIDHelperService.karabinerInstalled
                    model.accessibilityTrusted = KeyInjector.isTrusted
                }
            },
            onReady: { port in
                Task { @MainActor in
                    JoypadModel.shared.port = port
                    JoypadModel.shared.refresh()
                }
            },
            onError: { message in
                Task { @MainActor in
                    JoypadModel.shared.serverError = message
                }
            },
            onIncoming: { peer in
                Task { @MainActor in
                    JoypadModel.shared.lastIncoming = "Reached Mac from \(peer)"
                }
            }
        )
        self.server = server
        server.start()
    }

    func refresh() {
        accessibilityTrusted = KeyInjector.isTrusted
        lastSend = injector.lastStatus
        targetName = injector.targetName
        injector.hid.refreshStatus()
        hidReady = injector.hidReady
        hidState = HIDHelperService.state(client: injector.hid)
        karabinerInstalled = HIDHelperService.karabinerInstalled
        usbConnected = USBMonitor.iPhoneConnected()
        links = NetworkAddresses.links(port: port)
        usbSetupReady = links.contains { $0.kind == .usb && ($0.ip.hasPrefix("192.168.2.") || $0.ip.hasPrefix("172.20.10.")) }
        usbNetworkReady = usbSetupReady
        hotspotActive = links.contains { $0.ip.hasPrefix("172.20.10.") }
        preferredURL = url(for: connectionPath)
    }

    func url(for path: ConnectionPath) -> String {
        switch path {
        case .wifi:
            if let wifi = links.first(where: { $0.kind == .wifi }) {
                return NetworkAddresses.url(for: wifi, port: port)
            }
            if let other = links.first(where: { $0.kind == .other && !$0.ip.contains(".local") }) {
                return NetworkAddresses.url(for: other, port: port)
            }
            return "http://127.0.0.1:\(port)"
        case .cable:
            if let usb = links.first(where: { $0.kind == .usb && ($0.ip.hasPrefix("192.168.2.") || $0.ip.hasPrefix("172.20.10.")) }) {
                return NetworkAddresses.url(for: usb, port: port)
            }
            return Self.usbShareURL
        }
    }
}
