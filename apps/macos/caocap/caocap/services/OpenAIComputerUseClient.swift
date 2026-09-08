import FirebaseFunctions
import Foundation

struct ComputerUseStepResult {
    let responseId: String
    let callId: String?
    let actions: [[String: Any]]
    let message: String?
    let done: Bool
}

/// Calls the `computerUseStep` Firebase Function, which holds the OpenAI key server-side and
/// talks to the Responses API using gpt-6-astra with cua-driver's tools exposed as standard
/// function-calling tools (see firebase/functions/src/index.ts).
@MainActor
final class OpenAIComputerUseClient {
    func step(
        taskSummary: String,
        screenshotBase64: String,
        previousResponseId: String?,
        previousCallId: String?
    ) async throws -> ComputerUseStepResult {
        var payload: [String: Any] = [
            "taskSummary": taskSummary,
            "screenshotBase64": screenshotBase64,
        ]
        if let previousResponseId {
            payload["previousResponseId"] = previousResponseId
        }
        if let previousCallId {
            payload["previousCallId"] = previousCallId
        }

        let result = try await Functions.functions(region: "us-central1")
            .httpsCallable("computerUseStep")
            .call(payload)

        guard let data = result.data as? [String: Any],
              let responseId = data["responseId"] as? String,
              let done = data["done"] as? Bool else {
            throw OpenAIComputerUseClientError.unexpectedResponse
        }

        return ComputerUseStepResult(
            responseId: responseId,
            callId: data["callId"] as? String,
            actions: data["actions"] as? [[String: Any]] ?? [],
            message: data["message"] as? String,
            done: done
        )
    }
}

enum OpenAIComputerUseClientError: Error {
    case unexpectedResponse
}
