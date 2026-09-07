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

    @Test func canonicalWatchURLAcceptsWatchAndShortLinks() {
        #expect(
            RemoteCommandMapping.canonicalWatchURL(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
                == "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )
        #expect(
            RemoteCommandMapping.canonicalWatchURL(from: "https://youtube.com/watch?v=dQw4w9WgXcQ&t=12")
                == "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )
        #expect(
            RemoteCommandMapping.canonicalWatchURL(from: "  https://youtu.be/dQw4w9WgXcQ  ")
                == "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )
    }

    @Test func canonicalWatchURLRejectsDisallowedAddresses() {
        #expect(RemoteCommandMapping.canonicalWatchURL(from: "https://www.youtube.com") == nil)
        #expect(RemoteCommandMapping.canonicalWatchURL(from: "https://www.youtube.com/watch") == nil)
        #expect(
            RemoteCommandMapping.canonicalWatchURL(from: "https://www.youtube.com/playlist?list=PLabc") == nil
        )
        #expect(
            RemoteCommandMapping.canonicalWatchURL(from: "https://www.youtube.com/embed/dQw4w9WgXcQ") == nil
        )
        #expect(
            RemoteCommandMapping.canonicalWatchURL(from: "https://www.youtube.com/channel/UCdQw4w9WgXc") == nil
        )
        #expect(RemoteCommandMapping.canonicalWatchURL(from: "https://example.com/watch?v=dQw4w9WgXcQ") == nil)
        #expect(RemoteCommandMapping.canonicalWatchURL(from: "javascript:alert(1)") == nil)
        #expect(RemoteCommandMapping.canonicalWatchURL(from: "http://www.youtube.com/watch?v=dQw4w9WgXcQ") == nil)
        #expect(RemoteCommandMapping.canonicalWatchURL(from: "https://youtu.be/short") == nil)
        #expect(RemoteCommandMapping.canonicalWatchURL(from: nil) == nil)
    }
}
