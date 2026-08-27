# YouGlass product foundations

This document is the detailed companion to the concise product rules in `AGENTS.md`. It describes the eight improvement areas implemented in the current local milestone and the boundaries an agent should preserve when extending them.

## 1. Continue Watching as the Home center

`YouTubeStorePlayback` records a position, duration, and last-updated date for recently watched videos. The store removes checkpoints near completion and bounds the remaining entries. `ContinueWatchingRow` renders progress and a resume label on Home and Library; the progress track is shown only when a real unfinished checkpoint with a known duration exists and is constrained to the thumbnail's bottom overlay so it cannot become a top-of-card decoration. Removing a card clears only its local checkpoint.

Source boundaries:

- `Stores/YouTubeStorePlayback.swift`
- `Views/Home/HomeLibraryViews.swift`
- `Views/Home/YouTubeHomeView.swift`

## 2. Player workspace

`YouTubeStoreQueue` prepares a bounded queue from the selected video, existing queue, feed candidates, history, and saved videos. `PlayerQueuePanel` exposes autoplay, remove, clear, and direct selection. The native watch screen handles queue auto-advance, playback speed, mini-player, full screen, PIP, save, and Share. Player state remains usable for playable cached videos even when the network is unavailable.

The full watch page has one vertical scroll owner. The media/details column, comments panel, and Up Next rail use intrinsic-height stacks so comments remain reachable at compact window sizes; the rail supplements sparse API responses from the local catalog and is capped at ten visible recommendations. The expanded player uses the window's full-size content region so its header has no standalone title-bar cap; regular feed mode retains the shell's top breathing room. Keep the primary playback controls centered on the media independently of status/PIP chrome, use one continuous rounded shelf for the header actions, and preserve the shared media radius plus centered glow when changing the player boundary.

## 3. Personal Library

Collections store video IDs and remain independent of YouTube account playlists. Notes are local, capped, editable through the store API, and may include the current playback timestamp. The catalog resolves metadata from history, saved/liked videos, the queue, and current feed data. Do not put account credentials or raw API responses into this store.

## 4. Command palette and keyboard flow

`CommandPaletteView` is opened by the toolbar command button, `⌘K`, the application menu, or the Dock menu. It supports search, arrow-key selection, Return, Escape, navigation, refresh, theme cycling, and selected-player commands. Keep actions routed through `YouTubeStore` so the palette does not duplicate state transitions.

## 5. Smarter Home recommendations

`RecommendationRanker` combines subscription, history, local likes, saved videos, search seeds, recency, and view signals while diversifying channels. The recommendation settings page controls Continue Watching visibility and whether Shorts are filtered from primary Home recommendations. The dedicated Shorts section remains independent. Cached personalized candidates use the same Shorts preference when they are stored/restored.

## 6. Reliability and performance

`YouGlassNetworkMonitor` publishes online/offline status to the main-actor store. Home restores cached feed candidates before attempting a live refresh and reports an offline state without clearing local data. `RemoteImage` uses a bounded `NSCache` (count and cost limits) for thumbnails and avatars; failed requests keep a stable placeholder. Player auto-advance is guarded against duplicate ended events.

## 7. Native macOS integration

`YouGlassNativeIntegration.swift` owns Now Playing metadata, remote transport commands, Dock menu actions, and the native sharing picker. The store registers handlers once and clears Now Playing when playback is dismissed. Keep remote commands scoped to the selected player and never place secrets or account state in Now Playing metadata.

## 8. Theme editor

`YouGlassThemeCustomization` currently provides a validated six-digit hex accent override. Settings edits it through the Accent editor; `Palette` applies it to selection, accent, pink/highlight, and progress treatments while preserving each theme family's coordinated Light/Dark palette. Reset removes the override and returns to the environment default.

## Validation checklist

After a UI-affecting change, rebuild the staged app bundle with `./script/build_and_run.sh --verify` and inspect the actual window. Cover Home, Library, player controls, `⌘K`, Settings Accent/Recommendations, and a relaunch. For visual theme work, test all 12 theme families in both color schemes when the player ambient boundary is touched.
