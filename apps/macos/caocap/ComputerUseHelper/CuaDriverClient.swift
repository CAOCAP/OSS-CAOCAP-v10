import AppKit
import ApplicationServices
import Foundation

/// Long-standing private AX SPI. It is the only way to map an AXUIElement to its
/// CGWindowID without CGWindowListCopyWindowInfo, which silently returns nothing
/// for other apps unless the calling process holds Screen Recording. We ship
/// Developer ID, not App Store, and fall back to the public path if it fails.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

struct ComputerUseDriverStatus: Codable {
    let installed: Bool
    let running: Bool
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
}

/// Owns a bundled runtime, never the user's global cua-driver daemon.
final class CuaDriverClient: @unchecked Sendable {
    private let lock = NSLock()
    private var activeProcess: Process?
    private var cancelled = false
    private var documentURL: URL?
    private var daemon: Process?
    private let socketDirectory = CuaDriverClient.makeSocketDirectory()
    private var socket: String { socketDirectory.appendingPathComponent(Self.socketName).path }

    static let socketName = "driver.sock"
    /// sockaddr_un.sun_path is 104 bytes on Darwin, including the terminator.
    static let maxSocketPathLength = 103

    /// Builds a socket directory whose full socket path fits in `sun_path`.
    ///
    /// The default temporary directory already costs ~49 characters in the helper
    /// and ~64 inside the sandboxed app's container, so appending a full 36-character
    /// UUID pushes the socket past the limit. `bind` then fails with
    /// "path must be shorter than SUN_LEN", the daemon never comes up, and the user
    /// is told to finish setup -- which is not the problem at all.
    static func makeSocketDirectory(
        base: URL = URL(fileURLWithPath: NSTemporaryDirectory()),
        token: String = String(UUID().uuidString.prefix(8))
    ) -> URL {
        let preferred = base.appendingPathComponent("caocap-\(token)")
        if socketPathFits(preferred) { return preferred }
        // /tmp keeps the prefix to five characters when the container path cannot.
        return URL(fileURLWithPath: "/tmp").appendingPathComponent("caocap-\(token)")
    }

    static func socketPathFits(_ directory: URL) -> Bool {
        directory.appendingPathComponent(socketName).path.utf8.count <= maxSocketPathLength
    }
    private var binary: URL? {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/cua-driver")
        if FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        #if DEBUG
        if let explicit = ProcessInfo.processInfo.environment["CAOCAP_DRIVER_PATH"], FileManager.default.isExecutableFile(atPath: explicit) { return URL(fileURLWithPath: explicit) }
        #endif
        return nil
    }

    func status() -> ComputerUseDriverStatus {
        ComputerUseDriverStatus(installed: binary != nil, running: daemon?.isRunning == true,
            accessibilityGranted: AXIsProcessTrusted(), screenRecordingGranted: CGPreflightScreenCaptureAccess())
    }
    func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestScreenCaptureAccess()
    }
    /// Spawns the bundled driver from this unsandboxed helper. The main app is
    /// sandboxed, and a sandboxed parent would pass its sandbox to the child --
    /// which can then never hold Accessibility or Screen Recording.
    func ensureDaemonRunning() throws {
        if daemon?.isRunning == true { return }
        guard let binary else { throw DriverError("setupIncomplete") }
        try FileManager.default.createDirectory(
            at: socketDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.removeItem(atPath: socket)
        let process = Process()
        process.executableURL = binary
        // TCC rolls an embedded XPC service's responsibility up to its containing app.
        process.arguments = ["serve", "--embedded", "--host-bundle-id", "com.Ficruty.caocap", "--socket", socket]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        daemon = process
        for _ in 0..<50 {
            if FileManager.default.fileExists(atPath: socket) { return }
            guard process.isRunning else { break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        terminateDaemon()
        throw DriverError("setupIncomplete")
    }
    private func terminateDaemon() {
        if let daemon, daemon.isRunning { daemon.terminate() }
        daemon = nil
        try? FileManager.default.removeItem(at: socketDirectory)
    }
    func prepareDocument(path: String) throws {
        lock.withLock { cancelled = false }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.lastPathComponent.hasPrefix("CAOCAP-"), url.pathExtension == "txt",
              let data = FileManager.default.contents(atPath: url.path), data.isEmpty,
              try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw DriverError("documentChanged") }
        documentURL = url
        try ensureDaemonRunning()
        _ = try execute(URL(fileURLWithPath: "/usr/bin/open"), ["-a", "TextEdit", url.path], timeout: 10)
        for _ in 0..<120 {
            if (try? target()) != nil { return }
            try checkCancellation()
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw DriverError("documentChanged")
    }
    func captureScreenshot(bundleIdentifier: String) throws -> Data {
        guard bundleIdentifier == "com.apple.TextEdit" else { throw DriverError("unsupportedTarget") }
        let target = try target()
        let temp = socketDirectory.appendingPathComponent("frame-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: temp) }
        let response = try call("get_window_state", ["pid": target.pid, "window_id": target.window, "include_accessibility_tree": false,
            "max_dimension": 1600, "screenshot_out_file": temp.path, "session": "caocap"])
        guard let data = try? Data(contentsOf: temp) else {
            // The driver omits an unprovable capture and still exits 0, naming the
            // reason (px_capture_unavailable / px_frame_mismatch) in its response.
            recordTargetFailure("no screenshot written; driver said: \(String(decoding: response, as: UTF8.self).prefix(1500))")
            throw DriverError("actionFailed")
        }
        guard data.count <= 4_194_304 else {
            recordTargetFailure("screenshot too large: \(data.count) bytes")
            throw DriverError("actionFailed")
        }
        return data
    }
    func performAction(_ action: [String: Any], bundleIdentifier: String) throws {
        guard bundleIdentifier == "com.apple.TextEdit" else { throw DriverError("unsupportedTarget") }
        let target = try target()
        let base: [String: Any] = ["pid": target.pid, "window_id": target.window, "session": "caocap"]
        switch action["type"] as? String {
        case "type":
            guard let text = action["text"] as? String, !text.isEmpty, text.utf16.count <= 8000 else { throw DriverError("invalidModelAction") }
            _ = try call("type_text", base.merging(["text": text]) { _, new in new })
        case "keypress":
            guard let keys = action["keys"] as? [String], ["cmd+s", "cmd+a", "left", "right", "up", "down", "backspace", "enter"].contains(keys.joined(separator: "+")) else { throw DriverError("invalidModelAction") }
            let tool = keys.count == 1 ? "press_key" : "hotkey"
            let args: [String: Any] = keys.count == 1 ? ["key": keys[0]] : ["keys": keys]
            _ = try call(tool, base.merging(args) { _, new in new })
        case "wait": Thread.sleep(forTimeInterval: 0.25)
        default: throw DriverError("invalidModelAction")
        }
        try checkCancellation()
        _ = try self.target()
    }
    func cancel() {
        lock.lock(); cancelled = true; let process = activeProcess; lock.unlock()
        if process?.isRunning == true { process?.terminate() }
    }
    func shutdown() {
        cancel()
        documentURL = nil
        terminateDaemon()
    }
    private func checkCancellation() throws {
        if lock.withLock({ cancelled }) { throw DriverError("stoppedOnMac") }
    }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private func editor(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        guard depth < 12 else { return nil }
        if attribute(element, kAXRoleAttribute) as? String == kAXTextAreaRole { return element }
        for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
            if let result = editor(in: child, depth: depth + 1) { return result }
        }
        return nil
    }
    /// AXDocument is a file URL string on some apps and a bare POSIX path on
    /// others. Comparing `URL` values directly makes the bare-path case never
    /// match, and the volume is case-insensitive, so normalize both sides to a
    /// resolved path and compare that instead.
    static func normalizedDocumentPath(_ raw: String) -> String? {
        guard !raw.isEmpty else { return nil }
        let url: URL
        if raw.lowercased().hasPrefix("file://") {
            guard let parsed = URL(string: raw) else { return nil }
            url = parsed
        } else {
            url = URL(fileURLWithPath: raw)
        }
        return url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func recordTargetFailure(_ reason: String) {
        #if DEBUG
        // Every branch below reports the same `documentChanged` code on the wire,
        // which makes a real failure impossible to tell apart from five others.
        try? reason.appending("\n").write(
            toFile: "/tmp/caocap-target-failure.txt", atomically: true, encoding: .utf8
        )
        #endif
    }

    private func target() throws -> (pid: Int, window: Int) {
        try checkCancellation()
        guard let documentURL else {
            recordTargetFailure("no prepared document"); throw DriverError("documentChanged")
        }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first else {
            recordTargetFailure("TextEdit is not running"); throw DriverError("documentChanged")
        }
        let wanted = documentURL.resolvingSymlinksInPath().path
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let windows = attribute(axApp, kAXWindowsAttribute) as? [AXUIElement] ?? []
        let matches = windows.filter { element in
            guard let raw = attribute(element, kAXDocumentAttribute) as? String,
                  let path = Self.normalizedDocumentPath(raw) else { return false }
            return path.compare(wanted, options: .caseInsensitive) == .orderedSame
        }
        guard matches.count == 1, let window = matches.first else {
            let seen = windows.compactMap { attribute($0, kAXDocumentAttribute) as? String }
            recordTargetFailure("wanted \(wanted); \(windows.count) window(s), \(matches.count) match(es); AXDocument seen: \(seen)")
            throw DriverError("documentChanged")
        }
        guard (attribute(window, "AXSheets") as? [AXUIElement] ?? []).isEmpty else {
            recordTargetFailure("a sheet is open over the document"); throw DriverError("documentChanged")
        }
        guard let editor = editor(in: window) else {
            recordTargetFailure("no text area found in the document window"); throw DriverError("documentChanged")
        }
        guard AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success,
              AXUIElementSetAttributeValue(editor, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else {
            recordTargetFailure("could not raise or focus the document (Accessibility?)"); throw DriverError("documentChanged")
        }
        var windowID = CGWindowID(0)
        if _AXUIElementGetWindow(window, &windowID) == .success, windowID != 0 {
            return (Int(app.processIdentifier), Int(windowID))
        }
        // Public fallback. Needs Screen Recording in this process, so it may find
        // nothing even though the window is plainly on screen.
        let records = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let title = attribute(window, kAXTitleAttribute) as? String
        let candidates = records.filter {
            ($0[kCGWindowOwnerPID as String] as? Int) == Int(app.processIdentifier)
            && ($0[kCGWindowName as String] as? String) == title
            && ($0[kCGWindowLayer as String] as? Int) == 0
        }
        guard candidates.count == 1, let id = candidates[0][kCGWindowNumber as String] as? Int else {
            let names = records.filter { ($0[kCGWindowOwnerPID as String] as? Int) == Int(app.processIdentifier) }
                .map { $0[kCGWindowName as String] as? String ?? "<nil>" }
            recordTargetFailure("AX window id unavailable; AX title \(title ?? "<nil>"); \(candidates.count) CGWindow match(es); names: \(names)")
            throw DriverError("documentChanged")
        }
        return (Int(app.processIdentifier), id)
    }
    private func call(_ tool: String, _ args: [String: Any]) throws -> Data {
        guard let binary else { throw DriverError("setupIncomplete") }
        return try execute(binary, ["call", tool, String(decoding: try JSONSerialization.data(withJSONObject: args), as: UTF8.self), "--socket", socket], timeout: 15)
    }
    private func execute(_ executable: URL, _ arguments: [String], timeout: TimeInterval) throws -> Data {
        try checkCancellation()
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: output.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: output) }
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }
        // Keep stderr. Discarding it turns every driver failure into a bare
        // "actionFailed" with no way to tell what the driver actually objected to.
        let errorFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: errorFile.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: errorFile) }
        let errorHandle = try FileHandle(forWritingTo: errorFile)
        defer { try? errorHandle.close() }
        let process = Process(); process.executableURL = executable; process.arguments = arguments
        process.standardOutput = handle; process.standardError = errorHandle
        lock.withLock { activeProcess = process }
        defer { lock.withLock { activeProcess = nil } }
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if lock.withLock({ cancelled }) || Date() >= deadline {
                process.terminate()
                Thread.sleep(forTimeInterval: 0.1)
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                throw DriverError(lock.withLock({ cancelled }) ? "stoppedOnMac" : "runTimeout")
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        guard process.terminationStatus == 0 else {
            let err = (try? String(contentsOf: errorFile, encoding: .utf8)) ?? ""
            let out = (try? String(contentsOf: output, encoding: .utf8)) ?? ""
            recordTargetFailure("""
                driver exited \(process.terminationStatus)
                argv: \(arguments.joined(separator: " "))
                stderr: \(err.prefix(1500))
                stdout: \(out.prefix(500))
                """)
            throw DriverError("actionFailed")
        }
        let data = try Data(contentsOf: output)
        guard data.count <= 8_388_608 else { throw DriverError("actionFailed") }
        return data
    }
}
struct DriverError: LocalizedError {
    let code: String
    init(_ code: String) { self.code = code }
    var errorDescription: String? { code }
}
