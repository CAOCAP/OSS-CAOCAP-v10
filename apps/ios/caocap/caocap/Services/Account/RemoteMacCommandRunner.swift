import Foundation

@MainActor
public protocol RemoteMacCommandRunning: AnyObject {
    func requestOpenYouTubeOnMac() async -> String
    func requestOpenYouTubeVideoOnMac(url: String) async -> String
    func requestOpenURLOnMac(url: String) async -> String
    func startComputerUseOnMac(requestId: String, taskSummary: String) async throws -> RemoteCommandTracker
    func reconnectCommand(uid: String, commandID: String, taskSummary: String) -> RemoteCommandTracker?
}
public extension RemoteMacCommandRunning {
    func startComputerUseOnMac(requestId: String, taskSummary: String) async throws -> RemoteCommandTracker { throw RemoteCommandStartError.unavailable }
    func reconnectCommand(uid: String, commandID: String, taskSummary: String) -> RemoteCommandTracker? { nil }
}
@MainActor
final class RemoteMacCommandRunner: RemoteMacCommandRunning {
    private let client: RemoteCommandClient
    private let authManager: AuthenticationManager
    private let devicePresence: DevicePresence
    init(client: RemoteCommandClient, authManager: AuthenticationManager, devicePresence: DevicePresence) {
        self.client = client; self.authManager = authManager; self.devicePresence = devicePresence
    }
    private func preflight() throws {
        guard authManager.isAuthenticated else { throw RemoteCommandStartError.signInRequired }
        guard devicePresence.otherDevices.contains(where: { $0.platform == "macos" }) else { throw RemoteCommandStartError.noMac }
    }
    func startComputerUseOnMac(requestId: String, taskSummary: String) async throws -> RemoteCommandTracker {
        try preflight()
        return try await client.start(function: "createComputerUseTask", id: requestId, arguments: ["taskSummary": taskSummary])
    }
    func reconnectCommand(uid: String, commandID: String, taskSummary: String) -> RemoteCommandTracker? {
        client.reconnect(uid: uid, id: commandID, taskSummary: taskSummary)
    }
    func requestOpenYouTubeOnMac() async -> String { await open("createOpenYouTube") }
    func requestOpenYouTubeVideoOnMac(url: String) async -> String {
        guard let url = RemoteCommandMapping.canonicalWatchURL(from: url) else { return RemoteCommandChatCopy.invalidURLMessage() }
        return await open("createOpenYouTubeVideo", args: ["url": url])
    }
    func requestOpenURLOnMac(url: String) async -> String {
        guard let url = RemoteCommandMapping.canonicalDocumentationURL(from: url) else { return RemoteCommandChatCopy.invalidURLMessage(for: .page) }
        return await open("createOpenURL", args: ["url": url])
    }
    private func open(_ function: String, args: [String: String] = [:]) async -> String {
        do {
            try preflight()
            let tracker = try await client.start(function: function, arguments: args)
            for await update in tracker.updates() {
                if update.terminal || update.phase == "unconfirmed" { return update.summary }
                if Task.isCancelled { return "Stopped waiting. Your Mac may still finish this request." }
            }
            return tracker.activity.summary
        } catch { return error.localizedDescription }
    }
}
