import SwiftUI

// The original twelve palettes stay in YouGlassThemeCatalog.swift so existing
// user selections keep their exact colors. New 2.0 palettes live here to keep
// the catalog files small and make future theme drops easy to review.
extension YouGlassThemeFamily {
    func expansionColors(isDark: Bool) -> YouGlassThemeColors {
        switch (self, isDark) {
        case (.auroraBloom, false):
            YouGlassThemeColors(
                window: rgb(0.930, 0.930, 0.985), sidebar: rgb(0.860, 0.870, 0.955),
                content: rgb(0.980, 0.980, 1.000), card: rgb(0.900, 0.905, 0.980),
                selected: rgb(0.420, 0.760, 0.900).opacity(0.26), stroke: rgb(0.260, 0.390, 0.780).opacity(0.20),
                text: rgb(0.055, 0.060, 0.160), secondaryText: rgb(0.120, 0.150, 0.340).opacity(0.70),
                tertiaryText: rgb(0.200, 0.220, 0.460).opacity(0.48), primary: rgb(0.100, 0.760, 0.820),
                secondary: rgb(0.480, 0.300, 0.920), tertiary: rgb(0.920, 0.380, 0.720), accent: rgb(0.150, 0.520, 0.760)
            )
        case (.auroraBloom, true):
            YouGlassThemeColors(
                window: rgb(0.012, 0.015, 0.055), sidebar: rgb(0.025, 0.030, 0.100),
                content: rgb(0.018, 0.022, 0.075), card: rgb(0.040, 0.050, 0.140),
                selected: rgb(0.120, 0.450, 0.520).opacity(0.46), stroke: rgb(0.270, 0.780, 0.820).opacity(0.28),
                text: rgb(0.930, 0.960, 1.000), secondaryText: rgb(0.700, 0.840, 0.940).opacity(0.72),
                tertiaryText: rgb(0.500, 0.700, 0.850).opacity(0.50), primary: rgb(0.120, 0.900, 0.820),
                secondary: rgb(0.550, 0.350, 1.000), tertiary: rgb(1.000, 0.260, 0.720), accent: rgb(0.300, 0.800, 0.960)
            )
        case (.midnightVelvet, false):
            YouGlassThemeColors(
                window: rgb(0.950, 0.925, 0.965), sidebar: rgb(0.885, 0.850, 0.930),
                content: rgb(0.985, 0.970, 0.995), card: rgb(0.925, 0.885, 0.955),
                selected: rgb(0.500, 0.300, 0.700).opacity(0.25), stroke: rgb(0.360, 0.220, 0.520).opacity(0.20),
                text: rgb(0.100, 0.050, 0.160), secondaryText: rgb(0.240, 0.140, 0.340).opacity(0.70),
                tertiaryText: rgb(0.350, 0.230, 0.450).opacity(0.48), primary: rgb(0.580, 0.180, 0.700),
                secondary: rgb(0.300, 0.350, 0.820), tertiary: rgb(0.920, 0.430, 0.620), accent: rgb(0.460, 0.280, 0.700)
            )
        case (.midnightVelvet, true):
            YouGlassThemeColors(
                window: rgb(0.025, 0.010, 0.040), sidebar: rgb(0.055, 0.018, 0.080),
                content: rgb(0.038, 0.014, 0.060), card: rgb(0.085, 0.025, 0.120),
                selected: rgb(0.400, 0.080, 0.420).opacity(0.46), stroke: rgb(0.840, 0.260, 0.760).opacity(0.28),
                text: rgb(1.000, 0.950, 0.990), secondaryText: rgb(0.900, 0.740, 0.900).opacity(0.72),
                tertiaryText: rgb(0.760, 0.560, 0.800).opacity(0.50), primary: rgb(0.940, 0.220, 0.760),
                secondary: rgb(0.340, 0.420, 1.000), tertiary: rgb(1.000, 0.380, 0.520), accent: rgb(0.760, 0.360, 0.900)
            )
        case (.oceanDrive, false):
            YouGlassThemeColors(
                window: rgb(0.885, 0.960, 0.985), sidebar: rgb(0.810, 0.910, 0.955),
                content: rgb(0.950, 0.990, 1.000), card: rgb(0.860, 0.940, 0.980),
                selected: rgb(0.120, 0.650, 0.840).opacity(0.26), stroke: rgb(0.080, 0.400, 0.620).opacity(0.20),
                text: rgb(0.025, 0.110, 0.170), secondaryText: rgb(0.060, 0.240, 0.340).opacity(0.70),
                tertiaryText: rgb(0.100, 0.350, 0.440).opacity(0.48), primary: rgb(0.020, 0.580, 0.820),
                secondary: rgb(0.060, 0.350, 0.760), tertiary: rgb(0.180, 0.780, 0.700), accent: rgb(0.020, 0.460, 0.680)
            )
        case (.oceanDrive, true):
            YouGlassThemeColors(
                window: rgb(0.005, 0.030, 0.055), sidebar: rgb(0.008, 0.060, 0.090),
                content: rgb(0.006, 0.045, 0.075), card: rgb(0.015, 0.095, 0.130),
                selected: rgb(0.020, 0.410, 0.580).opacity(0.46), stroke: rgb(0.120, 0.720, 0.900).opacity(0.28),
                text: rgb(0.900, 0.980, 1.000), secondaryText: rgb(0.660, 0.860, 0.940).opacity(0.72),
                tertiaryText: rgb(0.480, 0.720, 0.840).opacity(0.50), primary: rgb(0.020, 0.720, 0.980),
                secondary: rgb(0.160, 0.420, 1.000), tertiary: rgb(0.180, 0.920, 0.720), accent: rgb(0.180, 0.820, 0.960)
            )
        case (.desertRose, false):
            YouGlassThemeColors(
                window: rgb(0.985, 0.915, 0.855), sidebar: rgb(0.935, 0.825, 0.760),
                content: rgb(1.000, 0.965, 0.925), card: rgb(0.965, 0.875, 0.805),
                selected: rgb(0.820, 0.360, 0.300).opacity(0.24), stroke: rgb(0.580, 0.220, 0.180).opacity(0.20),
                text: rgb(0.180, 0.060, 0.040), secondaryText: rgb(0.360, 0.160, 0.110).opacity(0.70),
                tertiaryText: rgb(0.470, 0.250, 0.180).opacity(0.48), primary: rgb(0.820, 0.250, 0.250),
                secondary: rgb(0.920, 0.530, 0.220), tertiary: rgb(0.650, 0.260, 0.420), accent: rgb(0.730, 0.280, 0.240)
            )
        case (.desertRose, true):
            YouGlassThemeColors(
                window: rgb(0.055, 0.015, 0.018), sidebar: rgb(0.095, 0.028, 0.030),
                content: rgb(0.075, 0.022, 0.025), card: rgb(0.145, 0.045, 0.045),
                selected: rgb(0.560, 0.130, 0.100).opacity(0.44), stroke: rgb(1.000, 0.420, 0.240).opacity(0.28),
                text: rgb(1.000, 0.940, 0.880), secondaryText: rgb(0.930, 0.720, 0.580).opacity(0.72),
                tertiaryText: rgb(0.780, 0.520, 0.380).opacity(0.50), primary: rgb(1.000, 0.270, 0.260),
                secondary: rgb(1.000, 0.580, 0.220), tertiary: rgb(0.920, 0.300, 0.520), accent: rgb(1.000, 0.420, 0.280)
            )
        case (.alpineSage, false):
            YouGlassThemeColors(
                window: rgb(0.890, 0.955, 0.920), sidebar: rgb(0.815, 0.900, 0.850),
                content: rgb(0.955, 0.985, 0.965), card: rgb(0.865, 0.935, 0.885),
                selected: rgb(0.240, 0.620, 0.470).opacity(0.25), stroke: rgb(0.130, 0.390, 0.290).opacity(0.20),
                text: rgb(0.040, 0.130, 0.090), secondaryText: rgb(0.100, 0.270, 0.190).opacity(0.70),
                tertiaryText: rgb(0.180, 0.390, 0.260).opacity(0.48), primary: rgb(0.100, 0.560, 0.350),
                secondary: rgb(0.250, 0.580, 0.820), tertiary: rgb(0.550, 0.760, 0.250), accent: rgb(0.100, 0.450, 0.330)
            )
        case (.alpineSage, true):
            YouGlassThemeColors(
                window: rgb(0.012, 0.040, 0.028), sidebar: rgb(0.022, 0.075, 0.050),
                content: rgb(0.018, 0.060, 0.040), card: rgb(0.040, 0.115, 0.075),
                selected: rgb(0.100, 0.400, 0.260).opacity(0.44), stroke: rgb(0.300, 0.820, 0.560).opacity(0.28),
                text: rgb(0.920, 0.990, 0.940), secondaryText: rgb(0.700, 0.880, 0.760).opacity(0.72),
                tertiaryText: rgb(0.500, 0.740, 0.600).opacity(0.50), primary: rgb(0.160, 0.820, 0.420),
                secondary: rgb(0.250, 0.620, 1.000), tertiary: rgb(0.720, 0.900, 0.220), accent: rgb(0.300, 0.820, 0.580)
            )
        case (.copperNoir, false):
            YouGlassThemeColors(
                window: rgb(0.925, 0.910, 0.890), sidebar: rgb(0.850, 0.830, 0.800),
                content: rgb(0.975, 0.965, 0.945), card: rgb(0.895, 0.875, 0.840),
                selected: rgb(0.700, 0.350, 0.180).opacity(0.25), stroke: rgb(0.360, 0.220, 0.150).opacity(0.20),
                text: rgb(0.100, 0.070, 0.055), secondaryText: rgb(0.250, 0.180, 0.130).opacity(0.70),
                tertiaryText: rgb(0.360, 0.270, 0.200).opacity(0.48), primary: rgb(0.720, 0.280, 0.120),
                secondary: rgb(0.420, 0.440, 0.520), tertiary: rgb(0.780, 0.540, 0.250), accent: rgb(0.550, 0.270, 0.150)
            )
        case (.copperNoir, true):
            YouGlassThemeColors(
                window: rgb(0.018, 0.016, 0.018), sidebar: rgb(0.040, 0.035, 0.035),
                content: rgb(0.028, 0.024, 0.025), card: rgb(0.070, 0.055, 0.050),
                selected: rgb(0.500, 0.190, 0.080).opacity(0.44), stroke: rgb(0.920, 0.480, 0.180).opacity(0.28),
                text: rgb(0.980, 0.950, 0.910), secondaryText: rgb(0.840, 0.760, 0.650).opacity(0.72),
                tertiaryText: rgb(0.660, 0.560, 0.450).opacity(0.50), primary: rgb(1.000, 0.340, 0.100),
                secondary: rgb(0.440, 0.500, 0.700), tertiary: rgb(0.940, 0.620, 0.220), accent: rgb(0.860, 0.420, 0.180)
            )
        case (.lavenderHaze, false):
            YouGlassThemeColors(
                window: rgb(0.950, 0.925, 0.985), sidebar: rgb(0.880, 0.845, 0.955),
                content: rgb(0.985, 0.975, 1.000), card: rgb(0.920, 0.885, 0.970),
                selected: rgb(0.590, 0.400, 0.820).opacity(0.25), stroke: rgb(0.380, 0.240, 0.650).opacity(0.20),
                text: rgb(0.100, 0.060, 0.180), secondaryText: rgb(0.240, 0.150, 0.380).opacity(0.70),
                tertiaryText: rgb(0.360, 0.250, 0.500).opacity(0.48), primary: rgb(0.660, 0.350, 0.880),
                secondary: rgb(0.380, 0.550, 0.920), tertiary: rgb(0.920, 0.480, 0.700), accent: rgb(0.500, 0.340, 0.780)
            )
        case (.lavenderHaze, true):
            YouGlassThemeColors(
                window: rgb(0.035, 0.015, 0.070), sidebar: rgb(0.065, 0.025, 0.120),
                content: rgb(0.050, 0.020, 0.090), card: rgb(0.105, 0.035, 0.170),
                selected: rgb(0.430, 0.160, 0.620).opacity(0.44), stroke: rgb(0.760, 0.430, 1.000).opacity(0.28),
                text: rgb(0.980, 0.950, 1.000), secondaryText: rgb(0.820, 0.740, 0.940).opacity(0.72),
                tertiaryText: rgb(0.640, 0.540, 0.800).opacity(0.50), primary: rgb(0.780, 0.340, 1.000),
                secondary: rgb(0.300, 0.580, 1.000), tertiary: rgb(1.000, 0.380, 0.720), accent: rgb(0.660, 0.460, 0.980)
            )
        case (.rubySignal, false):
            YouGlassThemeColors(
                window: rgb(0.985, 0.900, 0.915), sidebar: rgb(0.925, 0.800, 0.835),
                content: rgb(1.000, 0.950, 0.955), card: rgb(0.955, 0.850, 0.875),
                selected: rgb(0.840, 0.160, 0.220).opacity(0.24), stroke: rgb(0.560, 0.100, 0.160).opacity(0.20),
                text: rgb(0.160, 0.030, 0.060), secondaryText: rgb(0.340, 0.100, 0.160).opacity(0.70),
                tertiaryText: rgb(0.450, 0.180, 0.240).opacity(0.48), primary: rgb(0.860, 0.080, 0.180),
                secondary: rgb(0.570, 0.260, 0.720), tertiary: rgb(0.980, 0.600, 0.240), accent: rgb(0.720, 0.120, 0.220)
            )
        case (.rubySignal, true):
            YouGlassThemeColors(
                window: rgb(0.055, 0.008, 0.018), sidebar: rgb(0.095, 0.012, 0.030),
                content: rgb(0.075, 0.010, 0.025), card: rgb(0.145, 0.022, 0.045),
                selected: rgb(0.620, 0.060, 0.100).opacity(0.44), stroke: rgb(1.000, 0.240, 0.300).opacity(0.28),
                text: rgb(1.000, 0.940, 0.940), secondaryText: rgb(0.950, 0.700, 0.740).opacity(0.72),
                tertiaryText: rgb(0.800, 0.500, 0.560).opacity(0.50), primary: rgb(1.000, 0.100, 0.220),
                secondary: rgb(0.620, 0.300, 0.900), tertiary: rgb(1.000, 0.650, 0.200), accent: rgb(1.000, 0.260, 0.340)
            )
        case (.monochromeStudio, false):
            YouGlassThemeColors(
                window: rgb(0.935, 0.940, 0.950), sidebar: rgb(0.865, 0.875, 0.895),
                content: rgb(0.985, 0.988, 0.992), card: rgb(0.905, 0.915, 0.930),
                selected: rgb(0.360, 0.450, 0.560).opacity(0.22), stroke: rgb(0.180, 0.210, 0.260).opacity(0.20),
                text: rgb(0.055, 0.065, 0.080), secondaryText: rgb(0.180, 0.200, 0.240).opacity(0.70),
                tertiaryText: rgb(0.280, 0.300, 0.350).opacity(0.48), primary: rgb(0.120, 0.160, 0.220),
                secondary: rgb(0.380, 0.470, 0.600), tertiary: rgb(0.620, 0.670, 0.740), accent: rgb(0.250, 0.350, 0.480)
            )
        case (.monochromeStudio, true):
            YouGlassThemeColors(
                window: rgb(0.012, 0.014, 0.018), sidebar: rgb(0.028, 0.032, 0.040),
                content: rgb(0.020, 0.023, 0.030), card: rgb(0.055, 0.062, 0.075),
                selected: rgb(0.240, 0.310, 0.420).opacity(0.42), stroke: rgb(0.650, 0.720, 0.840).opacity(0.26),
                text: rgb(0.950, 0.960, 0.980), secondaryText: rgb(0.760, 0.790, 0.850).opacity(0.72),
                tertiaryText: rgb(0.580, 0.620, 0.700).opacity(0.50), primary: rgb(0.760, 0.820, 0.920),
                secondary: rgb(0.370, 0.470, 0.650), tertiary: rgb(0.600, 0.700, 0.820), accent: rgb(0.560, 0.680, 0.860)
            )
        case (.cosmicCoral, false):
            YouGlassThemeColors(
                window: rgb(0.985, 0.910, 0.900), sidebar: rgb(0.930, 0.825, 0.850),
                content: rgb(1.000, 0.960, 0.950), card: rgb(0.955, 0.855, 0.870),
                selected: rgb(0.900, 0.280, 0.380).opacity(0.24), stroke: rgb(0.580, 0.180, 0.330).opacity(0.20),
                text: rgb(0.140, 0.040, 0.090), secondaryText: rgb(0.330, 0.120, 0.220).opacity(0.70),
                tertiaryText: rgb(0.450, 0.210, 0.310).opacity(0.48), primary: rgb(0.950, 0.260, 0.360),
                secondary: rgb(0.420, 0.280, 0.850), tertiary: rgb(0.980, 0.560, 0.300), accent: rgb(0.760, 0.260, 0.520)
            )
        case (.cosmicCoral, true):
            YouGlassThemeColors(
                window: rgb(0.015, 0.012, 0.055), sidebar: rgb(0.030, 0.022, 0.100),
                content: rgb(0.022, 0.016, 0.075), card: rgb(0.050, 0.030, 0.140),
                selected: rgb(0.540, 0.100, 0.240).opacity(0.44), stroke: rgb(1.000, 0.300, 0.420).opacity(0.28),
                text: rgb(0.960, 0.950, 1.000), secondaryText: rgb(0.800, 0.740, 0.940).opacity(0.72),
                tertiaryText: rgb(0.620, 0.540, 0.820).opacity(0.50), primary: rgb(1.000, 0.220, 0.360),
                secondary: rgb(0.420, 0.300, 1.000), tertiary: rgb(1.000, 0.620, 0.240), accent: rgb(0.960, 0.380, 0.620)
            )
        case (.indigoHarbor, false):
            YouGlassThemeColors(
                window: rgb(0.880, 0.925, 0.985), sidebar: rgb(0.800, 0.870, 0.955),
                content: rgb(0.950, 0.975, 1.000), card: rgb(0.855, 0.905, 0.980),
                selected: rgb(0.260, 0.380, 0.820).opacity(0.26), stroke: rgb(0.160, 0.260, 0.620).opacity(0.20),
                text: rgb(0.030, 0.060, 0.150), secondaryText: rgb(0.070, 0.150, 0.330).opacity(0.70),
                tertiaryText: rgb(0.140, 0.250, 0.450).opacity(0.48), primary: rgb(0.160, 0.360, 0.900),
                secondary: rgb(0.040, 0.620, 0.680), tertiary: rgb(0.360, 0.780, 0.520), accent: rgb(0.160, 0.320, 0.760)
            )
        case (.indigoHarbor, true):
            YouGlassThemeColors(
                window: rgb(0.005, 0.018, 0.060), sidebar: rgb(0.010, 0.035, 0.105),
                content: rgb(0.008, 0.026, 0.080), card: rgb(0.018, 0.055, 0.145),
                selected: rgb(0.100, 0.200, 0.560).opacity(0.46), stroke: rgb(0.220, 0.600, 1.000).opacity(0.28),
                text: rgb(0.920, 0.960, 1.000), secondaryText: rgb(0.700, 0.820, 0.960).opacity(0.72),
                tertiaryText: rgb(0.500, 0.680, 0.880).opacity(0.50), primary: rgb(0.220, 0.460, 1.000),
                secondary: rgb(0.060, 0.820, 0.880), tertiary: rgb(0.280, 0.900, 0.520), accent: rgb(0.300, 0.620, 1.000)
            )
        case (.paperLantern, false):
            YouGlassThemeColors(
                window: rgb(0.985, 0.955, 0.855), sidebar: rgb(0.935, 0.875, 0.700),
                content: rgb(1.000, 0.985, 0.925), card: rgb(0.960, 0.900, 0.750),
                selected: rgb(0.900, 0.600, 0.120).opacity(0.25), stroke: rgb(0.500, 0.350, 0.120).opacity(0.20),
                text: rgb(0.110, 0.090, 0.040), secondaryText: rgb(0.260, 0.220, 0.120).opacity(0.70),
                tertiaryText: rgb(0.380, 0.320, 0.190).opacity(0.48), primary: rgb(0.920, 0.560, 0.040),
                secondary: rgb(0.180, 0.360, 0.680), tertiary: rgb(0.720, 0.240, 0.180), accent: rgb(0.400, 0.330, 0.100)
            )
        case (.paperLantern, true):
            YouGlassThemeColors(
                window: rgb(0.018, 0.025, 0.055), sidebar: rgb(0.030, 0.045, 0.095),
                content: rgb(0.025, 0.035, 0.075), card: rgb(0.055, 0.070, 0.140),
                selected: rgb(0.520, 0.330, 0.060).opacity(0.44), stroke: rgb(1.000, 0.700, 0.180).opacity(0.28),
                text: rgb(0.950, 0.970, 1.000), secondaryText: rgb(0.780, 0.840, 0.950).opacity(0.72),
                tertiaryText: rgb(0.590, 0.680, 0.830).opacity(0.50), primary: rgb(1.000, 0.700, 0.100),
                secondary: rgb(0.220, 0.500, 0.940), tertiary: rgb(0.960, 0.260, 0.180), accent: rgb(0.520, 0.740, 1.000)
            )
        default:
            // Keep a safe fallback if a future family is added before its
            // expanded palette is supplied.
            YouGlassThemeFamily.youGlassOriginal.colors(isDark: isDark)
        }
    }

    private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }
}
