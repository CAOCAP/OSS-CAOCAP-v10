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
    case macRequestsOff

    var label: String {
        switch self {
        case .none: return ""
        case .pending: return "Pending"
        case .opened: return "Opened"
        case .failed: return "Failed"
        case .macRequestsOff: return "Mac has requests off"
        }
    }
}

enum RemoteCommandMapping {
    static let youtubeURL = "https://www.youtube.com"
    static let pendingTimeout: TimeInterval = 20

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
        case "claimed":
            return .pending
        case "pending":
            if let pendingSince, now.timeIntervalSince(pendingSince) >= pendingTimeout {
                return .macRequestsOff
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
}

/// Creates allowlisted openYouTube commands and surfaces the receipt from Firestore.
@Observable
@MainActor
final class RemoteCommandClient {
    private(set) var receipt: RemoteCommandReceipt = .none
    private(set) var isSending = false

    private let logger = Logger(subsystem: "com.caocap.app", category: "RemoteCommand")
    private var listener: ListenerRegistration?
    private var timeoutTask: Task<Void, Never>?
    private var pendingSince: Date?
    private var lastStatus: String?
    private var observationTask: Task<Void, Never>?
    private var signedInUID: String?

    func attach(authManager: AuthenticationManager) {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.apply(authManager.authState)
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = authManager.authState
                    } onChange: {
                        continuation.resume()
                    }
                }
            }
        }
    }

    func openYouTubeOnMac() async {
        guard !isSending, let uid = signedInUID else { return }
        isSending = true
        receipt = .pending
        pendingSince = Date()
        stopListening()
        do {
            let result = try await Functions.functions(region: "us-central1")
                .httpsCallable("createOpenYouTube")
                .call()
            let data = result.data
            guard let commandId = RemoteCommandMapping.commandId(from: data) else {
                throw NSError(
                    domain: "RemoteCommandClient",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing command id."]
                )
            }
            listen(uid: uid, commandId: commandId)
            startTimeoutWatch()
        } catch {
            logger.error("createOpenYouTube failed: \(error.localizedDescription, privacy: .public)")
            receipt = .failed
            pendingSince = nil
        }
        isSending = false
    }

    private func apply(_ state: AuthState) {
        switch state {
        case .authenticated(let uid):
            signedInUID = uid
        case .anonymous, .loading, .failed:
            signedInUID = nil
            stopListening()
            timeoutTask?.cancel()
            receipt = .none
            pendingSince = nil
            lastStatus = nil
        }
    }

    private func listen(uid: String, commandId: String) {
        listener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("commands")
            .document(commandId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.logger.error("Command listener failed: \(error.localizedDescription, privacy: .public)")
                        self.receipt = .failed
                        return
                    }
                    let status = snapshot?.data()?["status"] as? String
                    self.lastStatus = status
                    self.receipt = RemoteCommandMapping.receipt(
                        status: status,
                        pendingSince: self.pendingSince
                    )
                    if self.receipt == .opened || self.receipt == .failed {
                        self.timeoutTask?.cancel()
                    }
                }
            }
    }

    private func startTimeoutWatch() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(RemoteCommandMapping.pendingTimeout))
            guard !Task.isCancelled, let self else { return }
            if self.receipt == .pending, self.lastStatus == "pending" || self.lastStatus == nil {
                self.receipt = .macRequestsOff
            }
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }
}
