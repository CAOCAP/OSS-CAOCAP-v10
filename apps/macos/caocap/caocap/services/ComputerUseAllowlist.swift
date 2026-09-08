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

    /// Names the app a request asks for when that app isn't one we can drive.
    ///
    /// Every run targets TextEdit, so without this a "open WhatsApp for me" prompt quietly became
    /// a TextEdit run that failed for an unrelated-looking reason. This is a guard rail against
    /// that specific confusion, not general intent parsing — an unrecognised app name still falls
    /// through to the normal run and its normal failure reporting.
    static func unsupportedAppNamed(in prompt: String) -> String? {
        let lowercased = prompt.lowercased()
        guard !lowercased.contains("textedit"), !lowercased.contains("text edit") else { return nil }
        return knownUnsupportedApps.first { lowercased.contains($0.key) }?.value
    }

    private static let knownUnsupportedApps: KeyValuePairs<String, String> = [
        "whatsapp": "WhatsApp",
        "whats app": "WhatsApp",
        "safari": "Safari",
        "chrome": "Chrome",
        "finder": "Finder",
        "mail": "Mail",
        "messages": "Messages",
        "notes": "Notes",
        "pages": "Pages",
        "numbers": "Numbers",
        "keynote": "Keynote",
        "xcode": "Xcode",
        "terminal": "Terminal",
        "spotify": "Spotify",
        "slack": "Slack",
        "calendar": "Calendar",
        "photos": "Photos",
        "preview": "Preview",
    ]
}
