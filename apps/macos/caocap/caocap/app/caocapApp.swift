//
//  caocapApp.swift
//  caocap
//
//  Created by Azzam Alrashed on 18/08/2026.
//

import AppKit
import SwiftUI

/// Keeps the process alive after the last window closes so the status item stays in the menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let companion = CompanionController()
    let authenticationManager = AuthenticationManager()
    let devicePresence = DevicePresence()
    let remoteCommandRelay = RemoteCommandRelay()

    func applicationDidFinishLaunching(_ notification: Notification) {
        FirebaseConfiguration.configure()
        authenticationManager.start()
        devicePresence.attach(authManager: authenticationManager)
        remoteCommandRelay.attach(authManager: authenticationManager)
        companion.install()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .showMainWindow, object: nil)
        }
        return true
    }
}

extension Notification.Name {
    static let showMainWindow = Notification.Name("caocap.showMainWindow")
}

@main
struct caocapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("CAOCAP", id: "main") {
            ContentView()
        }
        .commands {
            CommandMenu("Agent") {
                AgentMenuControls(companion: appDelegate.companion)
            }
        }

        // Status item on the right side of the menu bar. Separate from the Dock app icon.
        MenuBarExtra {
            StatusItemMenu(
                companion: appDelegate.companion,
                authenticationManager: appDelegate.authenticationManager,
                devicePresence: appDelegate.devicePresence,
                remoteCommandRelay: appDelegate.remoteCommandRelay
            )
        } label: {
            StatusItemLabel()
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Always-on label so Dock reopen can restore the window even when the menu is closed.
private struct StatusItemLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image("MenuBarIcon")
            .renderingMode(.template)
            .accessibilityLabel("CAOCAP")
            .onReceive(NotificationCenter.default.publisher(for: .showMainWindow)) { _ in
                MainWindowFocus.reveal(openIfNeeded: openWindow)
            }
    }
}

/// Menu shown when the status item is clicked.
private struct StatusItemMenu: View {
    @Bindable var companion: CompanionController
    @Bindable var authenticationManager: AuthenticationManager
    @Bindable var devicePresence: DevicePresence
    @Bindable var remoteCommandRelay: RemoteCommandRelay
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        AgentMenuControls(companion: companion)
        Button("Open CAOCAP") {
            MainWindowFocus.reveal(openIfNeeded: openWindow)
        }
        Divider()
        accountMenuItems
        Divider()
        Button("Quit CAOCAP") {
            NSApp.terminate(nil)
        }
    }

    @ViewBuilder
    private var accountMenuItems: some View {
        switch authenticationManager.authState {
        case .signedOut:
            Button("Sign in with Apple") {
                Task { await authenticationManager.signInWithApple() }
            }
            .disabled(authenticationManager.isSigningIn)
        case .signedIn(let uid):
            Button("UID: \(uid)") {}
                .disabled(true)
            if devicePresence.otherDevices.isEmpty {
                Button("No other devices") {}
                    .disabled(true)
            } else {
                ForEach(devicePresence.otherDevices) { device in
                    Button(device.menuLabel()) {}
                        .disabled(true)
                }
            }
            Toggle("Enable requests from my iPhone", isOn: $remoteCommandRelay.requestsEnabled)
            Button("Sign Out") {
                authenticationManager.signOut()
            }
        case .failed(let message):
            Button(message) {}
                .disabled(true)
            Button("Sign in with Apple") {
                Task { await authenticationManager.signInWithApple() }
            }
            .disabled(authenticationManager.isSigningIn)
        }
    }
}

/// Shared controls keep menu-bar and keyboard access in sync with the floating agent.
private struct AgentMenuControls: View {
    @Bindable var companion: CompanionController

    var body: some View {
        Button("Chat with \(companion.persona.displayName)") {
            companion.openChat()
        }
        .keyboardShortcut("j", modifiers: [.command, .shift])
        Button(companion.isAwake ? "Hide \(companion.persona.displayName)" : "Show \(companion.persona.displayName)") {
            companion.toggleAwake()
        }
        Picker("Companion", selection: Binding(
            get: { companion.persona },
            set: { companion.setPersona($0) }
        )) {
            ForEach(CompanionPersona.allCases) { persona in
                Text(persona.displayName).tag(persona)
            }
        }
        .pickerStyle(.inline)
    }
}
