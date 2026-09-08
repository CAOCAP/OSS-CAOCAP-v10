import Foundation
import OSLog

struct ComputerUseDriverStatus: Codable {
    let installed: Bool
    let running: Bool
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
}

/// Thin bridge from the sandboxed caocap app to the unsandboxed ComputerUseHelper XPC service.
@MainActor
final class ComputerUseHelperClient {
    private let logger = Logger(subsystem: "com.caocap.app", category: "ComputerUseHelperClient")

    func ping() async throws -> String {
        try await withProxy { proxy, continuation in
            proxy.ping { reply in continuation.resume(returning: reply) }
        }
    }

    func status() async throws -> ComputerUseDriverStatus {
        let data = try await withProxy { proxy, continuation in
            proxy.status { data in continuation.resume(returning: data) }
        }
        return try JSONDecoder().decode(ComputerUseDriverStatus.self, from: data)
    }

    func captureScreenshot(bundleIdentifier: String) async throws -> Data {
        try await withProxy { proxy, continuation in
            proxy.captureScreenshot(bundleIdentifier: bundleIdentifier) { pngData, errorMessage in
                if let pngData {
                    continuation.resume(returning: pngData)
                } else {
                    continuation.resume(throwing: ComputerUseHelperClientError.driverError(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func launchApp(bundleIdentifier: String) async throws {
        let result: Void = try await withProxy { proxy, continuation in
            proxy.launchApp(bundleIdentifier: bundleIdentifier) { errorMessage in
                if let errorMessage {
                    continuation.resume(throwing: ComputerUseHelperClientError.driverError(errorMessage))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        return result
    }

    func performAction(_ action: [String: Any], bundleIdentifier: String) async throws {
        let actionJSON = try JSONSerialization.data(withJSONObject: action)
        let result: Void = try await withProxy { proxy, continuation in
            proxy.performAction(actionJSON: actionJSON, bundleIdentifier: bundleIdentifier) { errorMessage in
                if let errorMessage {
                    continuation.resume(throwing: ComputerUseHelperClientError.driverError(errorMessage))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        return result
    }

    func requestPermissions() async throws {
        let result: Void = try await withProxy { proxy, continuation in
            proxy.requestPermissions { errorMessage in
                if let errorMessage {
                    continuation.resume(throwing: ComputerUseHelperClientError.driverError(errorMessage))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        return result
    }

    private func withProxy<T>(
        _ body: @escaping (ComputerUseHelperProtocol, CheckedContinuation<T, Error>) -> Void
    ) async throws -> T {
        let connection = makeConnection()
        connection.resume()
        defer { connection.invalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: error)
            } as? ComputerUseHelperProtocol

            guard let proxy else {
                continuation.resume(throwing: ComputerUseHelperClientError.invalidProxy)
                return
            }

            body(proxy, continuation)
        }
    }

    private func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(serviceName: "com.Ficruty.caocap.ComputerUseHelper")
        connection.remoteObjectInterface = NSXPCInterface(with: ComputerUseHelperProtocol.self)
        connection.invalidationHandler = { [logger] in
            logger.info("ComputerUseHelper connection invalidated.")
        }
        connection.interruptionHandler = { [logger] in
            logger.warning("ComputerUseHelper connection interrupted.")
        }
        return connection
    }
}

enum ComputerUseHelperClientError: Error {
    case invalidProxy
    case driverError(String)
}
