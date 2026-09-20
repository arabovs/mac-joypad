import ApplicationServices
import AppKit
import CoreGraphics
import Darwin
import Foundation

final class KeyInjector: NSObject {
    private let lock = NSLock()
    private var held: [String: Int] = [:]
    private var lastApp: NSRunningApplication?
    private var holdTimer: DispatchSourceTimer?
    private var holdStartedAt: Date?
    private var faceHoldStartedAt: Date?
    private var turboDown = true
    private var delayedMoveUps: [String: DispatchWorkItem] = [:]
    let hid = HIDHelperClient()
    var onHeldChanged: ((Set<String>) -> Void)?

    private(set) var lastStatus = "No keys sent yet"
    private(set) var targetName = "—"
    var hidReady: Bool { hid.isReady }

    private let codes: [String: CGKeyCode] = [
        "up": 0x7E,
        "down": 0x7D,
        "left": 0x7B,
        "right": 0x7C,
        "ne": 0x5C,
        "se": 0x55,
        "sw": 0x53,
        "nw": 0x59,
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
        "j": "j", "k": "k",
        "ne": "9", "se": "3", "sw": "1", "nw": "7"
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

    private let moveKeys: Set<String> = ["up", "down", "left", "right", "ne", "se", "sw", "nw"]
    private let faceKeys: Set<String> = ["q", "w", "e", "r", "a", "s", "d", "f"]
    private let moveReleaseDelay: TimeInterval = 0.075
    private let turboDelay: TimeInterval = 0.14
    private let turboPeriod: TimeInterval = 0.1
    private let turboDownDuty: TimeInterval = 0.055

    func set(key: String, down: Bool) -> Set<String> {
        guard codes[key] != nil else { return currentlyHeld() }
        if moveKeys.contains(key) {
            if down {
                cancelMoveRelease(key)
                if currentlyHeld().contains(key) {
                    return currentlyHeld()
                }
            } else {
                scheduleMoveRelease(key)
                return currentlyHeld()
            }
        }
        return apply(key: key, down: down)
    }

    func releaseAll() -> Set<String> {
        lock.lock()
        let pending = Array(delayedMoveUps.values)
        delayedMoveUps.removeAll()
        let keys = Array(held.keys)
        held.removeAll()
        lock.unlock()
        pending.forEach { $0.cancel() }
        _ = hid.send(held: [])
        syncHoldTimer([])
        DispatchQueue.main.async { [weak self] in
            for key in keys { self?.post(key: key, down: false, repeating: false) }
        }
        return []
    }

    func currentlyHeld() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(held.keys)
    }

    private func apply(key: String, down: Bool) -> Set<String> {
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
        _ = hid.send(held: snapshot)
        syncHoldTimer(snapshot)
        if shouldPost {
            DispatchQueue.main.async { [weak self] in
                self?.post(key: key, down: postDown, repeating: false)
            }
        }
        return snapshot
    }

    private func cancelMoveRelease(_ key: String) {
        lock.lock()
        let work = delayedMoveUps.removeValue(forKey: key)
        lock.unlock()
        work?.cancel()
    }

    private func scheduleMoveRelease(_ key: String) {
        cancelMoveRelease(key)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let pending = self.delayedMoveUps.removeValue(forKey: key)
            self.lock.unlock()
            guard pending != nil else { return }
            let snapshot = self.apply(key: key, down: false)
            self.onHeldChanged?(snapshot)
        }
        lock.lock()
        delayedMoveUps[key] = work
        lock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + moveReleaseDelay, execute: work)
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

    private func syncHoldTimer(_ snapshot: Set<String>) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if snapshot.isEmpty {
                self.holdTimer?.cancel()
                self.holdTimer = nil
                self.holdStartedAt = nil
                self.faceHoldStartedAt = nil
                self.turboDown = true
                return
            }
            if self.holdTimer != nil { return }
            self.holdStartedAt = Date()
            self.turboDown = true
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + .milliseconds(16), repeating: .milliseconds(16))
            timer.setEventHandler { [weak self] in self?.repeatHeld() }
            timer.resume()
            self.holdTimer = timer
        }
    }

    private func repeatHeld() {
        let keys = currentlyHeld()
        guard !keys.isEmpty else { return }

        let dirs = keys.intersection(moveKeys)
        let faces = keys.intersection(faceKeys)
        let rest = keys.subtracting(moveKeys).subtracting(faceKeys)
        var hidKeys = dirs.union(rest)

        let elapsed: TimeInterval
        if faces.isEmpty {
            faceHoldStartedAt = nil
            turboDown = true
            elapsed = 0
        } else {
            if faceHoldStartedAt == nil {
                faceHoldStartedAt = Date()
                turboDown = true
            }
            elapsed = Date().timeIntervalSince(faceHoldStartedAt ?? Date())
        }
        var facesDown = true
        if !faces.isEmpty, elapsed >= turboDelay {
            let phase = (elapsed - turboDelay).truncatingRemainder(dividingBy: turboPeriod)
            facesDown = phase < turboDownDuty
        }
        if facesDown {
            hidKeys.formUnion(faces)
        }

        if facesDown != turboDown {
            turboDown = facesDown
            for key in faces {
                post(key: key, down: facesDown, repeating: false)
            }
        }
        _ = hid.send(held: hidKeys)
    }

    private func post(key: String, down: Bool, repeating: Bool) {
        guard let code = codes[key], let event = makeEvent(code: code, key: key, down: down, repeating: repeating) else { return }

        guard let target = targetApp() else {
            event.post(tap: .cghidEventTap)
            if !repeating {
                lastStatus = "No front app. Click Cursor or TextEdit, then press again."
            }
            return
        }

        targetName = target.localizedName ?? "unknown"
        let pids = inputPids(for: target)
        for pid in pids {
            event.postToPid(pid)
        }
        if let front = NSWorkspace.shared.frontmostApplication, !isSelf(front) {
            event.post(tap: .cghidEventTap)
        }

        lastStatus = "\(key) \(down ? "down" : "up")\(repeating ? " hold" : "") → \(targetName)  ax=\(Self.isTrusted) hid=\(hid.isReady) pids=\(pids.count)"
    }

    private func makeEvent(code: CGKeyCode, key: String, down: Bool, repeating: Bool) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { return nil }
        event.flags = []
        event.setIntegerValueField(.keyboardEventAutorepeat, value: repeating ? 1 : 0)
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
