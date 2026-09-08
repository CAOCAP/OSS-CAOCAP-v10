import AppKit
import ApplicationServices
import Foundation

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
    private var socketDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("caocap-driver-\(UUID().uuidString)")
    private var socket: String { socketDirectory.appendingPathComponent("driver.sock").path }
    private var binary: URL? {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/cua-driver")
        if FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        #if DEBUG
        if let explicit = ProcessInfo.processInfo.environment["CAOCAP_DRIVER_PATH"], FileManager.default.isExecutableFile(atPath: explicit) { return URL(fileURLWithPath: explicit) }
        #endif
        return nil
    }

    func status() -> ComputerUseDriverStatus {
        ComputerUseDriverStatus(installed: binary != nil, running: FileManager.default.fileExists(atPath: socket),
            accessibilityGranted: AXIsProcessTrusted(), screenRecordingGranted: CGPreflightScreenCaptureAccess())
    }
    func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestScreenCaptureAccess()
    }
    func configure(socketPath: String) throws {
        let url = URL(fileURLWithPath: socketPath).standardizedFileURL
        guard url.lastPathComponent == "driver.sock", url.deletingLastPathComponent().lastPathComponent.hasPrefix("caocap-driver-"),
              FileManager.default.fileExists(atPath: url.path) else { throw DriverError("setupIncomplete") }
        socketDirectory = url.deletingLastPathComponent()
    }
    func prepareDocument(path: String) throws {
        lock.withLock { cancelled = false }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.lastPathComponent.hasPrefix("CAOCAP-"), url.pathExtension == "txt",
              let data = FileManager.default.contents(atPath: url.path), data.isEmpty,
              try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw DriverError("documentChanged") }
        documentURL = url
        guard FileManager.default.fileExists(atPath: socket) else { throw DriverError("setupIncomplete") }
        _ = try execute(URL(fileURLWithPath: "/usr/bin/open"), ["-a", "TextEdit", url.path], timeout: 10)
        for _ in 0..<30 {
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
        _ = try call("get_window_state", ["pid": target.pid, "window_id": target.window, "include_accessibility_tree": false,
            "max_dimension": 1600, "screenshot_out_file": temp.path, "session": "caocap"])
        let data = try Data(contentsOf: temp)
        guard data.count <= 4_194_304 else { throw DriverError("actionFailed") }
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
    private func target() throws -> (pid: Int, window: Int) {
        try checkCancellation()
        guard let documentURL, let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first else { throw DriverError("documentChanged") }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let windows = attribute(axApp, kAXWindowsAttribute) as? [AXUIElement] ?? []
        let matches = windows.filter { element in
            guard let raw = attribute(element, kAXDocumentAttribute) as? String,
                  let url = URL(string: raw) else { return false }
            return url.standardizedFileURL == documentURL
        }
        guard matches.count == 1, let window = matches.first,
              (attribute(window, "AXSheets") as? [AXUIElement] ?? []).isEmpty,
              let editor = editor(in: window) else { throw DriverError("documentChanged") }
        guard AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success,
              AXUIElementSetAttributeValue(editor, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else { throw DriverError("documentChanged") }
        let records = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = records.filter {
            ($0[kCGWindowOwnerPID as String] as? Int) == Int(app.processIdentifier)
            && ($0[kCGWindowName as String] as? String) == (attribute(window, kAXTitleAttribute) as? String)
            && ($0[kCGWindowLayer as String] as? Int) == 0
        }
        guard candidates.count == 1, let id = candidates[0][kCGWindowNumber as String] as? Int else { throw DriverError("documentChanged") }
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
        let process = Process(); process.executableURL = executable; process.arguments = arguments
        process.standardOutput = handle; process.standardError = FileHandle.nullDevice
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
        guard process.terminationStatus == 0 else { throw DriverError("actionFailed") }
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
