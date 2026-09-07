import SwiftUI
import UniformTypeIdentifiers

/// Attaches session lifecycle handlers: workspace sync, onboarding, undo bridge, and geometry.
struct AppSessionLifecycle: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(DevicePresence.self) private var devicePresence
    @Environment(RemoteCommandClient.self) private var remoteCommandClient
    @Bindable var session: AppSessionCoordinator
    let geometry: GeometryProxy
    let undoManager: UndoManager?

    func body(content: Content) -> some View {
        content
            .onChange(of: session.router.currentWorkspace) {
                session.handleWorkspaceChange(undoManager: undoManager)
            }
            .onAppear {
                session.bootstrap(undoManager: undoManager)
                session.attachRemoteMacCommands(
                    RemoteMacCommandRunner(
                        client: remoteCommandClient,
                        authManager: authManager,
                        devicePresence: devicePresence
                    )
                )
                session.updateContainerSize(geometry.size)
            }
            .task {
                await session.appUpdateService.checkForUpdate()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await SubscriptionManager.shared.refreshEntitlements()
                }
            }
            .onChange(of: session.coCaptain.isPresented) { _, isPresented in
                session.handleCoCaptainPresentationChange(isPresented: isPresented)
            }
            .onChange(of: session.coCaptain.successfulAssistantResponseCount) {
                session.handleCoCaptainSuccessCountChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { _ in
                session.handleUndoStackChanged()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { _ in
                session.handleUndoStackChanged()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleChatOrDismissSheets)) { _ in
                session.handleFABTapOrCommandJ()
            }
            .onReceive(NotificationCenter.default.publisher(for: .summonCoCaptain)) { _ in
                _ = session.actionDispatcher.perform(.summonCoCaptain, source: .user)
            }
            .onReceive(NotificationCenter.default.publisher(for: .performUndo)) { _ in
                session.performUndo(undoManager: undoManager)
            }
            .onReceive(NotificationCenter.default.publisher(for: .performRedo)) { _ in
                session.performRedo(undoManager: undoManager)
            }
            .onPreferenceChange(NodeSizePreferenceKey.self) { value in
                session.updateNodeSizes(value)
            }
            .onChange(of: geometry.size) { _, newSize in
                session.updateContainerSize(newSize)
            }
            .fileImporter(
                isPresented: $session.showingFileImporter,
                allowedContentTypes: [.json, UTType(filenameExtension: "caocap")].compactMap { $0 },
                allowsMultipleSelection: false
            ) { result in
                session.importProject(from: result)
            }
            .environment(session.onboarding)
    }
}
