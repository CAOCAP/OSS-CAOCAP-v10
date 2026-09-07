import SwiftUI

/// Root view that composes the agent hub, selected Workspace, overlays, and session sheets.
///
/// Session orchestration lives in `AppSessionCoordinator`; this view wires UI only.
/// FAB + call chrome live in a passthrough `UIWindow` above system sheets.
struct ContentView: View {
    @State private var session = AppSessionCoordinator()
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let agent = session.selectedAgent {
                    workspaceCanvas
                        .id(agent.id)
                        .overlay(alignment: .topLeading) {
                            Button { session.returnToHome() } label: {
                                Label("Back to Home", systemImage: "chevron.backward")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                            .controlSize(.large)
                            .accessibilityIdentifier("workspace.back")
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    if session.showingHUD {
                        CanvasHUDView(
                            store: session.router.activeStore,
                            viewportScale: session.currentScale,
                            onSignInTapped: { session.showingSignIn = true },
                            onCheckpointsTapped: { session.showingSnapshotBrowser = true }
                        )
                        .padding(.top, 56)
                    }
                    KeyboardShortcutBridge(
                        onToggleChatOrDismissSheets: { session.handleFABTapOrCommandJ() },
                        onUndo: { _ = session.actionDispatcher.perform(.undo, source: .user) },
                        onRedo: { _ = session.actionDispatcher.perform(.redo, source: .user) }
                    )
                } else {
                    AgentHubView(session: session)
                }
            }
            .onboardingTooltipOverlay(
                // FAB tooltips render in the chrome overlay window so they sit above the FAB.
                rendersAnchor: {
                    !$0.isCanvasLocal
                        && !$0.isCoCaptainLocal
                        && $0 != .floatingCommandButton
                }
            )
            .background(Color.black.ignoresSafeArea())
            .overlay { launchOverlay }
            .overlay { introOverlay }
            .overlay { personalizationOverlay }
            .overlay { updatePromptOverlay }
            .overlay {
                if session.showConfetti {
                    ZStack {
                        ConfettiCelebrationView()
                        VStack {
                            Spacer()
                            TutorialGraduationBanner()
                                .padding(.horizontal, 24)
                                .padding(.bottom, 48)
                        }
                    }
                    .zIndex(95)
                    .transition(.opacity)
                }
            }
            .modifier(AppSheetsModifier(session: session))
            .modifier(AppSessionLifecycle(
                session: session,
                geometry: geometry,
                undoManager: undoManager
            ))
            .onAppear {
                GlobalFloatingChromeController.shared.install(session: session)
            }
            .onDisappear {
                GlobalFloatingChromeController.shared.uninstall()
            }
        }
    }

    @ViewBuilder
    private var workspaceCanvas: some View {
        switch session.router.currentWorkspace {
        case .root:
            WorkspaceCanvasView(
                store: session.router.rootStore,
                canvasID: "root_canvas",
                viewport: $session.viewport,
                currentScale: $session.currentScale,
                canvasFocusNodeID: session.canvasFocusNodeID,
                onNodeAction: { session.handleNodeAction($0) },
                onNavigateToSubCanvas: { fileName in
                    session.handleSubCanvasNavigation(fileName: fileName)
                },
                onRecoverUnsupportedProject: {
                    session.router.createFreshCanvas()
                },
                onFlyToNode: { session.focusCanvasNode($0) }
            )
        case .project(let fileName):
            WorkspaceCanvasView(
                store: session.router.activeStore,
                canvasID: "project_canvas_\(fileName)",
                viewport: $session.viewport,
                currentScale: $session.currentScale,
                canvasFocusNodeID: session.canvasFocusNodeID,
                onNodeAction: { session.handleNodeAction($0) },
                onNavigateToSubCanvas: { fileName in
                    session.handleSubCanvasNavigation(fileName: fileName)
                },
                onRecoverUnsupportedProject: {
                    session.router.createFreshCanvas()
                },
                onFlyToNode: { session.focusCanvasNode($0) }
            )
        }
    }

    @ViewBuilder
    private var launchOverlay: some View {
        if session.isLaunching {
            LaunchScreenView()
                .transition(.opacity)
                .zIndex(100)
        }
    }

    @ViewBuilder
    private var introOverlay: some View {
        if !session.isLaunching && session.intro.shouldPresent {
            IntroView(coordinator: session.intro) {
                session.finishIntroFlow()
            }
            .transition(.opacity)
            .zIndex(80)
        }
    }

    @ViewBuilder
    private var personalizationOverlay: some View {
        if !session.isLaunching
            && !session.intro.shouldPresent
            && session.personalization.shouldPresent {
            PersonalizationOnboardingView(
                coordinator: session.personalization,
                onBackToIntro: {
                    session.returnToIntroFromPersonalization()
                },
                onFinish: {
                    session.finishPersonalizationFlow()
                }
            )
            .transition(.opacity)
            .zIndex(75)
        }
    }

    @ViewBuilder
    private var updatePromptOverlay: some View {
        if let availableUpdate = session.appUpdateService.availableUpdate,
           session.appUpdateService.shouldPresentUpdatePrompt,
           !session.isLaunching {
            AppUpdatePromptView(update: availableUpdate, onUpdate: {})
                .zIndex(90)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthenticationManager())
        .environment(DevicePresence())
        .environment(RemoteCommandClient())
}
