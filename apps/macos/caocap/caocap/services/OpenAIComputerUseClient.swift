import FirebaseFunctions
import Foundation

struct ComputerUseStepResult {
    let actions: [[String: Any]]
    let done: Bool
}
@MainActor
final class OpenAIComputerUseClient {
    func step(runID: String, commandID: String?, stepIndex: Int, taskSummary: String, screenshotBase64: String) async throws -> ComputerUseStepResult {
        var payload: [String: Any] = ["runId": runID, "stepIndex": stepIndex, "taskSummary": taskSummary, "screenshotBase64": screenshotBase64]
        if let commandID { payload["commandId"] = commandID }
        do {
            let callable = Functions.functions(region: "us-central1").httpsCallable("computerUseStep")
            callable.timeoutInterval = 55
            let result = try await callable.call(payload)
            try Task.checkCancellation()
            guard let data = result.data as? [String: Any], let done = data["done"] as? Bool,
                  let actions = data["actions"] as? [[String: Any]] else { throw ComputerUseFailure.invalidModelAction }
            return ComputerUseStepResult(actions: actions, done: done)
        } catch let error as NSError {
            if Task.isCancelled { throw CancellationError() }
            if let details = error.userInfo[FunctionsErrorDetailsKey] as? [String: Any], let raw = details["failureCode"] as? String, let failure = ComputerUseFailure(rawValue: raw) { throw failure }
            throw (error as? ComputerUseFailure) ?? ComputerUseFailure.modelUnavailable
        }
    }
}
