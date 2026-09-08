import Foundation
import Observation

@MainActor @Observable
final class ComputerUseRunCoordinator {
    struct Request { let taskSummary: String; var commandID: String? = nil }
    enum Origin { case local, remote }
    struct RunHandle { let id: UUID }
    private let service: any ComputerUseRunning
    private let preflight: (Origin) async throws -> URL
    private(set) var activeID: UUID?
    private var task: Task<Void, Never>?
    private var timedOutID: UUID?
    private var timeout: Task<Void, Never>?
    var isRunning: Bool { activeID != nil }
    init(service: any ComputerUseRunning, gate: ComputerUseInstallGate, workspace: ComputerUseWorkspace) {
        self.service = service
        self.preflight = { origin in
            await gate.refresh()
            guard gate.isReady else { throw ComputerUseFailure.setupIncomplete }
            guard let folder = origin == .remote ? workspace.storedFolderOnly() : workspace.resolveFolder() else { throw ComputerUseFailure.noWorkspaceFolder }
            return folder
        }
    }
    init(service: any ComputerUseRunning, preflight: @escaping (Origin) async throws -> URL) {
        self.service = service; self.preflight = preflight
    }
    @discardableResult
    func start(request: Request, origin: Origin, beforeStart: @escaping () async throws -> Void = {},
               onEvent: @escaping (ComputerUseRunEvent) async throws -> Void) async throws -> RunHandle {
        guard activeID == nil else { throw ComputerUseFailure.busy }
        let id = UUID(); activeID = id // Reserve before the first suspension, including permission checks.
        do {
            guard !request.taskSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  request.taskSummary.utf16.count <= 500,
                  ComputerUseAllowlist.unsupportedAppNamed(in: request.taskSummary) == nil else { throw ComputerUseFailure.unsupportedTarget }
            let folder = try await preflight(origin)
            try Task.checkCancellation()
            guard activeID == id else { throw CancellationError() }
            try await beforeStart()
            try Task.checkCancellation()
            guard activeID == id else { throw CancellationError() }
            task = Task {
                do { try await self.service.run(id: id, commandID: request.commandID, taskSummary: request.taskSummary, folderURL: folder, onEvent: onEvent) }
                catch {
                    let failure: ComputerUseFailure = self.timedOutID == id ? .runTimeout : (error is CancellationError ? .stoppedOnMac : (error as? ComputerUseFailure ?? .actionFailed))
                    try? await onEvent(.failed(failure))
                }
                if self.activeID == id { self.activeID = nil; self.task = nil; self.timeout?.cancel(); self.timeout = nil }
            }
            timeout = Task {
                try? await Task.sleep(for: .seconds(180))
                guard !Task.isCancelled, self.activeID == id else { return }
                self.timedOutID = id
                self.cancel(runID: id)
            }
            return RunHandle(id: id)
        } catch {
            if activeID == id { activeID = nil }
            throw error
        }
    }
    func cancel(runID: UUID? = nil) {
        guard runID == nil || activeID == runID else { return }
        task?.cancel(); service.stop()
        if task == nil { activeID = nil }
    }
}
