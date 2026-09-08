import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

public struct RemoteCommandActivity: Codable, Hashable {
    public let uid: String
    public let commandID: String
    public var taskSummary: String
    public var phase: String = "pending"
    public var steps: [String] = []
    public var fileName: String?
    public var previewText: String?
    public var previewTruncated = false
    public var failureCode: String?
    public var terminal: Bool { ["opened", "completed", "failed", "expired"].contains(phase) }
    public var summary: String {
        switch phase {
        case "pending": "Waiting for your Mac…"
        case "claimed": "Your Mac received the request"
        case "running": "Working in TextEdit on your Mac…"
        case "opened": "Opened on your Mac"
        case "completed": "Saved \(fileName ?? "document") on your Mac"
        case "expired": "Request expired. Try again."
        case "unconfirmed": failureCode == "reportingDeadline" ? "Your Mac stopped reporting." : "Your Mac has not confirmed this request. It may still be working."
        case "failed": Self.failureMessage(failureCode)
        default: "Checking your Mac’s result…"
        }
    }
    public static func failureMessage(_ code: String?) -> String {
        switch code {
        case "setupIncomplete": "Finish computer-use setup on your Mac first."
        case "noWorkspaceFolder": "Choose a working folder on your Mac first."
        case "busy": "Your Mac is already working on a task."
        case "stoppedOnMac": "Stopped on your Mac. Partial work may remain."
        case "quotaExceeded": "The computer-use allowance has been reached."
        case "runTimeout", "stepLimitExceeded": "The task reached its limit. Partial work may remain on your Mac."
        case "serviceUnavailable", "modelUnavailable": "Computer use is temporarily unavailable."
        case "documentChanged": "A change to the TextEdit document interrupted the task."
        case "signInRequired": "Sign in to send this to your Mac."
        case "noMac": "Sign in on your Mac with the same account, then try again."
        default: "The task could not finish. Check your Mac; partial work may remain."
        }
    }
}

@MainActor @Observable
public final class RemoteCommandTracker: Identifiable {
    public let id: String
    public private(set) var activity: RemoteCommandActivity
    private var listener: ListenerRegistration?
    private var timer: Task<Void, Never>?
    private var subscribers: [UUID: AsyncStream<RemoteCommandActivity>.Continuation] = [:]
    private var data: [String: Any]?
    private var lastPublished: RemoteCommandActivity?
    private var stopped = false
    private var expiring = false
    init(uid: String, id: String, taskSummary: String) {
        self.id = id; self.activity = RemoteCommandActivity(uid: uid, commandID: id, taskSummary: taskSummary)
    }
    public func updates() -> AsyncStream<RemoteCommandActivity> {
        let key = UUID()
        return AsyncStream { continuation in
            continuation.yield(activity)
            if activity.terminal || stopped { continuation.finish(); return }
            subscribers[key] = continuation
            continuation.onTermination = { [weak self] _ in Task { @MainActor in self?.subscribers.removeValue(forKey: key) } }
        }
    }
    func listen() {
        guard listener == nil, !stopped else { return }
        let uid = activity.uid
        let ref = Firestore.firestore().document("users/\(uid)/commands/\(id)")
        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, !self.stopped, Auth.auth().currentUser?.uid == uid else { return }
                if error != nil { self.activity.phase = "unconfirmed"; self.publish(); return }
                if let value = snapshot?.data(), snapshot?.metadata.hasPendingWrites == false { self.data = value; self.apply(value) }
            }
        }
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, !self.stopped else { return }
                guard let data = self.data else { continue }
                self.apply(data)
                if data["status"] as? String == "pending", let expires = data["expiresAt"] as? Timestamp,
                   expires.dateValue() <= Date(), !self.expiring {
                    self.expiring = true
                    _ = try? await Firestore.firestore().runTransaction { tx, error in
                        do {
                            let value = try tx.getDocument(ref).data()
                            if value?["status"] as? String == "pending" { tx.updateData(["status": "expired", "finishedAt": FieldValue.serverTimestamp()], forDocument: ref) }
                        } catch let failure { error?.pointee = failure as NSError }
                        return nil
                    }
                    self.expiring = false
                }
            }
        }
    }
    /// Pure snapshot application is also the regression-test seam; no global receipt state.
    func apply(_ data: [String: Any], now: Date = Date()) {
        guard !stopped, data["requestId"] as? String == id, data["schemaVersion"] as? Int == 2 else { return }
        let phase = data["status"] as? String ?? "unconfirmed"
        activity.phase = phase
        activity.steps = (data["steps"] as? [[String: Any]] ?? []).prefix(20).compactMap { $0["summary"] as? String }
        activity.failureCode = data["failureCode"] as? String
        if let result = data["result"] as? [String: Any], phase == "completed",
           let name = result["fileName"] as? String, let preview = result["previewText"] as? String,
           !name.isEmpty, !name.contains("/"), !name.contains("\\"), !preview.isEmpty {
            activity.fileName = name
            activity.previewText = String(String.UnicodeScalarView(preview.unicodeScalars.prefix(8000)))
            activity.previewTruncated = result["previewTruncated"] as? Bool ?? false
        } else if phase == "completed" { activity.phase = "failed"; activity.failureCode = "noResultFile" }
        if !activity.terminal {
            let deadline = (data["reportingDeadline"] as? Timestamp)?.dateValue()
            let created = (data["createdAt"] as? Timestamp)?.dateValue()
            if deadline.map({ now >= $0 }) == true || (data["type"] as? String != "computerUse" && created.map({ now.timeIntervalSince($0) >= 20 }) == true) { activity.phase = "unconfirmed" }
        }
        if !activity.terminal, let deadline = (data["reportingDeadline"] as? Timestamp)?.dateValue(), now >= deadline { activity.failureCode = "reportingDeadline" }
        publish()
        if activity.terminal { detach() }
    }
    func fail(_ code: String) { activity.phase = "failed"; activity.failureCode = code; publish(); detach() }
    func uncertain() { activity.phase = "unconfirmed"; publish() }
    private func publish() {
        guard lastPublished != activity else { return }
        lastPublished = activity
        subscribers.values.forEach { $0.yield(activity) }
    }
    public func cancelWaiting() { detach() }
    private func detach() {
        stopped = true; listener?.remove(); listener = nil; timer?.cancel(); timer = nil
        subscribers.values.forEach { $0.finish() }; subscribers.removeAll()
    }
}
