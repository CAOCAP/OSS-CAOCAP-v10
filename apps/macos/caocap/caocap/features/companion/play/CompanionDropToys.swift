import Foundation
import SwiftUI

/// Double-tap spin, right-click toys, and a one-shot first-chat confetti burst.
@MainActor
final class CompanionDropToys: CompanionPlayDirector {
    private var spinTask: Task<Void, Never>?

    func handle(_ event: CompanionPlayEvent, play: CompanionPlay) {
        switch event {
        case .doubleTapped:
            spin(play: play)
        case .rightClicked:
            presentMenu(play: play)
        case .chatOpened:
            celebrateFirstChatIfNeeded(play: play)
        case .personaChanged:
            spinTask?.cancel()
            play.motion.spinDegrees = 0
        default:
            break
        }
    }

    private func presentMenu(play: CompanionPlay) {
        play.presentContextMenu([
            CompanionPlayMenuItem(title: "Spin") { [weak self] in
                self?.spin(play: play)
            },
            CompanionPlayMenuItem(title: "Wave hello") {
                play.dispatch(.waveHello)
            },
        ])
    }

    private func spin(play: CompanionPlay) {
        guard play.allowsMotion else { return }
        spinTask?.cancel()
        play.motion.spinDegrees = 0
        withAnimation(.easeInOut(duration: 0.55)) {
            play.motion.spinDegrees = 360
        }
        spinTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(560))
            guard !Task.isCancelled else { return }
            withTransaction(Transaction(animation: nil)) {
                play.motion.spinDegrees = 0
            }
        }
    }

    private func celebrateFirstChatIfNeeded(play: CompanionPlay) {
        let key = CompanionDefaults.didCelebrateChat(for: play.persona)
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard play.allowsMotion else { return }
        play.confettiToken = UUID()
    }
}
