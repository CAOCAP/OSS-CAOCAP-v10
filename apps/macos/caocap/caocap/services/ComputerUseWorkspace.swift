import AppKit
import OSLog
import Observation

/// The folder Agent-mode runs are allowed to produce files in, and where the result check looks.
///
/// The app is sandboxed, so access comes from the user picking the folder. An app-scoped bookmark
/// keeps that grant across launches — otherwise every single prompt would open a folder picker.
@MainActor @Observable
final class ComputerUseWorkspace {
    private static let bookmarkKey = "computerUse.workspaceBookmark"

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.caocap.app", category: "ComputerUseWorkspace")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasFolder: Bool { defaults.data(forKey: Self.bookmarkKey) != nil }

    /// Returns the saved folder, asking the user to choose one the first time. `nil` means the
    /// user cancelled the picker.
    func resolveFolder() -> URL? {
        if let stored = storedFolder() { return stored }
        return promptForFolder()
    }

    func forgetFolder() {
        defaults.removeObject(forKey: Self.bookmarkKey)
    }

    func storedFolderOnly() -> URL? { storedFolder() }
    var folderDisplayName: String { storedFolder()?.lastPathComponent ?? "Not chosen" }
    @discardableResult func chooseFolder() -> URL? { promptForFolder() }

    private func storedFolder() -> URL? {
        guard let data = defaults.data(forKey: Self.bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            logger.warning("Stored workspace bookmark could not be resolved; asking again.")
            forgetFolder()
            return nil
        }
        if isStale {
            store(url)
        }
        return url
    }

    private func promptForFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Choose the folder where the Agent should save its work."
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        store(url)
        return url
    }

    private func store(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            logger.error("Failed to create a security-scoped bookmark for the chosen folder.")
            return
        }
        defaults.set(data, forKey: Self.bookmarkKey)
    }
}
