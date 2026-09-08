import Foundation

final class ComputerUseHelperImplementation: NSObject, ComputerUseHelperProtocol {
    private let driver = CuaDriverClient()
    private let queue = DispatchQueue(label: "com.caocap.driver")
    func configure(socketPath: String, reply: @escaping (String?) -> Void) {
        queue.async { do { try self.driver.configure(socketPath: socketPath); reply(nil) } catch { reply(error.localizedDescription) } }
    }
    func ping(reply: @escaping (String) -> Void) { reply("ready") }
    func status(reply: @escaping (Data) -> Void) {
        queue.async { reply((try? JSONEncoder().encode(self.driver.status())) ?? Data()) }
    }
    func prepareDocument(path: String, reply: @escaping (String?) -> Void) {
        queue.async { do { try self.driver.prepareDocument(path: path); reply(nil) } catch { reply(error.localizedDescription) } }
    }
    func captureScreenshot(bundleIdentifier: String, reply: @escaping (Data?, String?) -> Void) {
        queue.async { do { reply(try self.driver.captureScreenshot(bundleIdentifier: bundleIdentifier), nil) } catch { reply(nil, error.localizedDescription) } }
    }
    func performAction(actionJSON: Data, bundleIdentifier: String, reply: @escaping (String?) -> Void) {
        queue.async {
            do {
                guard let action = try JSONSerialization.jsonObject(with: actionJSON) as? [String: Any] else { throw DriverError("invalidModelAction") }
                try self.driver.performAction(action, bundleIdentifier: bundleIdentifier); reply(nil)
            } catch { reply(error.localizedDescription) }
        }
    }
    func requestPermissions(reply: @escaping (String?) -> Void) {
        DispatchQueue.main.async { self.driver.requestPermissions(); reply(nil) }
    }
    func cancel(reply: @escaping () -> Void) { driver.cancel(); reply() }
    func shutdown(reply: @escaping () -> Void) { driver.shutdown(); reply() }
    deinit { driver.shutdown() }
}
