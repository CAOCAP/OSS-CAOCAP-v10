import Foundation
import Observation
import OSLog
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Orchestrates root-session state: routing, actions, sheets, and onboarding hooks.
@MainActor
@Observable
final class AppSessionCoordinator {
    var agentLibrary: AgentLibrary
    var selectedTab: HubTab = .home
    private(set) var selectedAgent: LibraryAgent?
    var showingAgentWizard = false
    @ObservationIgnored private var agentChats: [String: CoCaptainViewModel] = [:]

    var router = AppRouter()
    var coCaptain = CoCaptainViewModel()
    private(set) var actionDispatcher = AppActionDispatcher()
    @ObservationIgnored private var remoteMacCommands: (any RemoteMacCommandRunning)?

    var showingFileImporter = false
    var showingPurchaseSheet = false
    var showingUsage = false
    var showingSignIn = false
    var showingSettings = false
    var showingSnapshotBrowser = false
    var showingProfile = false
    var showingActivity = false
    var showingHelp = false
    var showingAppIconPicker = false
    var showConfetti = false
    var showingCopilotCall = false
    var showingCopilotPicker = false
    var activeCopilotCallMode: CopilotInteractionMode = .voice
    var selectedCopilot: CopilotPersona = UserProfileStore().loadSelectedCopilot()
    @ObservationIgnored var copilotCallViewModel: CopilotCallViewModel?

    var currentScale: CGFloat = 1.0
    var isLaunching = true
    var appUpdateService = AppUpdateService.shared
    var viewport = ViewportState()
    var nodeSizes: [UUID: CGSize] = [:]
    var containerSize: CGSize = .zero
    /// Briefly highlights a node after fly-to navigation from CoCaptain.
    var canvasFocusNodeID: UUID?
    @ObservationIgnored private var canvasFocusClearTask: Task<Void, Never>?
    /// Matches `LaunchScreenView` entrance length so the brand animation can land.
    /// Tests may shorten this to avoid sleeping for the full brand dwell.
    var launchMinimumVisibleDuration: Duration = .milliseconds(1_200)
    /// Hard cap so splash never blocks interaction longer than the old fixed delay.
    var launchMaximumVisibleDuration: Duration = .seconds(2.5)
    @ObservationIgnored private var launchDismissTask: Task<Void, Never>?

    var exportURL: URL?
    var showExportSheet = false

    var intro = IntroCoordinator()
    var personalization = PersonalizationOnboardingCoordinator()
    var onboarding = OnboardingCoordinator()

    var coCaptainDetent: PresentationDetent = .medium
    var coCaptainStartsLarge = false
    var coCaptainAllowsMediumDetent = true

    private var actionsConfigured = false
    @ObservationIgnored private var activeUndoManager: UndoManager?
    @ObservationIgnored private var workspaceUndoManagers: [String: UndoManager] = [:]
    

    init(agentLibrary: AgentLibrary? = nil) {
        self.agentLibrary = agentLibrary ?? AgentLibrary()
        onboarding.onLessonWillStart = { [weak self] lessonID in
            self?.prepareWorkspace(for: lessonID)
        }
        onboarding.onTutorialCompleted = { [weak self] in
            self?.celebrateTutorialGraduation()
        }
    }

    // MARK: - Agent hub

    func openAgent(_ agent: LibraryAgent) {
        guard agentLibrary.agents.contains(where: { $0.id == agent.id }) else { return }
        closeListedSheets()
        coCaptain.suspendAgentSession()
        dismissCopilotCall()
        selectedTab = .home
        selectedAgent = agent
        updateSelectedCopilot(agent.persona)
        let chat = agentChats[agent.id] ?? CoCaptainViewModel()
        agentChats[agent.id] = chat
        coCaptain = chat
        coCaptain.agentDisplayName = agent.name
        router.openAgentWorkspace(fileName: agent.workspaceFileName, name: agent.name)
        handleWorkspaceChange(undoManager: activeUndoManager)
        coCaptain.resumeAgentSession()
    }

    func returnToHome() {
        closeListedSheets()
        coCaptain.suspendAgentSession()
        dismissCopilotCall()
        selectedAgent = nil
        selectedTab = .home
        canvasFocusNodeID = nil
        canvasFocusClearTask?.cancel()
    }

    private enum StorageKey {
        static let gridOpacity = "grid_opacity"
        static let lastGridOpacity = "last_grid_opacity"
        static let showingHUD = "showing_hud"
    }

    var gridOpacity: Double {
        get {
            if UserDefaults.standard.object(forKey: StorageKey.gridOpacity) == nil {
                return 0.1
            }
            return UserDefaults.standard.double(forKey: StorageKey.gridOpacity)
        }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.gridOpacity) }
    }

    private var lastGridOpacity: Double {
        get {
            if UserDefaults.standard.object(forKey: StorageKey.lastGridOpacity) == nil {
                return 0.1
            }
            return UserDefaults.standard.double(forKey: StorageKey.lastGridOpacity)
        }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.lastGridOpacity) }
    }

    var showingHUD: Bool {
        get { UserDefaults.standard.bool(forKey: StorageKey.showingHUD) }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.showingHUD) }
    }

    var coCaptainAvailableDetents: Set<PresentationDetent> {
        coCaptainAllowsMediumDetent ? [.medium, .large] : [.large]
    }

    // MARK: - Lifecycle

    func bootstrap(undoManager: UndoManager?) {
        activeUndoManager = undoManager
        selectedCopilot = UserProfileStore().loadSelectedCopilot()
        bindCoCaptainSession()
        configureActionsIfNeeded()
        actionDispatcher.refreshCopilotActionTitle()
        syncViewportWithActiveStore()
        attachUndoManager(undoManager)
        configureCoCaptainProjectSession()

        scheduleLaunchOverlayDismissal()
    }

    func attachRemoteMacCommands(_ runner: any RemoteMacCommandRunning) {
        remoteMacCommands = runner
        coCaptain.remoteMacCommands = runner
    }

    /// Dismisses the launch overlay when the session is ready, after a short brand
    /// minimum and before a hard maximum — not a fixed cosmetic sleep.
    private func scheduleLaunchOverlayDismissal() {
        launchDismissTask?.cancel()
        launchDismissTask = Task { @MainActor [weak self] in
            await self?.dismissLaunchOverlayWhenReady()
        }
    }

    private func dismissLaunchOverlayWhenReady() async {
        let clock = ContinuousClock()
        let started = clock.now

        await waitForLaunchReadiness()
        guard !Task.isCancelled else { return }

        let readyAt = clock.now
        let minAt = started + launchMinimumVisibleDuration
        let maxAt = started + launchMaximumVisibleDuration
        let dismissAt = min(max(readyAt, minAt), maxAt)
        let remaining = dismissAt - clock.now
        if remaining > .zero {
            try? await Task.sleep(for: remaining)
        }
        guard !Task.isCancelled else { return }

        finishLaunchOverlayDismissal()
    }

    /// Root `ProjectStore` loads synchronously in `AppRouter` before UI appears.
    /// Yield so SwiftUI can commit the first canvas frame under the overlay.
    private func waitForLaunchReadiness() async {
        await Task.yield()
    }

    private func finishLaunchOverlayDismissal() {
        guard isLaunching else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            isLaunching = false
        }
        PerformanceSignposts.endLaunch()
        if !intro.shouldPresent {
            startInteractiveOnboardingIfNeeded()
        }
    }

    func handleWorkspaceChange(undoManager: UndoManager?) {
        guard selectedAgent != nil else { return }
        let fileName = router.activeStore.fileName
        let workspaceUndo = workspaceUndoManagers[fileName] ?? UndoManager()
        workspaceUndoManagers[fileName] = workspaceUndo
        activeUndoManager = workspaceUndo
        bindCoCaptainSession()
        attachUndoManager(workspaceUndo)
        configureCoCaptainProjectSession()
        syncViewportWithActiveStore()
    }

    func updateContainerSize(_ size: CGSize) {
        containerSize = size
    }

    /// Called when the motivational intro tour finishes. Presents personalization if needed.
    func finishIntroFlow() {
        startInteractiveOnboardingIfNeeded()
    }

    /// Called when the personalization survey finishes or is skipped.
    func finishPersonalizationFlow() {
        selectedCopilot = UserProfileStore().loadSelectedCopilot()
        actionDispatcher.refreshCopilotActionTitle()
        onboarding.startIfNeeded()
    }

    func updateSelectedCopilot(_ persona: CopilotPersona) {
        let resolvedPersona = selectedAgent?.persona ?? persona
        UserProfileStore().saveSelectedCopilot(resolvedPersona)
        selectedCopilot = resolvedPersona
        actionDispatcher.refreshCopilotActionTitle()
    }

    /// Re-opens the intro tour while personalization remains in progress.
    func returnToIntroFromPersonalization() {
        intro.reset()
    }

    /// Starts the gesture tutorial only when intro and personalization are both complete.
    func startInteractiveOnboardingIfNeeded() {
        guard !personalization.shouldPresent else { return }
        onboarding.startIfNeeded()
    }

    func restartPersonalization() {
        returnToHome()
        personalization.reset()
        router.navigate(to: .root, addToStack: false, animated: false)
        syncViewportWithActiveStore()
    }

    func restartOnboarding() {
        returnToHome()
        intro.reset()
        personalization.reset()
        onboarding.reset()
        router.navigate(to: .root, addToStack: false, animated: false)
        syncViewportWithActiveStore()
    }

    func restartTutorial() {
        onboarding.reset()
        router.navigate(to: .root, addToStack: false, animated: false)
        syncViewportWithActiveStore()
        onboarding.startIfNeeded()
        presentChatIfTutorialNeedsIt()
    }

    func restartTutorialFromHelp() {
        showingHelp = false
        restartTutorial()
    }

    func startLessonFromHelp(_ lessonID: OnboardingLessonID) {
        showingHelp = false
        prepareWorkspace(for: lessonID)
        onboarding.startLesson(lessonID, advancesThroughLessons: false)
        presentChatIfTutorialNeedsIt()
    }

    func prepareWorkspace(for lessonID: OnboardingLessonID) {
        closeListedSheets()
        router.navigate(to: .root, addToStack: false, animated: false)
        syncViewportWithActiveStore()
        _ = lessonID
    }

    private func celebrateTutorialGraduation() {
        HapticsManager.shared.notification(.success)
        showConfetti = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.showConfetti = false
        }
    }

    func eraseEverything(authManager: AuthenticationManager) async throws {
        guard !LocalGemmaModelManager.shared.isDownloadingLocalModel else {
            throw AppDataResetError.localModelDownloadInProgress
        }

        returnToHome()
        onboarding.reset()

        let stores = [router.rootStore] + Array(router.projects.values)
        for store in stores {
            await store.prepareForDataReset()
        }

        authManager.signOut()
        LocalGemmaModelManager.shared.clearLocalModelCache()
        try await AppDataResetService.eraseLocalData()
        ActivityStore.shared.reset()
        agentLibrary = AgentLibrary()
        agentChats.removeAll()
        workspaceUndoManagers.removeAll()
        router = AppRouter()
        coCaptain = CoCaptainViewModel()
        actionDispatcher = AppActionDispatcher()
        intro = IntroCoordinator()
        personalization = PersonalizationOnboardingCoordinator()
        onboarding = OnboardingCoordinator()
        onboarding.onLessonWillStart = { [weak self] lessonID in
            self?.prepareWorkspace(for: lessonID)
        }
        onboarding.onTutorialCompleted = { [weak self] in
            self?.celebrateTutorialGraduation()
        }
        viewport = ViewportState()
        currentScale = 1
        nodeSizes = [:]
        actionsConfigured = false

        bindCoCaptainSession()
        configureActionsIfNeeded()
        attachUndoManager(activeUndoManager)
        configureCoCaptainProjectSession()
        syncViewportWithActiveStore()
        launchDismissTask?.cancel()
        launchDismissTask = nil
        isLaunching = false
        PerformanceSignposts.endLaunch()
    }

    func updateNodeSizes(_ sizes: [UUID: CGSize]) {
        nodeSizes = sizes
    }

    // MARK: - Undo

    func performUndo(undoManager: UndoManager?) {
        guard selectedAgent != nil else { return }
        activeUndoManager?.undo()
        router.activeStore.undoStackChanged += 1
    }

    func performRedo(undoManager: UndoManager?) {
        guard selectedAgent != nil else { return }
        activeUndoManager?.redo()
        router.activeStore.undoStackChanged += 1
    }

    func handleUndoStackChanged() {
        router.activeStore.undoStackChanged += 1
    }

    // MARK: - Node Actions

    func handleNodeAction(_ action: NodeAction) {
        guard let actionID = action.appActionID else { return }
        _ = actionDispatcher.perform(actionID, source: .user)
    }

    func handleSubCanvasNavigation(fileName: String) {
        router.navigateToSubCanvas(fileName: fileName)
    }

    // MARK: - Listed Sheets

    /// Session SwiftUI sheets that FAB tap / ⌘J can dismiss together.
    /// HUD, voice/video call, launch, intro, and confetti are overlays and stay.
    var hasListedSheetPresented: Bool {
        coCaptain.isPresented
            || showingAgentWizard
            || showingSignIn
            || showingPurchaseSheet
            || showingSettings
            || showingUsage
            || showingSnapshotBrowser
            || showExportSheet
            || showingProfile
            || showingActivity
            || showingHelp
            || showingAppIconPicker
            || showingCopilotPicker
    }

    func closeListedSheets() {
        showingAgentWizard = false
        if coCaptain.isPresented {
            coCaptain.setPresented(false)
        }
        showingSignIn = false
        showingPurchaseSheet = false
        showingSettings = false
        showingUsage = false
        showingSnapshotBrowser = false
        showExportSheet = false
        showingProfile = false
        showingActivity = false
        showingHelp = false
        showingAppIconPicker = false
        showingCopilotPicker = false
    }

    /// FAB tap and ⌘J: open chat at large, or close every listed sheet if one is already up.
    func handleFABTapOrCommandJ() {
        if hasListedSheetPresented {
            closeListedSheets()
            return
        }
        presentCoCaptain(preferredDetent: .large)
    }

    // MARK: - Onboarding + CoCaptain Presentation

    func handleCoCaptainPresentationChange(isPresented: Bool) {
        if isPresented {
            Task {
                await SubscriptionManager.shared.refreshEntitlements()
            }
            if onboarding.currentStep == .tapFAB {
                onboarding.completeCurrentStep()
            }
        } else {
            if onboarding.currentStep == .dismissCoCaptain {
                onboarding.completeCurrentStep()
            } else if onboarding.currentStep == .chatCoCaptain
                        || onboarding.currentStep == .applyCoCaptainChange {
                if coCaptainHasPendingOnboardingReview {
                    onboarding.moveToStep(.applyCoCaptainChange)
                } else {
                    onboarding.moveToStep(.chatCoCaptain)
                }
            } else if onboarding.currentStep == .chatCoCaptainGameEdit
                        || onboarding.currentStep == .reviewCoCaptainChange {
                onboarding.moveToStep(.chatCoCaptainGameEdit)
            }
        }
    }

    func handleCoCaptainSuccessCountChange() {
        // Chat-sheet tutorial steps advance from CoCaptainView, not from a palette prompt row.
    }

    func handleHelpGuidesShownForOnboarding() {
        if onboarding.currentStep == .browseHelpGuides {
            onboarding.completeCurrentStep()
        }
    }

    func handleCoCaptainSheetAppeared() {
        guard coCaptainStartsLarge else { return }
        Task { @MainActor in
            await Task.yield()
            self.coCaptainAllowsMediumDetent = true
        }
    }

    func requestCoCaptainExpandedPresentation() {
        coCaptainAllowsMediumDetent = true
        coCaptainDetent = .large
    }

    // MARK: - File Import

    func importProject(from result: Result<[URL], Error>) {
        let logger = Logger(subsystem: "com.caocap.app", category: "FileImport")
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }

            guard selectedURL.startAccessingSecurityScopedResource() else {
                logger.error("Failed to start accessing security scoped resource.")
                return
            }

            Task { @MainActor [weak self] in
                defer {
                    selectedURL.stopAccessingSecurityScopedResource()
                }

                do {
                    let newFileName = try await Task.detached(priority: .userInitiated) { () -> String in
                        let data = try Data(contentsOf: selectedURL)
                        let decoder = JSONDecoder()
                        _ = try decoder.decode(ProjectSnapshot.self, from: data)

                        let persistence = ProjectPersistenceService()
                        let newFileName = CanvasFileNaming.newCanvasFileName()
                        let targetURL = persistence.fileURL(for: newFileName)
                        try data.write(to: targetURL, options: .atomic)
                        return newFileName
                    }.value

                    logger.info("Successfully imported project to: \(newFileName)")
                    ActivityStore.shared.recordSuccessfulSave(at: Date())

                    guard let self else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.router.navigate(to: .project(newFileName))
                    }
                } catch {
                    logger.error("Import failed: \(error.localizedDescription)")
                }
            }

        case .failure(let error):
            logger.error("Document picker failed: \(error.localizedDescription)")
        }
    }

    // MARK: - CoCaptain Session Hooks

    func bindCoCaptainSession() {
        coCaptain.onFlyToNode = { [weak self] nodeId in
            self?.focusCanvasNode(nodeId)
        }
        coCaptain.onReviewItemApplied = { [weak self] _, _ in
            self?.handleOnboardingReviewApplied()
        }
        coCaptain.onOnboardingReviewFallback = { [weak self] in
            let lessonID = self?.onboarding.activeLessonID?.rawValue ?? OnboardingLessonID.omniboxNavigation.rawValue
            AnalyticsService.shared.logEvent(
                OnboardingAnalytics.cocaptainReviewFallback,
                parameters: [OnboardingAnalytics.lessonID: lessonID]
            )
        }
    }

    func flyToTargetScale(for node: SpatialNode, nodeId: UUID) -> CGFloat {
        guard containerSize != .zero else { return 1.0 }

        let size = nodeSizes[nodeId] ?? CGSize(width: 280, height: 180)

        let paddingFactor: CGFloat = 0.8
        let scaleX = (containerSize.width * paddingFactor) / size.width
        let scaleY = (containerSize.height * paddingFactor) / size.height
        return min(min(scaleX, scaleY), 1.2)
    }

    // MARK: - Private

    private func attachUndoManager(_ undoManager: UndoManager?) {
        router.activeStore.undoManager = undoManager
        router.rootStore.undoManager = undoManager
    }

    private func syncViewportWithActiveStore() {
        viewport = ViewportState(
            offset: router.activeStore.viewportOffset,
            scale: router.activeStore.viewportScale
        )
        currentScale = viewport.scale
    }

    func ensureActionsConfigured() {
        configureActionsIfNeeded()
    }

    private func configureActionsIfNeeded() {
        guard !actionsConfigured else { return }
        actionsConfigured = true
        configureActions()
    }

    private func configureActions() {
        actionDispatcher.register(.goRoot) { [weak self] in
            guard let self else { return }
            if let agent = self.selectedAgent {
                self.router.openAgentWorkspace(fileName: agent.workspaceFileName, name: agent.name)
            } else {
                self.router.goRoot()
            }
            self.currentScale = 1.0
        }
        actionDispatcher.register(.goBack) { [weak self] in
            guard let self else { return }
            self.router.goBack()
        }
        actionDispatcher.register(.createNode) { [weak self] in
            self?.createNode(type: .standard)
        }
        actionDispatcher.register(.createFirebaseNode) { [weak self] in
            self?.createNode(type: .standard)
        }
        actionDispatcher.register(.summonCoCaptain) { [weak self] in
            self?.presentCoCaptainReplacingListedSheets(preferredDetent: .medium)
        }
        actionDispatcher.register(.summonCopilotVoice) { [weak self] in
            self?.presentCopilotCall(mode: .voice)
        }
        actionDispatcher.register(.summonCopilotVideo) { [weak self] in
            self?.presentCopilotCall(mode: .video)
        }
        actionDispatcher.register(.undo) { [weak self] in
            guard let self else { return }
            self.performUndo(undoManager: self.activeUndoManager)
        }
        actionDispatcher.register(.redo) { [weak self] in
            guard let self else { return }
            self.performRedo(undoManager: self.activeUndoManager)
        }
        actionDispatcher.register(.openFile) { [weak self] in
            self?.showingFileImporter = true
        }
        actionDispatcher.register(.toggleGrid) { [weak self] in
            self?.toggleGrid()
        }
        actionDispatcher.register(.shareCanvas) { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let url = await ExportService.export(from: self.router.activeStore, format: .caocap) {
                    self.exportURL = url
                    self.showExportSheet = true
                }
            }
        }
        actionDispatcher.register(.proSubscription) { [weak self] in
            self?.presentPurchaseSheet()
        }
        actionDispatcher.register(.signIn) { [weak self] in
            self?.showingSignIn = true
        }
        actionDispatcher.register(.openSettings) { [weak self] in
            self?.showingSettings = true
        }
        actionDispatcher.register(.openUsage) { [weak self] in
            self?.showingUsage = true
        }
        actionDispatcher.register(.openProfile) { [weak self] in
            self?.showingProfile = true
        }
        actionDispatcher.register(.openActivity) { [weak self] in
            self?.showingActivity = true
        }
        actionDispatcher.register(.openWhatsApp) {
            if let url = SupportContact.whatsAppURL {
                UIApplication.shared.open(url)
            }
        }
        actionDispatcher.register(.help) { [weak self] in
            self?.showingHelp = true
        }
        actionDispatcher.register(.openAppIcon) { [weak self] in
            self?.showingAppIconPicker = true
        }
        actionDispatcher.register(.changeCopilot) { [weak self] in
            self?.showingCopilotPicker = true
        }
        actionDispatcher.register(.openSnapshotBrowser) { [weak self] in
            self?.showingSnapshotBrowser = true
        }
        actionDispatcher.register(.moveNode) { [weak self] args in
            self?.moveNode(arguments: args)
        }
        actionDispatcher.register(.themeNode) { [weak self] args in
            self?.themeNode(arguments: args)
        }
        actionDispatcher.register(.transformNode) { [weak self] args in
            self?.transformNode(arguments: args)
        }
        actionDispatcher.register(.organizeNodes) { [weak self] in
            guard let self else { return }
            self.router.activeStore.organizeNodes()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                self.viewport.fitTo(nodes: self.router.activeStore.nodes, containerSize: self.containerSize)
            }
        }
        actionDispatcher.register(.toggleHUD) { [weak self] in
            guard let self else { return }
            self.showingHUD.toggle()
        }
        actionDispatcher.register(.createSubCanvas) { [weak self] in
            self?.router.activeStore.addNode(type: .subCanvas)
        }
        actionDispatcher.register(.openYouTubeOnMac) { [weak self] _ -> String? in
            Task { @MainActor [weak self] in
                _ = await self?.remoteMacCommands?.requestOpenYouTubeOnMac()
            }
            return RemoteCommandChatCopy.askingMessage(for: .homepage)
        }
        actionDispatcher.register(.openYouTubeVideoOnMac) { [weak self] args -> String? in
            let url = args?["url"] ?? ""
            Task { @MainActor [weak self] in
                _ = await self?.remoteMacCommands?.requestOpenYouTubeVideoOnMac(url: url)
            }
            return RemoteCommandChatCopy.askingMessage(for: .video)
        }
        actionDispatcher.register(.openURLOnMac) { [weak self] args -> String? in
            let url = args?["url"] ?? ""
            Task { @MainActor [weak self] in
                _ = await self?.remoteMacCommands?.requestOpenURLOnMac(url: url)
            }
            return RemoteCommandChatCopy.askingMessage(for: .page)
        }
    }

    private func configureCoCaptainProjectSession() {
        coCaptain.remoteMacCommands = remoteMacCommands
        coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)
    }

    private func toggleGrid() {
        if gridOpacity > 0.0 {
            lastGridOpacity = gridOpacity
            gridOpacity = 0.0
        } else {
            gridOpacity = lastGridOpacity > 0.0 ? lastGridOpacity : 0.1
        }
    }

    private func presentPurchaseSheet() {
        presentListedSheetAfterClosingOthers { [weak self] in
            self?.showingPurchaseSheet = true
        }
    }

    /// Opens the purchase sheet, dismissing any covering sheet first when needed.
    func requestPurchaseSheet() {
        presentPurchaseSheet()
    }

    private func moveNode(arguments args: [String: String]?) {
        guard let args,
              let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
              let xStr = args["x"], let x = Double(xStr),
              let yStr = args["y"], let y = Double(yStr) else { return }
        router.activeStore.updateNodePosition(id: uuid, position: CGPoint(x: x, y: y))
    }

    private func themeNode(arguments args: [String: String]?) {
        guard let args,
              let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
              let themeStr = args["theme"], let theme = NodeTheme(rawValue: themeStr) else { return }
        router.activeStore.updateNodeTheme(id: uuid, theme: theme)
    }

    private func transformNode(arguments args: [String: String]?) {
        guard let args,
              let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
              let typeStr = args["type"], let type = NodeType(rawValue: typeStr) else { return }

        router.activeStore.updateNodeType(id: uuid, type: type)
    }

    private func createNode(type: NodeType) {
        router.activeStore.addNode(type: type)
    }

    func focusCanvasNode(_ nodeId: UUID) {
        guard let node = router.activeStore.nodes.first(where: { $0.id == nodeId }) else { return }
        let targetScale = flyToTargetScale(for: node, nodeId: nodeId)
        HapticsManager.shared.trigger(.light)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            viewport.flyTo(nodePosition: node.position, containerSize: containerSize, targetScale: targetScale)
        }
        canvasFocusNodeID = nodeId
        canvasFocusClearTask?.cancel()
        canvasFocusClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self, !Task.isCancelled else { return }
            if self.canvasFocusNodeID == nodeId {
                self.canvasFocusNodeID = nil
            }
        }

    }

    private var tutorialNeedsChatSheet: Bool {
        switch onboarding.currentStep {
        case .tapFAB, .chatCoCaptain, .dismissCoCaptain, .chatCoCaptainGameEdit,
             .reviewCoCaptainChange, .applyCoCaptainChange:
            return true
        default:
            return false
        }
    }

    /// Opens chat at large when a CoCaptain-sheet lesson step is already active.
    /// `tapFAB` stays a user gesture — it does not auto-present.
    private func presentChatIfTutorialNeedsIt() {
        switch onboarding.currentStep {
        case .chatCoCaptain, .dismissCoCaptain, .chatCoCaptainGameEdit,
             .reviewCoCaptainChange, .applyCoCaptainChange:
            guard !coCaptain.isPresented else { return }
            presentCoCaptain(preferredDetent: .large)
        default:
            break
        }
    }

    private func presentListedSheetAfterClosingOthers(_ present: @escaping () -> Void) {
        if hasListedSheetPresented {
            closeListedSheets()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.3))
                guard self != nil else { return }
                present()
            }
        } else {
            present()
        }
    }

    /// Radial-menu Chat: open at medium, replacing any listed sheet. Tutorial steps that need chat stay large.
    func presentCoCaptainReplacingListedSheets(preferredDetent: PresentationDetent) {
        let detent: PresentationDetent = tutorialNeedsChatSheet ? .large : preferredDetent
        let agentID = selectedAgent?.id
        presentListedSheetAfterClosingOthers { [weak self] in
            guard let self, self.selectedAgent?.id == agentID else { return }
            self.presentCoCaptain(preferredDetent: detent)
        }
    }

    private func presentCoCaptain(preferredDetent: PresentationDetent) {
        guard selectedAgent != nil else { return }
        let detent: PresentationDetent = tutorialNeedsChatSheet ? .large : preferredDetent
        let startsLarge = detent == .large
        coCaptainStartsLarge = startsLarge
        coCaptainAllowsMediumDetent = !startsLarge
        coCaptainDetent = detent
        configureCoCaptainProjectSession()
        coCaptain.setPresented(true)
    }

    func presentCopilotCall(mode: CopilotInteractionMode) {
        guard selectedAgent != nil else { return }
        closeListedSheets()

        let persona = selectedCopilot
        let context = copilotCallProjectContext()
        let viewModel = CopilotCallViewModel(
            mode: mode,
            persona: persona,
            projectContext: context
        )
        viewModel.onDismiss = { [weak self] in
            self?.dismissCopilotCall()
        }
        viewModel.onUpgrade = { [weak self] in
            self?.presentPurchaseSheet()
        }
        copilotCallViewModel = viewModel
        activeCopilotCallMode = mode
        showingCopilotCall = true
    }

    func dismissCopilotCall() {
        showingCopilotCall = false
        let viewModel = copilotCallViewModel
        copilotCallViewModel = nil
        Task {
            await viewModel?.liveService.stop()
        }
    }

    private func copilotCallProjectContext() -> String {
        let store = router.activeStore
        let workspaceLabel: String
        switch router.currentWorkspace {
        case .root:
            workspaceLabel = "root"
        case .project(let fileName):
            workspaceLabel = fileName
        }
        let nodeSummary = store.nodes
            .prefix(12)
            .map { "- \($0.title) (\($0.type.rawValue))" }
            .joined(separator: "\n")
        return """
        Workspace: \(workspaceLabel)
        Node count: \(store.nodes.count)
        Nodes:
        \(nodeSummary)
        """
    }

    private func handleOnboardingReviewApplied() {
        guard onboarding.currentStep == .applyCoCaptainChange,
              !coCaptainHasPendingOnboardingReview else {
            return
        }

        let lessonID = onboarding.activeLessonID?.rawValue ?? OnboardingLessonID.omniboxNavigation.rawValue
        AnalyticsService.shared.logEvent(
            OnboardingAnalytics.cocaptainReviewApplied,
            parameters: [OnboardingAnalytics.lessonID: lessonID]
        )

        coCaptain.setPresented(false)

        if onboarding.activeLessonID == .canvasBasics {
            celebrateTutorialGraduation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                guard let self,
                      self.onboarding.currentStep == .applyCoCaptainChange else {
                    return
                }
                self.onboarding.completeCurrentStep()
            }
            return
        }

        onboarding.completeCurrentStep()
    }

    private var coCaptainHasPendingOnboardingReview: Bool {
        coCaptain.items.contains { item in
            guard case .reviewBundle(let bundle) = item.content else { return false }
            return bundle.items.contains { $0.status.isUnresolved }
        }
    }

}
