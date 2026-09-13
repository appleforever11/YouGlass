import SwiftUI

extension YouGlassThemeFamily {
    func colors(isDark: Bool) -> YouGlassThemeColors {
        switch (self, isDark) {
        case (.neoCitrus, false):
            YouGlassThemeColors(
                window: rgb(0.965, 0.976, 0.825),
                sidebar: rgb(0.925, 0.950, 0.735),
                content: rgb(0.990, 0.994, 0.905),
                card: rgb(0.955, 0.975, 0.820),
                selected: rgb(0.780, 0.925, 0.320).opacity(0.38),
                stroke: rgb(0.365, 0.555, 0.135).opacity(0.26),
                text: rgb(0.075, 0.105, 0.055),
                secondaryText: rgb(0.150, 0.205, 0.115).opacity(0.72),
                tertiaryText: rgb(0.185, 0.245, 0.130).opacity(0.52),
                primary: rgb(0.965, 0.885, 0.000),
                secondary: rgb(0.410, 0.850, 0.055),
                tertiary: rgb(0.250, 0.790, 0.685),
                accent: rgb(0.105, 0.565, 0.495)
            )
        case (.neoCitrus, true):
            YouGlassThemeColors(
                window: rgb(0.025, 0.040, 0.020),
                sidebar: rgb(0.035, 0.060, 0.028),
                content: rgb(0.040, 0.055, 0.032),
                card: rgb(0.070, 0.100, 0.052),
                selected: rgb(0.430, 0.610, 0.090).opacity(0.42),
                stroke: rgb(0.700, 0.900, 0.140).opacity(0.30),
                text: rgb(0.965, 0.985, 0.900),
                secondaryText: rgb(0.850, 0.910, 0.725).opacity(0.72),
                tertiaryText: rgb(0.760, 0.850, 0.610).opacity(0.50),
                primary: rgb(0.995, 0.875, 0.020),
                secondary: rgb(0.500, 0.930, 0.050),
                tertiary: rgb(0.180, 0.820, 0.700),
                accent: rgb(0.710, 0.925, 0.120)
            )
        case (.youGlassOriginal, false):
            YouGlassThemeColors(
                window: rgb(0.950, 0.930, 0.960),
                sidebar: rgb(0.975, 0.950, 0.980),
                content: rgb(0.990, 0.970, 0.990),
                card: rgb(0.960, 0.940, 0.980),
                selected: rgb(0.900, 0.750, 0.910).opacity(0.48),
                stroke: rgb(0.580, 0.200, 0.580).opacity(0.16),
                text: .black,
                secondaryText: Color.black.opacity(0.58),
                tertiaryText: Color.black.opacity(0.36),
                primary: rgb(0.800, 0.060, 0.440),
                secondary: rgb(0.440, 0.120, 0.780),
                tertiary: rgb(0.240, 0.100, 0.640),
                accent: rgb(0.200, 0.300, 0.820)
            )
        case (.youGlassOriginal, true):
            YouGlassThemeColors(
                window: rgb(0.008, 0.006, 0.016),
                sidebar: rgb(0.018, 0.012, 0.038),
                content: rgb(0.014, 0.008, 0.028),
                card: rgb(0.035, 0.018, 0.060),
                selected: rgb(0.280, 0.080, 0.250).opacity(0.52),
                stroke: rgb(0.960, 0.260, 0.720).opacity(0.20),
                text: .white,
                secondaryText: Color.white.opacity(0.62),
                tertiaryText: Color.white.opacity(0.38),
                primary: rgb(0.980, 0.160, 0.640),
                secondary: rgb(0.620, 0.240, 1.000),
                tertiary: rgb(0.300, 0.180, 0.980),
                accent: rgb(0.500, 0.560, 1.000)
            )
        case (.electricTide, false):
            YouGlassThemeColors(
                window: rgb(0.900, 0.980, 0.965), sidebar: rgb(0.850, 0.955, 0.930),
                content: rgb(0.950, 0.995, 0.985), card: rgb(0.885, 0.970, 0.945),
                selected: rgb(0.245, 0.790, 0.690).opacity(0.34), stroke: rgb(0.060, 0.520, 0.475).opacity(0.22),
                text: rgb(0.035, 0.130, 0.120), secondaryText: rgb(0.055, 0.230, 0.205).opacity(0.68),
                tertiaryText: rgb(0.070, 0.290, 0.250).opacity(0.48), primary: rgb(0.040, 0.730, 0.670),
                secondary: rgb(0.120, 0.660, 0.900), tertiary: rgb(0.340, 0.820, 0.300), accent: rgb(0.020, 0.490, 0.540)
            )
        case (.electricTide, true):
            YouGlassThemeColors(
                window: rgb(0.005, 0.035, 0.045), sidebar: rgb(0.010, 0.060, 0.070),
                content: rgb(0.008, 0.045, 0.055), card: rgb(0.018, 0.090, 0.095),
                selected: rgb(0.040, 0.430, 0.390).opacity(0.46), stroke: rgb(0.160, 0.880, 0.800).opacity(0.28),
                text: rgb(0.900, 1.000, 0.975), secondaryText: rgb(0.700, 0.940, 0.890).opacity(0.70),
                tertiaryText: rgb(0.550, 0.850, 0.790).opacity(0.48), primary: rgb(0.090, 0.880, 0.800),
                secondary: rgb(0.160, 0.650, 1.000), tertiary: rgb(0.300, 0.930, 0.470), accent: rgb(0.250, 0.930, 0.850)
            )
        case (.arcticGlass, false):
            YouGlassThemeColors(
                window: rgb(0.920, 0.970, 0.995), sidebar: rgb(0.875, 0.940, 0.985),
                content: rgb(0.970, 0.990, 1.000), card: rgb(0.900, 0.955, 0.995),
                selected: rgb(0.420, 0.720, 0.950).opacity(0.28), stroke: rgb(0.230, 0.520, 0.800).opacity(0.20),
                text: rgb(0.040, 0.100, 0.160), secondaryText: rgb(0.080, 0.210, 0.340).opacity(0.68),
                tertiaryText: rgb(0.140, 0.300, 0.450).opacity(0.46), primary: rgb(0.220, 0.650, 0.920),
                secondary: rgb(0.480, 0.430, 0.850), tertiary: rgb(0.440, 0.850, 0.910), accent: rgb(0.180, 0.460, 0.780)
            )
        case (.arcticGlass, true):
            YouGlassThemeColors(
                window: rgb(0.020, 0.050, 0.085), sidebar: rgb(0.030, 0.075, 0.120),
                content: rgb(0.024, 0.060, 0.100), card: rgb(0.045, 0.105, 0.160),
                selected: rgb(0.170, 0.430, 0.720).opacity(0.42), stroke: rgb(0.430, 0.770, 1.000).opacity(0.28),
                text: rgb(0.940, 0.980, 1.000), secondaryText: rgb(0.760, 0.880, 0.960).opacity(0.70),
                tertiaryText: rgb(0.620, 0.790, 0.920).opacity(0.48), primary: rgb(0.250, 0.710, 1.000),
                secondary: rgb(0.520, 0.480, 1.000), tertiary: rgb(0.360, 0.900, 0.980), accent: rgb(0.480, 0.760, 1.000)
            )
        case (.roseQuartz, false):
            YouGlassThemeColors(
                window: rgb(0.995, 0.930, 0.950), sidebar: rgb(0.985, 0.890, 0.930),
                content: rgb(1.000, 0.970, 0.980), card: rgb(0.985, 0.910, 0.950),
                selected: rgb(0.890, 0.430, 0.670).opacity(0.28), stroke: rgb(0.620, 0.240, 0.480).opacity(0.20),
                text: rgb(0.170, 0.060, 0.120), secondaryText: rgb(0.330, 0.110, 0.230).opacity(0.66),
                tertiaryText: rgb(0.410, 0.170, 0.300).opacity(0.46), primary: rgb(0.900, 0.330, 0.570),
                secondary: rgb(0.580, 0.400, 0.900), tertiary: rgb(1.000, 0.520, 0.420), accent: rgb(0.690, 0.260, 0.600)
            )
        case (.roseQuartz, true):
            YouGlassThemeColors(
                window: rgb(0.070, 0.018, 0.050), sidebar: rgb(0.100, 0.025, 0.075),
                content: rgb(0.080, 0.020, 0.060), card: rgb(0.130, 0.035, 0.095),
                selected: rgb(0.490, 0.100, 0.310).opacity(0.46), stroke: rgb(1.000, 0.350, 0.680).opacity(0.28),
                text: rgb(1.000, 0.940, 0.970), secondaryText: rgb(0.960, 0.750, 0.850).opacity(0.70),
                tertiaryText: rgb(0.900, 0.600, 0.760).opacity(0.48), primary: rgb(1.000, 0.250, 0.620),
                secondary: rgb(0.660, 0.380, 1.000), tertiary: rgb(1.000, 0.410, 0.310), accent: rgb(0.930, 0.360, 0.720)
            )
        case (.deepOrbit, false):
            YouGlassThemeColors(
                window: rgb(0.900, 0.935, 0.990), sidebar: rgb(0.845, 0.900, 0.975),
                content: rgb(0.950, 0.970, 1.000), card: rgb(0.875, 0.925, 0.990),
                selected: rgb(0.300, 0.480, 0.920).opacity(0.30), stroke: rgb(0.170, 0.330, 0.760).opacity(0.22),
                text: rgb(0.025, 0.060, 0.150), secondaryText: rgb(0.060, 0.140, 0.330).opacity(0.68),
                tertiaryText: rgb(0.100, 0.210, 0.440).opacity(0.48), primary: rgb(0.050, 0.560, 0.950),
                secondary: rgb(0.260, 0.260, 0.900), tertiary: rgb(0.170, 0.780, 0.900), accent: rgb(0.180, 0.350, 0.850)
            )
        case (.deepOrbit, true):
            YouGlassThemeColors(
                window: rgb(0.002, 0.018, 0.055), sidebar: rgb(0.005, 0.030, 0.090),
                content: rgb(0.004, 0.022, 0.070), card: rgb(0.012, 0.045, 0.125),
                selected: rgb(0.080, 0.180, 0.520).opacity(0.48), stroke: rgb(0.220, 0.580, 1.000).opacity(0.30),
                text: rgb(0.930, 0.960, 1.000), secondaryText: rgb(0.700, 0.800, 0.970).opacity(0.72),
                tertiaryText: rgb(0.520, 0.670, 0.930).opacity(0.50), primary: rgb(0.050, 0.640, 1.000),
                secondary: rgb(0.260, 0.310, 1.000), tertiary: rgb(0.130, 0.830, 1.000), accent: rgb(0.350, 0.560, 1.000)
            )
        case (.goldenGate, false):
            YouGlassThemeColors(
                window: rgb(0.940, 0.950, 0.960), sidebar: rgb(0.870, 0.900, 0.930),
                content: rgb(0.980, 0.985, 0.990), card: rgb(0.910, 0.930, 0.950),
                selected: rgb(0.780, 0.570, 0.250).opacity(0.25), stroke: rgb(0.250, 0.320, 0.380).opacity(0.20),
                text: rgb(0.080, 0.110, 0.140), secondaryText: rgb(0.180, 0.240, 0.280).opacity(0.70),
                tertiaryText: rgb(0.240, 0.340, 0.420).opacity(0.50), primary: rgb(0.720, 0.280, 0.200),
                secondary: rgb(0.800, 0.570, 0.180), tertiary: rgb(0.380, 0.620, 0.760), accent: rgb(0.200, 0.400, 0.560)
            )
        case (.goldenGate, true):
            YouGlassThemeColors(
                window: rgb(0.025, 0.030, 0.040), sidebar: rgb(0.045, 0.052, 0.066),
                content: rgb(0.035, 0.042, 0.054), card: rgb(0.075, 0.085, 0.105),
                selected: rgb(0.480, 0.240, 0.180).opacity(0.40), stroke: rgb(0.800, 0.620, 0.320).opacity(0.28),
                text: rgb(0.950, 0.960, 0.970), secondaryText: rgb(0.780, 0.820, 0.860).opacity(0.70),
                tertiaryText: rgb(0.600, 0.680, 0.740).opacity(0.50), primary: rgb(0.900, 0.320, 0.240),
                secondary: rgb(0.900, 0.680, 0.280), tertiary: rgb(0.380, 0.720, 0.920), accent: rgb(0.480, 0.720, 0.920)
            )
        case (.silverMist, false):
            YouGlassThemeColors(
                window: rgb(0.930, 0.940, 0.950), sidebar: rgb(0.860, 0.880, 0.910),
                content: rgb(0.975, 0.980, 0.985), card: rgb(0.900, 0.920, 0.940),
                selected: rgb(0.500, 0.650, 0.780).opacity(0.25), stroke: rgb(0.250, 0.340, 0.420).opacity(0.20),
                text: rgb(0.080, 0.100, 0.130), secondaryText: rgb(0.190, 0.240, 0.300).opacity(0.68),
                tertiaryText: rgb(0.250, 0.330, 0.400).opacity(0.48), primary: rgb(0.560, 0.620, 0.700),
                secondary: rgb(0.370, 0.580, 0.800), tertiary: rgb(0.640, 0.770, 0.880), accent: rgb(0.260, 0.460, 0.680)
            )
        case (.silverMist, true):
            YouGlassThemeColors(
                window: rgb(0.025, 0.028, 0.035), sidebar: rgb(0.050, 0.055, 0.065),
                content: rgb(0.035, 0.040, 0.050), card: rgb(0.080, 0.090, 0.105),
                selected: rgb(0.260, 0.380, 0.500).opacity(0.40), stroke: rgb(0.650, 0.750, 0.860).opacity(0.26),
                text: rgb(0.950, 0.960, 0.970), secondaryText: rgb(0.780, 0.820, 0.880).opacity(0.70),
                tertiaryText: rgb(0.600, 0.680, 0.760).opacity(0.50), primary: rgb(0.600, 0.700, 0.850),
                secondary: rgb(0.320, 0.580, 0.900), tertiary: rgb(0.500, 0.800, 0.950), accent: rgb(0.450, 0.700, 0.920)
            )
        case (.forestRadar, false):
            YouGlassThemeColors(
                window: rgb(0.910, 0.955, 0.910), sidebar: rgb(0.840, 0.920, 0.850),
                content: rgb(0.965, 0.985, 0.960), card: rgb(0.885, 0.945, 0.890),
                selected: rgb(0.300, 0.680, 0.360).opacity(0.25), stroke: rgb(0.170, 0.470, 0.250).opacity(0.20),
                text: rgb(0.050, 0.130, 0.075), secondaryText: rgb(0.120, 0.280, 0.160).opacity(0.70),
                tertiaryText: rgb(0.190, 0.360, 0.220).opacity(0.50), primary: rgb(0.100, 0.620, 0.300),
                secondary: rgb(0.560, 0.720, 0.150), tertiary: rgb(0.250, 0.720, 0.620), accent: rgb(0.100, 0.480, 0.280)
            )
        case (.forestRadar, true):
            YouGlassThemeColors(
                window: rgb(0.018, 0.045, 0.025), sidebar: rgb(0.028, 0.070, 0.040),
                content: rgb(0.024, 0.058, 0.032), card: rgb(0.050, 0.105, 0.060),
                selected: rgb(0.120, 0.420, 0.180).opacity(0.44), stroke: rgb(0.340, 0.760, 0.300).opacity(0.28),
                text: rgb(0.930, 0.980, 0.920), secondaryText: rgb(0.720, 0.880, 0.740).opacity(0.70),
                tertiaryText: rgb(0.540, 0.760, 0.580).opacity(0.50), primary: rgb(0.180, 0.820, 0.360),
                secondary: rgb(0.700, 0.820, 0.180), tertiary: rgb(0.220, 0.800, 0.620), accent: rgb(0.320, 0.820, 0.420)
            )
        case (.emberConsole, false):
            YouGlassThemeColors(
                window: rgb(0.980, 0.940, 0.900), sidebar: rgb(0.940, 0.860, 0.780),
                content: rgb(0.995, 0.970, 0.935), card: rgb(0.955, 0.890, 0.820),
                selected: rgb(0.920, 0.500, 0.180).opacity(0.25), stroke: rgb(0.680, 0.300, 0.100).opacity(0.20),
                text: rgb(0.170, 0.080, 0.040), secondaryText: rgb(0.340, 0.180, 0.100).opacity(0.70),
                tertiaryText: rgb(0.450, 0.260, 0.140).opacity(0.50), primary: rgb(0.920, 0.300, 0.080),
                secondary: rgb(0.980, 0.650, 0.080), tertiary: rgb(0.760, 0.180, 0.100), accent: rgb(0.720, 0.260, 0.080)
            )
        case (.emberConsole, true):
            YouGlassThemeColors(
                window: rgb(0.055, 0.025, 0.018), sidebar: rgb(0.090, 0.040, 0.025),
                content: rgb(0.070, 0.030, 0.020), card: rgb(0.130, 0.055, 0.030),
                selected: rgb(0.580, 0.180, 0.060).opacity(0.44), stroke: rgb(0.980, 0.500, 0.140).opacity(0.28),
                text: rgb(0.990, 0.940, 0.880), secondaryText: rgb(0.900, 0.720, 0.560).opacity(0.72),
                tertiaryText: rgb(0.760, 0.540, 0.360).opacity(0.50), primary: rgb(1.000, 0.340, 0.080),
                secondary: rgb(1.000, 0.700, 0.120), tertiary: rgb(0.920, 0.180, 0.120), accent: rgb(1.000, 0.520, 0.160)
            )
        case (.solarDesk, false):
            YouGlassThemeColors(
                window: rgb(0.985, 0.965, 0.890), sidebar: rgb(0.930, 0.900, 0.800),
                content: rgb(1.000, 0.985, 0.940), card: rgb(0.960, 0.925, 0.820),
                selected: rgb(0.850, 0.650, 0.200).opacity(0.26), stroke: rgb(0.420, 0.420, 0.220).opacity(0.20),
                text: rgb(0.100, 0.110, 0.090), secondaryText: rgb(0.250, 0.270, 0.220).opacity(0.70),
                tertiaryText: rgb(0.370, 0.390, 0.310).opacity(0.50), primary: rgb(0.980, 0.700, 0.080),
                secondary: rgb(0.200, 0.490, 0.820), tertiary: rgb(0.280, 0.720, 0.650), accent: rgb(0.160, 0.400, 0.680)
            )
        case (.solarDesk, true):
            YouGlassThemeColors(
                window: rgb(0.018, 0.028, 0.060), sidebar: rgb(0.030, 0.050, 0.100),
                content: rgb(0.024, 0.040, 0.080), card: rgb(0.055, 0.080, 0.150),
                selected: rgb(0.520, 0.360, 0.080).opacity(0.44), stroke: rgb(0.920, 0.700, 0.250).opacity(0.28),
                text: rgb(0.940, 0.960, 1.000), secondaryText: rgb(0.760, 0.820, 0.940).opacity(0.70),
                tertiaryText: rgb(0.580, 0.680, 0.850).opacity(0.50), primary: rgb(1.000, 0.740, 0.120),
                secondary: rgb(0.180, 0.520, 0.980), tertiary: rgb(0.260, 0.820, 0.760), accent: rgb(0.480, 0.720, 1.000)
            )
        case (.peachChrome, false):
            YouGlassThemeColors(
                window: rgb(0.995, 0.925, 0.900), sidebar: rgb(0.960, 0.850, 0.850),
                content: rgb(1.000, 0.965, 0.950), card: rgb(0.980, 0.890, 0.880),
                selected: rgb(0.900, 0.500, 0.500).opacity(0.24), stroke: rgb(0.600, 0.300, 0.360).opacity(0.20),
                text: rgb(0.180, 0.070, 0.090), secondaryText: rgb(0.360, 0.160, 0.200).opacity(0.70),
                tertiaryText: rgb(0.460, 0.240, 0.280).opacity(0.50), primary: rgb(0.980, 0.420, 0.360),
                secondary: rgb(0.320, 0.700, 0.820), tertiary: rgb(0.820, 0.460, 0.700), accent: rgb(0.700, 0.320, 0.460)
            )
        case (.peachChrome, true):
            YouGlassThemeColors(
                window: rgb(0.065, 0.022, 0.050), sidebar: rgb(0.100, 0.030, 0.075),
                content: rgb(0.080, 0.028, 0.060), card: rgb(0.140, 0.050, 0.100),
                selected: rgb(0.520, 0.180, 0.320).opacity(0.44), stroke: rgb(0.980, 0.450, 0.500).opacity(0.28),
                text: rgb(1.000, 0.940, 0.940), secondaryText: rgb(0.940, 0.740, 0.780).opacity(0.70),
                tertiaryText: rgb(0.840, 0.560, 0.680).opacity(0.50), primary: rgb(1.000, 0.360, 0.420),
                secondary: rgb(0.180, 0.700, 0.820), tertiary: rgb(0.820, 0.300, 0.700), accent: rgb(0.500, 0.760, 0.900)
            )
        default:
            expansionColors(isDark: isDark)
        }
    }

    private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }
}
