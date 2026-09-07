import FirebaseFirestore
import Foundation
import Observation
import OSLog

struct LinkedDevice: Equatable, Identifiable {
    let id: String
    let platform: String
    let lastSeen: Date

    var displayName: String {
        switch platform {
        case "ios": return "iPhone"
        case "macos": return "Mac"
        default: return platform
        }
    }

    func menuLabel(now: Date = Date()) -> String {
        "\(displayName) · \(DevicePresenceMapping.lastSeenLabel(from: lastSeen, now: now))"
    }
}

enum DevicePresenceMapping {
    static func linkedDevices(
        documents: [(id: String, data: [String: Any])],
        excluding localDeviceId: String
    ) -> [LinkedDevice] {
        documents.compactMap { id, data -> LinkedDevice? in
            guard id != localDeviceId else { return nil }
            guard let platform = data["platform"] as? String, !platform.isEmpty else { return nil }
            guard let lastSeen = date(from: data["lastSeen"]) else { return nil }
            return LinkedDevice(id: id, platform: platform, lastSeen: lastSeen)
        }
        .sorted { $0.lastSeen > $1.lastSeen }
    }

    static func date(from value: Any?) -> Date? {
        if let date = value as? Date { return date }
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        return nil
    }

    static func lastSeenLabel(from date: Date, now: Date = Date()) -> String {
        if now.timeIntervalSince(date) < 45 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

/// Writes this Mac's heartbeat and listens for other devices on the same account.
@Observable
@MainActor
final class DevicePresence {
    private(set) var otherDevices: [LinkedDevice] = []

    private let logger = Logger(subsystem: "com.caocap.app", category: "DevicePresence")
    private let defaultsKey = "caocap.deviceId"

    private var listener: ListenerRegistration?
    private var heartbeatTask: Task<Void, Never>?
    private var observationTask: Task<Void, Never>?
    private var signedInUID: String?

    var localDeviceId: String {
        if let existing = UserDefaults.standard.string(forKey: defaultsKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: defaultsKey)
        return id
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

    func apply(_ state: MacAuthState) {
        switch state {
        case .signedIn(let uid):
            start(uid: uid)
        case .signedOut, .failed:
            stop()
        }
    }

    private func start(uid: String) {
        if signedInUID == uid, heartbeatTask != nil { return }
        stop()
        signedInUID = uid
        listen(uid: uid)
        heartbeatTask = Task { [weak self] in
            await self?.writeHeartbeat()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await self?.writeHeartbeat()
            }
        }
    }

    private func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        listener?.remove()
        listener = nil
        signedInUID = nil
        otherDevices = []
    }

    private func listen(uid: String) {
        let localId = localDeviceId
        listener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("devices")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.logger.error("Device listener failed: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    let documents = (snapshot?.documents ?? []).map { ($0.documentID, $0.data()) }
                    self.otherDevices = DevicePresenceMapping.linkedDevices(
                        documents: documents,
                        excluding: localId
                    )
                }
            }
    }

    private func writeHeartbeat() async {
        guard let uid = signedInUID else { return }
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("devices")
                .document(localDeviceId)
                .setData(
                    [
                        "platform": "macos",
                        "lastSeen": FieldValue.serverTimestamp()
                    ],
                    merge: true
                )
        } catch {
            logger.error("Heartbeat write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
