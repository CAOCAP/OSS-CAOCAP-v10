import AppKit
import FirebaseFirestore
import Foundation
import Observation
import OSLog

/// Listens for allowlisted openYouTube and openYouTubeVideo commands and opens them in the default browser.
/// Off until the user enables requests from iPhone.
@Observable
@MainActor
final class RemoteCommandRelay {
    private static let optInKey = "caocap.enableIPhoneRequests"
    private static let deviceIdKey = "caocap.deviceId"

    var requestsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(requestsEnabled, forKey: Self.optInKey)
            sync()
        }
    }

    private let logger = Logger(subsystem: "com.caocap.app", category: "RemoteCommandRelay")
    private var listener: ListenerRegistration?
    private var observationTask: Task<Void, Never>?
    private var signedInUID: String?
    private var claimingIDs: Set<String> = []

    private var localDeviceId: String {
        if let existing = UserDefaults.standard.string(forKey: Self.deviceIdKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: Self.deviceIdKey)
        return id
    }

    init() {
        requestsEnabled = UserDefaults.standard.bool(forKey: Self.optInKey)
    }

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

    private func apply(_ state: MacAuthState) {
        switch state {
        case .signedIn(let uid):
            signedInUID = uid
            sync()
        case .signedOut, .failed:
            signedInUID = nil
            stopListening()
        }
    }

    private func sync() {
        if let uid = signedInUID, requestsEnabled {
            startListening(uid: uid)
        } else {
            stopListening()
        }
    }

    private func startListening(uid: String) {
        if listener != nil { return }
        listener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("commands")
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.logger.error("Command listener failed: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    for document in snapshot?.documents ?? [] {
                        await self.handlePending(document)
                    }
                }
            }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
        claimingIDs.removeAll()
    }

    private func handlePending(_ document: QueryDocumentSnapshot) async {
        let id = document.documentID
        guard claimingIDs.insert(id).inserted else { return }

        let data = document.data()
        let type = data["type"] as? String
        let urlString = data["url"] as? String
        let urlToOpen: String?
        if type == "openYouTube", urlString == YouTubeWatchURL.homepage {
            urlToOpen = YouTubeWatchURL.homepage
        } else if type == "openYouTubeVideo" {
            urlToOpen = YouTubeWatchURL.canonicalWatchURL(from: urlString)
        } else {
            urlToOpen = nil
        }
        guard let urlToOpen else {
            claimingIDs.remove(id)
            logger.warning("Ignored command \(id, privacy: .public) with disallowed type or URL.")
            return
        }

        do {
            try await claim(document)
            let opened = openURL(urlToOpen)
            if opened {
                try await complete(document.reference, status: "opened", timestampField: "openedAt")
            } else {
                try await complete(document.reference, status: "failed", timestampField: "failedAt")
            }
            claimingIDs.remove(id)
        } catch {
            logger.error("Command \(id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            claimingIDs.remove(id)
        }
    }

    private func claim(_ document: QueryDocumentSnapshot) async throws {
        let deviceId = localDeviceId
        _ = try await Firestore.firestore().runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(document.reference)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            guard snapshot.data()?["status"] as? String == "pending" else {
                errorPointer?.pointee = NSError(
                    domain: "RemoteCommandRelay",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Command is no longer pending."]
                )
                return nil
            }
            transaction.updateData(
                [
                    "status": "claimed",
                    "claimedByDeviceId": deviceId,
                    "claimedAt": FieldValue.serverTimestamp()
                ],
                forDocument: document.reference
            )
            return nil
        }
    }

    private func complete(_ reference: DocumentReference, status: String, timestampField: String) async throws {
        try await reference.updateData([
            "status": status,
            timestampField: FieldValue.serverTimestamp()
        ])
    }

    private func openURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return NSWorkspace.shared.open(url)
    }
}
