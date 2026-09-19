import ApplicationServices
import AppKit
import CoreGraphics
import Darwin
import Foundation

final class KeyInjector: NSObject {
    private let lock = NSLock()
    private var held: [String: Int] = [:]
    private var lastApp: NSRunningApplication?

    private(set) var lastStatus = "No keys sent yet"
    private(set) var targetName = "—"

    private let codes: [String: CGKeyCode] = [
        "up": 0x7E,
        "down": 0x7D,
        "left": 0x7B,
        "right": 0x7C,
        "q": 0x0C,
        "w": 0x0D,
        "e": 0x0E,
        "r": 0x0F,
        "a": 0x00,
        "s": 0x01,
        "d": 0x02,
        "f": 0x03,
        "j": 0x26,
        "k": 0x28
    ]

    private let glyphs: [String: String] = [
        "q": "q", "w": "w", "e": "e", "r": "r",
        "a": "a", "s": "s", "d": "d", "f": "f",
        "j": "j", "k": "k"
    ]

    override init() {
        super.init()
        rememberFrontApp()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    static var isTrusted: Bool {
        if AXIsProcessTrustedWithOptions(nil) { return true }
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedApplicationAttribute as CFString,
            &value
        )
        return err != .apiDisabled
    }

    static func promptTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func set(key: String, down: Bool) -> Set<String> {
        guard codes[key] != nil else { return currentlyHeld() }
        lock.lock()
        let current = held[key, default: 0]
        var shouldPost = false
        var postDown = down
        if down {
            held[key] = current + 1
            shouldPost = current == 0
            postDown = true
        } else if current > 0 {
            held[key] = current - 1
            if current == 1 {
                held.removeValue(forKey: key)
                shouldPost = true
                postDown = false
            }
        }
        let snapshot = Set(held.keys)
        lock.unlock()
        if shouldPost {
            DispatchQueue.main.async { [weak self] in
                self?.post(key: key, down: postDown)
            }
        }
        return snapshot
    }

    func releaseAll() -> Set<String> {
        lock.lock()
        let keys = Array(held.keys)
        held.removeAll()
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            for key in keys { self?.post(key: key, down: false) }
        }
        return []
    }

    func currentlyHeld() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(held.keys)
    }

    @objc private func frontAppChanged(_ note: Notification) {
        rememberFrontApp()
    }

    private func rememberFrontApp() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              !isSelf(front)
        else { return }
        lastApp = front
        targetName = front.localizedName ?? "unknown"
    }

    private func isSelf(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == Bundle.main.bundleIdentifier || app.processIdentifier == ProcessInfo.processInfo.processIdentifier
    }

    private func isCursor(_ app: NSRunningApplication) -> Bool {
        let name = (app.localizedName ?? "").lowercased()
        let id = (app.bundleIdentifier ?? "").lowercased()
        return name == "cursor" || id == "com.todesktop.230313mzl4w4u92" || id.contains("anysphere")
    }

    private func targetApp() -> NSRunningApplication? {
        if let front = NSWorkspace.shared.frontmostApplication, !isSelf(front) {
            return front
        }
        if let lastApp, !lastApp.isTerminated, !isSelf(lastApp) {
            return lastApp
        }
        return NSWorkspace.shared.runningApplications.first {
            $0.activationPolicy == .regular && !isSelf($0) && isCursor($0)
        }
    }

    private func post(key: String, down: Bool) {
        guard let code = codes[key], let event = makeEvent(code: code, key: key, down: down) else { return }

        guard let target = targetApp() else {
            event.post(tap: .cghidEventTap)
            lastStatus = "No front app. Click Cursor or TextEdit, then press again."
            return
        }

        targetName = target.localizedName ?? "unknown"
        NSApp.yieldActivation(to: target)
        target.activate()

        let pids = inputPids(for: target)
        for pid in pids {
            event.postToPid(pid)
        }
        event.post(tap: .cghidEventTap)
        sendSystemEvents(key: key, code: code, down: down)

        lastStatus = "\(key) \(down ? "down" : "up") → \(targetName)  ax=\(Self.isTrusted) pids=\(pids.count)"
    }

    private func makeEvent(code: CGKeyCode, key: String, down: Bool) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { return nil }
        event.flags = []
        event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
        if let glyph = glyphs[key], !glyph.isEmpty {
            var utf16 = Array(glyph.utf16)
            utf16.withUnsafeMutableBufferPointer { buffer in
                if let base = buffer.baseAddress {
                    event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
                }
            }
        }
        return event
    }

    private func sendSystemEvents(key: String, code: CGKeyCode, down: Bool) {
        let script: String
        if let glyph = glyphs[key] {
            script = "tell application \"System Events\" to key \(down ? "down" : "up") \"\(glyph)\""
        } else if down {
            script = "tell application \"System Events\" to key code \(code)"
        } else {
            return
        }
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let message = error?["NSAppleScriptErrorMessage"] {
            lastStatus += " applescript=\(message)"
        }
    }

    private func inputPids(for app: NSRunningApplication) -> [pid_t] {
        var pids: [pid_t] = [app.processIdentifier]
        guard isCursor(app) else { return pids }

        let count = Int(proc_listallpids(nil, 0))
        guard count > 0 else { return pids }
        var all = [pid_t](repeating: 0, count: max(count + 32, 4096))
        let listed = Int(proc_listallpids(&all, Int32(all.count * MemoryLayout<pid_t>.size)))
        guard listed > 0 else { return pids }
        let nPids = listed > all.count ? listed / MemoryLayout<pid_t>.size : listed
        var path = [CChar](repeating: 0, count: 1024)
        for i in 0..<min(nPids, all.count) {
            let pid = all[i]
            guard pid > 0 else { continue }
            let n = proc_pidpath(pid, &path, UInt32(path.count))
            guard n > 0 else { continue }
            let s = String(cString: path)
            if s.contains("Cursor Helper (Renderer).app") {
                pids.append(pid)
            }
        }
        return pids
    }
}
