import Foundation
import Observation

@MainActor @Observable
final class ComputerUseAgentService {
    private let helperClient: any ComputerUseDriving
    private let openAIClient: any ComputerUseModel
    private(set) var isRunning = false
    private let now: () -> Date
    private let access: (URL) -> Bool
    private let releaseAccess: (URL) -> Void
    private let verify: (URL) throws -> ComputerUseResult
    init(helperClient: any ComputerUseDriving, openAIClient: any ComputerUseModel,
         now: @escaping () -> Date = Date.init,
         access: @escaping (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
         releaseAccess: @escaping (URL) -> Void = { $0.stopAccessingSecurityScopedResource() },
         verify: @escaping (URL) throws -> ComputerUseResult = ComputerUseAgentService.verifyResult) {
        self.helperClient = helperClient; self.openAIClient = openAIClient
        self.now = now; self.access = access; self.releaseAccess = releaseAccess; self.verify = verify
    }
    func stop() { helperClient.cancel() }
    func run(id: UUID, commandID: String?, taskSummary: String, folderURL: URL,
             onEvent: @escaping (ComputerUseRunEvent) async throws -> Void) async throws {
        guard !isRunning else { throw ComputerUseFailure.busy }
        isRunning = true
        defer { isRunning = false }
        guard access(folderURL) else { throw ComputerUseFailure.noWorkspaceFolder }
        defer { releaseAccess(folderURL) }
        let file = folderURL.appendingPathComponent("CAOCAP-\(id.uuidString).txt")
        guard !FileManager.default.fileExists(atPath: file.path) else { throw ComputerUseFailure.documentChanged }
        try Task.checkCancellation()
        try Data().write(to: file, options: .withoutOverwriting)
        try await helperClient.prepareDocument(file)
        let deadline = now().addingTimeInterval(180)
        for index in 0..<20 {
            try Task.checkCancellation()
            guard now() < deadline else { throw ComputerUseFailure.runTimeout }
            try await onEvent(.checkpoint)
            let screenshot = try await helperClient.captureScreenshot(bundleIdentifier: "com.apple.TextEdit")
            let response = try await openAIClient.step(runID: id.uuidString, commandID: commandID, stepIndex: index,
                taskSummary: taskSummary, screenshotBase64: screenshot.base64EncodedString())
            try Task.checkCancellation()
            guard now() < deadline else { throw ComputerUseFailure.runTimeout }
            try await onEvent(.checkpoint)
            try Task.checkCancellation()
            if response.done {
                let result = try verify(file)
                try await onEvent(.completed(result, file))
                return
            }
            guard response.actions.count == 1, let action = response.actions.first else { throw ComputerUseFailure.invalidModelAction }
            try await helperClient.performAction(action, bundleIdentifier: "com.apple.TextEdit")
            try Task.checkCancellation()
            let summary: String
            switch action["type"] as? String {
            case "type": summary = "Typed document text"
            case "keypress": summary = (action["keys"] as? [String]) == ["cmd", "s"] ? "Saved the document" : "Edited document text"
            default: summary = "Waited for TextEdit"
            }
            try await onEvent(.step(ComputerUseStep(index: index + 1, summary: summary, timestamp: now())))
        }
        throw ComputerUseFailure.stepLimitExceeded
    }
    static func verifyResult(_ file: URL) throws -> ComputerUseResult {
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) <= 1_048_576,
              let text = try? String(contentsOf: file, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ComputerUseFailure.noResultFile }
        let scalars = text.unicodeScalars
        return ComputerUseResult(fileName: file.lastPathComponent, previewText: String(String.UnicodeScalarView(scalars.prefix(8000))), previewTruncated: scalars.count > 8000)
    }
}
