# YouGlass source map

Use when locating a subsystem. Paths describe responsibilities; inspect current source rather than assuming historical filenames or layouts are unchanged.

- `Package.swift`: package, target, platform, resource, test, and Sparkle dependency definitions.
- `Sources/YouTubeMac/App/`: app entry point, root composition, commands, and window sizing.
- `Sources/YouTubeMac/Models/`: value models, policies, and model fixtures for videos, subscriptions, themes, playback, and API responses.
- `Sources/YouTubeMac/Stores/`: the main-actor store declaration plus focused extensions for initialization, settings, playback, feed loading/ranking/navigation, search, account, community, persistence, and presentation.
- `Sources/YouTubeMac/Views/Home/`: main window layout, navigation/sidebar content, recommendation surfaces, cards, playlists, and shared home states.
- `Sources/YouTubeMac/Views/Settings/`: settings state, sidebar/detail pages, theme controls, layout components, window configuration, and the AppKit-backed scroll container.
- `Sources/YouTubeMac/Views/Player/`: player overlay, native watch screen, native transport controls, inline WebKit host/coordinator, playback controller, JavaScript bridge, ambient palette sampling, and player support views.
- `Sources/YouTubeMac/Services/`: YouTube Data API client slices/response models/errors, WebKit feed/comments bridge slices, and debug-engine slices/models/utilities.
- `Sources/YouTubeMac/Models/YouGlassThemeCatalog.swift` and `YouGlassRuntimeStabilityPolicy.swift`: theme families/colors and platform safety policies.
- `Sources/YouTubeMac/Views/Shared/`: palette, ambient theme rendering, shared surfaces, and parallax modifiers.
- `Sources/YouTubeMac/Services/`: OAuth credentials/browser sign-in, focused WebKit compatibility bridges, Keychain access, PIP window/session management, diagnostics, request helpers, prewarming, and updates.
- `YouTubeBrowserWindow` keeps its ARC-retained reusable NSWindow with `isReleasedWhenClosed = false`; its WebKit finish callback only handles the currently attached WebView and does not mutate window chrome after navigation.
- `Sources/YouTubeMac/Views/Home/YouTubeChannelView.swift`: channel detail surface composed with the Home window.
- `Sources/YouTubeMac/Resources/`: Icon Composer source, fallback icon resources, and packaged assets.
- `Tests/YouTubeMacTests/`: XCTest coverage for models, policies, diagnostics, and persistence-adjacent behavior.
- Recommendations: `Models/RecommendationRanker.swift` owns candidate ranking and diversity; `RecommendationSignals.swift` owns bounded interests and source rotation; `RecommendationModels.swift` owns feed partitioning and presented-ID rotation. Store query construction and feed presentation are separate from persistence.
- API response models are split into video/search, account, and community files. Display formatting lives in `Models/YouTubeDisplayFormatting.swift`.
- Library composition and note editing live in `PersonalLibraryView.swift` and `LibraryNoteSheet.swift`; `HomeLibraryViews.swift` owns Continue Watching. Theme metadata and concrete palettes live in `YouGlassThemeCatalog.swift` and `YouGlassThemePalettes.swift`.
- `script/`: local build, test, release packaging, diagnostics export, and optional remote-development helpers.
- `docs/`: user-facing screenshots and public project documentation.
- `.docs/`: this internal, tracked project knowledge base.
- `.codex/`: local Codex recovery/configuration metadata; it is ignored and is not the source of truth for application code.
- `backups/`, `dist/`, `.build/`, `tmp/`: local artifacts and recovery/build output; do not treat them as newer source than Git without an explicit comparison.
