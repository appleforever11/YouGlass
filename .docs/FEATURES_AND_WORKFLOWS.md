# YouGlass product foundations

This document is the detailed companion to the concise product rules in `AGENTS.md`. It describes the eight product foundations plus the YouGlass 2.0 Theme Center expansion and the boundaries an agent should preserve when extending them.

## 1. Continue Watching as the second Home section

`YouTubeStorePlayback` records a position, duration, and last-updated date for recently watched videos. The store removes checkpoints near completion and bounds the remaining entries. On Home, the `For You` recommendation row comes first below the hero, and the enabled/populated `ContinueWatchingRow` follows as the second section. The row also appears in Library. It renders progress and a resume label; the progress track is shown only when a real unfinished checkpoint with a known duration exists and is constrained to the thumbnail's bottom overlay so it cannot become a top-of-card decoration. Removing a card clears only its local checkpoint.

Source boundaries:

- `Stores/YouTubeStorePlayback.swift`
- `Views/Home/HomeLibraryViews.swift`
- `Views/Home/YouTubeHomeView.swift`

## 2. Player workspace

`YouTubeStoreQueue` prepares a bounded queue from the selected video, existing queue, feed candidates, history, and saved videos. `PlayerQueuePanel` exposes autoplay, remove, clear, and direct selection. The native watch screen handles queue auto-advance, playback speed, mini-player, full screen, PIP, save, and Share. Player state remains usable for playable cached videos even when the network is unavailable.

The full watch page has one outer vertical AppKit scroll owner. The media/details column and Up Next rail use intrinsic-height stacks, while the comments panel is a bounded 360-point AppKit scroll box hosting SwiftUI rows; scrolling over comments stays inside that box instead of moving the page. The expanded player uses the window's full-size content region so its header has no standalone title-bar cap; regular feed mode retains the shell's top breathing room. The fixed header and scroll document share one low-contrast root fade, with no independent page-start rectangle or divider; preserve the small media top inset needed for the perimeter glow. The header title is intentionally the focal point: it uses a heavy active-theme gradient and expands through the flexible space before the fixed action shelf, with `NOW PLAYING` directly below and the channel as tertiary context. Keep the primary playback controls centered on the media independently of status/PIP chrome, use one continuous rounded shelf for the header actions, and preserve the shared media radius plus centered glow when changing the player boundary. Keep player scroll surfaces on the AppKit bridge on macOS 26+; nested SwiftUI vertical `ScrollView` values have caused AttributeGraph `initializeWithCopy` crashes in this workspace.

## 3. Personal Library

Collections store video IDs and remain independent of YouTube account playlists. Notes are local, capped, editable through the store API, and may include the current playback timestamp. The catalog resolves metadata from history, saved/liked videos, the queue, and current feed data. Do not put account credentials or raw API responses into this store.

## 4. Command palette and keyboard flow

`CommandPaletteView` is opened by the toolbar command button, `⌘K`, the application menu, or the Dock menu. It supports search, arrow-key selection, Return, Escape, navigation, refresh, theme cycling, and selected-player commands. Its modal surface uses an opaque theme-colored base with a restrained material/tint layer so the Home feed, desktop windows, and other translucent layers cannot show through the command list. The overlay is a sibling of the horizontal Home shell, which keeps the palette centered in the full window instead of placing it at the shell's trailing edge. Each command row has a visible accent-backed pointer hover state, and hovering a row makes it the active selection for Return. Keep actions routed through `YouTubeStore` so the palette does not duplicate state transitions.

## 5. Smarter Home recommendations

`RecommendationRanker` combines subscription, history, local likes, saved videos, search seeds, recency, and view signals while diversifying channels. YouGlass permanently excludes YouTube Shorts from recommendations and from the feed/API/WebKit/channel ingestion paths that supply them. Search and direct-open reject Shorts URLs and Shorts-oriented queries, the Shorts navigation/settings surfaces are removed, and known Short entries are sanitized from local history, library references, queue, playback checkpoints, recommendation seeds, and feed caches when they are loaded or written. YouTube account-side history, likes, and playlists are not modified.

The Data API does not expose a reliable Shorts flag, so API results use the shared title marker policy; WebKit and channel extraction additionally reject `/shorts/` and reel renderer entries before they become `VideoItem` values.

## 6. Reliability and performance

`YouGlassNetworkMonitor` publishes online/offline status to the main-actor store. Home restores cached feed candidates before attempting a live refresh and reports an offline state without clearing local data. `RemoteImage` uses a bounded `NSCache` (count and cost limits) for thumbnails and avatars; failed requests keep a stable placeholder. Player auto-advance is guarded against duplicate ended events.

## 7. Native macOS integration

`YouGlassNativeIntegration.swift` owns Now Playing metadata, remote transport commands, Dock menu actions, and the native sharing picker. The store registers handlers once and clears Now Playing when playback is dismissed. Keep remote commands scoped to the selected player and never place secrets or account state in Now Playing metadata.

## 8. Theme editor

`YouGlassThemeCustomization` currently provides a validated six-digit hex accent override. Settings edits it through the Accent editor; `Palette` applies it to selection, accent, pink/highlight, and progress treatments while preserving each theme family's coordinated Light/Dark palette. Reset removes the override and returns to the environment default.

## 9. YouGlass 2.0 Theme Center

The Theme Center now contains 24 selectable environment families. The original twelve families retain their existing raw values and exact Light/Dark palettes so saved preferences remain compatible. Twelve new families live in `Models/YouGlassThemeCatalogExpansion.swift` and provide paired palettes for Aurora Bloom, Midnight Velvet, Ocean Drive, Desert Rose, Alpine Sage, Copper Noir, Lavender Haze, Ruby Signal, Monochrome Studio, Cosmic Coral, Indigo Harbor, and Paper Lantern.

Each family exposes a stable title, subtitle, SF Symbol, collection, and optional NEW/FEATURED badge. Appearance adds a collection menu, case-insensitive search over the title/subtitle/collection, a matching-result count, an empty state, and a Surprise me action. These controls only filter or choose the catalog; the store continues to persist the selected `visualTheme` through the existing preference key.

The approved YouGlass 2.0 Glass Prism artwork is packaged in the Icon Composer resource, the fallback ICNS, and the source preview PNG. Unrelated legacy artwork is not part of the YouGlass resource set.

## Validation checklist

After a UI-affecting change, rebuild the staged app bundle with `./script/build_and_run.sh --verify` and inspect the actual window. Cover Home, Library, player controls, `⌘K`, Settings Accent/Recommendations, and a relaunch. For visual Theme Center work, verify every family exposes both Light and Dark colors and that the Appearance page scrolls through the expanded catalog. When the player ambient boundary is touched, test all 24 families in both color schemes.
