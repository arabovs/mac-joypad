import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct ContentView: View {
    @Bindable var model: JoypadModel

    var body: some View {
        VStack(spacing: 16) {
            header
            pathPicker
            statusRow
            urlCard
            PadPreview(pressed: model.pressed)
            permissionCard
            help
        }
        .padding(22)
        .frame(width: 640)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("JOYPAD")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(4)
            Text("Use your iPhone as a Mac controller")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var pathPicker: some View {
        Picker("Connection", selection: $model.connectionPath) {
            Text("Wi‑Fi").tag(ConnectionPath.wifi)
            Text("Cable").tag(ConnectionPath.cable)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            if model.connectionPath == .cable {
                StatusChip(
                    title: model.usbConnected ? "iPhone plugged in" : "Waiting for USB",
                    ok: model.usbConnected
                )
            } else {
                StatusChip(
                    title: model.links.contains(where: { $0.kind == .wifi }) ? "Wi‑Fi ready" : "No Wi‑Fi address",
                    ok: model.links.contains(where: { $0.kind == .wifi })
                )
            }
            StatusChip(
                title: model.clients == 1 ? "1 controller" : "\(model.clients) controllers",
                ok: model.clients > 0
            )
            StatusChip(
                title: model.hidState.chipTitle,
                ok: model.hidState.isLive
            )
        }
    }

    private var urlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open this in the iPhone browser. Type http:// — Chrome hangs on https://")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .help("Open this in the iPhone browser. Type http:// — Chrome hangs on https://")
            Text(model.preferredURL)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .help(model.preferredURL)
            Text(statusLine)
                .font(.caption)
                .foregroundStyle(statusOK ? .green : .orange)
                .fixedSize(horizontal: false, vertical: true)
                .help(statusLine)
            Text(model.lastIncoming)
                .font(.caption)
                .foregroundStyle(model.lastIncoming.hasPrefix("Reached") ? .green : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .help(model.lastIncoming)
            HStack(alignment: .center, spacing: 16) {
                QRCodeView(text: model.preferredURL)
                    .frame(width: 120, height: 120)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 8) {
                    if model.connectionPath == .cable {
                        Button("Open Internet Sharing") { model.openInternetSharing() }
                    }
                    Button(model.connectionPath == .wifi ? "Copy Wi‑Fi link" : "Copy cable link") {
                        model.copyPreferredURL()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Minimize") {
                        NSApp.windows.first { $0.title == "Joypad" }?.miniaturize(nil)
                    }
                }
            }
            if let error = model.serverError {
                Text(error).foregroundStyle(.red).font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusLine: String {
        switch model.connectionPath {
        case .wifi:
            return "No cable needed. iPhone and Mac must be on the same Wi‑Fi. Turn Personal Hotspot off."
        case .cable:
            return model.usbSetupReady
                ? "USB network is up."
                : "USB needs Internet Sharing on the Mac so the cable can carry the page."
        }
    }

    private var statusOK: Bool {
        switch model.connectionPath {
        case .wifi:
            return model.links.contains { $0.kind == .wifi }
        case .cable:
            return model.usbSetupReady
        }
    }

    private var openEmuHelp: String {
        switch model.hidState {
        case .live:
            return "OpenEmu: the Karabiner virtual keyboard is live. Keep Input set to Keyboard and use the bindings you already made. Grant OpenEmu Input Monitoring if the game still sees nothing."
        case .needsKarabiner:
            return "OpenEmu needs Karabiner-Elements once. Install it, allow the system extension, then come back and allow the Joypad HID helper. Cursor keys still work without that."
        case .needsApproval:
            return "Karabiner is installed. Click Allow HID helper, then enable Joypad in Login Items / Background Items. macOS will ask for an admin password once."
        case .helperOff:
            return "The HID helper is registered but the Karabiner virtual keyboard is not ready. Open Karabiner-Elements once so its driver is running, then retry a pad button."
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.accessibilityTrusted ? "Mac key control is allowed" : "Allow Accessibility so buttons can press keys")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Sending into: \(model.targetName)")
                .font(.caption.monospaced())
                .fixedSize(horizontal: false, vertical: true)
                .help("Sending into: \(model.targetName)")
            Text(model.lastSend)
                .font(.caption.monospaced())
                .foregroundStyle(model.lastSend.contains("BLOCKED") ? .red : .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .help(model.lastSend)
            Text(model.accessibilityTrusted
                 ? "Click into Cursor (or TextEdit), then use the phone. Flicker on this window is only the preview — keys go to the app in front."
                 : "The pad on the phone is fine. macOS still has to allow this copy of Joypad to type. Remove every Joypad row, click +, add /Applications/Joypad.app, turn it on, then quit and reopen Joypad.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(openEmuHelp)
                .font(.caption)
                .foregroundStyle(model.hidState.isLive ? Color.secondary : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
                .help(model.hidState.chipTitle)
            HStack(spacing: 8) {
                Button("Open Accessibility settings") { model.openAccessibilitySettings() }
                    .buttonStyle(.borderedProminent)
                    .help("Opens System Settings → Privacy & Security → Accessibility")
                if !model.karabinerInstalled {
                    Button("Get Karabiner-Elements") { model.openKarabinerDownload() }
                } else if !model.hidState.isLive {
                    Button("Allow HID helper") { model.allowHIDHelper() }
                }
                if !model.accessibilityTrusted {
                    Button("Quit Joypad") { NSApp.terminate(nil) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(model.accessibilityTrusted ? Color.green.opacity(0.12) : Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.connectionPath == .wifi {
                helpLine("1. Put the iPhone on the same Wi‑Fi as this Mac. Turn Personal Hotspot OFF.")
                helpLine("2. Open Safari, or Chrome with Always use secure connections OFF, to \(model.preferredURL)")
                helpLine("3. Click Cursor or the game, then use the phone. D‑pad = arrows. QWER/ASDF = buttons. Select = J. Start = K.")
                helpLine("OpenEmu: keep Input set to Keyboard (the bindings you already made). Install Karabiner-Elements, allow the Joypad HID helper, and give OpenEmu Input Monitoring.")
            } else {
                helpLine("1. Plug the iPhone in with USB‑C and tap Trust. Turn Personal Hotspot OFF.")
                helpLine("2. On the Mac click Open Internet Sharing. Share Wi‑Fi to iPhone USB, then enable Internet Sharing.")
                helpLine("3. Open Safari, or Chrome with Always use secure connections OFF, to http://192.168.2.1:7777")
                helpLine("4. Click Cursor or the game, then use the phone. D‑pad = arrows. QWER/ASDF = buttons. Select = J. Start = K.")
                helpLine("OpenEmu: keep Input set to Keyboard (the bindings you already made). Install Karabiner-Elements, allow the Joypad HID helper, and give OpenEmu Input Monitoring.")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func helpLine(_ text: String) -> some View {
        Text(text)
            .fixedSize(horizontal: false, vertical: true)
            .help(text)
    }
}

struct StatusChip: View {
    let title: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
    }
}

struct PadPreview: View {
    let pressed: Set<String>

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 6) {
                key("up", "▲")
                HStack(spacing: 6) {
                    key("left", "◀")
                    key("right", "▶")
                }
                key("down", "▼")
            }
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(["q", "w", "e", "r"], id: \.self) { key($0, $0.uppercased()) }
                }
                HStack(spacing: 8) {
                    ForEach(["a", "s", "d", "f"], id: \.self) { key($0, $0.uppercased()) }
                }
            }
            VStack(spacing: 6) {
                key("j", "SEL")
                key("k", "STR")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func key(_ id: String, _ label: String) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .frame(width: 36, height: 32)
            .background(pressed.contains(id) ? Color.green : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct QRCodeView: View {
    let text: String

    var body: some View {
        if let image = Self.image(for: text) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            Color.white
        }
    }

    private static func image(for text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}

struct MenuBarView: View {
    var model: JoypadModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.clients > 0 ? "iPhone linked" : "Waiting for iPhone")
            Text(model.preferredURL).font(.caption.monospaced())
            Button("Copy link") { model.copyPreferredURL() }
            Button("Open Accessibility settings") { model.openAccessibilitySettings() }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(8)
    }
}
