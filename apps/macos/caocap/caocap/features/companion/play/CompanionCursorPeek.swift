import CoreGraphics
import Foundation

/// Lean the pet toward a nearby pointer without stealing clicks.
@MainActor
final class CompanionCursorPeek: CompanionPlayDirector {
    func handle(_ event: CompanionPlayEvent, play: CompanionPlay) {
        switch event {
        case .idleTick, .dragBegan, .dragEnded, .personaChanged, .unhovered, .tucked, .woke:
            updatePeek(play: play)
        default:
            break
        }
    }

    private func updatePeek(play: CompanionPlay) {
        guard play.allowsMotion, play.isAwake, !play.isDragging else {
            play.motion.peekOffset = .zero
            return
        }

        let frame = play.agentFrame
        guard !frame.isEmpty else {
            play.motion.peekOffset = .zero
            return
        }

        let pointer = play.pointerLocation
        if frame.contains(pointer) {
            play.motion.peekOffset = .zero
            return
        }

        let dx = pointer.x - frame.midX
        let dy = pointer.y - frame.midY
        let distance = hypot(dx, dy)
        guard distance > 1, distance <= CompanionLayout.peekReach else {
            play.motion.peekOffset = .zero
            return
        }

        let closeness = 1 - (distance / CompanionLayout.peekReach)
        let lean = 8 + (CompanionLayout.maxPeek - 8) * closeness
        play.motion.peekOffset = CGSize(
            width: (dx / distance) * lean,
            height: (dy / distance) * lean
        )
    }
}
