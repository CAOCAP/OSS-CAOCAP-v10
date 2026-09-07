import SwiftUI

/// Stretch while dragging, then spring back on drop.
@MainActor
final class CompanionSquashBounce: CompanionPlayDirector {
    func handle(_ event: CompanionPlayEvent, play: CompanionPlay) {
        switch event {
        case .dragBegan:
            play.isBobPaused = true
            guard play.allowsMotion else {
                play.motion.squashScale = CGSize(width: 1, height: 1)
                return
            }
            withAnimation(.easeOut(duration: 0.12)) {
                play.motion.squashScale = CGSize(width: 1.12, height: 0.90)
            }
        case .dragEnded:
            play.isBobPaused = false
            guard play.allowsMotion else {
                play.motion.squashScale = CGSize(width: 1, height: 1)
                return
            }
            withAnimation(.spring(duration: 0.45, bounce: 0.38)) {
                play.motion.squashScale = CGSize(width: 1, height: 1)
            }
        case .personaChanged:
            play.isBobPaused = false
            play.motion.squashScale = CGSize(width: 1, height: 1)
        default:
            break
        }
    }
}
