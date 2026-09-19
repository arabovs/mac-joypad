import AppKit
import SwiftUI

@main
struct JoypadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Joypad", systemImage: "gamecontroller.fill") {
            MenuBarView(model: JoypadModel.shared)
        }
    }
}

final class JoypadWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: JoypadWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let installed = "/Applications/Joypad.app"
        let running = URL(fileURLWithPath: Bundle.main.bundlePath).standardizedFileURL.path
        if FileManager.default.fileExists(atPath: installed),
           running != URL(fileURLWithPath: installed).standardizedFileURL.path {
            NSWorkspace.shared.open(URL(fileURLWithPath: installed))
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return
        }

        NSApp.setActivationPolicy(.regular)
        let hosting = NSHostingView(rootView: ContentView(model: JoypadModel.shared))
        hosting.sizingOptions = .intrinsicContentSize
        let size = NSSize(width: 684, height: 860)
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = JoypadWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Joypad"
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentView = hosting
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return true
    }

    func minimizeWindow() {
        window?.miniaturize(nil)
    }
}
