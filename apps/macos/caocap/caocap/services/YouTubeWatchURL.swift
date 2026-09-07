import Foundation

/// Shared allowlist for YouTube watch URLs the Mac may open.
enum YouTubeWatchURL {
    static let homepage = "https://www.youtube.com"

    /// Returns `https://www.youtube.com/watch?v=VIDEO_ID` when `raw` is an allowlisted watch URL.
    static func canonicalWatchURL(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host?.lowercased() else {
            return nil
        }

        let videoID: String?
        if host == "youtu.be" || host == "www.youtu.be" {
            let parts = url.path.split(separator: "/").map(String.init)
            guard parts.count == 1 else { return nil }
            videoID = parts[0]
        } else if host == "youtube.com" || host == "www.youtube.com" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard path == "watch" else { return nil }
            videoID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "v" })?
                .value
        } else {
            return nil
        }

        guard let videoID, isYouTubeVideoID(videoID) else { return nil }
        return "https://www.youtube.com/watch?v=\(videoID)"
    }

    private static func isYouTubeVideoID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil
    }
}
