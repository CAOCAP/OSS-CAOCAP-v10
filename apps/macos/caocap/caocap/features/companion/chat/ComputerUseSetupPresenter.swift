import AppKit
import SwiftUI

/// Hosts ComputerUseSetupSheet in its own small window. A real SwiftUI `.sheet` needs an
/// existing window to attach to, which the menu-bar-triggered debug path doesn't have, so this
/// gives the sheet a home; the same presenter is reused once chat can trigger it in Sub-phase D.
@MainActor
enum ComputerUseSetupPresenter {
    private static var window: NSWindow?

    static func present(installGate: ComputerUseInstallGate) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Computer Use Setup"
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: ComputerUseSetupSheet(installGate: installGate) {
            window?.close()
        })
        panel.center()
        window = panel
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }
}
