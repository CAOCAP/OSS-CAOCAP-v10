import Foundation
import Testing
@testable import caocap

struct NodeActionAppActionTests {
    @Test func everyNodeActionResolvesToAppActionID() {
        let mappings: [(NodeAction, AppActionID)] = [
            (.navigateRoot, .goRoot),
            (.openSettings, .openSettings),
            (.openProfile, .openProfile),
            (.summonCoCaptain, .summonCoCaptain),
            (.proSubscription, .proSubscription),
            (.openActivity, .openActivity),
            (.openWhatsApp, .openWhatsApp),
            (.openHelp, .help),
            (.openAppIcon, .openAppIcon)
        ]

        for (nodeAction, expectedID) in mappings {
            #expect(nodeAction.appActionID == expectedID)
        }
    }

    @Test func pinableAppActionsRoundTripToNodeAction() throws {
        let pinableIDs: [AppActionID] = [
            .goRoot,
            .openSettings,
            .openProfile,
            .summonCoCaptain,
            .proSubscription,
            .openActivity,
            .openWhatsApp,
            .help,
            .openAppIcon
        ]

        for actionID in pinableIDs {
            let nodeAction = try #require(actionID.pinableNodeAction)
            #expect(nodeAction.appActionID == actionID)
        }
    }

    @MainActor
    @Test func dispatcherExposesNewRootShortcutActions() throws {
        let dispatcher = AppActionDispatcher()
        let newIDs: [AppActionID] = [.openActivity, .openWhatsApp, .help, .openAppIcon]

        for id in newIDs {
            let definition = try #require(dispatcher.definition(for: id))
            #expect(!definition.isMutating)
            #expect(!definition.allowsAutonomousExecution)
            #expect(definition.canPinToCanvas)
            #expect(id.pinableNodeAction != nil)
        }
    }

    @MainActor
    @Test func dispatcherExposesOpenYouTubeOnMacWithoutPinning() throws {
        let dispatcher = AppActionDispatcher()
        let definition = try #require(dispatcher.definition(for: .openYouTubeOnMac))
        #expect(!definition.isMutating)
        #expect(definition.allowsAutonomousExecution)
        #expect(!definition.canPinToCanvas)
        #expect(definition.category == .assistant)
        #expect(AppActionID.openYouTubeOnMac.pinableNodeAction == nil)
    }

    @MainActor
    @Test func dispatcherExposesOpenYouTubeVideoOnMacWithoutPinning() throws {
        let dispatcher = AppActionDispatcher()
        let definition = try #require(dispatcher.definition(for: .openYouTubeVideoOnMac))
        #expect(!definition.isMutating)
        #expect(definition.allowsAutonomousExecution)
        #expect(!definition.canPinToCanvas)
        #expect(definition.category == .assistant)
        #expect(AppActionID.openYouTubeVideoOnMac.pinableNodeAction == nil)
    }

    @MainActor
    @Test func dispatcherExposesOpenURLOnMacWithoutPinning() throws {
        let dispatcher = AppActionDispatcher()
        let definition = try #require(dispatcher.definition(for: .openURLOnMac))
        #expect(!definition.isMutating)
        #expect(definition.allowsAutonomousExecution)
        #expect(!definition.canPinToCanvas)
        #expect(definition.category == .assistant)
        #expect(AppActionID.openURLOnMac.pinableNodeAction == nil)
    }
}
