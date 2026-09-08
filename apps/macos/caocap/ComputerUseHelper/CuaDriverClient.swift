import Foundation

struct ComputerUseDriverStatus: Codable {
    let installed: Bool
    let running: Bool
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
}

/// Talks to the externally-installed `cua-driver` binary (github.com/trycua/cua, v0.24.0).
/// This project never runs cua-driver's own installer — the user installs it by hand.
///
/// CLI surface confirmed empirically via `cua-driver manifest --pretty` and `cua-driver describe
/// <tool>` on the installed 0.24.0 binary (Sep 2026): `cua-driver serve` starts a persistent
/// daemon; `cua-driver call <tool> '<json>'` invokes one tool against that daemon (the `call`
/// subcommand prefix is required — there is no bare `cua-driver <tool>` form). Tool names/params
/// below match `describe`'s output for this version; a future cua-driver release could still
/// change them.
final class CuaDriverClient {
    private static let binaryCandidatePaths = [
        "/usr/local/bin/cua-driver",
        "/opt/homebrew/bin/cua-driver",
        "\(NSHomeDirectory())/.local/bin/cua-driver",
    ]

    private var serveProcess: Process?

    func status() -> ComputerUseDriverStatus {
        guard Self.resolvedBinaryPath() != nil else {
            return ComputerUseDriverStatus(installed: false, running: false, accessibilityGranted: false, screenRecordingGranted: false)
        }
        guard let permissionsData = try? callTool("check_permissions", argsJSON: ["prompt": false]),
              let json = try? JSONSerialization.jsonObject(with: permissionsData) as? [String: Any] else {
            return ComputerUseDriverStatus(installed: true, running: false, accessibilityGranted: false, screenRecordingGranted: false)
        }
        return ComputerUseDriverStatus(
            installed: true,
            running: true,
            accessibilityGranted: json["accessibility"] as? Bool ?? false,
            screenRecordingGranted: json["screen_recording"] as? Bool ?? false
        )
    }

    func ensureDaemonRunning() throws {
        guard let binaryPath = Self.resolvedBinaryPath() else {
            throw CuaDriverClientError.notInstalled
        }
        guard (try? callTool("list_apps", argsJSON: [:])) == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["serve"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        serveProcess = process

        // Give the daemon a moment to bind before the first tool call.
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Requests the OS Accessibility/Screen Recording prompts if not already granted.
    func requestPermissions() throws {
        _ = try callTool("check_permissions", argsJSON: ["prompt": true])
    }

    /// Captures a screenshot of the first on-screen window belonging to `bundleIdentifier`'s process.
    /// Throws `CuaDriverClientError.noMatchingWindow` if the app isn't running / has no windows.
    func captureScreenshot(bundleIdentifier: String) throws -> Data {
        let (pid, windowID) = try resolveTarget(bundleIdentifier: bundleIdentifier)

        let tempPath = NSTemporaryDirectory() + "cua-screenshot-\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        _ = try callTool("get_window_state", argsJSON: [
            "pid": pid,
            "window_id": windowID,
            "include_accessibility_tree": false,
            "screenshot_out_file": tempPath,
        ])

        guard let data = FileManager.default.contents(atPath: tempPath) else {
            throw CuaDriverClientError.unexpectedResponse
        }
        return data
    }

    /// Launches the app (in the background, per cua-driver's own default) and then explicitly
    /// brings it forward — `launch_app` alone deliberately never steals focus, but this phase
    /// needs the user to actually see CoCaptain working, and foregrounded interaction with
    /// dialogs/sheets is more reliable than fully-backgrounded automation.
    func launchApp(bundleIdentifier: String) throws {
        _ = try callTool("launch_app", argsJSON: ["bundle_id": bundleIdentifier])
        if let appsData = try? callTool("list_apps", argsJSON: [:]),
           let pid = Self.firstRunningPID(forBundleIdentifier: bundleIdentifier, in: appsData) {
            _ = try? callTool("bring_to_front", argsJSON: ["pid": pid])
        }
    }

    /// Translates one model-issued action (see computerUseTools in firebase/functions/src/index.ts)
    /// into the matching cua-driver tool call.
    func performAction(_ action: [String: Any], bundleIdentifier: String) throws {
        guard let type = action["type"] as? String else {
            throw CuaDriverClientError.unexpectedResponse
        }

        let (pid, windowID) = try resolveTarget(bundleIdentifier: bundleIdentifier)

        switch type {
        case "click":
            _ = try callTool("click", argsJSON: [
                "pid": pid,
                "window_id": windowID,
                "x": action["x"] as? Int ?? 0,
                "y": action["y"] as? Int ?? 0,
                "button": action["button"] as? String ?? "left",
            ])
        case "double_click":
            _ = try callTool("double_click", argsJSON: [
                "pid": pid,
                "window_id": windowID,
                "x": action["x"] as? Int ?? 0,
                "y": action["y"] as? Int ?? 0,
            ])
        case "type":
            _ = try callTool("type_text", argsJSON: [
                "pid": pid,
                "window_id": windowID,
                "text": action["text"] as? String ?? "",
            ])
        case "keypress":
            let keys = action["keys"] as? [String] ?? []
            if keys.count <= 1 {
                _ = try callTool("press_key", argsJSON: [
                    "pid": pid,
                    "window_id": windowID,
                    "key": keys.first ?? "",
                ])
            } else {
                _ = try callTool("hotkey", argsJSON: [
                    "pid": pid,
                    "window_id": windowID,
                    "keys": keys,
                ])
            }
        case "scroll":
            _ = try callTool("scroll", argsJSON: [
                "pid": pid,
                "window_id": windowID,
                "direction": action["direction"] as? String ?? "down",
                "amount": action["amount"] as? Int ?? 3,
                "by": action["by"] as? String ?? "line",
            ])
        case "wait":
            Thread.sleep(forTimeInterval: 1.0)
        default:
            throw CuaDriverClientError.unsupportedAction(type)
        }
    }

    /// Resolves the window to act on. Prefers whatever on-screen window is currently frontmost
    /// (highest z_index) over anything scoped to `bundleIdentifier`'s own pid: a native Open/Save
    /// panel from a sandboxed app is hosted out-of-process and belongs to a system panel service,
    /// not the app itself (per `describe get_window_state`'s `window_owner_pid_mismatch` note), so
    /// strictly following the target app's pid would miss it. Falls back to a bundle-scoped lookup
    /// only if no window list is available at all.
    private func resolveTarget(bundleIdentifier: String) throws -> (pid: Int, windowID: Int) {
        let windowsData = try callTool("list_windows", argsJSON: ["on_screen_only": true])
        if let frontmost = Self.frontmostWindow(in: windowsData) {
            return frontmost
        }

        let appsData = try callTool("list_apps", argsJSON: [:])
        guard let pid = Self.firstRunningPID(forBundleIdentifier: bundleIdentifier, in: appsData) else {
            throw CuaDriverClientError.noMatchingWindow
        }
        let windowsForPid = try callTool("list_windows", argsJSON: ["pid": pid, "on_screen_only": true])
        guard let windowID = Self.firstWindowID(in: windowsForPid) else {
            throw CuaDriverClientError.noMatchingWindow
        }
        return (pid, windowID)
    }

    private func callTool(_ name: String, argsJSON: [String: Any]) throws -> Data {
        guard let binaryPath = Self.resolvedBinaryPath() else {
            throw CuaDriverClientError.notInstalled
        }
        let argsData = try JSONSerialization.data(withJSONObject: argsJSON)
        let argsString = String(data: argsData, encoding: .utf8) ?? "{}"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["call", name, argsString]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CuaDriverClientError.toolCallFailed(name: name, exitCode: process.terminationStatus)
        }
        return outputPipe.fileHandleForReading.readDataToEndOfFile()
    }

    private static func resolvedBinaryPath() -> String? {
        if let found = binaryCandidatePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }
        return which("cua-driver")
    }

    private static func which(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty == false) ? path : nil
        } catch {
            return nil
        }
    }

    /// list_apps returns `pid: 0` for an installed-but-not-running app (per `describe list_apps`);
    /// the output bundle-id field name isn't shown in the schema description, so this tries the
    /// two most likely names.
    private static func firstRunningPID(forBundleIdentifier bundleIdentifier: String, in data: Data) -> Int? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let apps = (json as? [[String: Any]]) ?? (json as? [String: Any])?["apps"] as? [[String: Any]] ?? []
        let match = apps.first {
            (($0["bundle_id"] as? String) == bundleIdentifier || ($0["bundleIdentifier"] as? String) == bundleIdentifier)
                && ($0["running"] as? Bool == true)
        }
        guard let pid = match?["pid"] as? Int, pid != 0 else { return nil }
        return pid
    }

    private static func firstWindowID(in data: Data) -> Int? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let windows = (json as? [[String: Any]]) ?? (json as? [String: Any])?["windows"] as? [[String: Any]] ?? []
        return windows.first?["window_id"] as? Int
    }

    /// Per `describe list_windows`: "take the maximum integer z_index; if every value is null,
    /// use an explicit fallback instead of relying on array order" — falls back to the first
    /// listed window when no entry has a usable z_index.
    private static func frontmostWindow(in data: Data) -> (pid: Int, windowID: Int)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let windows = (json as? [[String: Any]]) ?? (json as? [String: Any])?["windows"] as? [[String: Any]] ?? []
        guard !windows.isEmpty else { return nil }

        let ranked = windows.max { lhs, rhs in
            (lhs["z_index"] as? Int ?? Int.min) < (rhs["z_index"] as? Int ?? Int.min)
        }
        let chosen = ranked?["z_index"] != nil ? ranked : windows.first

        guard let pid = chosen?["pid"] as? Int, let windowID = chosen?["window_id"] as? Int else {
            return nil
        }
        return (pid, windowID)
    }
}

enum CuaDriverClientError: Error {
    case notInstalled
    case noMatchingWindow
    case unexpectedResponse
    case unsupportedAction(String)
    case toolCallFailed(name: String, exitCode: Int32)
}
