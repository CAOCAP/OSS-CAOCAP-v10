import SwiftUI

/// Desktop agent and chat affordance. Drag is handled by AppKit.
struct CompanionView: View {
    @Bindable var controller: CompanionController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bobOffset: CGFloat = 0

    private var play: CompanionPlay { controller.play }

    private var accent: Color {
        controller.persona == .cocaptain
            ? Color(red: 0.12, green: 0.53, blue: 0.76)
            : Color(red: 0.57, green: 0.39, blue: 0.81)
    }

    var body: some View {
        ZStack(alignment: .center) {
            if let token = play.confettiToken, play.allowsMotion {
                CompanionConfetti(token: token, accent: accent) {
                    play.confettiToken = nil
                }
            }

            VStack(alignment: .center, spacing: 6) {
                Text(play.bubbleText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())

                Image(controller.persona.imageName(for: play.mood))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: CompanionLayout.spriteSize, height: CompanionLayout.spriteSize)
                    .scaleEffect(x: play.motion.squashScale.width, y: play.motion.squashScale.height)
                    .rotationEffect(.degrees(play.motion.tiltDegrees + play.motion.spinDegrees))
                    .offset(
                        x: play.motion.peekOffset.width,
                        y: play.motion.peekOffset.height + visibleBob
                    )
                    .accessibilityLabel(controller.persona.displayName)
            }
        }
        .padding(8)
        .frame(
            width: CompanionLayout.panelSize.width,
            height: CompanionLayout.panelSize.height
        )
        .animation(play.allowsMotion ? .easeOut(duration: 0.16) : nil, value: play.motion.peekOffset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chat with \(controller.persona.displayName)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { controller.toggleChat() }
        .onAppear {
            play.allowsMotion = !reduceMotion
            startIdleMotion()
        }
        .onChange(of: reduceMotion) { _, reduced in
            play.allowsMotion = !reduced
            if reduced {
                play.resetTransientMotion()
                stopBob()
            } else if !play.isBobPaused {
                startIdleMotion()
            }
        }
        .onChange(of: play.isBobPaused) { _, paused in
            if paused || reduceMotion {
                stopBob()
            } else {
                startIdleMotion()
            }
        }
        .onChange(of: play.bobAmplitude) { _, _ in
            if play.allowsMotion, !play.isBobPaused {
                startIdleMotion()
            }
        }
        .onChange(of: play.allowsMotion) { _, allowed in
            if !allowed {
                stopBob()
            } else if !play.isBobPaused {
                startIdleMotion()
            }
        }
    }

    private var visibleBob: CGFloat {
        play.isBobPaused || !play.allowsMotion ? 0 : bobOffset
    }

    private func startIdleMotion() {
        guard play.allowsMotion, !play.isBobPaused else {
            stopBob()
            return
        }
        withTransaction(Transaction(animation: nil)) {
            bobOffset = 0
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            bobOffset = -play.bobAmplitude
        }
    }

    private func stopBob() {
        withTransaction(Transaction(animation: nil)) {
            bobOffset = 0
        }
    }
}
