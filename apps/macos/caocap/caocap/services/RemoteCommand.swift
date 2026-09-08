import Foundation
import FirebaseFirestore

struct RemoteCommand {
    let id: String
    let taskSummary: String?
    let openURL: URL?
    let expiresAt: Date
    static func parse(id: String, data: [String: Any]) -> RemoteCommand? {
        guard data["schemaVersion"] as? Int == 2, data["requestId"] as? String == id,
              let expires = data["expiresAt"] as? Timestamp,
              let type = data["type"] as? String else { return nil }
        if type == "computerUse" {
            guard data["target"] as? String == "com.apple.TextEdit", data["url"] is NSNull,
                  let summary = data["taskSummary"] as? String, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  summary.utf16.count <= 500 else { return nil }
            return RemoteCommand(id: id, taskSummary: summary, openURL: nil, expiresAt: expires.dateValue())
        }
        let raw = data["url"] as? String
        let url: String?
        switch type {
        case "openYouTube": url = raw == YouTubeWatchURL.homepage ? raw : nil
        case "openYouTubeVideo": url = YouTubeWatchURL.canonicalWatchURL(from: raw)
        case "openURL": url = AllowlistedOpenURL.canonicalDocumentationURL(from: raw)
        default: return nil
        }
        guard let url, let parsed = URL(string: url) else { return nil }
        return RemoteCommand(id: id, taskSummary: nil, openURL: parsed, expiresAt: expires.dateValue())
    }
}
