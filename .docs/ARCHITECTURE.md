# YouGlass architecture notes

## Package and scenes

`Package.swift` defines one executable product, `YouGlass`, backed by the `YouTubeMac` target. The target imports SwiftUI, AppKit, WebKit, Foundation, and Sparkle as needed and copies the `Resources` directory.

`YouTubeMacApp` owns the app-wide `@StateObject` `YouTubeStore` and injects it into:

- the main `WindowGroup("YouGlass", id: "main")`;
- the separate `Settings` scene.

The settings scene also receives the store's persisted color scheme via the SwiftUI environment and preferred color scheme. `YouGlassWindowSizingView` is a small AppKit bridge that keeps the main window inside the active screen's visible frame.

## Source organization

The source tree is organized by responsibility rather than by one-file-per-feature monolith. App composition lives in `App/`, value types in `Models/`, the main-actor state machine in focused `Stores/` extensions, SwiftUI surfaces in `Views/Home/`, `Views/Settings/`, and `Views/Player/`, and network/WebKit/diagnostic code in `Services/`. Keep each Swift source file below 500 lines. Large JavaScript payloads are split into ordered script-part files and joined by a small Swift facade.

## State ownership and data flow

- `YouTubeStore` is `@MainActor` and `ObservableObject`. It owns published UI state, account/feed orchestration, local preference writes, saved videos, playback checkpoints, and calls into API/OAuth/browser/bridge services.
- `Models/` contains plain value types and policies. Keep parsing, validation, and policy decisions there when they do not require UI state.
- `YouTubeStore` is declared in `Stores/YouTubeStore.swift`; focused extensions keep initialization, settings, playback, feed, account, persistence, community, search, and presentation responsibilities independently editable.
- `YouGlassSettingsView` owns only settings-window-local state such as selected page, sidebar visibility, text-field drafts, alerts, and authorization progress. Its pages, components, theme cards, window configuration, and scroll bridge live in separate `Views/Settings/` files. Shared settings are read/written through `YouTubeStore` and `@AppStorage`.
- `YouGlassVisualTheme.swift` provides the shared `Palette`/ambient background layer. `YouGlassThemeCatalog.swift` provides the 12 selectable theme families and their light/dark colors.
- `Views/Home/YouTubeHomeView` renders the main navigation and feed surfaces from the store, with sidebar, hero, card, playlist, image, background, and loading states separated into focused files.
- `Views/Player/` renders native controls and coordinates player state. The inline player owns the visible WebKit media surface, lifecycle, coordinator, messages, and ordered JavaScript command bridge independently from the native watch screen.

## Settings layout

The settings surface is intentionally a sidebar/detail layout:

```text
Settings scene
└── YouGlassSettingsView
    ├── settingsChrome
    ├── settingsSidebar (native List selection)
    └── settingsDetail inside a scrollable detail viewport
        ├── General
        ├── Appearance
        ├── Account & API
        ├── Recommendations
        ├── Playback
        ├── Comments & Chat
        ├── Notifications
        ├── Privacy & Data
        ├── Advanced
        └── About & Help
```

The Appearance page is deliberately taller than the default window because it contains the theme catalog. The scroll bridge uses a stock `NSScrollView` with an `NSHostingController` document to avoid a macOS 27 private SwiftUI hosting-scroll hit-test crash. The controller's `sizeThatFits(in:)` result supplies the document height at the real viewport width, preventing the hosted page from being centered inside an oversized document. The SwiftUI root is top-leading aligned, and page resets resolve the visual top against the document view's coordinate direction. Keep AppKit as a narrow boundary, avoid custom `NSScrollView.layout()` callbacks and max-height document fills, reset only when changing pages, and leave user-driven scrolling alone after the initial layout settles.

## Service boundaries

- `Services/YouTubeAPIClient*`: public/account-scoped YouTube Data API requests split by search, video, channel, comments, live chat, account, playlists, and transport responsibilities; response models and quota/transient error classification are separate files.
- `YouTubeOAuthClient`: client ID/secret/token persistence and Google authorization exchange.
- `YouTubeBrowserWindow`: visible authentication/session window and sign-out/reset behavior.
- `YouTubeWebFeedBridge*` and `YouTubeCommentsBridge*`: WebKit-backed compatibility/data extraction paths split into request, navigation, extraction, script, and payload responsibilities. `YouTubeSubscriptionBridge`, `YouTubeChannelBridge`, and `YouTubeLiveChatBridge` remain focused standalone bridges. They are intentionally isolated from the main SwiftUI view tree.
- `YouGlassPictureInPicture` and `YouGlassDesktopPIPWindow`: desktop PIP state/window management.
- `YouGlassDiagnostics` and `YouGlassDebugEngine*`: structured redacted events, session lifecycle, crash artifacts, persistence, and exportable support data split into focused service files.
- `YouGlassUpdater`: Sparkle update controller and stable appcast flow.

## Platform stability rules

- macOS 26 and later use the safe runtime stability policy: hidden WebKit bridges are disabled by default and parallax uses stable hover behavior.
- WebKit surfaces are treated as remote layer-tree owners. Avoid unnecessary reparenting, masking, or zero-size first passes around them.
- Keychain credentials and OAuth/API secrets are local runtime state. Never move them into source, diagnostics, commits, or `.docs`.
- AppKit bridges should be lifecycle-scoped to the representable/coordinator or owning window. Do not create global strong references to views/windows without an explicit ownership reason.
