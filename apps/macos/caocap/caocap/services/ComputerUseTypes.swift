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
    let coordinator: ComputerUseRunCoordinator
    let installGate: ComputerUseInstallGate
    let workspace: ComputerUseWorkspace
}

/// The live state of one Agent-mode turn, rendered as an activity card in chat.
struct AgentRunActivity: Equatable {
    var steps: [ComputerUseStep] = []
    var state: ComputerUseTaskState = .running
}

nonisolated enum ComputerUseFailure: String, Error, Codable, LocalizedError {
    case setupIncomplete, noWorkspaceFolder, busy, unsupportedTarget, stoppedOnMac, runTimeout
    case modelUnavailable, actionFailed, noResultFile, quotaExceeded, serviceUnavailable
    case invalidModelAction, stepLimitExceeded, reportingUnavailable, documentChanged
    var errorDescription: String? {
        switch self {
        case .setupIncomplete: "Finish computer-use setup on your Mac first."
        case .noWorkspaceFolder: "Choose a working folder on your Mac first."
        case .busy: "Your Mac is already working on a task."
        case .unsupportedTarget: "This build can only write a document in TextEdit."
        case .stoppedOnMac: "Stopped on your Mac. Partial work may remain in the working folder."
        case .runTimeout: "The task reached its time limit. Partial work may remain."
        case .quotaExceeded: "The computer-use allowance has been reached."
        case .serviceUnavailable: "Computer use is temporarily unavailable."
        case .modelUnavailable: "The model could not complete this step."
        case .noResultFile: "The prepared document has no saved text yet."
        case .documentChanged: "The TextEdit document changed or a dialog interrupted the task."
        case .reportingUnavailable: "The connection was lost. Work stopped; the result is unconfirmed."
        case .invalidModelAction: "The model requested an unsupported action. Work stopped."
        case .stepLimitExceeded: "The task reached its step limit. Partial work may remain."
        case .actionFailed: "An action could not finish. Partial work may remain."
        }
    }
}
struct ComputerUseResult: Equatable, Codable {
    let fileName: String
    let previewText: String
    let previewTruncated: Bool
    var firestoreData: [String: Any] { ["fileName": fileName, "previewText": previewText, "previewTruncated": previewTruncated] }
}
enum ComputerUseRunEvent {
    case checkpoint
    case step(ComputerUseStep)
    case completed(ComputerUseResult, URL)
    case failed(ComputerUseFailure)
}
