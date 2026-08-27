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

## Product foundation flows

The current product layer is deliberately local-first and is composed from small store extensions rather than a second persistence system:

- `YouTubeStorePlayback` records bounded per-video positions and durations. `continueWatching` filters completed items and feeds both the Home row and Library.
- `YouTubeStoreLibrary` stores up to 40 named `YouGlassLibraryCollection` values and 200 `YouGlassVideoNote` values in UserDefaults. Collections retain IDs while the store resolves the newest known `VideoItem` metadata from the local catalog.
- `YouTubeStoreQueue` stores a bounded `YouGlassPlaybackQueueState` with the current queue and autoplay preference. The player exposes queue navigation, remove/clear actions, and rate selection without requiring a YouTube account.
- `YouTubeStoreExperience` is the bridge for the command palette, theme accent override, mini-player/full-screen/share actions, and native media controls. `YouGlassNativeIntegration` owns Now Playing, remote commands, Dock actions, and the native sharing picker.
- `RecommendationRanker` handles local feed signals and the optional Shorts filter. `YouGlassNetworkMonitor`, the feed cache, and `YouGlassImageCache` keep the shell useful during transient network failures and prevent repeated thumbnail downloads.

The main Home surface has one vertical scroll owner. Library, Continue Watching, and recommendation rows are rendered in that owner so the lower content remains reachable at compact window sizes. Cards use context menus for save, queue, and collection actions; the command palette is available from the toolbar, `⌘K`, the app menu, and the Dock menu.

## Full-player ambient surface and interaction safety

`YouTubePlayerOverlay` mounts `PlayerAmbientSurface` behind `NativeWatchScreen`. The full watch page must preserve that layer as the visual source of truth: `NativeWatchScreenBody` owns one shared low-contrast fade behind the fixed header and scroll document, `NativeWatchScreenLayout` does not add an independent page-start fill or header divider, and `BlendedPlayerSurfaceModifier` clips the WebKit media content without applying a second outer clip to its ambient glow. This keeps the theme flowing around the video, metadata, and recommendation rail while retaining the media's rounded boundary. The relevant implementation lives in `Views/Player/NativeWatchScreenBody.swift`, `NativeWatchScreenLayout.swift`, and `PlayerAmbientViews.swift`.

The wide and narrow watch layouts use one outer vertical `ScrollView` as the page owner. `watchDetailsContent`, `commentsList`, and `relatedRail` contribute intrinsic height directly; comments use a bounded minimum panel height so the fallback state remains reachable, while the ten-item Up Next rail is not hidden behind a second vertical scroll view. `YouTubeStoreRecommendations` merges sparse API results with the loaded local catalog before the rail is rendered. The native transport centers the five primary playback buttons against the media frame and lays status/PIP controls independently at the trailing edge. The fixed header masks its material into the shared root fade rather than ending with a lower-edge rectangle. Its title block is title-first: the active theme colors a heavy title gradient that fills the flexible width before the fixed shelf, `NOW PLAYING` follows beneath it, and the channel stays subdued; the detail title remains unchanged. The main window's AppKit sizing bridge enables `.fullSizeContentView` and a transparent hidden title bar; expanded player mode removes the feed shell's top inset so the custom header flows to the window edge, while regular feed mode retains its inset. Header actions are rendered within one continuous rounded glass shelf rather than separate outlined circles. `PlayerMediaMetrics.cornerRadius` is shared by the SwiftUI surface, native player border, and AppKit/WebKit host; the perimeter shadows use zero x/y offsets so the glow remains balanced on all four edges.

Video-opening buttons use `YouTubeStore.openFromUserInteraction(_:)` from the home and player surfaces. It yields one MainActor turn before mutating the selected video so macOS 26 accessibility presses do not copy title/geometry state while SwiftUI's AttributeGraph transaction is still updating. The supplied 1.13.3 crash report showed `AccessibilityNode.sendAction`/`accessibilityPerformPress` reaching `initializeWithCopy for YouGlassVideoTitleBlock`; the guarded path was rebuilt and exercised successfully in the player.

Runtime visual validation for this boundary covers all 12 theme families in both Light and Dark (24 rebuilt app launches/captures). Each state must open the player, retain the themed ambient flow at the media/page boundary, and avoid a flat opaque rectangle or clipped glow.

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
