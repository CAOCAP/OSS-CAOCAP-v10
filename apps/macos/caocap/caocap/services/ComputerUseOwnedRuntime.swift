import Foundation

/// The application directly spawns the embedded daemon so TCC observes CAOCAP's responsibility chain.
@MainActor
final class ComputerUseOwnedRuntime {
    private var daemon: Process?
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("caocap-driver-\(UUID().uuidString)")
    var socket: String { directory.appendingPathComponent("driver.sock").path }
    var binary: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/XPCServices/ComputerUseHelper.xpc/Contents/Helpers/cua-driver") }
    var installed: Bool { FileManager.default.isExecutableFile(atPath: binary.path) }
    var running: Bool { daemon?.isRunning == true }
    func start() async throws {
        if running { return }
        guard installed else { throw ComputerUseFailure.setupIncomplete }
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? FileManager.default.removeItem(atPath: socket)
        let process = Process()
        process.executableURL = binary
        process.arguments = ["serve", "--embedded", "--host-bundle-id", Bundle.main.bundleIdentifier ?? "com.Ficruty.caocap", "--socket", socket]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); daemon = process
        do {
            for _ in 0..<50 {
                try Task.checkCancellation()
                guard process.isRunning else { throw ComputerUseFailure.setupIncomplete }
                if FileManager.default.fileExists(atPath: socket) { return }
                try await Task.sleep(for: .milliseconds(100))
            }
            throw ComputerUseFailure.setupIncomplete
        } catch { shutdown(); throw error }
    }
    func shutdown() {
        if let daemon, daemon.isRunning { daemon.terminate() }
        daemon = nil
        try? FileManager.default.removeItem(at: directory)
    }
}
