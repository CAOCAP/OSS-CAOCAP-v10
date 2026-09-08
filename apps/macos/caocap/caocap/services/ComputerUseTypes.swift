import Foundation

enum ComputerUseTaskState: Equatable {
    case idle
    case awaitingPermission
    case awaitingFolderSelection
    case running
    case awaitingUserInput(prompt: String)
    case stopped
    case failed(message: String)
    case completed(resultPath: String)
}

struct ComputerUseStep: Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let summary: String
    let timestamp: Date
}

/// What a chat turn in Agent mode needs in order to run. Bundled so the chat session takes one
/// dependency instead of reaching for three separately-owned services.
@MainActor
struct ComputerUseContext {
    let agentService: ComputerUseAgentService
    let installGate: ComputerUseInstallGate
    let workspace: ComputerUseWorkspace
}

/// The live state of one Agent-mode turn, rendered as an activity card in chat.
struct AgentRunActivity: Equatable {
    var steps: [ComputerUseStep] = []
    var state: ComputerUseTaskState = .running
}
