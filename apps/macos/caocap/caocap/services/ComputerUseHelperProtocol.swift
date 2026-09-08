import Foundation

/// XPC contract between the sandboxed caocap app and the unsandboxed ComputerUseHelper.
///
/// This declaration must be kept identical (selector-for-selector) to the copy in
/// ComputerUseHelper/ComputerUseHelperProtocol.swift. XPC matches methods by Objective-C
/// selector, not by shared Swift type, so the two targets each carry their own copy
/// rather than sharing a source file across the sandbox boundary.
@objc(ComputerUseHelperProtocol)
protocol ComputerUseHelperProtocol {
    func ping(reply: @escaping (String) -> Void)

    /// JSON-encoded ComputerUseDriverStatus.
    func status(reply: @escaping (Data) -> Void)

    /// PNG bytes on success; a human-readable error description on failure.
    func captureScreenshot(bundleIdentifier: String, reply: @escaping (Data?, String?) -> Void)

    /// Brings the app to the front, launching it first if needed. Non-nil reply is an error description.
    func launchApp(bundleIdentifier: String, reply: @escaping (String?) -> Void)

    /// `actionJSON` is one action from the model's computer-use response (e.g. click/type/scroll),
    /// passed through unmodified. Non-nil reply is an error description.
    func performAction(actionJSON: Data, bundleIdentifier: String, reply: @escaping (String?) -> Void)

    /// Raises the OS Accessibility/Screen Recording prompts if not already granted. Non-nil reply is an error description.
    func requestPermissions(reply: @escaping (String?) -> Void)
}
