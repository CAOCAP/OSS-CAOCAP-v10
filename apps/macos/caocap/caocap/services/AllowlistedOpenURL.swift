import Foundation

/// Shared allowlist for documentation URLs the Mac may open besides YouTube.
enum AllowlistedOpenURL {
    /// Returns a canonical https URL when `raw` is on an allowlisted documentation host.
    static func canonicalDocumentationURL(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.port == nil || components.port == 443 else {
            return nil
        }

        let canonicalHost: String
        switch host {
        case "developer.apple.com", "www.developer.apple.com":
            canonicalHost = "developer.apple.com"
        case "docs.swift.org":
            canonicalHost = "docs.swift.org"
        case "swift.org", "www.swift.org":
            canonicalHost = "swift.org"
        default:
            return nil
        }

        components.scheme = "https"
        components.host = canonicalHost
        components.user = nil
        components.password = nil
        components.port = nil
        components.fragment = nil
        if components.path.isEmpty {
            components.path = "/"
        }
        return components.string
    }
}
