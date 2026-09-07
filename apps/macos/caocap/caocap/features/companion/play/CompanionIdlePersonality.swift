import Foundation

/// Occasional greeting bubble, then a sleepy tuck after sitting still.
@MainActor
final class CompanionIdlePersonality: CompanionPlayDirector {
    private let owner = "idle"
    private var lastInteraction = Date()
    private var didWaveThisIdle = false
    private var isSleepy = false

    func handle(_ event: CompanionPlayEvent, play: CompanionPlay) {
        switch event {
        case .hovered, .unhovered, .dragBegan, .dragEnded, .tapped, .doubleTapped, .rightClicked,
             .chatOpened, .chatClosed, .personaChanged, .waveHello, .woke, .tucked:
            resetIdle(play: play)
        case .idleTick:
            tick(play: play)
        }
    }

    private func resetIdle(play: CompanionPlay) {
        lastInteraction = Date()
        didWaveThisIdle = false
        isSleepy = false
        play.clearBubble(owner: owner)
        if !play.isBobPaused {
            play.bobAmplitude = CompanionLayout.defaultBobAmplitude
        }
    }

    private func tick(play: CompanionPlay) {
        guard play.isAwake else { return }
        if play.isChatPresented || play.isDragging || play.isHovered {
            if isSleepy {
                isSleepy = false
                play.clearBubble(owner: owner)
                if !play.isBobPaused {
                    play.bobAmplitude = CompanionLayout.defaultBobAmplitude
                }
            }
            return
        }

        let elapsed = Date().timeIntervalSince(lastInteraction)
        if elapsed >= 45 {
            isSleepy = true
            play.setBubble("zzz", priority: .idle, owner: owner)
            if play.allowsMotion, !play.isBobPaused {
                play.bobAmplitude = CompanionLayout.sleepyBobAmplitude
            }
        } else if elapsed >= 20, !didWaveThisIdle {
            didWaveThisIdle = true
            let greeting = play.persona == .costar ? "Hi!" : "Hey!"
            play.setBubble(greeting, priority: .idle, owner: owner, duration: 3)
        }
    }
}
