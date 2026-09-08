import AppKit
import SwiftUI

/// Shown when a computer-use task is requested but cua-driver isn't installed or running yet.
/// CAOCAP never runs the installer itself — this only shows the command and lets the user
/// check again once they've run it.
struct ComputerUseSetupSheet: View {
    let installGate: ComputerUseInstallGate
    var onDismiss: () -> Void

    @State private var isChecking = false
    @State private var didCopy = false

    private var needsInstall: Bool {
        installGate.status?.installed != true || installGate.status?.running != true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if needsInstall {
                Text("Computer use needs a local driver")
                    .font(.headline)

                Text("CoCaptain drives real apps through cua-driver, a small helper that runs on this Mac. It isn't installed or isn't running yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(ComputerUseInstallGate.installCommand)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

                    Button(didCopy ? "Copied" : "Copy") {
                        copyInstallCommand()
                    }
                }

                Text("Run this in Terminal, then check again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Computer use needs permission")
                    .font(.headline)

                Text("CoCaptain needs Accessibility and Screen Recording access to see and operate TextEdit. macOS will ask you to approve this.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onDismiss)
                Button {
                    Task { await checkAgain() }
                } label: {
                    if isChecking {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(needsInstall ? "Check again" : "Grant Permissions")
                    }
                }
                .disabled(isChecking)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func copyInstallCommand() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ComputerUseInstallGate.installCommand, forType: .string)
        didCopy = true
    }

    private func checkAgain() async {
        isChecking = true
        if needsInstall {
            await installGate.refresh()
        } else {
            await installGate.requestPermissions()
        }
        isChecking = false
        if installGate.isReady {
            onDismiss()
        }
    }
}
