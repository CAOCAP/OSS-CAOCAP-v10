import AppKit
import SwiftUI

struct AgentChatView: View {
    @Bindable var controller: CompanionController

    var body: some View {
        AgentConversationView(
            session: controller.chatSession,
            persona: controller.persona,
            isPresented: controller.isChatPresented,
            close: controller.closeChat,
            openHub: controller.openMainWindow
        )
        .id(controller.persona)
    }
}

private struct AgentConversationView: View {
    @Bindable var session: AgentChatSession
    let persona: CompanionPersona
    let isPresented: Bool
    let close: () -> Void
    let openHub: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var composerFocused: Bool

    private var accent: Color {
        persona == .cocaptain
            ? Color(red: 0.12, green: 0.53, blue: 0.76)
            : Color(red: 0.57, green: 0.39, blue: 0.81)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            conversation
            composer
        }
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Color(nsColor: .windowBackgroundColor).opacity(0.88)
                    .background(.regularMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .tint(accent)
        .onChange(of: isPresented, initial: true) { _, presented in
            composerFocused = presented
        }
        .onExitCommand(perform: close)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(persona.idleImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .padding(3)
                .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(persona.displayName)
                    .font(.system(size: 14, weight: .semibold))
                Text(session.isStreaming ? "Thinking…" : "Your desktop agent")
                    .font(.system(size: 11))
                    .foregroundStyle(session.isStreaming ? accent : .secondary)
            }
            Spacer(minLength: 6)
            if !session.messages.isEmpty {
                headerButton("trash", label: "Clear conversation") {
                    session.clearChat()
                }
            }
            headerButton("square.grid.2x2", label: "Open CAOCAP", action: openHub)
            headerButton("xmark", label: "Close chat", action: close)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func headerButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if session.messages.isEmpty {
                    welcome
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(session.messages) { message in
                            messageRow(for: message)
                        }

                        if case .failed(let errorMsg) = session.generationState {
                            errorCard(message: errorMsg)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("conversation-bottom")
                    }
                    .padding(20)
                }
            }
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .onChange(of: session.messages.count) { _, _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    proxy.scrollTo("conversation-bottom", anchor: .bottom)
                }
            }
            .onChange(of: session.messages.last?.text) { _, _ in
                proxy.scrollTo("conversation-bottom", anchor: .bottom)
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func messageRow(for message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 17))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.leading, 36)
            .id(message.id)

        case .assistant:
            HStack(alignment: .top, spacing: 10) {
                Image(persona.idleImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(2)
                    .background(accent.opacity(0.08), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    if message.text.isEmpty && message.isStreaming {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking…")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text(LocalizedStringKey(message.text))
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .textSelection(.enabled)

                        if message.isStreaming {
                            ProgressView()
                                .controlSize(.mini)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 17))
                .overlay {
                    RoundedRectangle(cornerRadius: 17)
                        .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.trailing, 28)
            .id(message.id)
        }
    }

    private func errorCard(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text("Response failed")
                    .font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Retry") {
                session.retryLastTurn()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        }
        .id("error-state")
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Image(persona.idleImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .padding(12)
                .background {
                    Circle().fill(accent.opacity(0.07))
                }
                .accessibilityHidden(true)
                .padding(.bottom, 16)
            Text("What are we\nworking on?")
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Text("Start with a task, a question, or an idea.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            HStack(spacing: 8) {
                suggestion("Explain SwiftUI", symbol: "swift", prompt: "Explain how SwiftUI State and Binding work in simple terms.")
                suggestion("Brainstorm ideas", symbol: "sparkle.magnifyingglass", prompt: "Help me brainstorm ideas for an intelligent Mac companion agent.")
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 25)
    }

    private func suggestion(_ title: String, symbol: String, prompt: String) -> some View {
        Button {
            session.draft = prompt
            submit()
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.primary.opacity(0.045), in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var composer: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Message \(persona.displayName)…", text: $session.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .onSubmit(submit)
                    .accessibilityLabel("Message \(persona.displayName)")

                HStack {
                    Text("⌥ Return for a new line")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if session.isStreaming {
                        Button(action: { session.stopGeneration() }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stop generation")
                        .help("Stop generation")
                    } else {
                        Button(action: submit) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(session.canSubmit ? .white : .secondary)
                                .frame(width: 30, height: 30)
                                .background(session.canSubmit ? accent : Color.primary.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!session.canSubmit)
                        .keyboardShortcut(.return, modifiers: .command)
                        .accessibilityLabel("Send prompt to \(persona.displayName)")
                        .help("Send prompt (⌘ Return)")
                    }
                }
            }
            .padding(13)
            .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(composerFocused ? accent.opacity(0.45) : .primary.opacity(0.12), lineWidth: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 15)
        .padding(.top, 8)
    }

    private func submit() {
        session.submitDraft()
        composerFocused = true
    }
}

#Preview {
    AgentChatView(controller: CompanionController())
        .frame(width: 372, height: 510)
}
