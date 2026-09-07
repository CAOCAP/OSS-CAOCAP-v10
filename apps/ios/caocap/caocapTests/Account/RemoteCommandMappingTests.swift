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

    @Test func settledReceiptsAreTerminal() {
        #expect(RemoteCommandMapping.isSettled(.opened))
        #expect(RemoteCommandMapping.isSettled(.failed))
        #expect(RemoteCommandMapping.isSettled(.macRequestsOff))
        #expect(!RemoteCommandMapping.isSettled(.pending))
        #expect(!RemoteCommandMapping.isSettled(.none))
    }

    @Test func chatCopyUsesReceiptOutcome() {
        #expect(RemoteCommandChatCopy.message(for: .opened) == "YouTube opened on your Mac")
        #expect(RemoteCommandChatCopy.message(for: .failed) == "Your Mac could not open YouTube")
        #expect(
            RemoteCommandChatCopy.message(for: .macRequestsOff)
                == "Your Mac has requests from iPhone turned off"
        )
        #expect(
            RemoteCommandChatCopy.message(for: .pending)
                == "Your Mac has requests from iPhone turned off"
        )
    }
}
