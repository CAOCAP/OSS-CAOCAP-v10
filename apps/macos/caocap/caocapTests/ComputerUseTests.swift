import Foundation
import Testing
@testable import caocap

@MainActor struct ComputerUseTests {
    @Test func exactFileVerificationRejectsEmptyAndUnrelatedFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let expected = directory.appendingPathComponent("CAOCAP-test.txt")
        try Data().write(to: expected)
        try "Unrelated work".write(to: directory.appendingPathComponent("other.txt"), atomically: true, encoding: .utf8)
        #expect(throws: ComputerUseFailure.noResultFile) { try ComputerUseAgentService.verifyResult(expected) }
        let text = String(repeating: "😀", count: 8001)
        try text.write(to: expected, atomically: true, encoding: .utf8)
        let result = try ComputerUseAgentService.verifyResult(expected)
        #expect(result.previewText.unicodeScalars.count == 8000)
        #expect(result.previewTruncated)
        #expect(result.fileName == expected.lastPathComponent)
        let link = directory.appendingPathComponent("CAOCAP-link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: expected)
        #expect(throws: ComputerUseFailure.noResultFile) { try ComputerUseAgentService.verifyResult(link) }
    }
    @Test func reportingFailureStopsBeforeModelAction() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let driver = FakeDriver(); let model = FakeModel()
        let service = ComputerUseAgentService(helperClient: driver, openAIClient: model, access: { _ in true }, releaseAccess: { _ in })
        var checks = 0
        do {
            try await service.run(id: UUID(), commandID: "request-0001", taskSummary: "Write hello", folderURL: directory) { event in
                if case .checkpoint = event { checks += 1; if checks == 2 { throw ComputerUseFailure.reportingUnavailable } }
            }
            Issue.record("Expected reporting failure")
        } catch { #expect(error as? ComputerUseFailure == .reportingUnavailable) }
        #expect(model.requests == 1)
        #expect(driver.actions == 0)
    }
    @Test func coordinatorReservesBeforeSuspendingAndCancellationFencesPreflight() async throws {
        let driver = FakeDriver(); let model = FakeModel()
        let service = ComputerUseAgentService(helperClient: driver, openAIClient: model)
        var resume: CheckedContinuation<URL, Never>?
        let coordinator = ComputerUseRunCoordinator(service: service) { _ in await withCheckedContinuation { resume = $0 } }
        var firstFailure: ComputerUseFailure?
        let first = Task {
            do { try await coordinator.start(request: .init(taskSummary: "Write hello"), origin: .remote) { _ in } }
            catch { firstFailure = error is CancellationError ? .stoppedOnMac : error as? ComputerUseFailure }
        }
        while resume == nil { await Task.yield() }
        do {
            try await coordinator.start(request: .init(taskSummary: "Write another"), origin: .local) { _ in }
            Issue.record("Expected busy")
        } catch { #expect(error as? ComputerUseFailure == .busy) }
        coordinator.cancel()
        resume?.resume(returning: FileManager.default.temporaryDirectory)
        await first.value
        #expect(firstFailure == .stoppedOnMac)
        #expect(!coordinator.isRunning)
        #expect(model.requests == 0)
    }
}
@MainActor private final class FakeDriver: ComputerUseDriving {
    var actions = 0
    func prepareDocument(_ url: URL) async throws {}
    func captureScreenshot(bundleIdentifier: String) async throws -> Data { Data([1]) }
    func performAction(_ action: [String: Any], bundleIdentifier: String) async throws { actions += 1 }
    func cancel() {}
}
@MainActor private final class FakeModel: ComputerUseModel {
    var requests = 0
    func step(runID: String, commandID: String?, stepIndex: Int, taskSummary: String, screenshotBase64: String) async throws -> ComputerUseStepResult {
        requests += 1
        return ComputerUseStepResult(actions: [["type": "type", "text": "hello"]], done: false)
    }
}
