import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Native preferences for YouGlass. The settings scene is intentionally a
/// sidebar-detail layout so account, playback, and API controls stay
/// discoverable without turning the main YouTube surface into a settings form.
struct YouGlassSettingsView: View {
    @EnvironmentObject var store: YouTubeStore
    @State var sidebarVisible = true
    @State var selection: YouGlassSettingsPage? = .general
    @State var apiKey = ""
    @State var clientID = ""
    @State var clientSecret = ""
    @State var status: String?
    @State var authorizing = false
    @State var showingResetConfirmation = false
    @State var showingCacheResetConfirmation = false
    @State var accentHexDraft = ""
    @State var themeQuery = ""
    @State var settingsQuery = ""
    @State var themeCollection: YouGlassThemeCollection = .all
    @State var debugStatus: String?
    @AppStorage(YouGlassVisualDefaults.reduceAmbientMotion) var reduceAmbientMotion = false
    @AppStorage("YouGlass.preferTechnicalErrorAlerts") var preferTechnicalErrorAlerts = false
    @AppStorage(YouGlassDebugEngine.diagnosticsEnabledKey) var diagnosticsEnabled = false
    @AppStorage(YouGlassDebugEngine.verboseLoggingKey) var verboseDiagnostics = false
    @AppStorage(YouGlassDebugEngine.webKitBreadcrumbsKey) var captureWebKitBreadcrumbs = false
    @AppStorage(YouGlassHiddenWebKitPolicy.enabledKey) var hiddenWebKitCompatibility = false

    // Use the persisted app choice directly so Settings does not wait for the
    // window's system appearance to resolve before choosing its palette.
    var effectiveColorScheme: ColorScheme {
        store.colorScheme
    }

    var palette: Palette {
        Palette(
            effectiveColorScheme,
            theme: store.visualTheme,
            customization: store.themeCustomization
        )
    }

    var filteredThemeFamilies: [YouGlassThemeFamily] {
        let query = themeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return YouGlassThemeFamily.allCases.filter { theme in
            let matchesCollection = themeCollection == .all || theme.collection == themeCollection
            let matchesQuery = query.isEmpty
                || theme.title.localizedCaseInsensitiveContains(query)
                || theme.subtitle.localizedCaseInsensitiveContains(query)
                || theme.collection.title.localizedCaseInsensitiveContains(query)
            return matchesCollection && matchesQuery
        }
    }

    var filteredSettingsPages: [YouGlassSettingsPage] {
        YouGlassSettingsPage.allCases.filter { $0.matches(settingsQuery) }
    }
}
