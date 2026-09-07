import Foundation

/// CoCaptain-facing Mac command surface. Preflight, create, and wait for a receipt.
@MainActor
public protocol RemoteMacCommandRunning: AnyObject {
    func requestOpenYouTubeOnMac() async -> String
    func requestOpenYouTubeVideoOnMac(url: String) async -> String
    func requestOpenURLOnMac(url: String) async -> String
}

/// Runs allowlisted Mac open commands and returns localized chat copy.
@MainActor
final class RemoteMacCommandRunner: RemoteMacCommandRunning {
    private let client: RemoteCommandClient
    private let authManager: AuthenticationManager
    private let devicePresence: DevicePresence

    init(
        client: RemoteCommandClient,
        authManager: AuthenticationManager,
        devicePresence: DevicePresence
    ) {
        self.client = client
        self.authManager = authManager
        self.devicePresence = devicePresence
    }

    func requestOpenYouTubeOnMac() async -> String {
        await requestOpen(subject: .homepage) {
            await client.openYouTubeOnMac()
        }
    }

    func requestOpenYouTubeVideoOnMac(url: String) async -> String {
        guard RemoteCommandMapping.canonicalWatchURL(from: url) != nil else {
            return RemoteCommandChatCopy.invalidURLMessage(for: .video)
        }
        return await requestOpen(subject: .video) {
            await client.openYouTubeVideoOnMac(url: url)
        }
    }

    func requestOpenURLOnMac(url: String) async -> String {
        guard RemoteCommandMapping.canonicalDocumentationURL(from: url) != nil else {
            return RemoteCommandChatCopy.invalidURLMessage(for: .page)
        }
        return await requestOpen(subject: .page) {
            await client.openURLOnMac(url: url)
        }
    }

    private func requestOpen(
        subject: RemoteCommandChatCopy.Subject,
        send: () async -> Void
    ) async -> String {
        guard authManager.isAuthenticated else {
            return LocalizationManager.shared.localizedString("Sign in to send this to your Mac")
        }
        guard devicePresence.otherDevices.contains(where: { $0.platform == "macos" }) else {
            return LocalizationManager.shared.localizedString(
                "No Mac is signed in with this account"
            )
        }
        await send()
        let settled = await client.waitUntilSettled()
        return RemoteCommandChatCopy.message(for: settled, subject: subject)
    }
}
