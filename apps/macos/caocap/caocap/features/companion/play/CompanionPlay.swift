import AppKit
import Foundation
import Observation

enum CompanionMoodPriority: Int, Comparable {
    case rest = 0
    case idle = 1
    case interaction = 2
    case transient = 3

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct CompanionMotion: Equatable {
    var squashScale = CGSize(width: 1, height: 1)
    var peekOffset = CGSize.zero
    var tiltDegrees: CGFloat = 0
    var spinDegrees: CGFloat = 0
}

enum CompanionPlayEvent: Equatable {
    case hovered
    case unhovered
    case dragBegan
    case dragEnded(didMove: Bool)
    case tapped
    case doubleTapped
    case rightClicked
    case chatOpened
    case chatClosed
    case personaChanged
    case idleTick
    case waveHello
    case woke
    case tucked
}

struct CompanionPlayMenuItem {
    let title: String
    let action: () -> Void
}

@MainActor
protocol CompanionPlayDirector: AnyObject {
    func handle(_ event: CompanionPlayEvent, play: CompanionPlay)
}

/// Shared play state for the floating Agent. Directors write only their own fields.
@MainActor
@Observable
final class CompanionPlay {
    var mood: CompanionMood = .idle
    var motion = CompanionMotion()
    var bubbleText = "Chat with me"
    var confettiToken: UUID?

    var allowsMotion = true
    var isBobPaused = false
    var bobAmplitude: CGFloat = CompanionLayout.defaultBobAmplitude

    var persona: CompanionPersona = .cocaptain
    var isChatPresented = false
    var isDragging = false
    var isAwake = true
    var isHovered = false
    var agentFrame = CGRect.zero
    var pointerLocation = CGPoint.zero

    @ObservationIgnored
    weak var menuHost: NSView?
    @ObservationIgnored
    private var menuTarget: ContextMenuTarget?
    @ObservationIgnored
    private var directors: [any CompanionPlayDirector] = []
    @ObservationIgnored
    private var moodClaims: [PlayClaim<CompanionMood>] = []
    @ObservationIgnored
    private var bubbleClaims: [PlayClaim<String>] = []

    init(directors: [any CompanionPlayDirector]? = nil) {
        self.directors = directors ?? [
            CompanionMoodDirector(),
            CompanionSquashBounce(),
            CompanionIdlePersonality(),
            CompanionCursorPeek(),
            CompanionDropToys(),
        ]
        resolvePresentation()
    }

    func dispatch(_ event: CompanionPlayEvent) {
        pruneExpiredClaims()
        for director in directors {
            director.handle(event, play: self)
        }
        pruneExpiredClaims()
        resolvePresentation()
    }

    func setMood(
        _ mood: CompanionMood,
        priority: CompanionMoodPriority,
        owner: String,
        duration: TimeInterval? = nil
    ) {
        upsert(&moodClaims, value: mood, priority: priority, owner: owner, duration: duration)
        resolvePresentation()
    }

    func clearMood(owner: String) {
        moodClaims.removeAll { $0.owner == owner }
        resolvePresentation()
    }

    func setBubble(
        _ text: String,
        priority: CompanionMoodPriority,
        owner: String,
        duration: TimeInterval? = nil
    ) {
        upsert(&bubbleClaims, value: text, priority: priority, owner: owner, duration: duration)
        resolvePresentation()
    }

    func clearBubble(owner: String) {
        bubbleClaims.removeAll { $0.owner == owner }
        resolvePresentation()
    }

    func presentContextMenu(_ items: [CompanionPlayMenuItem]) {
        guard let view = menuHost, !items.isEmpty else { return }
        let menu = NSMenu()
        let target = ContextMenuTarget(items: items)
        menuTarget = target
        for (index, item) in items.enumerated() {
            let menuItem = NSMenuItem(
                title: item.title,
                action: #selector(ContextMenuTarget.invoke(_:)),
                keyEquivalent: ""
            )
            menuItem.target = target
            menuItem.tag = index
            menu.addItem(menuItem)
        }
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        } else {
            let point = view.convert(view.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
            menu.popUp(positioning: nil, at: point, in: view)
        }
    }

    func resetTransientMotion() {
        motion.squashScale = CGSize(width: 1, height: 1)
        motion.peekOffset = .zero
        motion.tiltDegrees = 0
        motion.spinDegrees = 0
        isBobPaused = false
        bobAmplitude = CompanionLayout.defaultBobAmplitude
    }

    private func upsert<Value>(
        _ claims: inout [PlayClaim<Value>],
        value: Value,
        priority: CompanionMoodPriority,
        owner: String,
        duration: TimeInterval?
    ) {
        claims.removeAll { $0.owner == owner }
        claims.append(
            PlayClaim(
                owner: owner,
                value: value,
                priority: priority,
                expiresAt: duration.map { Date().addingTimeInterval($0) }
            )
        )
    }

    private func pruneExpiredClaims() {
        let now = Date()
        moodClaims.removeAll { $0.isExpired(at: now) }
        bubbleClaims.removeAll { $0.isExpired(at: now) }
    }

    private func resolvePresentation() {
        pruneExpiredClaims()
        mood = winning(moodClaims)?.value ?? .idle
        if let bubble = winning(bubbleClaims)?.value {
            bubbleText = bubble
        } else {
            bubbleText = isChatPresented ? "Let's talk" : "Chat with me"
        }
    }

    private func winning<Value>(_ claims: [PlayClaim<Value>]) -> PlayClaim<Value>? {
        claims.enumerated().max { lhs, rhs in
            if lhs.element.priority != rhs.element.priority {
                return lhs.element.priority < rhs.element.priority
            }
            return lhs.offset < rhs.offset
        }?.element
    }
}

private struct PlayClaim<Value> {
    let owner: String
    let value: Value
    let priority: CompanionMoodPriority
    let expiresAt: Date?

    func isExpired(at date: Date) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= date
    }
}

private final class ContextMenuTarget: NSObject {
    private let items: [CompanionPlayMenuItem]

    init(items: [CompanionPlayMenuItem]) {
        self.items = items
    }

    @objc func invoke(_ sender: NSMenuItem) {
        guard items.indices.contains(sender.tag) else { return }
        items[sender.tag].action()
    }
}
