import Foundation

/// Runs unsandboxed. This is the only place in CAOCAP that holds Accessibility and
/// Screen Recording permissions and talks to cua-driver.
final class ComputerUseHelperImplementation: NSObject, ComputerUseHelperProtocol {
    private let driver = CuaDriverClient()

    func ping(reply: @escaping (String) -> Void) {
        reply("pong from ComputerUseHelper")
    }

    func status(reply: @escaping (Data) -> Void) {
        let status = driver.status()
        reply((try? JSONEncoder().encode(status)) ?? Data())
    }

    func captureScreenshot(bundleIdentifier: String, reply: @escaping (Data?, String?) -> Void) {
        do {
            try driver.ensureDaemonRunning()
            let png = try driver.captureScreenshot(bundleIdentifier: bundleIdentifier)
            reply(png, nil)
        } catch {
            reply(nil, String(describing: error))
        }
    }

    func launchApp(bundleIdentifier: String, reply: @escaping (String?) -> Void) {
        do {
            try driver.ensureDaemonRunning()
            try driver.launchApp(bundleIdentifier: bundleIdentifier)
            reply(nil)
        } catch {
            reply(String(describing: error))
        }
    }

    func performAction(actionJSON: Data, bundleIdentifier: String, reply: @escaping (String?) -> Void) {
        do {
            guard let action = try JSONSerialization.jsonObject(with: actionJSON) as? [String: Any] else {
                reply(String(describing: CuaDriverClientError.unexpectedResponse))
                return
            }
            try driver.ensureDaemonRunning()
            try driver.performAction(action, bundleIdentifier: bundleIdentifier)
            reply(nil)
        } catch {
            reply(String(describing: error))
        }
    }

    func requestPermissions(reply: @escaping (String?) -> Void) {
        do {
            try driver.ensureDaemonRunning()
            try driver.requestPermissions()
            reply(nil)
        } catch {
            reply(String(describing: error))
        }
    }
}
