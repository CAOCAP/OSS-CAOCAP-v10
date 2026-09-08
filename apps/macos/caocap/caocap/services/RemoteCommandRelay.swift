import AppKit
import FirebaseAuth
import FirebaseFirestore
import Observation

@MainActor @Observable
final class RemoteCommandRelay {
    var requestsEnabled = false {
        didSet {
            if let uid { UserDefaults.standard.set(requestsEnabled, forKey: "caocap.enableIPhoneRequests.\(uid)") }
            if !requestsEnabled { coordinator?.cancel() }
            sync()
        }
    }
    private(set) var lastRequest = "No requests yet"
    private var uid: String?
    private var epoch = UUID()
    private var listener: ListenerRegistration?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var handling = Set<String>()
    private var coordinator: ComputerUseRunCoordinator?
    private weak var companion: CompanionController?
    private var gate: ComputerUseInstallGate?
    private var localDeviceID: String {
        if let value = UserDefaults.standard.string(forKey: "caocap.deviceId") { return value }
        let value = UUID().uuidString; UserDefaults.standard.set(value, forKey: "caocap.deviceId"); return value
    }
    func attach(authManager: AuthenticationManager, coordinator: ComputerUseRunCoordinator, companion: CompanionController, gate: ComputerUseInstallGate) {
        self.coordinator = coordinator; self.companion = companion; self.gate = gate
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let next = user?.isAnonymous == false ? user?.uid : nil
            Task { @MainActor in
                guard let self, self.uid != next else { return }
                self.coordinator?.cancel()
                self.listener?.remove(); self.listener = nil; self.handling.removeAll()
                self.epoch = UUID(); self.uid = next
                self.requestsEnabled = next.map { UserDefaults.standard.bool(forKey: "caocap.enableIPhoneRequests.\($0)") } ?? false
            }
        }
    }
    private func sync() {
        guard let uid, requestsEnabled else { listener?.remove(); listener = nil; return }
        guard listener == nil else { return }
        let currentEpoch = epoch
        listener = Firestore.firestore().collection("users").document(uid).collection("commands")
            .whereField("status", isEqualTo: "pending").addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.epoch == currentEpoch, self.requestsEnabled else { return }
                    if error != nil { self.lastRequest = "Could not receive requests"; return }
                    for document in snapshot?.documents ?? [] {
                        guard self.handling.insert(document.documentID).inserted else { continue }
                        Task { await self.handle(document, uid: uid, epoch: currentEpoch) }
                    }
                }
            }
    }
    private func check(_ uid: String, _ epoch: UUID, allowDisabled: Bool = false) throws {
        guard self.uid == uid, self.epoch == epoch, Auth.auth().currentUser?.uid == uid,
              allowDisabled || requestsEnabled else { throw ComputerUseFailure.stoppedOnMac }
    }
    private func transition(_ ref: DocumentReference, from statuses: [String], fields: [String: Any], uid: String, epoch: UUID, claim: Bool = false) async throws {
        try check(uid, epoch, allowDisabled: fields["status"] as? String == "failed")
        let deviceID = localDeviceID
        _ = try await Firestore.firestore().runTransaction { tx, pointer in
            do {
                let data = try tx.getDocument(ref).data() ?? [:]
                guard let status = data["status"] as? String, statuses.contains(status) else { throw ComputerUseFailure.reportingUnavailable }
                if claim {
                    guard let expires = data["expiresAt"] as? Timestamp, expires.dateValue() > Date() else { throw ComputerUseFailure.runTimeout }
                } else if data["status"] as? String != "pending" {
                    guard data["claimedByDeviceId"] as? String == deviceID else { throw ComputerUseFailure.reportingUnavailable }
                }
                if !fields.isEmpty { tx.updateData(fields, forDocument: ref) }
                return nil
            } catch { pointer?.pointee = error as NSError; return nil }
        }
    }
    private func handle(_ document: QueryDocumentSnapshot, uid: String, epoch: UUID) async {
        let id = document.documentID
        guard let command = RemoteCommand.parse(id: id, data: document.data()) else { handling.remove(id); return }
        let ref = document.reference
        do {
            try check(uid, epoch)
            if command.expiresAt <= Date() {
                try await transition(ref, from: ["pending"], fields: ["status": "expired", "finishedAt": FieldValue.serverTimestamp()], uid: uid, epoch: epoch)
                handling.remove(id); return
            }
            try await transition(ref, from: ["pending"], fields: ["status": "claimed", "claimedAt": FieldValue.serverTimestamp(), "claimedByDeviceId": localDeviceID], uid: uid, epoch: epoch, claim: true)
        } catch { handling.remove(id); return } // Never execute after an uncertain claim.
        do {
            try check(uid, epoch)
            if let url = command.openURL {
                let opened = NSWorkspace.shared.open(url)
                var fields: [String: Any] = ["status": opened ? "opened" : "failed", "finishedAt": FieldValue.serverTimestamp()]
                if !opened { fields["failureCode"] = "actionFailed" }
                try await transition(ref, from: ["claimed"], fields: fields, uid: uid, epoch: epoch)
                lastRequest = opened ? "Opened on this Mac" : "Could not open the link"
                handling.remove(id); return
            }
            guard let summary = command.taskSummary, let coordinator else { throw ComputerUseFailure.setupIncomplete }
            var steps: [[String: Any]] = []
            var messageID: UUID?
            _ = try await coordinator.start(request: .init(taskSummary: summary, commandID: id), origin: .remote, beforeStart: {
                try self.check(uid, epoch)
                try await self.transition(ref, from: ["claimed"], fields: ["status": "running", "startedAt": FieldValue.serverTimestamp()], uid: uid, epoch: epoch)
                try self.check(uid, epoch)
                messageID = self.companion?.cocaptainChat.beginRemoteRun(taskSummary: summary)
                self.companion?.setPersona(.cocaptain)
                self.companion?.setAwake(true)
                self.companion?.openChat()
                self.lastRequest = "Working on your iPhone request"
            }, onEvent: { event in
                do {
                    switch event {
                    case .checkpoint:
                        try await self.transition(ref, from: ["running"], fields: [:], uid: uid, epoch: epoch)
                        try self.check(uid, epoch)
                    case .step(let step):
                        steps.append(["index": steps.count + 1, "summary": step.summary])
                        try await self.transition(ref, from: ["running"], fields: ["steps": steps], uid: uid, epoch: epoch)
                    case .completed(let result, _):
                        try await self.transition(ref, from: ["running"], fields: ["status": "completed", "result": result.firestoreData, "finishedAt": FieldValue.serverTimestamp()], uid: uid, epoch: epoch)
                        self.lastRequest = "Saved \(result.fileName)"; self.handling.remove(id)
                    case .failed(let failure):
                        try await self.transition(ref, from: ["running"], fields: ["status": "failed", "failureCode": failure.rawValue, "finishedAt": FieldValue.serverTimestamp()], uid: uid, epoch: epoch)
                        self.lastRequest = failure.localizedDescription; self.handling.remove(id)
                    }
                    if let messageID { self.companion?.cocaptainChat.receiveRunEvent(event, messageID: messageID) }
                } catch {
                    if let messageID { self.companion?.cocaptainChat.receiveRunEvent(.failed(.reportingUnavailable), messageID: messageID) }
                    self.handling.remove(id)
                    throw ComputerUseFailure.reportingUnavailable
                }
            })
        } catch {
            let failure = error as? ComputerUseFailure ?? .actionFailed
            try? await transition(ref, from: ["claimed", "running"], fields: ["status": "failed", "failureCode": failure.rawValue, "finishedAt": FieldValue.serverTimestamp()], uid: uid, epoch: epoch)
            lastRequest = failure.localizedDescription; handling.remove(id)
            if failure == .setupIncomplete, let gate { ComputerUseSetupPresenter.present(installGate: gate) }
            if failure == .noWorkspaceFolder { NotificationCenter.default.post(name: .showMainWindow, object: nil) }
        }
    }
}
