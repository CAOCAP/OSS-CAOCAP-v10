import Foundation
import Observation
import OSLog

/// Runs the observe -> decide -> act loop for one computer-use task: screenshot (via the
/// unsandboxed helper/cua-driver) -> OpenAIComputerUseClient -> allowlist check -> execute the
/// action (via the helper) -> repeat, until the model calls `finish` or a limit is hit.
///
/// One shared instance for the whole app (CompanionController owns it) since there is only one
/// desktop to drive regardless of which persona's chat started the task.
@MainActor
@Observable
final class ComputerUseAgentService {
    private static let maxSteps = 20
    private static let timeout: TimeInterval = 180
    private static let targetBundleIdentifier = "com.apple.TextEdit"

    private let helperClient: ComputerUseHelperClient
    private let openAIClient: OpenAIComputerUseClient
    private let logger = Logger(subsystem: "com.caocap.app", category: "ComputerUseAgentService")

    private var runTask: Task<Void, Never>?
    private var shouldStop = false

    var isRunning: Bool { runTask != nil }

    init(helperClient: ComputerUseHelperClient, openAIClient: OpenAIComputerUseClient) {
        self.helperClient = helperClient
        self.openAIClient = openAIClient
    }

    func start(
        taskSummary: String,
        folderURL: URL,
        onStep: @escaping (ComputerUseStep) -> Void,
        onStateChange: @escaping (ComputerUseTaskState) -> Void
    ) {
        guard runTask == nil else { return }
        shouldStop = false
        runTask = Task { [weak self] in
            await self?.run(taskSummary: taskSummary, folderURL: folderURL, onStep: onStep, onStateChange: onStateChange)
            self?.runTask = nil
        }
    }

    func stop() {
        shouldStop = true
    }

    private func run(
        taskSummary: String,
        folderURL: URL,
        onStep: @escaping (ComputerUseStep) -> Void,
        onStateChange: @escaping (ComputerUseTaskState) -> Void
    ) async {
        guard ComputerUseAllowlist.isAllowed(bundleIdentifier: Self.targetBundleIdentifier) else {
            onStateChange(.failed(message: "\(Self.targetBundleIdentifier) isn't allowlisted for computer-use."))
            return
        }

        onStateChange(.running)
        let taskStartDate = Date()
        let deadline = taskStartDate.addingTimeInterval(Self.timeout)

        do {
            try await helperClient.launchApp(bundleIdentifier: Self.targetBundleIdentifier)
        } catch {
            onStateChange(.failed(message: "Couldn't open TextEdit: \(error.localizedDescription)"))
            return
        }

        var previousResponseId: String?
        var previousCallId: String?
        var stepIndex = 0

        while stepIndex < Self.maxSteps {
            if shouldStop {
                onStateChange(.stopped)
                return
            }
            if Date() > deadline {
                onStateChange(.failed(message: "The task took too long and was stopped."))
                return
            }

            let screenshot: Data
            do {
                screenshot = try await helperClient.captureScreenshot(bundleIdentifier: Self.targetBundleIdentifier)
            } catch {
                onStateChange(.failed(message: "Couldn't see TextEdit: \(error.localizedDescription)"))
                return
            }

            let result: ComputerUseStepResult
            do {
                result = try await openAIClient.step(
                    taskSummary: taskSummary,
                    screenshotBase64: screenshot.base64EncodedString(),
                    previousResponseId: previousResponseId,
                    previousCallId: previousCallId
                )
            } catch {
                onStateChange(.failed(message: "The model couldn't be reached: \(error.localizedDescription)"))
                return
            }
            previousResponseId = result.responseId
            previousCallId = result.callId

            if result.done {
                logger.info("Model signaled finish: \(result.message ?? "", privacy: .public)")
                if let resultPath = Self.mostRecentFile(in: folderURL, modifiedAfter: taskStartDate) {
                    onStateChange(.completed(resultPath: resultPath))
                } else {
                    onStateChange(.failed(message: "The model said it finished, but no new file appeared in the selected folder."))
                }
                return
            }

            guard let action = result.actions.first else {
                // No tool call and not done: nudge by looping again with a fresh screenshot,
                // but this still counts against the step budget so a confused model can't spin forever.
                stepIndex += 1
                continue
            }

            if shouldStop {
                onStateChange(.stopped)
                return
            }

            do {
                try await helperClient.performAction(action, bundleIdentifier: Self.targetBundleIdentifier)
            } catch {
                onStateChange(.failed(message: "An action failed: \(error.localizedDescription)"))
                return
            }

            stepIndex += 1
            onStep(ComputerUseStep(index: stepIndex, summary: Self.describe(action), timestamp: Date()))
        }

        onStateChange(.failed(message: "Reached the step limit without finishing."))
    }

    private static func describe(_ action: [String: Any]) -> String {
        switch action["type"] as? String {
        case "click": return "Clicked"
        case "double_click": return "Double-clicked"
        case "type": return "Typed text"
        case "keypress": return "Pressed a key"
        case "scroll": return "Scrolled"
        case "wait": return "Waited"
        default: return "Performed an action"
        }
    }

    /// The independently-inspectable result check: only report success if a real file actually
    /// appeared, rather than trusting the model's own "finish" message.
    private static func mostRecentFile(in folderURL: URL, modifiedAfter date: Date) -> String? {
        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer { if accessing { folderURL.stopAccessingSecurityScopedResource() } }

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let newest = contents
            .compactMap { url -> (URL, Date)? in
                guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                    return nil
                }
                return (url, modified)
            }
            .filter { $0.1 >= date }
            .max { $0.1 < $1.1 }

        return newest?.0.path
    }
}
