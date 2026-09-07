import SwiftUI

/// Tiny burst of capsules above the pet. Driven by a one-shot token.
struct CompanionConfetti: View {
    let token: UUID
    let accent: Color
    var onFinished: () -> Void

    @State private var risen = false

    private var particles: [Particle] {
        let seed = token.hashValue
        return (0..<12).map { index in
            let scramble = seed &* (index + 3) &* 17
            let x = CGFloat((scramble % 90) - 45)
            let drift = CGFloat((scramble % 50) - 25)
            let size = CGFloat(4 + (abs(scramble) % 4))
            let palette: [Color] = [
                accent,
                Color(red: 1, green: 0.78, blue: 0.24),
                Color(red: 0.76, green: 0.38, blue: 0.42),
                .white,
            ]
            return Particle(
                id: index,
                x: x,
                drift: drift,
                size: size,
                color: palette[abs(scramble) % palette.count]
            )
        }
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Capsule()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 2.4)
                    .offset(
                        x: particle.x + (risen ? particle.drift : 0),
                        y: risen ? -96 : 8
                    )
                    .rotationEffect(.degrees(risen ? Double(particle.drift) * 3 : 0))
                    .opacity(risen ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: burst)
        .onChange(of: token) { _, _ in
            risen = false
            burst()
        }
    }

    private func burst() {
        withAnimation(.easeOut(duration: 0.85)) {
            risen = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            onFinished()
        }
    }

    private struct Particle: Identifiable {
        let id: Int
        let x: CGFloat
        let drift: CGFloat
        let size: CGFloat
        let color: Color
    }
}
