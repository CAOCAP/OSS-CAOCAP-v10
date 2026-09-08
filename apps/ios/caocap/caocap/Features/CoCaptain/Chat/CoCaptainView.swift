import SwiftUI
import UIKit

struct CoCaptainView: View {
    @Bindable var viewModel: CoCaptainViewModel
    var onRequestExpandedPresentation: (() -> Void)?
    private var text: String {
        get { viewModel.composerText }
        nonmutating set { viewModel.composerText = newValue }
    }
    private var mentions: [CoCaptainNodeMention] {
        get { viewModel.composerMentions }
        nonmutating set { viewModel.composerMentions = newValue }
    }
    private var attachments: [CoCaptainAttachment] {
        get { viewModel.composerAttachments }
        nonmutating set { viewModel.composerAttachments = newValue }
    }
    @State private var isConversationListPresented = false
    @FocusState private var isFocused: Bool
    @AppStorage(CoCaptainChatMode.storageKey) private var chatModeRawValue = CoCaptainChatMode.agent.rawValue
    
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var chatModeBinding: Binding<CoCaptainChatMode> {
        Binding(
            get: {
                CoCaptainChatMode(rawValue: chatModeRawValue) ?? .agent
            },
            set: { newValue in
                chatModeRawValue = newValue.rawValue
                viewModel.chatMode = newValue
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CoCaptainTimelineListView(
                    viewModel: viewModel,
                    lastScrollPosition: $viewModel.lastScrollPosition,
                    isFocused: $isFocused
                )

                CoCaptainInputComposer(
                    text: $viewModel.composerText,
                    chatMode: chatModeBinding,
                    mentions: $viewModel.composerMentions,
                    attachments: $viewModel.composerAttachments,
                    isFocused: $isFocused,
                    store: viewModel.store,
                    allowsContextPinning: true,
                    pinnableNodes: viewModel.pinnableContextNodes,
                    isThinking: viewModel.isThinking,
                    isConversationArchiveLoading: viewModel.isConversationArchiveLoading,
                    analysisItems: viewModel.analysisItems,
                    pendingReviewCount: viewModel.pendingReviewCount,
                    onSend: sendCurrentMessage,
                    onStop: viewModel.stopStreaming,
                    onFocusPendingReviews: {
                        onRequestExpandedPresentation?()
                        viewModel.focusPendingReviews()
                    },
                    onApplySuggestion: viewModel.applySuggestion,
                    onDismissSuggestion: viewModel.dismissSuggestion
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isFocused = false
                        isConversationListPresented = true
                    } label: {
                        Image(
                            systemName: horizontalSizeClass == .regular
                                ? "sidebar.left"
                                : "bubble.left.and.bubble.right"
                        )
                            .overlay(alignment: .topTrailing) {
                                if viewModel.pendingReviewCount > 0 {
                                    Text("\(viewModel.pendingReviewCount)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(3)
                                        .background(Color.orange, in: Circle())
                                        .offset(x: 7, y: -7)
                                }
                            }
                    }
                    .accessibilityLabel(
                        LocalizationManager.shared.localizedString("Open conversations")
                    )
                }

                ToolbarItem(placement: .principal) {
                    Button {
                        isFocused = false
                        isConversationListPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            VStack(spacing: 1) {
                                Text(viewModel.activeConversationTitle)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(viewModel.agentDisplayName)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        LocalizationManager.shared.localizedString(
                            "Open conversations"
                        )
                    )
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isFocused = false
                        viewModel.createConversation()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(viewModel.isThinking || viewModel.isConversationArchiveLoading)
                    .accessibilityLabel(
                        LocalizationManager.shared.localizedString("New conversation")
                    )

                    if horizontalSizeClass != .regular {
                        Button("Done") {
                            isFocused = false
                            viewModel.setPresented(false)
                        }
                        .onboardingTooltipAnchor(.coCaptainDoneButton)
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { viewModel.showingMacSignIn }, set: { viewModel.showingMacSignIn = $0 })) {
            SignInView()
        }
        .sheet(isPresented: $isConversationListPresented) {
            CoCaptainConversationListView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .coCaptainOnboardingTooltipOverlay()
        .onChange(of: text) { oldValue, newValue in
            hideChatOnboardingWhenTypingChanges(from: oldValue, to: newValue)
        }
        .onChange(of: isFocused) { _, isFocused in
            if isFocused {
                onRequestExpandedPresentation?()
            }
        }
        .onChange(of: viewModel.lastTurnCompletion) { _, completion in
            advanceOnboardingAfterGuidedEdit(completion)
        }
        .onChange(of: onboarding?.currentStep) { _, step in
            if step == .chatCoCaptain {
                hideChatOnboardingIfTextIsPresent()
            }
        }
        .onAppear {
            syncChatModeFromStorage()
            hideChatOnboardingIfTextIsPresent()
        }
        .onChange(of: chatModeRawValue) { _, _ in
            syncChatModeFromStorage()
        }
        .onChange(of: viewModel.composerDraftRequest) { _, draft in
            guard let draft else { return }
            text = draft.text
            mentions = draft.mentions
            attachments = draft.attachments
            viewModel.composerDraftRequest = nil
            isFocused = draft.shouldFocus
        }
        .onChange(of: viewModel.progressPhase) { oldPhase, newPhase in
            if let newPhase {
                announceForAccessibility(newPhase.localizedTitle)
            } else if oldPhase != nil {
                announceForAccessibility(
                    LocalizationManager.shared.localizedString(
                        "CoCaptain response ready."
                    )
                )
            }
        }
        .onChange(of: viewModel.pendingReviewCount) { oldCount, newCount in
            guard newCount > oldCount else { return }
            onRequestExpandedPresentation?()
            announceForAccessibility(
                LocalizationManager.shared.localizedString(
                    "Changes are ready for review."
                )
            )
        }
    }

    /// Keeps the view model aligned with the persisted composer mode.
    private func syncChatModeFromStorage() {
        viewModel.chatMode = CoCaptainChatMode(rawValue: chatModeRawValue) ?? .agent
    }

    private func announceForAccessibility(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func sendCurrentMessage() {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!prompt.isEmpty || !attachments.isEmpty), !viewModel.isThinking else { return }
        let submittedPrompt = prompt.isEmpty ? "Review the attached files." : prompt

        beginChatOnboardingResponseWaitIfNeeded()
        guard viewModel.sendMessage(
            submittedPrompt,
            mentions: mentions,
            attachments: attachments,
            purpose: currentTurnPurpose
        ) else { return }
        HapticsManager.shared.trigger(.soft)
        text = ""
        mentions = []
        attachments = []
        isFocused = false
    }

    /// Gives each onboarding conversation turn its explicit UX objective.
    private var currentTurnPurpose: CoCaptainTurnPurpose {
        switch onboarding?.currentStep {
        case .some(.chatCoCaptain), .some(.chatCoCaptainGameEdit):
            return .onboardingGuidedEdit
        default:
            return .standard
        }
    }

    /// Hides the onboarding tooltip if the user begins typing a message in the text field.
    private func hideChatOnboardingWhenTypingChanges(from oldValue: String, to newValue: String) {
        guard onboarding?.currentStep == .chatCoCaptain || onboarding?.currentStep == .chatCoCaptainGameEdit else { return }

        let wasEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isTyping = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if wasEmpty && isTyping {
            onboarding?.hidePopoverForCurrentStep()
        }
    }

    /// Hides the onboarding tooltip if there is already text present in the chat input composer when appearing.
    private func hideChatOnboardingIfTextIsPresent() {
        guard onboarding?.currentStep == .chatCoCaptain || onboarding?.currentStep == .chatCoCaptainGameEdit,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        onboarding?.hidePopoverForCurrentStep()
    }

    /// Hides the chat instruction while the user's idea handoff is in progress.
    private func beginChatOnboardingResponseWaitIfNeeded() {
        guard onboarding?.currentStep == .chatCoCaptain || onboarding?.currentStep == .chatCoCaptainGameEdit else { return }

        onboarding?.hidePopoverForCurrentStep()
    }

    /// Advances to the review step once the guided onboarding edit produces a review bundle.
    private func advanceOnboardingAfterGuidedEdit(
        _ completion: CoCaptainTurnCompletion?
    ) {
        guard onboarding?.currentStep == .chatCoCaptain || onboarding?.currentStep == .chatCoCaptainGameEdit,
              completion?.shouldAdvanceToOnboardingReview == true else {
            return
        }

        onboarding?.completeCurrentStep()
    }
}

#Preview {
    CoCaptainView(viewModel: CoCaptainViewModel())
}
