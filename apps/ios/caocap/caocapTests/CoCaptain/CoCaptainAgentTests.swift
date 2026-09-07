import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct CoCaptainAgentTests {
    @Test func onboardingWelcomePurposeDefinesFocusedPromptInstructions() {
        let instructions = CoCaptainTurnPurpose.onboardingWelcome.promptInstructions

        #expect(CoCaptainTurnPurpose.standard.promptInstructions == nil)
        #expect(instructions?.contains("40 to 80 words") == true)
        #expect(instructions?.contains("exactly one easy question") == true)
        #expect(instructions?.contains("at most two short example ideas") == true)
        #expect(instructions?.contains("Do not request app actions") == true)
        #expect(instructions?.contains("Match the language used by the user") == true)
    }

    @Test func onboardingBuildHandoffPurposeDefinesFocusedPromptInstructions() {
        let instructions = CoCaptainTurnPurpose.onboardingBuildHandoff.promptInstructions

        #expect(instructions?.contains("initial direction for what they want to build") == true)
        #expect(instructions?.contains("20 to 50 words") == true)
        #expect(instructions?.contains("transition back to the canvas") == true)
        #expect(instructions?.contains("Do not ask a question") == true)
        #expect(instructions?.contains("Do not request app actions") == true)
        #expect(instructions?.contains("invoke tools") == true)
        #expect(instructions?.contains("emit a `cocaptain_actions` block") == true)
        #expect(instructions?.contains("Match the language used by the user") == true)
    }

    @Test func turnCompletionShouldAdvanceToCanvasDismissalOnlyForSuccessfulHandoff() {
        let handoffSuccess = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingBuildHandoff,
            succeeded: true
        )
        let handoffFailure = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingBuildHandoff,
            succeeded: false
        )
        let welcomeSuccess = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingWelcome,
            succeeded: true
        )
        let standardSuccess = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .standard,
            succeeded: true
        )

        #expect(handoffSuccess.shouldAdvanceToCanvasDismissal)
        #expect(!handoffFailure.shouldAdvanceToCanvasDismissal)
        #expect(!welcomeSuccess.shouldAdvanceToCanvasDismissal)
        #expect(!standardSuccess.shouldAdvanceToCanvasDismissal)
    }

    @Test func turnExecutionPolicyMapsPurposesToExpectedModes() {
        #expect(CoCaptainTurnPurpose.standard.executionPolicy == .agent)
        #expect(CoCaptainTurnPurpose.onboardingWelcome.executionPolicy == .conversational)
        #expect(CoCaptainTurnPurpose.onboardingBuildHandoff.executionPolicy == .conversational)
        #expect(CoCaptainTurnPurpose.onboardingGuidedEdit.executionPolicy == .agentic)
        #expect(!CoCaptainTurnPurpose.standard.isConversationalTurn)
        #expect(CoCaptainTurnPurpose.onboardingWelcome.isConversationalTurn)
        #expect(CoCaptainTurnPurpose.onboardingBuildHandoff.isConversationalTurn)
        #expect(!CoCaptainTurnPurpose.onboardingGuidedEdit.isConversationalTurn)
    }

    @Test func turnPlanMapsModeAndPurposeToEffectivePolicy() {
        let agent = CoCaptainTurnPlan(purpose: .standard, mode: .agent)
        let ask = CoCaptainTurnPlan(purpose: .standard, mode: .ask)
        let plan = CoCaptainTurnPlan(purpose: .standard, mode: .plan)
        let welcome = CoCaptainTurnPlan(purpose: .onboardingWelcome, mode: .agent)
        let handoff = CoCaptainTurnPlan(purpose: .onboardingBuildHandoff, mode: .agent)
        let guided = CoCaptainTurnPlan(purpose: .onboardingGuidedEdit, mode: .ask)

        #expect(agent.effectivePolicy == .agent)
        #expect(ask.effectivePolicy == .ask)
        #expect(plan.effectivePolicy == .plan)
        #expect(welcome.effectivePolicy == .conversational)
        #expect(handoff.effectivePolicy == .conversational)
        #expect(guided.effectivePolicy == .agentic)
        #expect(CoCaptainTurnExecutionPolicy.agent.expectsStructuredResponse)
        #expect(CoCaptainTurnExecutionPolicy.agent.enforcesExecutableWork == false)
        #expect(CoCaptainTurnExecutionPolicy.agent.allowsAgenticRetry)
        #expect(CoCaptainTurnExecutionPolicy.agent.executesActions)
        #expect(CoCaptainTurnExecutionPolicy.ask.expectsStructuredResponse == false)
        #expect(CoCaptainTurnExecutionPolicy.ask.executesActions == false)
        #expect(CoCaptainTurnExecutionPolicy.ask.enforcesExecutableWork == false)
        #expect(CoCaptainTurnExecutionPolicy.ask.allowsAgenticRetry == false)
        #expect(CoCaptainTurnExecutionPolicy.plan.expectsStructuredResponse == false)
        #expect(CoCaptainTurnExecutionPolicy.plan.executesActions == false)
        #expect(CoCaptainTurnExecutionPolicy.plan.enforcesExecutableWork == false)
        #expect(CoCaptainTurnExecutionPolicy.plan.allowsAgenticRetry == false)
        #expect(CoCaptainTurnExecutionPolicy.agentic.enforcesExecutableWork)
        #expect(agent.requiresDegradedConnectionNotice)
        #expect(!ask.requiresDegradedConnectionNotice)
        #expect(!plan.requiresDegradedConnectionNotice)
        #expect(!welcome.requiresDegradedConnectionNotice)
        #expect(guided.requiresDegradedConnectionNotice)
        #expect(agent.contextDetailLevel == .implementation)
        #expect(ask.contextDetailLevel == .product)
        #expect(plan.contextDetailLevel == .product)
        #expect(!CoCaptainChatMode.agent.isProseOnly)
        #expect(CoCaptainChatMode.ask.isProseOnly)
        #expect(CoCaptainChatMode.plan.isProseOnly)
        #expect(CoCaptainChatMode.plan.promptInstructions != nil)
        #expect(CoCaptainChatMode.plan.promptInstructions != CoCaptainChatMode.ask.promptInstructions)
    }

    @MainActor
    @Test func productContextOmitsFirebaseImplementationDetails() throws {
        let store = makeStore()

        let context = ProjectContextBuilder().buildPromptContext(from: store, detailLevel: .product)

        #expect(context.contains("Project Name: Test Project"))
        #expect(!context.contains("SRS Readiness:"))
        #expect(!context.contains("Mini-App Firebase wiring rules"))
        #expect(!context.contains("__caocapFirestore"))
        #expect(!context.contains("Firebase Config:"))
    }

    @MainActor
    @Test func projectContextDescribesCanvasCardsNotHTML() throws {
        let store = makeStore()

        let context = ProjectContextBuilder().buildPromptContext(from: store)

        #expect(context.contains("Project Name: Test Project"))
        #expect(context.contains("Node Count:"))
        #expect(context.contains("cannot edit HTML"))
        #expect(!context.contains("SRS Readiness:"))
        #expect(!context.contains("<html><body><h1>Hello World!</h1></body></html>"))
    }

    @MainActor
    @Test func projectContextIncludesBlankCards() throws {
        let store = ProjectStore(
            fileName: "blank-canvas-test-\(UUID().uuidString).json",
            projectName: "Blank Project",
            initialNodes: [
                SpatialNode(
                    type: .standard,
                    position: CGPoint(x: 0, y: 0),
                    title: "Card"
                )
            ]
        )

        let context = ProjectContextBuilder().buildPromptContext(from: store)

        #expect(context.contains("Node Count: 1"))
        #expect(context.contains("Card"))
        #expect(!context.contains("Code:"))
    }

    @MainActor
    @Test func nodeContextIncludesSelectedNodeAndLinkedNeighbors() throws {
        let linkedID = UUID()
        let selectedID = UUID()
        let unrelatedID = UUID()
        let store = ProjectStore(
            fileName: "node-context-\(UUID().uuidString).json",
            projectName: "Node Context",
            initialNodes: [
                SpatialNode(id: selectedID, type: .standard, position: .zero, title: "Selected Card", connectedNodeIds: [linkedID]),
                SpatialNode(id: linkedID, type: .standard, position: .zero, title: "Linked Card"),
                SpatialNode(id: unrelatedID, type: .standard, position: .zero, title: "Unrelated")
            ]
        )

        let context = ProjectContextBuilder().buildNodePromptContext(from: store, nodeID: selectedID)

        #expect(context.contains("Selected Node ID: \(selectedID.uuidString)"))
        #expect(context.contains("Selected Node:"))
        #expect(context.contains("Linked Neighbor Nodes:"))
        #expect(context.contains("Linked Card"))
        #expect(context.contains("Unrelated [standard] id: \(unrelatedID.uuidString)"))
        #expect(!context.contains("SRS"))
    }

    @MainActor
    @Test func nodeAgentMessagesPersistOnNode() {
        let store = makeStore()
        let node = store.nodes[0]

        store.appendNodeAgentMessage(
            id: node.id,
            message: NodeAgentMessage(text: "Draft the intro", isUser: true),
            persist: false
        )

        let updatedNode = store.nodes.first(where: { $0.id == node.id })
        #expect(updatedNode?.agentState.messages.first?.text == "Draft the intro")
        #expect(updatedNode?.agentState.messages.first?.isUser == true)
    }

    @Test func nodeRoleInferenceRecognizesCanonicalTemplateNodes() {
        #expect(SpatialNode(type: .standard, position: .zero, title: "Card").role == .custom)
        #expect(SpatialNode(type: .subCanvas, position: .zero, title: "Nested").role == .subCanvas)
        #expect(SpatialNode(position: .zero, title: "New Logic").role == .custom)
    }

    @Test func chatBubbleMarkdownPreservesVisibleContent() {
        let bubble = ChatBubbleItem(
            text: """
            **Next steps**

            - Tighten layout
            - Improve contrast
            """,
            isUser: false
        )

        let renderedText = String(bubble.markdownText.characters)

        #expect(renderedText.contains("Next steps"))
        #expect(renderedText.contains("Tighten layout"))
        #expect(renderedText.contains("Improve contrast"))
    }

    @MainActor
    @Test func commandIntentResolverDoesNotMatchRemovedProjectCommands() throws {
        let resolver = CommandIntentResolver()
        let actions = TestActionDispatcher().availableActions

        #expect(resolver.resolve("create a project", availableActions: actions) == nil)
        #expect(resolver.resolve("please create a project", availableActions: actions) == nil)
        #expect(resolver.resolve("new project", availableActions: actions) == nil)
        #expect(resolver.resolve("open settings", availableActions: actions) == .openSettings)
        #expect(resolver.resolve("make a root page", availableActions: actions) == nil)
        #expect(resolver.resolve("do not create a project", availableActions: actions) == nil)
    }

    @MainActor
    @Test func commandIntentResolverMatchesArabicSettingsCommands() throws {
        let resolver = CommandIntentResolver()
        let actions = TestActionDispatcher().availableActions

        #expect(resolver.resolve("أنشئ مشروع جديد", availableActions: actions) == nil)
        #expect(resolver.resolve("لو سمحت أنشئ مشروع جديد", availableActions: actions) == nil)
        #expect(resolver.resolve("افتح الإعدادات", availableActions: actions) == .openSettings)
        #expect(resolver.resolve("اعرض المشاريع", availableActions: actions) == nil)
        #expect(resolver.resolve("لا تنشئ مشروع جديد", availableActions: actions) == nil)
    }

    @Test func functionCallAdapterAcceptsUppercaseExecutionMode() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["actionId": "go_root", "executionMode": "SAFE"]
            )
        ])

        #expect(directive.payload?.safeActions.first?.actionID == "go_root")
        #expect(directive.diagnostics.isEmpty)
    }

    @MainActor
    @Test func coordinatorRetriesDuplicateSafeActions() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                """
                Navigating.

                <cocaptain_actions>
                  <assistant_message>Navigating.</assistant_message>
                  <safe_actions>
                    <action id="go_root"/>
                    <action id="go_root"/>
                  </safe_actions>
                </cocaptain_actions>
                """,
                """
                Navigating.

                <cocaptain_actions>
                  <assistant_message>Navigating.</assistant_message>
                  <safe_actions><action id="go_root"/></safe_actions>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "go root",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("is duplicated") == true)
        #expect(dispatcher.executedActionIDs == [.goRoot])
        #expect(result.executionSummary?.summary.contains("Go to Root") == true)
    }

    @Test func parserUsesLastCompleteActionsBlock() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            First attempt.

            <cocaptain_actions>
              <assistant_message>Old payload.</assistant_message>
              <safe_actions><action id="go_root"/></safe_actions>
            </cocaptain_actions>

            Second attempt.

            <cocaptain_actions>
              <assistant_message>Latest payload.</assistant_message>
              <safe_actions><action id="open_settings"/></safe_actions>
            </cocaptain_actions>
            """

        let parsed = parser.parse(response)

        #expect(parsed.preamble.contains("First attempt."))
        #expect(parsed.preamble.contains("Second attempt."))
        #expect(parsed.payload?.assistantMessage == "Latest payload.")
        #expect(parsed.payload?.safeActions.first?.actionID == "open_settings")
    }

    @Test func parserIgnoresTrailingIncompleteActionsBlock() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            Working on it.

            <cocaptain_actions>
              <assistant_message>Valid payload.</assistant_message>
              <safe_actions><action id="go_root"/></safe_actions>
            </cocaptain_actions>

            <cocaptain_actions>
              <assistant_message>Still generating...
            """

        let parsed = parser.parse(response)

        #expect(parsed.payload?.assistantMessage == "Valid payload.")
        #expect(parsed.payload?.safeActions.first?.actionID == "go_root")
    }

    @MainActor
    @Test func validatorRejectsDuplicateAndOverlappingActions() {
        let payload = CoCaptainAgentPayload(
            assistantMessage: "Ready",
            safeActions: [
                CoCaptainAgentAction(actionID: "go_root"),
                CoCaptainAgentAction(actionID: "go_root")
            ],
            pendingActions: [
                CoCaptainAgentAction(actionID: "create_node"),
                CoCaptainAgentAction(actionID: "create_node"),
                CoCaptainAgentAction(actionID: "go_root")
            ]
        )

        let result = CoCaptainAgentValidator().validate(
            payload: payload,
            dispatcher: TestActionDispatcher(),
            requiresAgenticWork: false
        )

        #expect(!result.isValid)
        #expect(result.issues.contains { $0.contains("Safe action `go_root` is duplicated.") })
        #expect(result.issues.contains { $0.contains("Pending action `create_node` is duplicated.") })
        #expect(result.issues.contains { $0.contains("cannot appear in both") })
    }

    @Test func functionCallAdapterAcceptsSnakeCaseActionID() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["action_id": "go_root", "executionMode": "safe"]
            )
        ])

        #expect(directive.payload?.safeActions.first?.actionID == "go_root")
        #expect(directive.diagnostics.isEmpty)
    }

    @MainActor
    @Test func commandIntentResolverMatchesGoHomeAndHelpCenter() throws {
        let resolver = CommandIntentResolver()
        let actions = TestActionDispatcher().availableActions

        #expect(resolver.resolve("go home", availableActions: actions) == .goRoot)
        #expect(resolver.resolve("open help center", availableActions: actions) == .help)
    }

    @MainActor
    @Test func coordinatorReviewBundleTitleIncludesItemCount() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response:
                """
                Prepared two changes.

                <cocaptain_actions>
                  <assistant_message>Prepared two changes.</assistant_message>
                  <pending_actions><action id="create_node"/></pending_actions>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update headline.">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Updated</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "update and create",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(result.reviewDraft?.pendingActions.count == 1)
    }

    @Test func parserExtractsTrailingStructuredBlock() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            I can make that update.

            <cocaptain_actions>
              <assistant_message>I can make that update.</assistant_message>
              <safe_actions>
                <action id="go_root" />
              </safe_actions>
              <pending_actions></pending_actions>
              <node_edits></node_edits>
            </cocaptain_actions>
            """

        let parsed = parser.parse(response)

        #expect(parsed.preamble == "I can make that update.")
        #expect(parsed.visibleText == "I can make that update.")
        #expect(parsed.payload?.safeActions.count == 1)
        #expect(parsed.payload?.safeActions.first?.actionID == "go_root")
    }

    @Test func parserDetectsLoosePayloadWithoutWhitespace() throws {
        let parser = CoCaptainAgentParser()
        let response = "aesthetic.<cocaptain_actions><assistant_message>Implementing...</assistant_message></cocaptain_actions>"

        let parsed = parser.parse(response)
        #expect(parsed.preamble == "aesthetic.")
        #expect(parsed.payload?.assistantMessage == "Implementing...")
    }

    @Test func parserHandlesCurlyQuotesInLoosePayload() throws {
        let parser = CoCaptainAgentParser()
        // Some models send smart quotes like “assistantMessage”
        let response = "OK. { “assistantMessage”: “Hello” }"

        let parsed = parser.parse(response)
        #expect(parsed.preamble == "OK.")
        #expect(parsed.payload?.assistantMessage == "Hello")
    }

    @Test func parserHidesLooseTrailingActionXML() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            I can document that preference.

            <cocaptain_actions>
              <assistant_message>Documented the preference.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="srs" summary="Document color preference.">
                  <operation type="append">
                    <content><![CDATA[\nPrimary color: Slate Grey.]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """

        let parsed = parser.parse(response)

        #expect(parsed.preamble == "I can document that preference.")
    }

    @Test func parserHidesIncompleteLooseTrailingActionXML() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            Working on it.

            <cocaptain_actions>
              <assistant_message>Still generating...
            """

        let parsed = parser.parse(response)

        // Should NOT show the XML even if it's not closed yet.
        #expect(parsed.preamble == "Working on it.")
        #expect(parsed.payload == nil)
    }

    @Test func chatBubbleMarkdownFallsBackToInlineSyntax() {
        let bubble = ChatBubbleItem(
            text: "Hello *world*",
            isUser: false
        )

        // This should always succeed and at least render the italics if possible.
        let renderedText = String(bubble.markdownText.characters)
        #expect(renderedText.contains("world"))
    }

    @Test func chatBubbleMarkdownStylesInlineCode() {
        let bubble = ChatBubbleItem(
            text: "Use `let x = 5` here",
            isUser: false
        )

        let attributed = bubble.markdownText
        // Check if the parser identifies inline code
        var foundInlineCode = false
        for run in attributed.runs {
            if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                foundInlineCode = true
            }
        }
        #expect(foundInlineCode)
    }

    @Test func parserHandlesMultiLineXML() throws {
        let parser = CoCaptainAgentParser()
        let response = """
        Updating:
        <cocaptain_actions>
          <assistant_message>Multi-line</assistant_message>
        </cocaptain_actions>
        """

        let parsed = parser.parse(response)
        #expect(parsed.visibleText == "Updating:")
        #expect(parsed.payload?.assistantMessage == "Multi-line")
    }

    @Test func parserFallsBackOnMissingClosingTag() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            I can help.

            <cocaptain_actions>
              <assistant_message>Incomplete
            """

        let parsed = parser.parse(response)

        #expect(parsed.payload == nil)
        #expect(parsed.preamble == "I can help.")
    }

    @Test func xmlAdapterProducesCoordinatorDirective() throws {
        let adapter = CoCaptainXMLAgentAdapter()
        let response =
            """
            Done.

            <cocaptain_actions>
              <assistant_message>Done.</assistant_message>
              <safe_actions><action id="go_root"/></safe_actions>
              <pending_actions></pending_actions>
              <node_edits></node_edits>
            </cocaptain_actions>
            """

        let directive = adapter.directive(from: response)

        #expect(directive.preamble == "Done.")
        #expect(directive.visibleText == "Done.")
        #expect(directive.payload?.safeActions.first?.actionID == "go_root")
        #expect(directive.diagnostics.isEmpty)
        #expect(directive.source == .xml)
    }

    @Test func functionCallAdapterMapsSafeAction() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["actionId": "go_root", "executionMode": "safe"]
            )
        ])

        #expect(directive.payload?.safeActions.first?.actionID == "go_root")
        #expect(directive.payload?.pendingActions.isEmpty == true)
        #expect(directive.diagnostics.isEmpty)
        #expect(directive.source == .functionCall)
    }

    @Test func functionCallAdapterMapsPendingAction() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["actionId": "create_node", "executionMode": "pending"]
            )
        ])

        #expect(directive.payload?.pendingActions.first?.actionID == "create_node")
        #expect(directive.payload?.safeActions.isEmpty == true)
        #expect(directive.diagnostics.isEmpty)
    }

    @Test func functionCallAdapterPreservesSupplementalArguments() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()
        let directive = adapter.directive(
            from: [
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: [
                        "actionId": "moveNode",
                        "executionMode": "pending",
                        "nodeId": "ABC-123",
                        "x": "120",
                        "y": "80"
                    ]
                )
            ]
        )

        let action = try #require(directive.payload?.pendingActions.first)
        #expect(action.actionID == "moveNode")
        #expect(action.args?["nodeId"] == "ABC-123")
        #expect(action.args?["x"] == "120")
        #expect(action.args?["y"] == "80")
        #expect(action.args?["executionMode"] == nil)
    }

    @Test func functionCallAdapterReportsMalformedCalls() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()

        let missingAction = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["executionMode": "safe"]
            )
        ])
        let unknownFunction = adapter.directive(from: [
            CoCaptainAgentFunctionCall(name: "unknown_function", arguments: ["actionId": "go_root"])
        ])

        #expect(missingAction.payload == nil)
        #expect(missingAction.diagnostics.first?.contains("missing `actionId`") == true)
        #expect(unknownFunction.payload == nil)
        #expect(unknownFunction.diagnostics.first?.contains("Unknown function call") == true)
    }

    @Test func compositeAdapterMergesFunctionActionsAndFencedNodeEdits() throws {
        let adapter = CoCaptainCompositeAgentAdapter()
        let response =
            """
            I updated the project.

            <cocaptain_actions>
              <assistant_message>I updated the project.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Update Code.">
                  <operation type="replace_all">
                    <content><![CDATA[<h1>Fixed</h1>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """

        let directive = adapter.directive(
            from: response,
            functionCalls: [
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: ["actionId": "go_root", "executionMode": "safe"]
                )
            ]
        )

        #expect(directive.payload?.safeActions.first?.actionID == "go_root")
        #expect(directive.source == .combined)
    }

    @MainActor
    @Test func coordinatorRetriesMalformedStructuredPayload() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                """
                I prepared an edit.

                <cocaptain_actions>
                  <assistant_message>Incomplete
                """,
                """
                I prepared a valid code edit.

                <cocaptain_actions>
                  <assistant_message>I prepared a valid code edit.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update Code.">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Fixed</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "update the code",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(result.reviewDraft == nil)
    }

    @MainActor
    @Test func coordinatorForwardsOnboardingWelcomePurpose() async throws {
        let llm = TestLLMClient(
            response: "Welcome! What would you like to make?"
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        _ = try await coordinator.run(
            userMessage: "hi",
            store: makeStore(),
            dispatcher: nil,
            purpose: .onboardingWelcome
        ) { _ in }

        #expect(llm.receivedPurposes == [.onboardingWelcome])
    }

    @MainActor
    @Test func coordinatorForwardsOnboardingBuildHandoffPurpose() async throws {
        let llm = TestLLMClient(
            response: "Great idea. Let's head back to the canvas and start building."
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        _ = try await coordinator.run(
            userMessage: "a todo app",
            store: makeStore(),
            dispatcher: nil,
            purpose: .onboardingBuildHandoff
        ) { _ in }

        #expect(llm.receivedPurposes == [.onboardingBuildHandoff])
    }

    @MainActor
    @Test func conversationalBuildHandoffDoesNotAgenticRetryForMakeKeyword() async throws {
        let llm = TestLLMClient(
            response: "A Pac-Man game sounds fun. Let's head back to the canvas and start building."
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "I wanna make a pacman game",
            store: makeStore(),
            dispatcher: nil,
            purpose: .onboardingBuildHandoff
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(llm.receivedMessages.allSatisfy {
            !$0.contains("machine-readable CoCaptain action contract")
        })
        #expect(!result.visibleText.isEmpty)
        #expect(result.reviewDraft == nil)
        #expect(result.executionSummary == nil)
    }

    @MainActor
    @Test func conversationalTurnIgnoresStructuredPayloadFromModel() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response: """
            A Pac-Man game sounds fun. Let's head back to the canvas.

            <cocaptain_actions>
              <assistant_message>I built Pac-Man.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Build Pac-Man.">
                  <operation type="replace_all">
                    <content><![CDATA[<html><body>Pac-Man</body></html>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "I wanna make a pacman game",
            store: makeStore(),
            dispatcher: dispatcher,
            purpose: .onboardingBuildHandoff
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(result.reviewDraft == nil)
        #expect(result.executionSummary == nil)
        #expect(result.visibleText.contains("Pac-Man"))
        #expect(dispatcher.executedActionIDs.isEmpty)
    }

    @MainActor
    @Test func standardTurnAgenticRetriesWhenBuildRequestHasNoStructuredPayload() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                "A Pac-Man game sounds fun. We can build that together.",
                """
                I prepared a Pac-Man starter.

                <cocaptain_actions>
                  <assistant_message>I prepared a Pac-Man starter.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Build Pac-Man.">
                      <operation type="replace_all">
                        <content><![CDATA[<html><body>Pac-Man</body></html>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "I wanna make a pacman game",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(result.reviewDraft == nil)
    }

    @MainActor
    @Test func coordinatorExecutesSafeActionsAndStagesPendingReviews() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response:
                """
                I moved us to root and prepared a code update.

                <cocaptain_actions>
                  <assistant_message>I moved us to root and prepared a code update.</assistant_message>
                  <safe_actions><action id="go_root"/></safe_actions>
                  <pending_actions><action id="create_node"/></pending_actions>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update the headline.">
                      <operation type="replace_exact">
                        <target>Hello World!</target>
                        <content><![CDATA[Agentic Hello!]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let store = makeStore()

        let result = try await coordinator.run(
            userMessage: "Do it",
            store: store,
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs == [.goRoot])
        #expect(result.executionSummary?.summary.contains("Go to Root") == true)
        #expect(result.reviewDraft?.pendingActions.count == 1)
    }

    @MainActor
    @Test func coordinatorUsesNodeScopedSessionAndStagesTargetedEdit() async throws {
        let dispatcher = TestActionDispatcher()
        let store = makeStore()
        let miniAppNode = try #require(store.nodes.first)
        let llm = TestLLMClient(
            response:
                """
                I prepared a code-node update.

                <cocaptain_actions>
                  <assistant_message>I prepared a code-node update.</assistant_message>
                  <node_edits>
                    <node_edit nodeId="\(miniAppNode.id.uuidString)" role="miniApp" section="code" summary="Update targeted mini-app.">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Scoped</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "change this code node",
            store: store,
            dispatcher: dispatcher,
            scope: .node(miniAppNode.id)
        ) { _ in }

        #expect(llm.receivedScopes == [.node(miniAppNode.id)])
        #expect(result.reviewDraft == nil)
    }

    @MainActor
    @Test func coordinatorExecutesFunctionCalledSafeAction() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response: "Opening settings.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: ["actionId": "open_settings", "executionMode": "safe"]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "open settings",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs == [.openSettings])
        #expect(result.executionSummary?.summary.contains("Open Settings") == true)
    }

    @MainActor
    @Test func coordinatorStagesFunctionCalledPendingAction() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response: "I prepared the action for review.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: ["actionId": "create_node", "executionMode": "pending"]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "create a node",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.reviewDraft?.pendingActions.first?.actionID == AppActionID.createNode.rawValue)
    }

    @MainActor
    @Test func coordinatorRetriesUnsafeFunctionCalledSafeAction() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                "I will create a node.",
                "I prepared the action for review."
            ],
            functionCalls: [
                [
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                        arguments: ["actionId": "create_node", "executionMode": "safe"]
                    )
                ],
                [
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                        arguments: ["actionId": "create_node", "executionMode": "pending"]
                    )
                ]
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "create a node",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("move it to `pendingActions`") == true)
        #expect(result.reviewDraft?.pendingActions.first?.actionID == AppActionID.createNode.rawValue)
    }

    @MainActor
    @Test func coordinatorDoesNotPartiallyExecuteMalformedFunctionCall() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                "Opening settings.",
                "Opening settings."
            ],
            functionCalls: [
                [
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                        arguments: ["actionId": "open_settings", "executionMode": "safe"]
                    ),
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                        arguments: ["executionMode": "safe"]
                    )
                ],
                [
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                        arguments: ["actionId": "open_settings", "executionMode": "safe"]
                    )
                ]
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        _ = try await coordinator.run(
            userMessage: "open settings",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs == [.openSettings])
        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("missing `actionId`") == true)
    }

    @MainActor
    @Test func coordinatorDoesNotExecuteInvalidSafeActionBeforeRetry() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                """
                I will create a node.

                <cocaptain_actions>
                  <assistant_message>I will create a node.</assistant_message>
                  <safe_actions><action id="create_node"/></safe_actions>
                </cocaptain_actions>
                """,
                """
                I prepared the action for review.

                <cocaptain_actions>
                  <assistant_message>I prepared the action for review.</assistant_message>
                  <pending_actions><action id="create_node"/></pending_actions>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "create a node",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("move it to `pendingActions`") == true)
        #expect(result.reviewDraft?.pendingActions.count == 1)
    }

    @MainActor
    @Test func coordinatorReturnsFriendlyMessageWhenRetryPayloadIsStillInvalid() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response:
                """
                I will use an unknown action.

                <cocaptain_actions>
                  <assistant_message>I will use an unknown action.</assistant_message>
                  <safe_actions><action id="launch_rocket"/></safe_actions>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "create something",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.executionSummary == nil)
        #expect(result.reviewDraft == nil)
        #expect(result.payloadMessage?.contains("another run") == true)
        #expect(llm.receivedMessages.count == 3)
    }
    @Test func agentJSONValuePreservesNestedObjectsAndArrays() throws {
        let json = """
        {"summary": "Update", "operations": [{"type": "replace_all", "content": "<h1>New</h1>"}], "count": 2, "flag": true}
        """
        let decoded = try JSONDecoder().decode(
            [String: AgentJSONValue].self,
            from: Data(json.utf8)
        )

        #expect(decoded["summary"]?.stringValue == "Update")
        #expect(decoded["count"]?.stringValue == "2")
        #expect(decoded["flag"]?.stringValue == "true")
        let operations = decoded["operations"]?.arrayValue
        #expect(operations?.count == 1)
        #expect(operations?.first?.objectValue?["type"]?.stringValue == "replace_all")
        #expect(decoded["operations"]?.stringValue == nil)
    }
    @MainActor
    @Test func toolExecutorLeavesRequestAppActionToAdapterRouting() async throws {
        let store = makeStore()
        let llm = ToolLoopLLMClient(
            toolCall: CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["actionId": "go_root", "executionMode": "safe"]
            ),
            finalResponse: "Navigating."
        )
        let dispatcher = TestActionDispatcher()
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "go home please",
            store: store,
            dispatcher: dispatcher
        ) { _ in }

        // Executor must decline (nil) so the call routes through the adapters.
        #expect(llm.capturedToolResults.isEmpty)
        #expect(dispatcher.executedActionIDs == [.goRoot])
        #expect(result.executionSummary != nil)
    }

    @MainActor
    @Test func flyToReviewTargetInvokesCallback() {
        let vm = CoCaptainViewModel()
        let nodeID = UUID()
        var flownNodeID: UUID?
        vm.onFlyToNode = { flownNodeID = $0 }

        vm.flyToReviewTarget(nodeID)

        #expect(flownNodeID == nodeID)
    }

    @MainActor
    @Test func tokenLimitErrorAppendsProUpgradeReviewItem() async throws {
        let dispatcher = TestActionDispatcher()
        let error = TokenUsageLimitError(limitTokens: 50_000, usedTokens: 50_000, requestedTokens: 1_000)
        let coordinator = CoCaptainAgentCoordinator(llmClient: ThrowingLLMClient(error: error))
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.actionDispatcher = dispatcher

        vm.sendMessage("build a tiny app")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 0)

        let quotaError = vm.items.compactMap { item -> CoCaptainErrorItem? in
            guard case .error(let error) = item.content, error.kind == .quota else {
                return nil
            }
            return error
        }.last

        let proReviewBundleItem = vm.items.first { item in
            guard case .reviewBundle(let bundle) = item.content else { return false }
            return bundle.items.contains { reviewItem in
                if case .appAction(.proSubscription, nil) = reviewItem.source {
                    return true
                }
                return false
            }
        }
        let productCTAItem = vm.items.compactMap { item -> CoCaptainProductCTAItem? in
            guard case .productCTA(let cta) = item.content else { return nil }
            return cta
        }.first

        #expect(quotaError?.title == "Usage limit reached")
        #expect(quotaError?.isRecoverable == false)
        #expect(proReviewBundleItem == nil)
        #expect(productCTAItem?.title == "Free CoCaptain usage reached")
        #expect(productCTAItem?.primaryButtonTitle == "View Pro")
        #expect(productCTAItem?.actionID == .proSubscription)

        guard let productCTAItem else {
            Issue.record("Expected limit-reached product CTA.")
            return
        }

        vm.performProductCTA(productCTAItem)

        #expect(dispatcher.executedActionIDs.contains(.proSubscription))
        #expect(dispatcher.executedSources.last == .user)
    }

    @MainActor
    @Test func rejectedAttachmentsAreNotSubmittedOrRemovedFromComposerState() {
        let llm = AttachmentRejectingLLMClient()
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        let attachment = CoCaptainAttachment(
            fileName: "reference.png",
            mimeType: "image/png",
            data: Data([0])
        )

        let accepted = vm.sendMessage("Review this", attachments: [attachment])

        #expect(!accepted)
        #expect(llm.streamCount == 0)
        #expect(vm.items.allSatisfy { item in
            guard case .message(let bubble) = item.content else { return true }
            return !bubble.isUser
        })
        let attachmentError = vm.items.compactMap { item -> CoCaptainErrorItem? in
            guard case .error(let error) = item.content else { return nil }
            return error
        }.last
        #expect(attachmentError?.kind == .attachment)
        #expect(attachmentError?.message.contains("text-only") == true)
        #expect(attachmentError?.isRecoverable == false)
    }

    @MainActor
    @Test func completedAssistantResponseCountAdvancesAfterSuccessfulAgentTurn() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response: "Opening settings.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: ["actionId": "open_settings", "executionMode": "safe"]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.store = makeStore()
        vm.actionDispatcher = dispatcher

        vm.sendMessage("help me from the model")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(dispatcher.executedActionIDs == [.openSettings])
    }

    @MainActor
    @Test func retryPreservesOriginalModeWithoutDuplicatingUserMessage() async throws {
        let llm = TestLLMClient(responses: ["First answer", "Second answer"])
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.chatMode = .ask

        vm.sendMessage("Explain this canvas")
        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        let sourceMessage = try #require(
            vm.items.compactMap { item -> ChatBubbleItem? in
                guard case .message(let message) = item.content, message.isUser else {
                    return nil
                }
                return message
            }.first
        )
        vm.chatMode = .agent
        vm.retryTurn(sourceMessageID: sourceMessage.id)
        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        let userMessageCount = vm.items.reduce(into: 0) { count, item in
            guard case .message(let message) = item.content, message.isUser else { return }
            count += 1
        }
        #expect(userMessageCount == 1)
        #expect(llm.receivedMessages == ["Explain this canvas", "Explain this canvas"])
        #expect(llm.receivedChatModes == [.ask, .ask])
    }

    @MainActor
    @Test func dismissingChatDoesNotCancelAnActiveTurn() async throws {
        let llm = TestLLMClient(response: "Finished in the background")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.setPresented(true)

        vm.sendMessage("Keep working")
        vm.setPresented(false)
        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isPresented)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(vm.items.contains { item in
            guard case .message(let message) = item.content, !message.isUser else {
                return false
            }
            return message.text.contains("Finished in the background")
        })
    }

    @MainActor
    @Test func viewModelStreamsVisibleProseAndHidesStructuredPayload() async throws {
        let llm = ChunkedLLMClient(
            chunks: [
                "Renaming the headline",
                " now.\n\n<cocaptain_actions>\n  <assistant_message>Done.</assistant_message>\n  <node_edits>\n    <node_edit role=\"miniApp\" section=\"code\" summary=\"Rename\">\n      <operation type=\"replace_exact\">\n        <target>Hello World!</target>\n        <content><![CDATA[hi azzam]]></content>\n      </operation>\n    </node_edit>\n  </node_edits>\n</cocaptain_actions>"
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.chatMode = .agent
        vm.store = makeStore()

        vm.sendMessage("Rename the title to hi azzam")

        for _ in 0..<40 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)

        let assistantBubbles = vm.items.compactMap { item -> String? in
            guard case .message(let bubble) = item.content, !bubble.isUser else { return nil }
            return bubble.text
        }

        #expect(assistantBubbles.contains { $0.contains("Renaming the headline") })
        #expect(assistantBubbles.allSatisfy { !$0.contains("<cocaptain_actions>") })
        #expect(assistantBubbles.allSatisfy { !$0.contains("replace_exact") })
        #expect(vm.items.allSatisfy { item in
            if case .reviewBundle = item.content { return false }
            return true
        })
    }

    @MainActor
    @Test func viewModelStreamsVisibleTextInAskMode() async throws {
        let llm = ChunkedLLMClient(chunks: ["Here ", "are ", "three ideas."])
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.chatMode = .ask
        vm.store = makeStore()

        vm.sendMessage("what should we build?")

        for _ in 0..<40 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        let assistantText = vm.items.compactMap { item -> String? in
            guard case .message(let bubble) = item.content, !bubble.isUser else { return nil }
            return bubble.text
        }.joined(separator: "\n")
        #expect(assistantText.contains("three ideas"))
        #expect(vm.items.allSatisfy { item in
            if case .reviewBundle = item.content { return false }
            return true
        })
    }

    @MainActor
    @Test func projectScopeMentionsCombineMultipleNodeContexts() async throws {
        let store = makeStore()
        let firstID = try #require(store.nodes.first?.id)
        let otherNodeID = try #require(store.nodes.first(where: { $0.id != firstID })?.id)
        let llm = TestLLMClient(response: "Comparing the mentioned nodes.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        _ = try await coordinator.run(
            userMessage: "what does this node do?",
            store: store,
            dispatcher: nil,
            scope: .project,
            turnPlan: CoCaptainTurnPlan(purpose: .standard, mode: .ask),
            contextFocusNodeIDs: [firstID, otherNodeID]
        ) { _ in }

        let context = try #require(llm.receivedContexts.first ?? nil)
        #expect(context.contains("Selected Node ID: \(firstID.uuidString)"))
        #expect(context.contains("Selected Node ID: \(otherNodeID.uuidString)"))
        #expect(context.contains("Selected Node:"))
        #expect(context.contains("--- Mentioned node context ---"))
    }

    @Test func nodeAgentMessageRoundTripsMentionsAndAttachments() throws {
        let nodeID = UUID()
        let message = NodeAgentMessage(
            text: "Compare @Preview",
            isUser: true,
            mentions: [CoCaptainNodeMention(nodeID: nodeID, displayTitle: "Preview")],
            attachments: [
                CoCaptainAttachment(
                    fileName: "reference.txt",
                    mimeType: "text/plain",
                    data: Data("hello".utf8)
                )
            ]
        )

        let decoded = try JSONDecoder().decode(
            NodeAgentMessage.self,
            from: JSONEncoder().encode(message)
        )

        #expect(decoded == message)
    }

    @MainActor
    @Test func completedAssistantResponseCountAdvancesForDirectCommandResponses() {
        let dispatcher = TestActionDispatcher()
        let vm = CoCaptainViewModel()
        vm.actionDispatcher = dispatcher

        vm.sendMessage("open settings")

        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(dispatcher.executedActionIDs == [.openSettings])
    }

    @MainActor
    @Test func cancelledAgentTurnClearsThinkingState() async throws {
        let coordinator = CoCaptainAgentCoordinator(llmClient: ThrowingLLMClient(error: CancellationError()))
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("hi")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(vm.completedAssistantResponseCount == 0)
        #expect(vm.successfulAssistantResponseCount == 0)
    }

    @MainActor
    @Test func cancelledOnboardingBuildHandoffRecordsFailedCompletion() async throws {
        let coordinator = CoCaptainAgentCoordinator(llmClient: ThrowingLLMClient(error: CancellationError()))
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("I wanna make a pacman game", purpose: .onboardingBuildHandoff)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(vm.completedAssistantResponseCount == 0)
        #expect(vm.successfulAssistantResponseCount == 0)
        #expect(vm.lastTurnCompletion?.purpose == .onboardingBuildHandoff)
        #expect(vm.lastTurnCompletion?.succeeded == false)
        #expect(vm.lastTurnCompletion?.shouldAdvanceToCanvasDismissal == false)
    }

    @MainActor
    @Test func successfulOnboardingBuildHandoffRecordsTurnCompletion() async throws {
        let llm = TestLLMClient(
            response: "A todo app sounds great. Let's head back to the canvas and start building."
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("I wanna make a pacman game", purpose: .onboardingBuildHandoff)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(vm.lastTurnCompletion?.purpose == .onboardingBuildHandoff)
        #expect(vm.lastTurnCompletion?.succeeded == true)
        #expect(vm.lastTurnCompletion?.shouldAdvanceToCanvasDismissal == true)
        #expect(llm.receivedPurposes == [.onboardingBuildHandoff])
    }

    @MainActor
    @Test func failedOnboardingBuildHandoffShowsRetryMessageAndFailedCompletion() async throws {
        let llm = TestLLMClient(response: "")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("I wanna make a pacman game", purpose: .onboardingBuildHandoff)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.lastTurnCompletion?.purpose == .onboardingBuildHandoff)
        #expect(vm.lastTurnCompletion?.succeeded == false)
        #expect(vm.lastTurnCompletion?.shouldAdvanceToCanvasDismissal == false)
        #expect(vm.successfulAssistantResponseCount == 0)
        #expect(vm.items.contains { item in
            guard case .message(let bubble) = item.content else { return false }
            return bubble.text.contains("Please try sending your idea again.")
        })
    }

    @MainActor
    @Test func failedOnboardingBuildHandoffCanRetryWithoutCountingFailureAsSuccess() async throws {
        let llm = FailingThenSucceedingLLMClient(failureCount: 1)
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("I wanna make a pacman game", purpose: .onboardingBuildHandoff)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 0)
        #expect(vm.lastTurnCompletion?.succeeded == false)

        vm.sendMessage("a todo app again", purpose: .onboardingBuildHandoff)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.completedAssistantResponseCount == 2)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(vm.lastTurnCompletion?.purpose == .onboardingBuildHandoff)
        #expect(vm.lastTurnCompletion?.succeeded == true)
        #expect(vm.lastTurnCompletion?.shouldAdvanceToCanvasDismissal == true)
        #expect(llm.receivedPurposes.allSatisfy { $0 == .onboardingBuildHandoff })
    }

    @MainActor
    @Test func standardTurnCompletionDoesNotAdvanceToCanvasDismissal() async throws {
        let llm = TestLLMClient(response: "Here is how I can help.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("help me", purpose: .standard)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.lastTurnCompletion?.purpose == .standard)
        #expect(vm.lastTurnCompletion?.succeeded == true)
        #expect(vm.lastTurnCompletion?.shouldAdvanceToCanvasDismissal == false)
    }

    @MainActor
    @Test func failedOnboardingWelcomeCanRetryWithoutCountingFailureAsSuccess() async throws {
        let llm = FailingThenSucceedingLLMClient(failureCount: 2)
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("hi", purpose: .onboardingWelcome)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 0)
        let welcomeRetry = LocalizationManager.shared.localizedString(
            "I couldn't finish your welcome. Please try sending your message again."
        )
        #expect(vm.items.contains { item in
            switch item.content {
            case .message(let bubble):
                return bubble.text.contains(welcomeRetry)
            case .error(let error):
                return error.message.contains(welcomeRetry)
            default:
                return false
            }
        })

        vm.sendMessage("hi again", purpose: .onboardingWelcome)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.completedAssistantResponseCount == 2)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(llm.receivedPurposes.allSatisfy { $0 == .onboardingWelcome })
    }

    @Test func parserExtractsActionAttributesFromXML() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            <cocaptain_actions>
              <assistant_message>Navigate home.</assistant_message>
              <pending_actions>
                <action id="goRoot" label="home"/>
              </pending_actions>
            </cocaptain_actions>
            """

        let parsed = try #require(parser.parse(response).payload)
        #expect(parsed.pendingActions.count == 1)
        #expect(parsed.pendingActions[0].actionID == "goRoot")
        #expect(parsed.pendingActions[0].args?["label"] == "home")
    }

    @Test func commandIntentResolverRejectsNegatedInput() {
        let resolver = CommandIntentResolver()
        let actions = [
            AppActionDefinition(
                id: .goRoot,
                title: "Go to Root",
                icon: "house.fill",
                category: .navigation,
                isMutating: false,
                allowsAutonomousExecution: true
            )
        ]

        #expect(resolver.resolve("do not go home", availableActions: actions) == nil)
        #expect(resolver.resolve("go home", availableActions: actions) == .goRoot)
    }

    @MainActor
    @Test func coordinatorDoesNotRetryAgenticWorkForNegatedRequests() async throws {
        let llm = TestLLMClient(
            response:
                """
                Sure, I will not change anything.

                <cocaptain_actions>
                  <assistant_message>Sure, I will not change anything.</assistant_message>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        _ = try await coordinator.run(
            userMessage: "don't fix anything please",
            store: makeStore(),
            dispatcher: TestActionDispatcher()
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
    }

    @MainActor
    @Test func coordinatorRejectsUnknownPendingActionsBeforeDraft() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response:
                """
                <cocaptain_actions>
                  <assistant_message>Pending unknown action.</assistant_message>
                  <pending_actions><action id="launch_rocket"/></pending_actions>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "create a rocket",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(result.reviewDraft == nil)
    }

    @MainActor
    @Test func connectionFallbackStagesReviewWithoutExecutingSafeActions() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = FailingThenStructuredLLMClient(
            structuredResponse:
                """
                <cocaptain_actions>
                  <assistant_message>Fallback edit.</assistant_message>
                  <safe_actions><action id="goRoot"/></safe_actions>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update heading">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Fallback</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "update the code",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.reviewDraft == nil)
    }

    @MainActor
    @Test func connectionFallbackShowsDegradedNoticeWhenExecutableWorkMissing() async throws {
        let llm = FailingThenPlainLLMClient(fallbackResponse: "I can explain the idea, but I cannot apply changes right now.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "build a landing page",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(result.reviewDraft == nil)
        #expect(
            result.visibleText.contains(
                LocalizationManager.shared.localizedString("cocaptain.fallback.editsUnavailable")
            )
        )
    }

    @MainActor
    @Test func connectionFallbackOmitsDegradedNoticeForAskTurns() async throws {
        let llm = FailingThenPlainLLMClient(fallbackResponse: "Here are three ideas to explore next.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .ask)

        let result = try await coordinator.run(
            userMessage: "suggest three useful next improvements",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(
            !result.visibleText.contains(
                LocalizationManager.shared.localizedString("cocaptain.fallback.editsUnavailable")
            )
        )
    }

    @Test func chatModeStorageKeyAndComposerCopyAreStable() {
        #expect(CoCaptainChatMode.storageKey == "cocaptain.chatMode")
        #expect(CoCaptainChatMode(rawValue: "agent") == .agent)
        #expect(CoCaptainChatMode(rawValue: "ask") == .ask)
        #expect(CoCaptainChatMode(rawValue: "plan") == .plan)
        #expect(CoCaptainChatMode.allCases == [.agent, .ask, .plan])
        #expect(CoCaptainChatMode.agent.composerPlaceholder == LocalizationManager.shared.localizedString("cocaptain.composer.placeholder.agent"))
        #expect(CoCaptainChatMode.ask.composerPlaceholder == LocalizationManager.shared.localizedString("cocaptain.composer.placeholder.ask"))
        #expect(CoCaptainChatMode.plan.composerPlaceholder == LocalizationManager.shared.localizedString("cocaptain.composer.placeholder.plan"))
        #expect(CoCaptainChatMode.agent.displayName == LocalizationManager.shared.localizedString("Agent"))
        #expect(CoCaptainChatMode.ask.displayName == LocalizationManager.shared.localizedString("Ask"))
        #expect(CoCaptainChatMode.plan.displayName == LocalizationManager.shared.localizedString("Plan"))
    }

    @MainActor
    @Test func askModeNeverStagesReviewFromStructuredModelOutput() async throws {
        let llm = TestLLMClient(
            response: """
            Here is advice.

            <cocaptain_actions>
              <assistant_message>Renamed the title.</assistant_message>
              <safe_actions><action id="goRoot"/></safe_actions>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Rename title">
                  <operation type="replace_all">
                    <content><![CDATA[<html><body><h1>Should Not Stage</h1></body></html>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """
        )
        let dispatcher = TestActionDispatcher()
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .ask)

        let result = try await coordinator.run(
            userMessage: "rename the title to Cafe Menu",
            store: makeStore(),
            dispatcher: dispatcher,
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedExpectsStructuredResponse == [false])
        #expect(llm.receivedAvailableActionCounts == [0])
        #expect(llm.receivedToolExecutorPresence == [false])
        #expect(llm.receivedChatModes == [.ask])
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.reviewDraft == nil)
        #expect(result.executionSummary == nil)
        #expect(result.clarifyingQuestion == nil)
        #expect(result.visibleText.contains("Here is advice"))
        #expect(!result.visibleText.contains("Should Not Stage"))
    }

    @MainActor
    @Test func planModeNeverStagesReviewAndUsesPlanPromptPosture() async throws {
        let llm = TestLLMClient(
            response: """
            1. Clarify the goal
            2. Sketch the screen
            3. Wire the main action

            <cocaptain_actions>
              <assistant_message>Renamed the title.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Rename title">
                  <operation type="replace_all">
                    <content><![CDATA[<html><body><h1>Should Not Stage</h1></body></html>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """
        )
        let dispatcher = TestActionDispatcher()
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .plan)

        let result = try await coordinator.run(
            userMessage: "plan how to rename the title",
            store: makeStore(),
            dispatcher: dispatcher,
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedExpectsStructuredResponse == [false])
        #expect(llm.receivedAvailableActionCounts == [0])
        #expect(llm.receivedToolExecutorPresence == [false])
        #expect(llm.receivedChatModes == [.plan])
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.reviewDraft == nil)
        #expect(result.visibleText.contains("Clarify the goal"))
        #expect(!result.visibleText.contains("Should Not Stage"))

        let planPrompt = LLMService.shared.buildPrompt(
            userMessage: "plan how to rename the title",
            context: "SRS Readiness: draft",
            expectsStructuredResponse: false,
            availableActions: [],
            scope: .project,
            purpose: .standard,
            chatMode: .plan
        )
        #expect(planPrompt.contains("Plan mode objective:"))
        #expect(planPrompt.contains("numbered list"))
        #expect(planPrompt.contains("Do not request app actions"))
        #expect(!planPrompt.contains("Agent contract:"))
        #expect(!planPrompt.contains("Ask mode objective:"))
    }

    @MainActor
    @Test func askModeUsesProductContextAndAskPromptPosture() async throws {
        let store = makeStore()
                let llm = TestLLMClient(response: "Try clarifying the main user goal first.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .ask)

        _ = try await coordinator.run(
            userMessage: "what should we improve next?",
            store: store,
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        let context = try #require(llm.receivedContexts.first ?? nil)
        #expect(!context.contains("SRS Readiness:"))
        #expect(!context.contains("Mini-App Firebase wiring rules"))
        #expect(!context.contains("__caocapFirestore"))
        #expect(!context.contains("Firebase Config:"))

        let askPrompt = LLMService.shared.buildPrompt(
            userMessage: "what should we improve next?",
            context: context,
            expectsStructuredResponse: false,
            availableActions: TestActionDispatcher().availableActions,
            scope: .project,
            purpose: .standard,
            chatMode: .ask
        )
        #expect(askPrompt.contains("Ask mode objective:"))
        #expect(askPrompt.contains("Do not request app actions"))
        #expect(!askPrompt.contains("Agent contract:"))
    }

    @MainActor
    @Test func askModeSkipsMutatingDirectCommandShortCircuit() async throws {
        let llm = TestLLMClient(response: "Creating a Mini-App changes the canvas; here is how to think about it first.")
        let dispatcher = TestActionDispatcher()
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.store = makeStore()
        vm.actionDispatcher = dispatcher
        vm.chatMode = .ask

        vm.sendMessage("create mini-app")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(vm.pendingReviewCount == 0)
        #expect(llm.receivedMessages == ["create mini-app"])
        #expect(llm.receivedChatModes == [.ask])
        #expect(llm.receivedExpectsStructuredResponse == [false])
        #expect(
            vm.items.contains { item in
                guard case .message(let bubble) = item.content, !bubble.isUser else { return false }
                return bubble.text.contains("Creating a Mini-App")
            }
        )
    }

    @MainActor
    @Test func askModeStillAllowsNonMutatingAutonomousDirectCommands() async throws {
        let dispatcher = TestActionDispatcher()
        let vm = CoCaptainViewModel()
        vm.actionDispatcher = dispatcher
        vm.chatMode = .ask

        vm.sendMessage("open settings")

        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(dispatcher.executedActionIDs == [.openSettings])
        #expect(vm.pendingReviewCount == 0)
    }

    @MainActor
    @Test func commandIntentResolverMatchesOpenYouTubeOnMac() {
        let resolver = CommandIntentResolver()
        let actions = TestActionDispatcher().availableActions

        #expect(resolver.resolve("open youtube on my mac", availableActions: actions) == .openYouTubeOnMac)
        #expect(resolver.resolve("open youtube on mac", availableActions: actions) == .openYouTubeOnMac)
        #expect(resolver.resolve("please open youtube on my mac", availableActions: actions) == .openYouTubeOnMac)
        #expect(resolver.resolve("افتح يوتيوب على الماك", availableActions: actions) == .openYouTubeOnMac)
        #expect(resolver.resolve("افتح يوتيوب على جهاز الماك", availableActions: actions) == .openYouTubeOnMac)
        #expect(resolver.resolve("youtube", availableActions: actions) == nil)
        #expect(resolver.resolve("open youtube", availableActions: actions) == nil)
        #expect(
            resolver.resolve(
                "find a beginner SwiftUI tutorial on YouTube and open it on my Mac",
                availableActions: actions
            ) == nil
        )
        #expect(
            resolver.resolve(
                "find a beginner SwiftUI tutorial and open it on my Mac",
                availableActions: actions
            ) == nil
        )
        #expect(resolver.resolve("do not open youtube on my mac", availableActions: actions) == nil)
    }

    @MainActor
    @Test func agentModeOpenYouTubeOnMacUsesReceiptFromRunner() async throws {
        let dispatcher = TestActionDispatcher()
        let runner = TestRemoteMacCommandRunner()
        let vm = CoCaptainViewModel()
        vm.store = makeStore()
        vm.actionDispatcher = dispatcher
        vm.remoteMacCommands = runner
        vm.chatMode = .agent

        vm.sendMessage("open youtube on my mac")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(runner.requestCount == 1)
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(
            vm.items.contains { item in
                guard case .execution(let status) = item.content else { return false }
                return status.summary == "YouTube opened on your Mac"
            }
        )
    }

    @MainActor
    @Test func askModeSkipsOpenYouTubeOnMacDirectCommand() async throws {
        let llm = TestLLMClient(response: "I can talk about sending that to your Mac in Agent mode.")
        let dispatcher = TestActionDispatcher()
        let runner = TestRemoteMacCommandRunner()
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.store = makeStore()
        vm.actionDispatcher = dispatcher
        vm.remoteMacCommands = runner
        vm.chatMode = .ask

        vm.sendMessage("open youtube on my mac")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(runner.requestCount == 0)
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(llm.receivedMessages == ["open youtube on my mac"])
        #expect(llm.receivedChatModes == [.ask])
        #expect(llm.receivedExpectsStructuredResponse == [false])
    }

    @MainActor
    @Test func agentModeRunsOpenYouTubeOnMacFromSafeAction() async throws {
        let dispatcher = TestActionDispatcher()
        let runner = TestRemoteMacCommandRunner()
        let llm = TestLLMClient(
            response: "Opening YouTube on your Mac.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: ["actionId": "open_youtube_on_mac", "executionMode": "safe"]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let result = try await coordinator.run(
            userMessage: "open youtube on my mac",
            store: makeStore(),
            dispatcher: dispatcher,
            remoteMacCommands: runner
        ) { _ in }

        #expect(runner.requestCount == 1)
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.executionSummary?.summary == "YouTube opened on your Mac")
    }

    @MainActor
    @Test func agentModeRunsOpenYouTubeVideoFromSafeAction() async throws {
        let dispatcher = TestActionDispatcher()
        let runner = TestRemoteMacCommandRunner()
        let llm = TestLLMClient(
            response: "Opening a beginner SwiftUI tutorial on your Mac.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: [
                        "actionId": "open_youtube_video_on_mac",
                        "executionMode": "safe",
                        "url": "https://youtu.be/dQw4w9WgXcQ"
                    ]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let result = try await coordinator.run(
            userMessage: "Find a beginner SwiftUI tutorial on YouTube and open it on my Mac",
            store: makeStore(),
            dispatcher: dispatcher,
            remoteMacCommands: runner
        ) { _ in }

        #expect(runner.requestCount == 0)
        #expect(runner.videoRequestCount == 1)
        #expect(runner.lastVideoURL == "https://youtu.be/dQw4w9WgXcQ")
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.executionSummary?.summary == "This video opened on your Mac")
    }

    @MainActor
    @Test func agentModeRunsOpenURLFromSafeAction() async throws {
        let dispatcher = TestActionDispatcher()
        let runner = TestRemoteMacCommandRunner()
        let llm = TestLLMClient(
            response: "Opening Apple’s SwiftUI tutorial on your Mac.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: [
                        "actionId": "open_url_on_mac",
                        "executionMode": "safe",
                        "url": "https://developer.apple.com/tutorials/swiftui"
                    ]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let result = try await coordinator.run(
            userMessage: "Find a beginner SwiftUI tutorial and open it on my Mac",
            store: makeStore(),
            dispatcher: dispatcher,
            remoteMacCommands: runner
        ) { _ in }

        #expect(runner.requestCount == 0)
        #expect(runner.videoRequestCount == 0)
        #expect(runner.pageRequestCount == 1)
        #expect(runner.lastPageURL == "https://developer.apple.com/tutorials/swiftui")
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.executionSummary?.summary == "This page opened on your Mac")
    }

    @MainActor
    @Test func agentModeRejectsDisallowedOpenURL() async throws {
        let dispatcher = TestActionDispatcher()
        let runner = TestRemoteMacCommandRunner()
        let llm = TestLLMClient(
            response: "Opening that link on your Mac.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: [
                        "actionId": "open_url_on_mac",
                        "executionMode": "safe",
                        "url": "https://example.com/tutorials/swiftui"
                    ]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let result = try await coordinator.run(
            userMessage: "open this tutorial on my Mac",
            store: makeStore(),
            dispatcher: dispatcher,
            remoteMacCommands: runner
        ) { _ in }

        #expect(runner.pageRequestCount == 1)
        #expect(runner.videoRequestCount == 0)
        #expect(result.executionSummary?.summary == "That link cannot be opened on your Mac")
    }

    @MainActor
    @Test func agentModeRejectsInvalidYouTubeVideoURL() async throws {
        let dispatcher = TestActionDispatcher()
        let runner = TestRemoteMacCommandRunner()
        let llm = TestLLMClient(
            response: "Opening that link on your Mac.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: [
                        "actionId": "open_youtube_video_on_mac",
                        "executionMode": "safe",
                        "url": "https://example.com/watch?v=dQw4w9WgXcQ"
                    ]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let result = try await coordinator.run(
            userMessage: "open this video on my Mac",
            store: makeStore(),
            dispatcher: dispatcher,
            remoteMacCommands: runner
        ) { _ in }

        #expect(runner.videoRequestCount == 1)
        #expect(runner.requestCount == 0)
        #expect(result.executionSummary?.summary == "That YouTube link cannot be opened on your Mac")
    }

    @MainActor
    @Test func agentModeRejectsMissingYouTubeVideoURL() async throws {
        let dispatcher = TestActionDispatcher()
        let runner = TestRemoteMacCommandRunner()
        let llm = TestLLMClient(
            response: "Opening that video on your Mac.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: [
                        "actionId": "open_youtube_video_on_mac",
                        "executionMode": "safe"
                    ]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let result = try await coordinator.run(
            userMessage: "open a SwiftUI tutorial on my Mac",
            store: makeStore(),
            dispatcher: dispatcher,
            remoteMacCommands: runner
        ) { _ in }

        #expect(runner.videoRequestCount == 1)
        #expect(runner.lastVideoURL == "")
        #expect(runner.requestCount == 0)
        #expect(result.executionSummary?.summary == "That YouTube link cannot be opened on your Mac")
    }

    @MainActor
    @Test func askModeDoesNotExecuteYouTubeTutorialAction() async throws {
        let llm = TestLLMClient(response: "I can talk about finding a tutorial without sending it to your Mac.")
        let dispatcher = TestActionDispatcher()
        let runner = TestRemoteMacCommandRunner()
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.store = makeStore()
        vm.actionDispatcher = dispatcher
        vm.remoteMacCommands = runner
        vm.chatMode = .ask

        vm.sendMessage("Find a beginner SwiftUI tutorial and open it on my Mac")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(runner.requestCount == 0)
        #expect(runner.videoRequestCount == 0)
        #expect(runner.pageRequestCount == 0)
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(llm.receivedMessages == ["Find a beginner SwiftUI tutorial and open it on my Mac"])
        #expect(llm.receivedExpectsStructuredResponse == [false])
    }

    @MainActor
    @Test func agentPureProseResponseDoesNotRetry() async throws {
        let llm = TestLLMClient(response: "Here are three ideas to explore next.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "what should we build?",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(result.reviewDraft == nil)
        #expect(result.visibleText.contains("three ideas"))
    }

    @MainActor
    @Test func agentStagesReviewFromStructuredEditWithoutMutatingVerbs() async throws {
        let llm = TestLLMClient(
            response: """
            <cocaptain_actions>
              <assistant_message>Renamed the title.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Rename title">
                  <operation type="replace_all">
                    <content><![CDATA[<html><body><h1>Cafe Menu</h1></body></html>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "the title should be Cafe Menu",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(result.reviewDraft == nil)
    }

    @MainActor
    @Test func agentInvalidStructuredPayloadStillRetries() async throws {
        let llm = TestLLMClient(
            responses: [
                """
                <cocaptain_actions>
                  <assistant_message>Broken edit.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Broken</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """,
                """
                <cocaptain_actions>
                  <assistant_message>Fixed heading.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update heading">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Retry</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "rename the title",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(result.reviewDraft == nil)
    }

    @MainActor
    @Test func onboardingGuidedEditChatOnlyResponseTriggersRetry() async throws {
        let llm = TestLLMClient(
            responses: [
                "I can describe the landing page in chat.",
                """
                <cocaptain_actions>
                  <assistant_message>Created a card.</assistant_message>
                  <pending_actions>
                    <action id="create_node"/>
                  </pending_actions>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .onboardingGuidedEdit, mode: .agent)

        _ = try await coordinator.run(
            userMessage: "rename the title to Hello CAOCAP",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            purpose: .onboardingGuidedEdit,
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages[1].contains("request_app_action"))
    }

    @MainActor
    @Test func onboardingWelcomeStaysConversational() async throws {
        let llm = TestLLMClient(
            response: """
            Welcome! I help you build apps.
            <cocaptain_actions>
              <assistant_message>Should be ignored.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Ignored">
                  <operation type="replace_all">
                    <content><![CDATA[<h1>Nope</h1>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .onboardingWelcome, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "hi",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            purpose: .onboardingWelcome,
            turnPlan: turnPlan
        ) { _ in }

        #expect(result.reviewDraft == nil)
        #expect(llm.receivedMessages.count == 1)
    }
    @Test func parserExtractsClarifyingQuestion() {
        let parser = CoCaptainAgentParser()
        let response = """
        Let me make sure I understand.
        <cocaptain_actions>
          <assistant_message>Happy to help!</assistant_message>
          <clarifying_question prompt="What kind of change did you have in mind?">
            <option>Make the colors brighter</option>
            <option>Make the text bigger</option>
            <option>Add a fun animation</option>
          </clarifying_question>
        </cocaptain_actions>
        """

        let parsed = parser.parse(response)
        let question = parsed.payload?.clarifyingQuestion

        #expect(question?.prompt == "What kind of change did you have in mind?")
        #expect(question?.options == [
            "Make the colors brighter",
            "Make the text bigger",
            "Add a fun animation"
        ])
    }

    @Test func parserDropsMalformedClarifyingQuestion() {
        let parser = CoCaptainAgentParser()
        let response = """
        <cocaptain_actions>
          <assistant_message>Hmm.</assistant_message>
          <clarifying_question prompt="Only one option?">
            <option>Just this</option>
          </clarifying_question>
        </cocaptain_actions>
        """

        let parsed = parser.parse(response)

        #expect(parsed.payload?.clarifyingQuestion == nil)
        #expect(parsed.payload?.assistantMessage == "Hmm.")
    }

    @MainActor
    @Test func validatorAcceptsQuestionOnlyPayloadAsAgenticWork() {
        let validator = CoCaptainAgentValidator()
        let payload = CoCaptainAgentPayload(
            assistantMessage: "Quick question first.",
            clarifyingQuestion: CoCaptainClarifyingQuestion(
                prompt: "Which one did you mean?",
                options: ["The heading", "The button"]
            )
        )

        let result = validator.validate(
            payload: payload,
            dispatcher: nil,
            requiresAgenticWork: true
        )

        #expect(result.isValid)
    }

    @MainActor
    @Test func coordinatorReturnsClarifyingQuestionAndDropsAccompanyingEdits() async throws {
        let response = """
        <cocaptain_actions>
          <assistant_message>Before I change anything, one question.</assistant_message>
          <clarifying_question prompt="Which look do you want?">
            <option>Bright and playful</option>
            <option>Dark and sleek</option>
          </clarifying_question>
          <node_edits>
            <node_edit role="miniApp" section="code" summary="Update heading">
              <operation type="replace_exact">
                <target>Hello World!</target>
                <content><![CDATA[hi]]></content>
              </operation>
            </node_edit>
          </node_edits>
        </cocaptain_actions>
        """
        let llm = TestLLMClient(response: response)
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "change the look of my app",
            store: makeStore(),
            dispatcher: nil
        ) { _ in }

        #expect(result.clarifyingQuestion?.prompt == "Which look do you want?")
        #expect(result.clarifyingQuestion?.options.count == 2)
        #expect(result.reviewDraft == nil)
    }

    @MainActor
    @Test func answeringClarifyingQuestionLocksCardAndSendsOption() throws {
        let llm = TestLLMClient(response: "Nice choice!")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let viewModel = CoCaptainViewModel(agentCoordinator: coordinator)
        viewModel.configureProjectSession(store: nil, dispatcher: nil)

        let questionItem = CoCaptainClarifyingQuestionItem(
            question: CoCaptainClarifyingQuestion(
                prompt: "What should we improve?",
                options: ["Make the text bigger", "Change the colors"]
            )
        )
        let timelineItem = CoCaptainTimelineItem(content: .clarifyingQuestion(questionItem))
        viewModel.items.append(timelineItem)

        viewModel.answerClarifyingQuestion(itemID: timelineItem.id, option: "Change the colors")

        guard let index = viewModel.items.firstIndex(where: { $0.id == timelineItem.id }),
              case .clarifyingQuestion(let answered) = viewModel.items[index].content else {
            Issue.record("Expected the clarifying question item to remain")
            return
        }
        #expect(answered.answeredOption == "Change the colors")

        let sentUserMessage = viewModel.items.contains { item in
            guard case .message(let bubble) = item.content else { return false }
            return bubble.isUser && bubble.text == "Change the colors"
        }
        #expect(sentUserMessage)

        // A second tap must not re-send.
        viewModel.answerClarifyingQuestion(itemID: timelineItem.id, option: "Make the text bigger")
        guard case .clarifyingQuestion(let stillAnswered) = viewModel.items[index].content else {
            Issue.record("Expected the clarifying question item to remain")
            return
        }
        #expect(stillAnswered.answeredOption == "Change the colors")
    }

    // MARK: - Phase 3: node edits via function calling

    @Test func nodeEditFunctionAdapterMapsClarifyingQuestion() throws {
        let adapter = CoCaptainNodeEditFunctionAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainNodeEditTools.askClarifyingQuestionName,
                arguments: [
                    "prompt": "Which look do you want?",
                    "options": ["Bright and playful", "Dark and sleek"]
                ]
            )
        ])

        #expect(directive.payload?.clarifyingQuestion?.prompt == "Which look do you want?")
        #expect(directive.payload?.clarifyingQuestion?.options.count == 2)

        let tooFewOptions = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainNodeEditTools.askClarifyingQuestionName,
                arguments: ["prompt": "Vague?", "options": ["Only one"]]
            )
        ])
        #expect(tooFewOptions.payload == nil)
        #expect(tooFewOptions.diagnostics.isEmpty == false)
    }

    @MainActor
    @Test func functionCalledClarifyingQuestionBeatsFunctionCalledEdits() async throws {
        let llm = TestLLMClient(
            response: "One question first.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainNodeEditTools.askClarifyingQuestionName,
                    arguments: [
                        "prompt": "Which look do you want?",
                        "options": ["Bright and playful", "Dark and sleek"]
                    ]
                ),
                CoCaptainAgentFunctionCall(
                    name: "propose_node_edit",
                    arguments: [
                        "summary": "Guessy restyle",
                        "operations": [["type": "replace_all", "content": "<h1>Guess</h1>"]]
                    ]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "change the look",
            store: makeStore(),
            dispatcher: nil
        ) { _ in }

        #expect(result.clarifyingQuestion?.prompt == "Which look do you want?")
        #expect(result.reviewDraft == nil)
    }

    @MainActor
    @Test func buildPromptSwitchesContractWithNodeEditToolsFlag() {
        func prompt(toolsEnabled: Bool) -> String {
            LLMService.shared.buildPrompt(
                userMessage: "build a landing page",
                context: "Canvas context",
                expectsStructuredResponse: true,
                availableActions: [],
                scope: .project,
                purpose: .standard,
                chatMode: .agent,
                nodeEditToolsEnabled: toolsEnabled
            )
        }

        let toolsPrompt = prompt(toolsEnabled: true)
        #expect(!toolsPrompt.contains("propose_node_edit"))
        #expect(toolsPrompt.contains("ask_clarifying_question"))
        #expect(toolsPrompt.contains("cocaptain_actions") == false)

        let xmlPrompt = prompt(toolsEnabled: false)
        #expect(xmlPrompt.contains("XML schema for `cocaptain_actions`"))
        #expect(!xmlPrompt.contains("<learning_note"))
        #expect(xmlPrompt.contains("propose_node_edit") == false)
    }

    @MainActor
    @Test func agentPromptSendsTutorialFindsToDocumentationHosts() {
        let prompt = LLMService.shared.buildPrompt(
            userMessage: "Find a beginner SwiftUI tutorial and open it on my Mac",
            context: nil,
            expectsStructuredResponse: true,
            availableActions: TestActionDispatcher().availableActions,
            scope: .project,
            purpose: .standard,
            chatMode: .agent
        )
        #expect(prompt.contains("open_url_on_mac"))
        #expect(prompt.contains("developer.apple.com"))
        #expect(prompt.contains("Do not use YouTube"))
        #expect(!prompt.contains("https://www.youtube.com/watch?v=HyQgpxX__-A"))
        #expect(!prompt.contains("Never invent a video id"))
    }

    @MainActor
    private func makeStore() -> ProjectStore {
        ProjectStore(
            fileName: "onboarding-test-\(UUID().uuidString).json",
            projectName: "Test Project",
            initialNodes: [
                SpatialNode(
                    type: .standard,
                    position: CGPoint(x: 0, y: 0),
                    title: "Card",
                    theme: .blue
                ),
                SpatialNode(
                    type: .standard,
                    position: CGPoint(x: 80, y: 0),
                    title: "Other",
                    theme: .indigo
                )
            ]
        )
    }
}

@MainActor
private final class ThrowingLLMClient: CoCaptainLLMClient {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}

@MainActor
private final class AttachmentRejectingLLMClient: CoCaptainLLMClient {
    private(set) var streamCount = 0

    func resetChat(scope: CoCaptainAgentScope) {}

    func submissionError(for attachments: [CoCaptainAttachment]) -> CoCaptainSubmissionError? {
        attachments.isEmpty ? nil : .attachmentsRequireCloud
    }

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        streamCount += 1
        return AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

@MainActor
private final class TestLLMClient: CoCaptainLLMClient {
    private let responses: [String]
    private let functionCalls: [[CoCaptainAgentFunctionCall]]
    private var streamCount = 0
    var receivedMessages: [String] = []
    var receivedScopes: [CoCaptainAgentScope] = []
    var receivedPurposes: [CoCaptainTurnPurpose] = []
    var receivedChatModes: [CoCaptainChatMode] = []
    var receivedExpectsStructuredResponse: [Bool] = []
    var receivedAvailableActionCounts: [Int] = []
    var receivedContexts: [String?] = []
    var receivedToolExecutorPresence: [Bool] = []

    init(response: String) {
        self.responses = [response]
        self.functionCalls = []
    }

    init(response: String, functionCalls: [[CoCaptainAgentFunctionCall]]) {
        self.responses = [response]
        self.functionCalls = functionCalls
    }

    init(responses: [String]) {
        self.responses = responses
        self.functionCalls = []
    }

    init(responses: [String], functionCalls: [[CoCaptainAgentFunctionCall]]) {
        self.responses = responses
        self.functionCalls = functionCalls
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        receivedMessages.append(userMessage)
        receivedScopes.append(scope)
        receivedPurposes.append(purpose)
        receivedChatModes.append(chatMode)
        receivedExpectsStructuredResponse.append(expectsStructuredResponse)
        receivedAvailableActionCounts.append(availableActions.count)
        receivedContexts.append(context)
        receivedToolExecutorPresence.append(toolExecutor != nil)
        let index = streamCount
        let response = responses[min(index, responses.count - 1)]
        let calls = functionCalls.indices.contains(index) ? functionCalls[index] : []
        streamCount += 1

        return AsyncThrowingStream { continuation in
            continuation.yield(.text(response))
            if !calls.isEmpty {
                continuation.yield(.functionCalls(calls))
            }
            continuation.finish()
        }
    }
}

/// Yields text in multiple chunks so ViewModel streaming can be observed.
@MainActor
private final class ChunkedLLMClient: CoCaptainLLMClient {
    private let chunks: [String]

    init(chunks: [String]) {
        self.chunks = chunks
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        let chunks = self.chunks
        return AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(.text(chunk))
            }
            continuation.finish()
        }
    }
}

/// Simulates the LLMService tool loop: emits one tool call, answers it through
/// the injected executor when possible, then streams the final response text.
/// Calls the executor declines (returns `nil` for) are yielded as
/// `.functionCalls` events, mirroring the real collect-and-route behavior.
@MainActor
private final class ToolLoopLLMClient: CoCaptainLLMClient {
    private let toolCall: CoCaptainAgentFunctionCall
    private let finalResponse: String
    private(set) var capturedToolResults: [String] = []

    init(toolCall: CoCaptainAgentFunctionCall, finalResponse: String) {
        self.toolCall = toolCall
        self.finalResponse = finalResponse
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        let call = toolCall
        let response = finalResponse
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                if let toolExecutor, let result = await toolExecutor(call) {
                    self.capturedToolResults.append(result)
                } else {
                    continuation.yield(.functionCalls([call]))
                }
                continuation.yield(.text(response))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@MainActor
private final class FailingThenPlainLLMClient: CoCaptainLLMClient {
    private let fallbackResponse: String

    init(fallbackResponse: String) {
        self.fallbackResponse = fallbackResponse
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        if expectsStructuredResponse, context != nil {
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: NSError(
                        domain: "CoCaptainFallbackTest",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Structured request failed"]
                    )
                )
            }
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(.text(fallbackResponse))
            continuation.finish()
        }
    }
}

@MainActor
private final class FailingThenStructuredLLMClient: CoCaptainLLMClient {
    private let structuredResponse: String

    init(structuredResponse: String) {
        self.structuredResponse = structuredResponse
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        if expectsStructuredResponse, context != nil {
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: NSError(
                        domain: "CoCaptainFallbackTest",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Structured request failed"]
                    )
                )
            }
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(.text(structuredResponse))
            continuation.finish()
        }
    }
}

@MainActor
private final class FailingThenSucceedingLLMClient: CoCaptainLLMClient {
    private var remainingFailures: Int
    var receivedPurposes: [CoCaptainTurnPurpose] = []

    init(failureCount: Int) {
        self.remainingFailures = failureCount
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        receivedPurposes.append(purpose)

        if remainingFailures > 0 {
            remainingFailures -= 1
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: NSError(
                        domain: "CoCaptainOnboardingTest",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Temporary model failure"]
                    )
                )
            }
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(.text("Welcome! What would you like to make?"))
            continuation.finish()
        }
    }
}

@MainActor
private final class TestActionDispatcher: AppActionPerforming {
    let availableActions: [AppActionDefinition] = [
        AppActionDefinition(
            id: .goRoot,
            title: "Go to Root",
            icon: "house.fill",
            category: .navigation,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .createNode,
            title: "Create New Node",
            icon: "plus.square",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .openSettings,
            title: "Open Settings",
            icon: "gearshape.fill",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .help,
            title: "Help",
            icon: "questionmark.circle",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .proSubscription,
            title: "Pro Subscription",
            icon: "crown",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .openYouTubeOnMac,
            title: "Open YouTube homepage on the signed-in Mac (no search)",
            icon: "play.rectangle.fill",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .openYouTubeVideoOnMac,
            title: "Open a specific YouTube watch URL on the signed-in Mac",
            icon: "play.rectangle.fill",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .openURLOnMac,
            title: "Open an allowlisted documentation URL on the signed-in Mac",
            icon: "safari",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: true
        )
    ]

    var executedActionIDs: [AppActionID] = []
    var executedSources: [AppActionSource] = []

    func definition(for id: AppActionID) -> AppActionDefinition? {
        availableActions.first(where: { $0.id == id })
    }

    @discardableResult
    func perform(_ id: AppActionID, source: AppActionSource, arguments: [String: String]? = nil) -> AppActionResult {
        guard let definition = definition(for: id) else {
            return AppActionResult(actionID: id, title: id.rawValue, executed: false, message: "Missing")
        }

        if source == .agentAutomatic && (definition.isMutating || !definition.allowsAutonomousExecution) {
            return AppActionResult(actionID: id, title: definition.title, executed: false, message: "Blocked")
        }

        executedActionIDs.append(id)
        executedSources.append(source)
        return AppActionResult(actionID: id, title: definition.title, executed: true, message: "\(definition.title) executed.")
    }
}

@MainActor
private final class TestRemoteMacCommandRunner: RemoteMacCommandRunning {
    var requestCount = 0
    var videoRequestCount = 0
    var pageRequestCount = 0
    var lastVideoURL: String?
    var lastPageURL: String?
    var result = "YouTube opened on your Mac"
    var videoResult = "This video opened on your Mac"
    var pageResult = "This page opened on your Mac"

    func requestOpenYouTubeOnMac() async -> String {
        requestCount += 1
        return result
    }

    func requestOpenYouTubeVideoOnMac(url: String) async -> String {
        videoRequestCount += 1
        lastVideoURL = url
        if RemoteCommandMapping.canonicalWatchURL(from: url) == nil {
            return RemoteCommandChatCopy.invalidURLMessage(for: .video)
        }
        return videoResult
    }

    func requestOpenURLOnMac(url: String) async -> String {
        pageRequestCount += 1
        lastPageURL = url
        if RemoteCommandMapping.canonicalDocumentationURL(from: url) == nil {
            return RemoteCommandChatCopy.invalidURLMessage(for: .page)
        }
        return pageResult
    }
}
