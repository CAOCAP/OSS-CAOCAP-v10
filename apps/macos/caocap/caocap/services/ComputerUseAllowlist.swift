import Foundation

/// Restricts the computer-use loop to a known, reviewed set of target apps. TextEdit only for
/// this phase — see docs/macos-agent-plan.md Phase 3 ("Not in this phase: ... broad app coverage").
enum ComputerUseAllowlist {
    static let allowedBundleIdentifiers: Set<String> = [
        "com.apple.TextEdit",
    ]

    static func isAllowed(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return allowedBundleIdentifiers.contains(bundleIdentifier)
    }
}
