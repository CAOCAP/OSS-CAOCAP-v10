import AppKit
import Observation

/// Owns the companion panel for the process lifetime: wake, tuck, drag, and persistence.
@MainActor
@Observable
final class CompanionController {
    private(set) var isAwake: Bool
    private(set) var origin: NSPoint
    private(set) var persona: CompanionPersona
    private(set) var isDragging = false
    private(set) var isChatPresented = false

    let play = CompanionPlay()

    let cocaptainChat = AgentChatSession(persona: .cocaptain)
    private let costarChat = AgentChatSession(persona: .costar)

    var chatSession: AgentChatSession {
        persona == .cocaptain ? cocaptainChat : costarChat
    }

    /// Both personas share one desktop, so they share one computer-use context.
    func attachComputerUse(_ context: ComputerUseContext) {
        cocaptainChat.computerUse = context
        costarChat.computerUse = context
    }

    @ObservationIgnored
    private var panel: CompanionPanel?
    @ObservationIgnored
    private var chatPanel: AgentChatPanel?
    @ObservationIgnored
    private var screenObserver: NSObjectProtocol?
    @ObservationIgnored
    private var playTimer: Timer?

    init(defaults: UserDefaults = .standard) {
        if defaults.object(forKey: CompanionDefaults.isAwake) == nil {
            isAwake = true
        } else {
            isAwake = defaults.bool(forKey: CompanionDefaults.isAwake)
        }

        if defaults.object(forKey: CompanionDefaults.originX) != nil {
            origin = NSPoint(
                x: defaults.double(forKey: CompanionDefaults.originX),
                y: defaults.double(forKey: CompanionDefaults.originY)
            )
        } else {
            origin = Self.defaultOrigin()
        }

        if let raw = defaults.string(forKey: CompanionDefaults.persona),
           let stored = CompanionPersona(rawValue: raw) {
            persona = stored
        } else {
            persona = .cocaptain
        }

        play.persona = persona
        play.isAwake = isAwake
        setupChatReactions()
    }

    func install() {
        guard panel == nil else { return }
        let panel = CompanionPanel(
            rootView: CompanionView(controller: self),
            onDragBegan: { [weak self] in
                self?.beginDrag()
            },
            onDragEnded: { [weak self] didMove, clickCount in
                self?.endDrag(didMove: didMove, clickCount: clickCount)
            },
            onHoverChanged: { [weak self] hovering in
                self?.setHovered(hovering)
            },
            onRightClick: { [weak self] in
                self?.play.dispatch(.rightClicked)
            }
        )
        self.panel = panel
        play.menuHost = panel.contentView
        origin = clamp(origin)
        panel.setFrame(NSRect(origin: origin, size: CompanionLayout.panelSize), display: false)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reclampToScreens()
            }
        }

        if isAwake {
            panel.orderFrontRegardless()
            startPlayTimer()
        }
    }

    func setAwake(_ awake: Bool) {
        guard isAwake != awake else { return }
        isAwake = awake
        play.isAwake = awake
        UserDefaults.standard.set(awake, forKey: CompanionDefaults.isAwake)
        guard let panel else { return }
        if awake {
            origin = clamp(origin)
            panel.setFrameOrigin(origin)
            panel.orderFrontRegardless()
            startPlayTimer()
            play.dispatch(.woke)
        } else {
            closeChat()
            stopPlayTimer()
            play.isHovered = false
            play.resetTransientMotion()
            panel.orderOut(nil)
            play.dispatch(.tucked)
        }
    }

    func toggleAwake() {
        setAwake(!isAwake)
    }

    func setPersona(_ persona: CompanionPersona) {
        guard self.persona != persona else { return }
        self.persona = persona
        play.persona = persona
        UserDefaults.standard.set(persona.rawValue, forKey: CompanionDefaults.persona)
        play.dispatch(.personaChanged)
        handleGenerationState(chatSession.generationState)
        if !isAwake {
            setAwake(true)
        }
    }

    func beginDrag() {
        isDragging = true
        play.isDragging = true
        play.dispatch(.dragBegan)
        // Keep the draft, but tuck the chat while the user moves its agent.
        chatPanel?.orderOut(nil)
    }

    func endDrag(didMove: Bool, clickCount: Int = 1) {
        isDragging = false
        play.isDragging = false
        if didMove {
            let current = panel?.frame.origin ?? origin
            let clamped = clamp(current)
            origin = clamped
            if let panel, clamped != current {
                panel.setFrame(NSRect(origin: clamped, size: CompanionLayout.panelSize), display: true, animate: true)
            } else {
                panel?.setFrameOrigin(clamped)
            }
            persistOrigin()
            play.dispatch(.dragEnded(didMove: true))
            if isChatPresented {
                positionChat()
                chatPanel?.orderFrontRegardless()
            }
        } else {
            origin = panel?.frame.origin ?? origin
            play.dispatch(.dragEnded(didMove: false))
            if clickCount >= 2 {
                play.dispatch(.doubleTapped)
            } else {
                play.dispatch(.tapped)
                toggleChat()
            }
        }
    }

    func persistOrigin() {
        let stored = clamp(origin)
        origin = stored
        UserDefaults.standard.set(stored.x, forKey: CompanionDefaults.originX)
        UserDefaults.standard.set(stored.y, forKey: CompanionDefaults.originY)
    }

    func openMainWindow() {
        if MainWindowFocus.focusExisting() { return }
        NotificationCenter.default.post(name: .showMainWindow, object: nil)
        NSApp.activate()
    }

    func toggleChat() {
        if isChatPresented {
            closeChat()
        } else {
            openChat()
        }
    }

    func openChat() {
        if !isAwake { setAwake(true) }
        if chatPanel == nil {
            chatPanel = AgentChatPanel(rootView: AgentChatView(controller: self))
        }
        let alreadyPresented = isChatPresented
        isChatPresented = true
        play.isChatPresented = true
        positionChat()
        chatPanel?.makeKeyAndOrderFront(nil)
        if !alreadyPresented {
            play.dispatch(.chatOpened)
        }
    }

    func closeChat() {
        guard isChatPresented else { return }
        isChatPresented = false
        play.isChatPresented = false
        chatPanel?.orderOut(nil)
        play.dispatch(.chatClosed)
    }

    private func setHovered(_ hovering: Bool) {
        play.isHovered = hovering
        play.dispatch(hovering ? .hovered : .unhovered)
    }

    private func startPlayTimer() {
        stopPlayTimer()
        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickPlay()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        playTimer = timer
        tickPlay()
    }

    private func stopPlayTimer() {
        playTimer?.invalidate()
        playTimer = nil
    }

    private func tickPlay() {
        play.pointerLocation = NSEvent.mouseLocation
        play.agentFrame = panel?.frame ?? NSRect(origin: origin, size: CompanionLayout.panelSize)
        play.dispatch(.idleTick)
    }

    private func positionChat() {
        let agentFrame = panel?.frame ?? NSRect(origin: origin, size: CompanionLayout.panelSize)
        let visible = Self.screen(containing: agentFrame).visibleFrame
        chatPanel?.setFrame(AgentChatPanel.frame(beside: agentFrame, visibleFrame: visible), display: true)
    }

    private func reclampToScreens() {
        origin = clamp(origin)
        panel?.setFrameOrigin(origin)
        persistOrigin()
        if isChatPresented { positionChat() }
    }

    private func clamp(_ point: NSPoint) -> NSPoint {
        let size = CompanionLayout.panelSize
        let screen = Self.screen(containing: NSRect(origin: point, size: size))
        let visible = screen.visibleFrame
        let inset = CompanionLayout.screenInset
        let minX = visible.minX + inset
        let minY = visible.minY + inset
        let maxX = max(minX, visible.maxX - size.width - inset)
        let maxY = max(minY, visible.maxY - size.height - inset)
        return NSPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }

    private static func defaultOrigin() -> NSPoint {
        let size = CompanionLayout.panelSize
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        return NSPoint(
            x: visible.maxX - size.width - CompanionLayout.screenInset,
            y: visible.minY + CompanionLayout.screenInset
        )
    }

    private static func screen(containing rect: NSRect) -> NSScreen {
        if let hit = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) {
            return hit
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    private func setupChatReactions() {
        cocaptainChat.onStateChange = { [weak self] state in
            guard let self, self.persona == .cocaptain else { return }
            self.handleGenerationState(state)
        }
        costarChat.onStateChange = { [weak self] state in
            guard let self, self.persona == .costar else { return }
            self.handleGenerationState(state)
        }
    }

    private func handleGenerationState(_ state: GenerationState) {
        switch state {
        case .streaming:
            play.setMood(.thinking, priority: .interaction, owner: "ai")
        case .idle:
            play.clearMood(owner: "ai")
            play.setMood(.celebrating, priority: .interaction, owner: "ai_celebration", duration: 1.5)
        case .failed:
            play.clearMood(owner: "ai")
            play.setMood(.confused, priority: .interaction, owner: "ai_error", duration: 3.0)
        }
    }
}
