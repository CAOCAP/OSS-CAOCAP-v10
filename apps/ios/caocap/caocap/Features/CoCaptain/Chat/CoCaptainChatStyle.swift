import SwiftUI

/// Feature-local visual tokens for the CoCaptain conversation surfaces.
///
/// Keeping these values together makes the chat sheet feel like one product
/// while avoiding a second app-wide design system.
enum CoCaptainChatStyle {
    static let compactSpacing: CGFloat = 4
    static let smallSpacing: CGFloat = 8
    static let standardSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 16
    static let largeSpacing: CGFloat = 24

    static let messageCornerRadius: CGFloat = 18
    static let cardCornerRadius: CGFloat = 16
    static let composerCornerRadius: CGFloat = 22
    static let readableWidth: CGFloat = 640
    static let compactControlSize: CGFloat = 36
    static let minimumHitSize: CGFloat = 44

    static let subtleFill = Color.primary.opacity(0.045)
    static let raisedFill = Color.primary.opacity(0.065)
    static let subtleStroke = Color.primary.opacity(0.08)
    static let userMessageFill = Color.accentColor.opacity(0.16)
    static let userMessageStroke = Color.accentColor.opacity(0.22)
    static let mentionTint = Color.accentColor
    static let codeFill = Color.primary.opacity(0.07)
    static let pending = Color.orange
    static let success = Color.green

    /// Vertical gap between consecutive messages from the same speaker.
    static let groupedMessageSpacing: CGFloat = 6
}

private struct CoCaptainCardSurface: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(0.065))
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

extension View {
    func coCaptainCardSurface(
        tint: Color = .primary,
        cornerRadius: CGFloat = CoCaptainChatStyle.cardCornerRadius
    ) -> some View {
        modifier(CoCaptainCardSurface(tint: tint, cornerRadius: cornerRadius))
    }
}
