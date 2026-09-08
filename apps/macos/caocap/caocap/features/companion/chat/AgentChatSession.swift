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
    /// The mode this turn was produced in, so a finished plan can offer to run itself.
    let mode: AgentMode
    /// Present only on Agent-mode turns, which render an activity card instead of prose.
    var activity: AgentRunActivity?

    init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        text: String,
        isStreaming: Bool = false,
        timestamp: Date = Date(),
        mode: AgentMode = .ask,
        activity: AgentRunActivity? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.isStreaming = isStreaming
        self.timestamp = timestamp
        self.mode = mode
        self.activity = activity
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

    var mode: AgentMode {
        didSet {
            guard mode != oldValue else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: AgentMode.storageKey)
        }
    }

    /// `.streaming` covers both a model response and an Agent-mode run: from the composer's point
    /// of view they are the same "busy, and Stop is available" state.
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
    var computerUse: ComputerUseContext?

    @ObservationIgnored
    private let llmService: AgentLLMService

    @ObservationIgnored
    private var streamingTask: Task<Void, Never>?

    @ObservationIgnored
    private var agentRunTask: Task<Void, Never>?

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.caocap.app", category: "AgentChatSession")

    init(persona: CompanionPersona) {
        self.persona = persona
        self.llmService = AgentLLMService(persona: persona)
        let stored = UserDefaults.standard.string(forKey: AgentMode.storageKey)
        self.mode = stored.flatMap(AgentMode.init(rawValue:)) ?? .ask
    }

    func submitDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        draft = ""
        messages.append(ChatMessage(role: .user, text: text, mode: mode))
        start(prompt: text, in: mode)
    }

    /// Runs a plan the user just read, without making them retype it.
    func runPlanInAgentMode(_ plan: String) {
        guard !isStreaming else { return }
        mode = .agent
        start(prompt: plan, in: .agent)
    }

    private func start(prompt: String, in mode: AgentMode) {
        if mode.isProseOnly {
            startStreaming(userPrompt: prompt, mode: mode)
        } else {
            startAgentRun(taskSummary: prompt)
        }
    }

    func stopGeneration() {
        guard isStreaming else { return }
        streamingTask?.cancel()
        streamingTask = nil
        agentRunTask?.cancel()
        agentRunTask = nil
        computerUse?.agentService.stop()
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
        start(prompt: lastUserMessage.text, in: mode)
    }

    func clearChat() {
        stopGeneration()
        messages.removeAll()
        llmService.reset()
        setGenerationState(.idle)
    }

    private func startStreaming(userPrompt: String, mode: AgentMode) {
        streamingTask?.cancel()

        let assistantMessageID = UUID()
        messages.append(ChatMessage(id: assistantMessageID, role: .assistant, text: "", isStreaming: true, mode: mode))
        setGenerationState(.streaming)

        // The mode objective steers this turn only; the visible history keeps the user's own words.
        let modelPrompt = mode.promptInstructions.map { "\($0)\n\nUser message:\n\(userPrompt)" } ?? userPrompt

        streamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = self.llmService.sendMessageStream(modelPrompt)
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

    private func startAgentRun(taskSummary: String) {
        let messageID = UUID()
        messages.append(ChatMessage(id: messageID, role: .assistant, text: "", mode: .agent, activity: AgentRunActivity()))
        setGenerationState(.streaming)

        if let unsupported = ComputerUseAllowlist.unsupportedAppNamed(in: taskSummary) {
            finishRun(messageID, state: .failed(
                message: "I can only work in TextEdit right now, so I can't do this in \(unsupported)."
            ))
            return
        }

        guard let computerUse else {
            finishRun(messageID, state: .failed(message: "Computer use isn't available in this build."))
            return
        }

        agentRunTask = Task { [weak self] in
            guard let self else { return }
            await computerUse.installGate.refresh()
            guard !Task.isCancelled else { return }

            guard computerUse.installGate.isReady else {
                self.finishRun(messageID, state: .awaitingPermission)
                ComputerUseSetupPresenter.present(installGate: computerUse.installGate)
                return
            }

            guard let folderURL = computerUse.workspace.resolveFolder() else {
                self.finishRun(messageID, state: .awaitingFolderSelection)
                return
            }
            guard !Task.isCancelled else { return }

            computerUse.agentService.start(
                taskSummary: taskSummary,
                folderURL: folderURL,
                onStep: { [weak self] step in
                    self?.updateActivity(messageID) { $0.steps.append(step) }
                },
                onStateChange: { [weak self] state in
                    guard let self else { return }
                    if case .running = state {
                        self.updateActivity(messageID) { $0.state = state }
                    } else {
                        self.finishRun(messageID, state: state)
                    }
                }
            )
        }
    }

    private func finishRun(_ id: UUID, state: ComputerUseTaskState) {
        updateActivity(id) { $0.state = state }
        agentRunTask = nil
        if case .failed(let message) = state {
            setGenerationState(.failed(message))
        } else {
            setGenerationState(.idle)
        }
    }

    private func updateActivity(_ id: UUID, _ transform: (inout AgentRunActivity) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }),
              var activity = messages[index].activity else { return }
        transform(&activity)
        messages[index].activity = activity
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
