import Foundation

/// Sprite swaps for hover, drag, drop, first chat, and Wave hello.
@MainActor
final class CompanionMoodDirector: CompanionPlayDirector {
    private let owner = "mood"

    func handle(_ event: CompanionPlayEvent, play: CompanionPlay) {
        switch event {
        case .hovered:
            play.setMood(.thinking, priority: .interaction, owner: owner)
        case .unhovered:
            if !play.isDragging {
                play.clearMood(owner: owner)
            }
        case .dragBegan:
            play.setMood(.thinking, priority: .interaction, owner: owner)
        case .dragEnded(let didMove):
            if didMove {
                play.setMood(.celebrating, priority: .transient, owner: owner, duration: 1.2)
            } else if !play.isHovered {
                play.clearMood(owner: owner)
            }
        case .chatOpened:
            play.setMood(.celebrating, priority: .transient, owner: owner, duration: 1.4)
        case .waveHello:
            play.setMood(.confused, priority: .transient, owner: owner, duration: 1.5)
            play.setBubble("Hello!", priority: .transient, owner: owner, duration: 1.5)
        case .personaChanged, .tucked:
            play.clearMood(owner: owner)
            play.clearBubble(owner: owner)
        default:
            break
        }
    }
}
