import SwiftUI

/// A polymorphic wrapper that routes a generic timeline item to its specific
/// SwiftUI representation (chat bubble, execution summary, CTA, or review bundle).
struct TimelineItemView: View {
    let item: CoCaptainTimelineItem
    let viewModel: CoCaptainViewModel
    var isContinuation = false
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?

    private var isOnboardingReviewAnchorActive: Bool {
        guard let onboarding else { return false }
        return onboarding.showPopover && onboarding.currentStep == .reviewCoCaptainChange
    }

    private var isOnboardingApplyAnchorActive: Bool {
        guard let onboarding else { return false }
        return onboarding.showPopover && onboarding.currentStep == .applyCoCaptainChange
    }

    var body: some View {
        Group {
            switch item.content {
            case .message(let bubble):
                messageView(for: bubble)
            case .execution(let status):
                executionView(for: status)
            case .productCTA(let cta):
                ProductCTAView(item: cta) {
                    viewModel.performProductCTA(cta)
                }
            case .reviewBundle(let bundle):
                ReviewBundleView(
                    bundle: bundle,
                    viewModel: viewModel,
                    bundleID: item.id,
                    isOnboardingReviewAnchorActive: isOnboardingReviewAnchorActive,
                    isOnboardingApplyAnchorActive: isOnboardingApplyAnchorActive
                )
            case .clarifyingQuestion(let questionItem):
                ClarifyingQuestionCardView(item: questionItem) { option in
                    viewModel.answerClarifyingQuestion(itemID: item.id, option: option)
                }
            case .mentorNote(let noteItem):
                MentorNoteCardView(item: noteItem)
            case .error(let errorItem):
                CoCaptainErrorCardView(item: errorItem) {
                    viewModel.recoverFromError(errorItem)
                }
            }
        }
    }

    private func messageView(for bubble: ChatBubbleItem) -> some View {
        ChatBubbleView(
            message: bubble,
            createdAt: item.createdAt,
            onRetry: retryAction(for: bubble),
            onEdit: editAction(for: bubble),
            onResend: resendAction(for: bubble),
            onFeedback: feedbackAction(for: bubble),
            showsActions: !viewModel.isStreamingAssistantMessage(id: item.id),
            isContinuation: isContinuation
        )
    }

    private func executionView(for status: ExecutionStatusItem) -> some View {
        ExecutionSummaryView(status: status, onUndo: undoAction(for: status))
    }

    private func retryAction(for bubble: ChatBubbleItem) -> (() -> Void)? {
        guard let sourceID = bubble.inReplyToMessageID else { return nil }
        return { viewModel.retryTurn(sourceMessageID: sourceID) }
    }

    private func editAction(for bubble: ChatBubbleItem) -> (() -> Void)? {
        guard bubble.isUser else { return nil }
        return { viewModel.editUserMessage(id: bubble.id) }
    }

    private func resendAction(for bubble: ChatBubbleItem) -> (() -> Void)? {
        guard bubble.isUser else { return nil }
        return { viewModel.resendUserMessage(id: bubble.id) }
    }

    private func feedbackAction(for bubble: ChatBubbleItem) -> ((CoCaptainMessageFeedback) -> Void)? {
        guard !bubble.isUser else { return nil }
        return { feedback in
            viewModel.recordFeedback(messageID: bubble.id, feedback: feedback)
        }
    }

    private func undoAction(for status: ExecutionStatusItem) -> (() -> Void)? {
        guard status.allowsUndo,
              viewModel.canUndoExecution(timelineItemID: item.id) else {
            return nil
        }
        return { viewModel.undoLastCanvasChange() }
    }
}

extension CoCaptainTimelineItem {
    /// True if this item is an assistant chat message that hasn't received any text yet.
    var isEmptyAssistantMessage: Bool {
        guard case .message(let bubble) = content,
              !bubble.isUser else {
            return false
        }

        return bubble.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// A discreet success indicator shown when the agent executes an app action without requiring review.
struct ExecutionSummaryView: View {
    let status: ExecutionStatusItem
    var onUndo: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: CoCaptainChatStyle.smallSpacing) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(status.summary)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            if status.allowsUndo, let onUndo {
                Button(LocalizationManager.shared.localizedString("Undo")) {
                    onUndo()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(minHeight: CoCaptainChatStyle.minimumHitSize)
            }
        }
        .padding(.horizontal, CoCaptainChatStyle.standardSpacing)
        .padding(.vertical, CoCaptainChatStyle.smallSpacing)
        .coCaptainCardSurface(tint: CoCaptainChatStyle.success)
    }
}

/// Distinct recovery surface for failed or explicitly stopped turns.
struct CoCaptainErrorCardView: View {
    let item: CoCaptainErrorItem
    let onRetry: () -> Void

    @State private var showsDetails = false

    var body: some View {
        HStack(alignment: .top, spacing: CoCaptainChatStyle.smallSpacing) {
            Image(systemName: iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 32, height: 32)
                .background(accentColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: CoCaptainChatStyle.smallSpacing) {
                Text(item.title)
                    .font(.body.weight(.semibold))

                Text(item.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let details = item.technicalDetails, !details.isEmpty {
                    DisclosureGroup(
                        LocalizationManager.shared.localizedString("Technical details"),
                        isExpanded: $showsDetails
                    ) {
                        Text(details)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .font(.caption.weight(.semibold))
                }

                if item.isRecoverable, item.sourceMessageID != nil {
                    Button {
                        onRetry()
                    } label: {
                        Label(
                            LocalizationManager.shared.localizedString(
                                item.kind == .stopped ? "Continue" : "Try again"
                            ),
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(minHeight: CoCaptainChatStyle.minimumHitSize)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(CoCaptainChatStyle.standardSpacing)
        .coCaptainCardSurface(tint: accentColor)
        .accessibilityElement(children: .contain)
    }

    private var iconName: String {
        switch item.kind {
        case .stopped: return "stop.circle"
        case .network: return "wifi.slash"
        case .attachment: return "paperclip.badge.ellipsis"
        case .quota: return "gauge.with.dots.needle.67percent"
        case .model: return "exclamationmark.bubble"
        }
    }

    private var accentColor: Color {
        switch item.kind {
        case .stopped: return .secondary
        case .quota: return .orange
        case .network, .attachment, .model: return .red
        }
    }
}

/// A "What you just learned" card revealed after the user applies a node edit.
/// Turns the apply moment into a small lesson about the user's own app.
struct MentorNoteCardView: View {
    let item: CoCaptainMentorNoteItem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: CoCaptainChatStyle.smallSpacing) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.yellow)
                .frame(width: 28, height: 28)
                .background(Color.yellow.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizationManager.shared.localizedString("cocaptain.mentorNote.title"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(item.note.concept)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                Text(item.note.body)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(CoCaptainChatStyle.standardSpacing)
        .coCaptainCardSurface(tint: Color.accentColor, cornerRadius: 18)
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .push(from: .bottom).combined(with: .opacity),
                    removal: .opacity
                )
        )
    }
}

/// A stylized banner emitted by the assistant to prompt the user to upgrade or subscribe.
struct ProductCTAView: View {
    let item: CoCaptainProductCTAItem
    let onPrimaryAction: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: CoCaptainChatStyle.smallSpacing) {
            CopilotAvatarView(size: 32)

            VStack(alignment: .leading, spacing: CoCaptainChatStyle.standardSpacing) {
                HStack(alignment: .top, spacing: CoCaptainChatStyle.smallSpacing) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)

                        Text(item.message)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Button {
                        onPrimaryAction()
                    } label: {
                        Text(item.primaryButtonTitle)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Spacer(minLength: 0)
                }
            }
            .padding(CoCaptainChatStyle.standardSpacing)
            .coCaptainCardSurface(tint: Color.accentColor, cornerRadius: 18)
            .frame(maxWidth: 420, alignment: .leading)

            Spacer(minLength: 0)
        }
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .push(from: .bottom).combined(with: .opacity),
                    removal: .opacity
                )
        )
    }
}
