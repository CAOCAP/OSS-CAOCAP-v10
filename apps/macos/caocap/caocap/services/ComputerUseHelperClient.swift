import Foundation
import ApplicationServices
import CoreGraphics

struct ComputerUseDriverStatus: Codable {
    let installed: Bool
    let running: Bool
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
}

private final class HelperReply<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var result: Result<T, Error>?
    func install(_ continuation: CheckedContinuation<T, Error>) {
        lock.lock()
        if let result { lock.unlock(); continuation.resume(with: result) }
        else { self.continuation = continuation; lock.unlock() }
    }
    func finish(_ result: Result<T, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation; self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

@MainActor
final class ComputerUseHelperClient {
    private let runtime = ComputerUseOwnedRuntime()
    private var connection: NSXPCConnection?
    private var pending: [UUID: (Error) -> Void] = [:]
    private func connected() -> NSXPCConnection {
        if let connection { return connection }
        let next = NSXPCConnection(serviceName: "com.Ficruty.caocap.ComputerUseHelper")
        next.remoteObjectInterface = NSXPCInterface(with: ComputerUseHelperProtocol.self)
        next.interruptionHandler = { [weak self] in Task { @MainActor in self?.disconnect() } }
        next.invalidationHandler = { [weak self] in Task { @MainActor in self?.disconnect() } }
        next.resume(); connection = next
        return next
    }
    private func disconnect() {
        let callbacks = pending.values; pending.removeAll(); connection = nil
        callbacks.forEach { $0(ComputerUseFailure.setupIncomplete) }
    }
    func cancel() {
        guard let proxy = connection?.remoteObjectProxy as? ComputerUseHelperProtocol else { return }
        proxy.cancel {}
    }
    func shutdown() {
        runtime.shutdown()
        (connection?.remoteObjectProxy as? ComputerUseHelperProtocol)?.shutdown {}
    }
    func ping() async throws -> String { try await request { proxy, reply in proxy.ping { reply(.success($0)) } } }
    func status() async throws -> ComputerUseDriverStatus {
        ComputerUseDriverStatus(installed: runtime.installed, running: runtime.running,
            accessibilityGranted: AXIsProcessTrusted(), screenRecordingGranted: CGPreflightScreenCaptureAccess())
    }
    func prepareDocument(_ url: URL) async throws {
        try await runtime.start()
        let _: Void = try await request { proxy, reply in proxy.configure(socketPath: runtime.socket) { reply(Self.voidResult($0)) } }
        try Task.checkCancellation()
        let _: Void = try await request { proxy, reply in proxy.prepareDocument(path: url.path) { reply(Self.voidResult($0)) } }
    }
    func captureScreenshot(bundleIdentifier: String) async throws -> Data {
        try await request { proxy, reply in
            proxy.captureScreenshot(bundleIdentifier: bundleIdentifier) { data, error in
                if let data { reply(.success(data)) } else { reply(.failure(ComputerUseFailure(rawValue: error ?? "") ?? .actionFailed)) }
            }
        }
    }
    func performAction(_ action: [String: Any], bundleIdentifier: String) async throws {
        let json = try JSONSerialization.data(withJSONObject: action)
        let _: Void = try await request { proxy, reply in proxy.performAction(actionJSON: json, bundleIdentifier: bundleIdentifier) { reply(Self.voidResult($0)) } }
    }
    func requestPermissions() async throws {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestScreenCaptureAccess()
    }
    nonisolated private static func voidResult(_ error: String?) -> Result<Void, Error> {
        error.map { .failure(ComputerUseFailure(rawValue: $0) ?? .actionFailed) } ?? .success(())
    }
    private func request<T>(_ body: (ComputerUseHelperProtocol, @escaping (Result<T, Error>) -> Void) -> Void) async throws -> T {
        let id = UUID(); let gate = HelperReply<T>()
        pending[id] = { gate.finish(.failure($0)) }
        defer { pending.removeValue(forKey: id) }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                guard let proxy = connected().remoteObjectProxyWithErrorHandler({ gate.finish(.failure($0)) }) as? ComputerUseHelperProtocol else {
                    gate.finish(.failure(ComputerUseFailure.setupIncomplete)); return
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 25) { gate.finish(.failure(ComputerUseFailure.runTimeout)) }
                body(proxy) { gate.finish($0) }
            }
        } onCancel: {
            gate.finish(.failure(CancellationError()))
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }
}
