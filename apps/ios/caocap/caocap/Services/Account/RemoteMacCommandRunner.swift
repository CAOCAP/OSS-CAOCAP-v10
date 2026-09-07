import Foundation

/// CoCaptain-facing Mac command surface. Preflight, create, and wait for a receipt.
@MainActor
public protocol RemoteMacCommandRunning: AnyObject {
    func requestOpenYouTubeOnMac() async -> String
}

/// Runs the allowlisted Open YouTube command and returns localized chat copy.
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
        guard authManager.isAuthenticated else {
            return LocalizationManager.shared.localizedString("Sign in to send this to your Mac")
        }
        guard devicePresence.otherDevices.contains(where: { $0.platform == "macos" }) else {
            return LocalizationManager.shared.localizedString(
                "No Mac is signed in with this account"
            )
        }
        await client.openYouTubeOnMac()
        let settled = await client.waitUntilSettled()
        return RemoteCommandChatCopy.message(for: settled)
    }
}
