import Foundation

@MainActor protocol ComputerUseDriving {
    func prepareDocument(_ url: URL) async throws
    func captureScreenshot(bundleIdentifier: String) async throws -> Data
    func performAction(_ action: [String: Any], bundleIdentifier: String) async throws
    func cancel()
}
@MainActor protocol ComputerUseModel {
    func step(runID: String, commandID: String?, stepIndex: Int, taskSummary: String, screenshotBase64: String) async throws -> ComputerUseStepResult
}
@MainActor protocol ComputerUseRunning {
    func run(id: UUID, commandID: String?, taskSummary: String, folderURL: URL,
             onEvent: @escaping (ComputerUseRunEvent) async throws -> Void) async throws
    func stop()
}
extension ComputerUseHelperClient: ComputerUseDriving {}
extension OpenAIComputerUseClient: ComputerUseModel {}
extension ComputerUseAgentService: ComputerUseRunning {}
