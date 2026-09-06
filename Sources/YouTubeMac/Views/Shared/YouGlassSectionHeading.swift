import SwiftUI

/// A consistent, quiet hierarchy that leaves the artwork as the focal point.
struct YouGlassSectionHeading: View {
    let title: String
    let subtitle: String
    let palette: Palette
    var count: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                if let count {
                    Text(count.formatted())
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(palette.secondaryText)
                }
            }
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct YouGlassEmptyState: View {
    let title: String
    let message: String
    let symbol: String
    let palette: Palette
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 58, height: 58)
                .background(palette.selected.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.text)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .fixedSize(horizontal: false, vertical: true)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(palette.accent)
                .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 240)
        .accessibilityElement(children: .contain)
    }
}
