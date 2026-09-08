import SwiftUI
import UIKit

/// An animated, pulsating three-dot indicator shown when the AI assistant
/// is processing a response but hasn't started streaming tokens yet.
struct ThinkingIndicator: View {
    @State private var dotScale: CGFloat = 0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.accentColor.opacity(0.55))
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotScale)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                        value: dotScale
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
        .onAppear {
            dotScale = reduceMotion ? 0.8 : 1.0
        }
    }
}

/// A composite view that renders a single message in the chat timeline,
/// including the avatar (if assistant), the message bubble, and trailing icons (if user).
struct ChatBubbleView: View {
    let message: ChatBubbleItem
    let createdAt: Date
    var onRetry: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onResend: (() -> Void)? = nil
    var onFeedback: ((CoCaptainMessageFeedback) -> Void)? = nil
    var showsActions = true
    /// True when the previous timeline item came from the same speaker, which
    /// suppresses the repeated avatar so a multi-message reply reads as one turn.
    var isContinuation = false

    @State private var copied = false
    @State private var previewAttachment: CoCaptainAttachment?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: CoCaptainChatStyle.smallSpacing) {
            if message.isUser {
                Spacer(minLength: 36)
            } else if isContinuation {
                Color.clear.frame(width: 28, height: 1)
            } else {
                CopilotAvatarView(size: 28)
                    .accessibilityHidden(true)
            }

            VStack(
                alignment: message.isUser ? .trailing : .leading,
                spacing: CoCaptainChatStyle.smallSpacing
            ) {
                if !message.mentions.isEmpty {
                    mentionChips
                }
                if !message.attachments.isEmpty {
                    attachmentGrid
                }
                if !message.text.isEmpty {
                    messageText
                }

                if !message.isUser, showsActions {
                    assistantActionRow
                }
            }
            .frame(
                maxWidth: CoCaptainChatStyle.readableWidth,
                alignment: message.isUser ? .trailing : .leading
            )
            .contextMenu {
                if message.isUser || showsActions {
                    messageContextMenu
                }
            }
            .accessibilityActions {
                if message.isUser || showsActions {
                    Button(
                        LocalizationManager.shared.localizedString("Copy message")
                    ) {
                        copyMessage()
                    }

                    Button(
                        LocalizationManager.shared.localizedString(
                            message.isUser ? "Edit message" : "Try response again"
                        )
                    ) {
                        if message.isUser {
                            onEdit?()
                        } else {
                            onRetry?()
                        }
                    }

                    Button(
                        LocalizationManager.shared.localizedString(
                            message.isUser ? "Send again" : "Helpful response"
                        )
                    ) {
                        if message.isUser {
                            onResend?()
                        } else {
                            onFeedback?(.helpful)
                        }
                    }
                }
            }

            if !message.isUser {
                Spacer(minLength: 20)
            }
        }
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .push(from: .bottom).combined(with: .opacity),
                    removal: .opacity
                )
        )
        .sheet(item: $previewAttachment) { attachment in
            NavigationStack {
                Group {
                    if let image = UIImage(data: attachment.data) {
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                    } else {
                        ContentUnavailableView(
                            LocalizationManager.shared.localizedString("Preview unavailable"),
                            systemImage: "photo.badge.exclamationmark"
                        )
                    }
                }
                .navigationTitle(attachment.fileName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(LocalizationManager.shared.localizedString("Done")) {
                            previewAttachment = nil
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messageText: some View {
        if message.isUser {
            ChatBubbleText(message: message)
                .padding(.horizontal, CoCaptainChatStyle.sectionSpacing)
                .padding(.vertical, CoCaptainChatStyle.standardSpacing)
                .background(
                    CoCaptainChatStyle.userMessageFill,
                    in: RoundedRectangle(
                        cornerRadius: CoCaptainChatStyle.messageCornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: CoCaptainChatStyle.messageCornerRadius,
                        style: .continuous
                    )
                    .stroke(CoCaptainChatStyle.userMessageStroke, lineWidth: 1)
                }
                .foregroundStyle(.primary)
        } else {
            ChatBubbleText(message: message)
                .padding(.vertical, CoCaptainChatStyle.compactSpacing)
                .foregroundStyle(.primary)
        }
    }

    private var attachmentGrid: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
            ForEach(message.attachments) { attachment in
                if attachment.isImage, let image = UIImage(data: attachment.data) {
                    Button {
                        previewAttachment = attachment
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 220, maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        LocalizationManager.shared.localizedString(
                            "Preview %@",
                            arguments: [attachment.fileName]
                        )
                    )
                } else {
                    Label(attachment.fileName, systemImage: "doc.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var mentionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(message.mentions) { mention in
                    Label(mention.displayTitle, systemImage: "scope")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            message.isUser
                                ? CoCaptainChatStyle.mentionTint
                                : Color.secondary
                        )
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            (message.isUser
                                ? CoCaptainChatStyle.mentionTint
                                : Color.primary).opacity(0.1),
                            in: Capsule()
                        )
                }
            }
        }
    }

    private var assistantActionRow: some View {
        HStack(spacing: 2) {
            Button {
                copyMessage()
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(
                        width: CoCaptainChatStyle.minimumHitSize,
                        height: CoCaptainChatStyle.minimumHitSize
                    )
            }
            .accessibilityLabel(
                LocalizationManager.shared.localizedString(
                    copied ? "Copied" : "Copy message"
                )
            )

            if let onRetry {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .frame(
                            width: CoCaptainChatStyle.minimumHitSize,
                            height: CoCaptainChatStyle.minimumHitSize
                        )
                }
                .accessibilityLabel(
                    LocalizationManager.shared.localizedString("Try response again")
                )
            }

            Menu {
                feedbackAndShareActions
            } label: {
                Image(systemName: "ellipsis")
                    .frame(
                        width: CoCaptainChatStyle.minimumHitSize,
                        height: CoCaptainChatStyle.minimumHitSize
                    )
            }
            .accessibilityLabel(
                LocalizationManager.shared.localizedString("More message actions")
            )

            Text(createdAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 2)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var messageContextMenu: some View {
        Button {
            copyMessage()
        } label: {
            Label(
                LocalizationManager.shared.localizedString("Copy message"),
                systemImage: "doc.on.doc"
            )
        }

        if message.isUser {
            if let onEdit {
                Button(action: onEdit) {
                    Label(
                        LocalizationManager.shared.localizedString("Edit message"),
                        systemImage: "pencil"
                    )
                }
            }

            if let onResend {
                Button(action: onResend) {
                    Label(
                        LocalizationManager.shared.localizedString("Send again"),
                        systemImage: "arrow.up.circle"
                    )
                }
            }
        } else if let onRetry {
            Button(action: onRetry) {
                Label(
                    LocalizationManager.shared.localizedString("Try response again"),
                    systemImage: "arrow.clockwise"
                )
            }
        }

        feedbackAndShareActions
    }

    @ViewBuilder
    private var feedbackAndShareActions: some View {
        if let onFeedback {
            Button {
                onFeedback(.helpful)
            } label: {
                Label(
                    LocalizationManager.shared.localizedString("Helpful response"),
                    systemImage: message.feedback == .helpful
                        ? "hand.thumbsup.fill"
                        : "hand.thumbsup"
                )
            }

            Button {
                onFeedback(.notHelpful)
            } label: {
                Label(
                    LocalizationManager.shared.localizedString("Not helpful"),
                    systemImage: message.feedback == .notHelpful
                        ? "hand.thumbsdown.fill"
                        : "hand.thumbsdown"
                )
            }
        }

        ShareLink(item: message.text) {
            Label(
                LocalizationManager.shared.localizedString("Share message"),
                systemImage: "square.and.arrow.up"
            )
        }
    }

    private func copyMessage() {
        UIPasteboard.general.string = message.text
        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            copied = false
        }
    }
}

/// Renders the Markdown payload of a chat bubble, applying special styling
/// to inline code blocks so they stand out against the bubble gradient.
struct ChatBubbleText: View {
    let message: ChatBubbleItem

    var body: some View {
        Text(styledMarkdown)
            .font(.body)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var styledMarkdown: AttributedString {
        if message.isUser {
            return AttributedString(message.text)
        }

        var attributed = message.markdownText
        attributed.mergeAttributes(
            AttributeContainer().font(.body),
            mergePolicy: .keepCurrent
        )

        for run in attributed.runs {
            if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                attributed[run.range].font = .body.monospaced()
                attributed[run.range].backgroundColor = CoCaptainChatStyle.codeFill
            }
        }

        return attributed
    }
}
