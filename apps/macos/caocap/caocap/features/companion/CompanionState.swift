import AppKit
import Foundation

/// Visual mood for the desktop companion sprite.
enum CompanionMood: String, Equatable {
    case idle
    case thinking
    case celebrating
    case confused
}

/// Desktop companion character. Persisted locally; not a product requirement.
enum CompanionPersona: String, CaseIterable, Identifiable, Equatable {
    case cocaptain
    case costar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cocaptain: return "CoCaptain"
        case .costar: return "CoStar"
        }
    }

    var idleImageName: String {
        imageName(for: .idle)
    }

    func imageName(for mood: CompanionMood) -> String {
        switch (self, mood) {
        case (.cocaptain, .idle): return "CoCaptainIdle"
        case (.cocaptain, .thinking): return "CoCaptainThinking"
        case (.cocaptain, .celebrating): return "CoCaptainCelebrating"
        case (.cocaptain, .confused): return "CoCaptainConfused"
        case (.costar, .idle): return "CoStarIdle"
        case (.costar, .thinking): return "CoStarThinking"
        case (.costar, .celebrating): return "CoStarCelebrating"
        case (.costar, .confused): return "CoStarThinking"
        }
    }
}

enum CompanionLayout {
    static let spriteSize: CGFloat = 112
    static let panelSize = NSSize(width: 184, height: 220)
    static let screenInset: CGFloat = 24
    static let clickSlop: CGFloat = 8
    static let peekReach: CGFloat = 120
    static let maxPeek: CGFloat = 14
    static let defaultBobAmplitude: CGFloat = 3
    static let sleepyBobAmplitude: CGFloat = 1.2
}

enum CompanionDefaults {
    static let isAwake = "companion.isAwake"
    static let originX = "companion.originX"
    static let originY = "companion.originY"
    static let persona = "companion.persona"

    static func didCelebrateChat(for persona: CompanionPersona) -> String {
        "companion.didCelebrateChat.\(persona.rawValue)"
    }
}
