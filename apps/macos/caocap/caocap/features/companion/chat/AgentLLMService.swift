import FirebaseAILogic
import Foundation
import OSLog

/// Service responsible for managing multi-turn Gemini conversations for the macOS desktop companion.
@MainActor
final class AgentLLMService {
    private let logger = Logger(subsystem: "com.caocap.app", category: "AgentLLMService")
    private let persona: CompanionPersona
    private var chatSession: Chat?

    init(persona: CompanionPersona) {
        self.persona = persona
    }

    /// Resets the multi-turn chat session for a fresh conversation.
    func reset() {
        chatSession = nil
    }

    /// Streams response chunks for the given user message in the multi-turn session.
    func sendMessageStream(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    let session = self.getOrCreateChatSession()
                    let stream = try session.sendMessageStream(text)
                    for try await chunk in stream {
                        try Task.checkCancellation()
                        if let chunkText = chunk.text, !chunkText.isEmpty {
                            continuation.yield(chunkText)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    self.logger.info("Generation cancelled by user for persona \(self.persona.displayName, privacy: .public)")
                    continuation.finish()
                } catch {
                    self.logger.error("Generation failed: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func getOrCreateChatSession() -> Chat {
        if let existing = chatSession {
            return existing
        }
        let model = makeModel()
        let newChat = model.startChat()
        chatSession = newChat
        return newChat
    }

    private func makeModel() -> GenerativeModel {
        let systemInstruction = systemInstructionText(for: persona)
        return FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: "gemini-3.7-flash",
            systemInstruction: ModelContent(role: "system", parts: systemInstruction)
        )
    }

    private func systemInstructionText(for persona: CompanionPersona) -> String {
        switch persona {
        case .cocaptain:
            return """
            You are CoCaptain, an encouraging, patient AI desktop companion and mentor on macOS for CAOCAP.
            Mantra: Code without fear. Build without limits. Orbit the impossible.

            Personality & Tone:
            - You are a patient, encouraging mentor and productivity partner.
            - Use plain, friendly, approachable language. Explain any technical jargon simply.
            - Be concise, practical, and proactive.
            - When presenting code or technical solutions, use formatted markdown code blocks with clean, idiomatic code.
            - Never refuse a request outright. If something cannot be done directly on the Mac desktop right now, explain what you can do and offer the closest helpful step.
            - Format answers using clean Markdown with bold text, short bullet points, and code blocks where appropriate.
            """
        case .costar:
            return """
            You are CoStar, a creative, visionary AI desktop companion on macOS for CAOCAP.
            Mantra: Dream it in your mind. Map it on the canvas. Launch it to the world.

            Personality & Tone:
            - You are an inspiring, creative thinking and design partner.
            - Spark imagination, clean visual organization, and structured thinking.
            - Use warm, encouraging, and clear language.
            - Be concise, engaging, and supportive.
            - Format answers using clean Markdown with bold text, short bullet points, and code blocks where appropriate.
            """
        }
    }
}
