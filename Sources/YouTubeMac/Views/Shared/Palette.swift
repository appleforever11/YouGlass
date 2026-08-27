import SwiftUI

struct Palette {
    let isDark: Bool
    let theme: YouGlassThemeFamily
    let customization: YouGlassThemeCustomization
    private let colors: YouGlassThemeColors

    init(
        _ scheme: ColorScheme,
        theme: YouGlassThemeFamily = .neoCitrus,
        customization: YouGlassThemeCustomization = .empty
    ) {
        isDark = scheme == .dark
        self.theme = theme
        self.customization = customization
        colors = theme.colors(isDark: scheme == .dark)
    }

    var window: Color { colors.window }
    var sidebar: Color { colors.sidebar }
    var content: Color { colors.content }
    var card: Color { colors.card }
    var queueCard: Color { isDark ? Color.white.opacity(0.034) : .white.opacity(0.60) }
    var search: Color { isDark ? Color.white.opacity(0.055) : Color.black.opacity(0.028) }
    var selected: Color { customization.accentColor ?? colors.selected }
    var pill: Color { isDark ? Color.white.opacity(0.042) : .white.opacity(0.64) }
    var stroke: Color { colors.stroke }
    var hairline: Color { isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.07) }
    var text: Color { colors.text }
    var secondaryText: Color { colors.secondaryText }
    var tertiaryText: Color { colors.tertiaryText }
    var pink: Color { customization.accentColor ?? colors.primary }
    var purple: Color { colors.secondary }
    var violet: Color { colors.tertiary }
    var accent: Color { customization.accentColor ?? colors.accent }
    var playButton: Color { isDark ? .white : .white }
    var playText: Color { .black }
}
