import Foundation
import Testing
@testable import caocap

struct RemoteCommandMappingTests {
    @Test func openedStatusIsOpened() {
        let receipt = RemoteCommandMapping.receipt(status: "opened", pendingSince: Date())
        #expect(receipt == .opened)
        #expect(receipt.label == "Opened")
    }

    @Test func claimedStaysPending() {
        let started = Date().addingTimeInterval(-30)
        let receipt = RemoteCommandMapping.receipt(status: "claimed", pendingSince: started)
        #expect(receipt == .pending)
    }

    @Test func pendingTimesOutToMacRequestsOff() {
        let started = Date().addingTimeInterval(-30)
        let receipt = RemoteCommandMapping.receipt(status: "pending", pendingSince: started)
        #expect(receipt == .macRequestsOff)
        #expect(receipt.label == "Mac has requests off")
    }

    @Test func commandIdReadsCallablePayload() {
        #expect(RemoteCommandMapping.commandId(from: ["commandId": "abc"]) == "abc")
        #expect(RemoteCommandMapping.commandId(from: "nope") == nil)
    }
}
