import Foundation
import FirebaseFirestore
import Testing
@testable import caocap

@MainActor struct RemoteCommandTrackerTests {
    private func snapshot(_ id: String, phase: String, result: [String: Any]? = nil) -> [String: Any] {
        var value: [String: Any] = ["schemaVersion": 2, "requestId": id, "type": "computerUse", "status": phase, "steps": [], "createdAt": Timestamp(date: Date()), "reportingDeadline": Timestamp(date: Date().addingTimeInterval(300))]
        if let result { value["result"] = result }
        return value
    }
    @Test func reversedCompletionCannotRedirectReceipts() {
        let first = RemoteCommandTracker(uid: "alice", id: "request-0001", taskSummary: "First")
        let second = RemoteCommandTracker(uid: "alice", id: "request-0002", taskSummary: "Second")
        second.apply(snapshot(second.id, phase: "completed", result: ["fileName": "second.txt", "previewText": "Second saved text", "previewTruncated": false]))
        first.apply(snapshot(second.id, phase: "completed", result: ["fileName": "wrong.txt", "previewText": "Wrong", "previewTruncated": false]))
        #expect(first.activity.phase == "pending")
        first.apply(snapshot(first.id, phase: "completed", result: ["fileName": "first.txt", "previewText": "First saved text", "previewTruncated": false]))
        #expect(first.activity.previewText == "First saved text")
        #expect(second.activity.previewText == "Second saved text")
    }
    @Test func lateReceiptReplacesPresentationDeadline() {
        let tracker = RemoteCommandTracker(uid: "alice", id: "request-0001", taskSummary: "First")
        tracker.apply(snapshot(tracker.id, phase: "running"), now: Date().addingTimeInterval(400))
        #expect(tracker.activity.phase == "unconfirmed")
        #expect(tracker.activity.summary == "Your Mac stopped reporting.")
        tracker.apply(snapshot(tracker.id, phase: "completed", result: ["fileName": "saved.txt", "previewText": "Actual preview", "previewTruncated": true]))
        #expect(tracker.activity.phase == "completed")
        #expect(tracker.activity.previewTruncated)
    }
    @Test func completionWithoutSavedPreviewIsNotSuccess() {
        let tracker = RemoteCommandTracker(uid: "alice", id: "request-0001", taskSummary: "First")
        tracker.apply(snapshot(tracker.id, phase: "completed"))
        #expect(tracker.activity.phase == "failed")
    }
    @Test func oldExecutionArchiveDecodesWithoutRemotePayload() throws {
        let json = "{\"id\":\"00000000-0000-0000-0000-000000000001\",\"summary\":\"Opened\",\"allowsUndo\":false}"
        let item = try JSONDecoder().decode(ExecutionStatusItem.self, from: Data(json.utf8))
        #expect(item.remoteCommand == nil)
    }
}
