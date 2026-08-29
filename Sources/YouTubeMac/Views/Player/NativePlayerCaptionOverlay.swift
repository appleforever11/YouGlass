import SwiftUI

struct NativePlayerCaptionOverlay: View {
    let text: String
    let bottomInset: CGFloat
    let isCompact: Bool

    var body: some View {
        let hasCaptionText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return ZStack(alignment: .bottom) {
            Text(text)
                .font(.system(size: isCompact ? 16 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .lineSpacing(2)
                .padding(.horizontal, isCompact ? 10 : 16)
                .padding(.vertical, isCompact ? 5 : 7)
                .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.86), radius: 4, y: 2)
                .frame(maxWidth: isCompact ? 520 : 980)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, isCompact ? 18 : 72)
                .opacity(hasCaptionText ? 1 : 0)
                .accessibilityHidden(!hasCaptionText)
                .accessibilityIdentifier("player-caption-text")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, bottomInset)
        .animation(
            .easeOut(duration: PlayerTransportLayout.normalControlTransitionDuration),
            value: bottomInset
        )
        .allowsHitTesting(false)
        .zIndex(isCompact ? 3 : 40)
    }
}
