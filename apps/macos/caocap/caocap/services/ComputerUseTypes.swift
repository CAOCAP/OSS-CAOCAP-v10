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
