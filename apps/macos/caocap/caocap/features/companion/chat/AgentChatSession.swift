import Foundation
import Observation
import OSLog

enum ChatMessageRole: Equatable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: ChatMessageRole
    var text: String
    var isStreaming: Bool
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        text: String,
        isStreaming: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.isStreaming = isStreaming
        self.timestamp = timestamp
    }
}

enum GenerationState: Equatable {
    case idle
    case streaming
    case failed(String)
}

/// Owns the multi-turn conversation and generation lifecycle for a companion persona.
@MainActor
@Observable
final class AgentChatSession {
    let persona: CompanionPersona
    var draft = ""
    private(set) var messages: [ChatMessage] = []
    private(set) var generationState: GenerationState = .idle

    var isStreaming: Bool {
        if case .streaming = generationState { return true }
        return false
    }

    var canSubmit: Bool {
        !isStreaming && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ObservationIgnored
    var onStateChange: ((GenerationState) -> Void)?

    @ObservationIgnored
    private let llmService: AgentLLMService

    @ObservationIgnored
    private var streamingTask: Task<Void, Never>?

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.caocap.app", category: "AgentChatSession")

    init(persona: CompanionPersona) {
        self.persona = persona
        self.llmService = AgentLLMService(persona: persona)
    }

    func submitDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        draft = ""
        messages.append(ChatMessage(role: .user, text: text))
        startStreaming(userPrompt: text)
    }

    func stopGeneration() {
        guard isStreaming else { return }
        streamingTask?.cancel()
        streamingTask = nil
        markCurrentAssistantFinished()
        setGenerationState(.idle)
    }

    func retryLastTurn() {
        guard !isStreaming else { return }
        // Find the last user message to retry
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else { return }

        // Remove trailing assistant message if it was an error or empty
        if let last = messages.last, last.role == .assistant {
            messages.removeLast()
        }

        setGenerationState(.idle)
        startStreaming(userPrompt: lastUserMessage.text)
    }

    func clearChat() {
        stopGeneration()
        messages.removeAll()
        llmService.reset()
        setGenerationState(.idle)
    }

    private func startStreaming(userPrompt: String) {
        streamingTask?.cancel()

        let assistantMessageID = UUID()
        messages.append(ChatMessage(id: assistantMessageID, role: .assistant, text: "", isStreaming: true))
        setGenerationState(.streaming)

        streamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = self.llmService.sendMessageStream(userPrompt)
                for try await chunk in stream {
                    try Task.checkCancellation()
                    self.appendChunk(chunk, toMessageID: assistantMessageID)
                }

                guard !Task.isCancelled else { return }
                self.markMessageFinished(id: assistantMessageID)
                self.setGenerationState(.idle)
            } catch is CancellationError {
                self.markMessageFinished(id: assistantMessageID)
                self.setGenerationState(.idle)
            } catch {
                self.logger.error("Generation error: \(error.localizedDescription, privacy: .public)")
                self.markMessageFinished(id: assistantMessageID)
                let errorMsg = error.localizedDescription
                self.setGenerationState(.failed(errorMsg))
            }
        }
    }

    private func appendChunk(_ chunk: String, toMessageID id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text += chunk
    }

    private func markMessageFinished(id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].isStreaming = false
    }

    private func markCurrentAssistantFinished() {
        if let last = messages.last, last.role == .assistant {
            messages[messages.count - 1].isStreaming = false
        }
    }

    private func setGenerationState(_ state: GenerationState) {
        self.generationState = state
        self.onStateChange?(state)
    }
}
