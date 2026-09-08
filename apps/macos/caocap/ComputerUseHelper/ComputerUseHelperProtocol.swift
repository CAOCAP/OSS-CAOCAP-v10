import Foundation

/// Keep identical in the app and helper targets (Objective-C XPC selectors).
@objc(ComputerUseHelperProtocol)
protocol ComputerUseHelperProtocol {
    func ping(reply: @escaping (String) -> Void)
    func status(reply: @escaping (Data) -> Void)
    func prepareDocument(path: String, reply: @escaping (String?) -> Void)
    func captureScreenshot(bundleIdentifier: String, reply: @escaping (Data?, String?) -> Void)
    func performAction(actionJSON: Data, bundleIdentifier: String, reply: @escaping (String?) -> Void)
    func requestPermissions(reply: @escaping (String?) -> Void)
    func cancel(reply: @escaping () -> Void)
    func shutdown(reply: @escaping () -> Void)
}
