import FirebaseFunctions
import FirebaseFirestore
import Foundation
import Observation
import OSLog

enum RemoteCommandReceipt: Equatable {
    case none
    case pending
    case opened
    case failed
    case unconfirmed
    case expired

    var label: String {
        switch self {
        case .none: return ""
        case .pending: return "Pending"
        case .opened: return "Opened"
        case .failed: return "Failed"
        case .unconfirmed: return "Not confirmed yet"
        case .expired: return "Request expired"
        }
    }
}

enum RemoteCommandChatCopy {
    enum Subject {
        case homepage
        case video
        case page
    }

    static func askingMessage(for subject: Subject) -> String {
        switch subject {
        case .homepage:
            return LocalizationManager.shared.localizedString("Asking your Mac to open YouTube…")
        case .video:
            return LocalizationManager.shared.localizedString("Asking your Mac to open this video…")
        case .page:
            return LocalizationManager.shared.localizedString("Asking your Mac to open this page…")
        }
    }

    static func invalidURLMessage(for subject: Subject = .video) -> String {
        switch subject {
        case .homepage, .video:
            return LocalizationManager.shared.localizedString("That YouTube link cannot be opened on your Mac")
        case .page:
            return LocalizationManager.shared.localizedString("That link cannot be opened on your Mac")
        }
    }

    static func message(for receipt: RemoteCommandReceipt, subject: Subject = .homepage) -> String {
        switch receipt {
        case .opened:
            switch subject {
            case .homepage:
                return LocalizationManager.shared.localizedString("YouTube opened on your Mac")
            case .video:
                return LocalizationManager.shared.localizedString("This video opened on your Mac")
            case .page:
                return LocalizationManager.shared.localizedString("This page opened on your Mac")
            }
        case .failed, .none:
            switch subject {
            case .homepage:
                return LocalizationManager.shared.localizedString("Your Mac could not open YouTube")
            case .video:
                return LocalizationManager.shared.localizedString("Your Mac could not open this video")
            case .page:
                return LocalizationManager.shared.localizedString("Your Mac could not open this page")
            }
        case .expired: return "Request expired. Try again."
        case .unconfirmed, .pending:
            return LocalizationManager.shared.localizedString(
                "Your Mac has not confirmed this request yet"
            )
        }
    }
}

enum RemoteCommandMapping {
    static let youtubeURL = "https://www.youtube.com"
    static let pendingTimeout: TimeInterval = 20

    static func isSettled(_ receipt: RemoteCommandReceipt) -> Bool {
        switch receipt {
        case .opened, .failed, .unconfirmed, .expired:
            return true
        case .none, .pending:
            return false
        }
    }

    static func receipt(
        status: String?,
        pendingSince: Date?,
        now: Date = Date()
    ) -> RemoteCommandReceipt {
        switch status {
        case "opened":
            return .opened
        case "failed":
            return .failed
        case "expired": return .expired
        case "claimed":
            return .pending
        case "pending":
            if let pendingSince, now.timeIntervalSince(pendingSince) >= pendingTimeout {
                return .unconfirmed
            }
            return .pending
        default:
            return .none
        }
    }

    static func commandId(from data: Any) -> String? {
        if let dict = data as? [String: Any] {
            return dict["commandId"] as? String
        }
        if let dict = data as? NSDictionary {
            return dict["commandId"] as? String
        }
        return nil
    }

    /// Returns `https://www.youtube.com/watch?v=VIDEO_ID` when `raw` is an allowlisted watch URL.
    static func canonicalWatchURL(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host?.lowercased() else {
            return nil
        }

        let videoID: String?
        if host == "youtu.be" || host == "www.youtu.be" {
            let parts = url.path.split(separator: "/").map(String.init)
            guard parts.count == 1 else { return nil }
            videoID = parts[0]
        } else if host == "youtube.com" || host == "www.youtube.com" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard path == "watch" else { return nil }
            videoID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "v" })?
                .value
        } else {
            return nil
        }

        guard let videoID, isYouTubeVideoID(videoID) else { return nil }
        return "https://www.youtube.com/watch?v=\(videoID)"
    }

    /// Returns a canonical https URL when `raw` is on an allowlisted documentation host.
    static func canonicalDocumentationURL(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.port == nil || components.port == 443 else {
            return nil
        }

        let canonicalHost: String
        switch host {
        case "developer.apple.com", "www.developer.apple.com":
            canonicalHost = "developer.apple.com"
        case "docs.swift.org":
            canonicalHost = "docs.swift.org"
        case "swift.org", "www.swift.org":
            canonicalHost = "swift.org"
        default:
            return nil
        }

        components.scheme = "https"
        components.host = canonicalHost
        components.user = nil
        components.password = nil
        components.port = nil
        components.fragment = nil
        if components.path.isEmpty {
            components.path = "/"
        }
        return components.string
    }

    private static func isYouTubeVideoID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil
    }
}

/// App-session registry. Every request owns its snapshot listener and receipt.
@Observable @MainActor
final class RemoteCommandClient {
    private(set) var trackers: [String: RemoteCommandTracker] = [:]
    private(set) var latestTracker: RemoteCommandTracker?
    private(set) var isSending = false
    private var signedInUID: String?
    private var submitted = Set<String>()
    private var observationTask: Task<Void, Never>?
    var receipt: RemoteCommandReceipt {
        switch latestTracker?.activity.phase {
        case "opened", "completed": .opened
        case "failed": .failed
        case "expired": .expired
        case "unconfirmed": .unconfirmed
        case nil: .none
        default: .pending
        }
    }
    func attach(authManager: AuthenticationManager) {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let next: String? = if case .authenticated(let uid) = authManager.authState { uid } else { nil }
                if self.signedInUID != next {
                    self.trackers.values.forEach { $0.cancelWaiting() }
                    self.trackers.removeAll(); self.submitted.removeAll(); self.latestTracker = nil; self.signedInUID = next
                }
                await withCheckedContinuation { continuation in
                    withObservationTracking { _ = authManager.authState } onChange: { continuation.resume() }
                }
            }
        }
    }
    func reconnect(uid: String, id: String, taskSummary: String) -> RemoteCommandTracker? {
        guard uid == signedInUID else { return nil }
        if let tracker = trackers[id] { return tracker }
        let tracker = RemoteCommandTracker(uid: uid, id: id, taskSummary: taskSummary)
        trackers[id] = tracker; tracker.listen(); return tracker
    }
    func start(function: String, id: String = UUID().uuidString, arguments: [String: String] = [:]) async throws -> RemoteCommandTracker {
        guard let uid = signedInUID else { throw RemoteCommandStartError.signInRequired }
        let tracker = trackers[id] ?? RemoteCommandTracker(uid: uid, id: id, taskSummary: arguments["taskSummary"] ?? "")
        guard submitted.insert(id).inserted else { return tracker }
        trackers[id] = tracker; latestTracker = tracker
        tracker.listen() // ID is known before transport; an uncertain response still has a receipt path.
        let payload = arguments.merging(["requestId": id]) { _, new in new }
        isSending = true
        defer { isSending = false }
        do {
            let result = try await Functions.functions(region: "us-central1").httpsCallable(function).call(payload)
            guard signedInUID == uid else { tracker.cancelWaiting(); throw CancellationError() }
            guard RemoteCommandMapping.commandId(from: result.data) == id else { throw RemoteCommandStartError.unavailable }
        } catch let error as NSError {
            if signedInUID != uid { tracker.cancelWaiting(); throw CancellationError() }
            let definitive = [FunctionsErrorCode.invalidArgument.rawValue, FunctionsErrorCode.permissionDenied.rawValue,
                FunctionsErrorCode.unauthenticated.rawValue, FunctionsErrorCode.resourceExhausted.rawValue,
                FunctionsErrorCode.alreadyExists.rawValue].contains(error.code)
            let detail = error.userInfo[FunctionsErrorDetailsKey] as? [String: Any]
            if definitive || detail?["failureCode"] != nil { tracker.fail(detail?["failureCode"] as? String ?? "actionFailed") }
            else { tracker.uncertain() }
        }
        return tracker
    }
    func openYouTubeOnMac() async { _ = try? await start(function: "createOpenYouTube") }
    func openYouTubeVideoOnMac(url: String) async { _ = try? await start(function: "createOpenYouTubeVideo", arguments: ["url": url]) }
    func openURLOnMac(url: String) async { _ = try? await start(function: "createOpenURL", arguments: ["url": url]) }
}
public enum RemoteCommandStartError: LocalizedError {
    case signInRequired, noMac, unavailable
    public var errorDescription: String? {
        switch self {
        case .signInRequired: "Sign in to send this to your Mac."
        case .noMac: "Sign in on your Mac with the same account."
        case .unavailable: "Computer use is unavailable."
        }
    }
}
