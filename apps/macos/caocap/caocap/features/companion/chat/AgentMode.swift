import Foundation

/// The macOS mirror of iOS's `CoCaptainChatMode`. Same three modes and the same contract — Ask
/// and Plan are prose-only, Agent is the one that acts — but "acting" here means driving a real
/// app on the desktop through computer-use rather than editing a canvas.
enum AgentMode: String, CaseIterable, Identifiable, Codable {
    case ask
    case plan
    case agent

    var id: String { rawValue }

    /// UserDefaults key for the last chosen mode.
    static let storageKey = "caocap.agentMode"

    var displayName: String {
        switch self {
        case .ask: return "Ask"
        case .plan: return "Plan"
        case .agent: return "Agent"
        }
    }

    var systemImageName: String {
        switch self {
        case .ask: return "bubble.left"
        case .plan: return "list.bullet.rectangle"
        case .agent: return "sparkles"
        }
    }

    var explanation: String {
        switch self {
        case .ask: return "Answers questions without touching your Mac"
        case .plan: return "Writes a step-by-step plan without running it"
        case .agent: return "Operates TextEdit on your Mac to do the work"
        }
    }

    func composerPlaceholder(personaName: String) -> String {
        switch self {
        case .ask: return "Ask \(personaName)…"
        case .plan: return "What should \(personaName) plan?"
        case .agent: return "What should \(personaName) do on your Mac?"
        }
    }

    /// True when the mode must not operate the desktop.
    var isProseOnly: Bool {
        switch self {
        case .ask, .plan: return true
        case .agent: return false
        }
    }

    /// Prepended to the user's message for prose modes. Agent mode doesn't use the chat model at
    /// all — its instructions live server-side in the `computerUseStep` function.
    var promptInstructions: String? {
        switch self {
        case .agent:
            return nil
        case .ask:
            return """
            Ask mode objective:
            - Answer with helpful, friendly prose only.
            - Do not claim to have opened, changed, or operated anything on the user's Mac.
            - If the request needs work done on the Mac, say so and suggest switching to Agent mode.
            - Match the language used by the user.
            """
        case .plan:
            return """
            Plan mode objective:
            - Outline a clear, beginner-friendly plan for the work the user is asking about.
            - Prefer a short numbered list of concrete steps (usually 3 to 7).
            - Explain the approach and the order of work; do not carry the work out.
            - Do not claim to have opened, changed, or operated anything on the user's Mac.
            - Match the language used by the user.
            """
        }
    }
}
