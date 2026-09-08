import AppKit
import FirebaseAuth
import Foundation
import Observation

@MainActor @Observable
final class GitHubSignInCoordinator {
    private(set) var userCode: String?
    private var cancelled = false
    func cancel() { cancelled = true; userCode = nil }
    func credential() async throws -> AuthCredential {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GitHubOAuthClientID") as? String,
              !clientID.isEmpty, !clientID.contains("$(") else { throw GitHubSignInError.configuration }
        cancelled = false
        defer { userCode = nil }
        let response = try await post("https://github.com/login/device/code", ["client_id": clientID, "scope": "read:user user:email"])
        guard let deviceCode = response["device_code"] as? String, let code = response["user_code"] as? String,
              let expires = response["expires_in"] as? Double, let initialInterval = response["interval"] as? Double else { throw GitHubSignInError.response }
        userCode = code
        NSWorkspace.shared.open(URL(string: "https://github.com/login/device")!)
        let deadline = Date().addingTimeInterval(expires)
        var interval = max(initialInterval, 5)
        while Date() < deadline {
            try await Task.sleep(for: .seconds(interval))
            guard !cancelled else { throw CancellationError() }
            let token = try await post("https://github.com/login/oauth/access_token", ["client_id": clientID, "device_code": deviceCode, "grant_type": "urn:ietf:params:oauth:grant-type:device_code"])
            if let access = token["access_token"] as? String { return GitHubAuthProvider.credential(withToken: access) }
            switch token["error"] as? String {
            case "authorization_pending": continue
            case "slow_down": interval += 5
            case "access_denied": throw CancellationError()
            case "expired_token": throw GitHubSignInError.expired
            default: throw GitHubSignInError.response
            }
        }
        throw GitHubSignInError.expired
    }
    private func post(_ endpoint: String, _ values: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: values)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw GitHubSignInError.response }
        return result
    }
}
private enum GitHubSignInError: LocalizedError {
    case configuration, response, expired
    var errorDescription: String? {
        switch self {
        case .configuration: "This build is missing its GitHub OAuth client ID."
        case .response: "GitHub sign-in could not finish. Please try again."
        case .expired: "The GitHub code expired. Please sign in again."
        }
    }
}
