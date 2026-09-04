# YouGlass product foundations

This document is the detailed companion to the concise product rules in `AGENTS.md`. It describes the eight product foundations plus the YouGlass 2.0 Theme Center expansion and the boundaries an agent should preserve when extending them.

## 1. Continue Watching as the second Home section

`YouTubeStorePlayback` records a position, duration, and last-updated date for recently watched videos. The store removes checkpoints near completion and bounds the remaining entries. On Home, the `For You` recommendation row comes first below the hero, and the enabled/populated `ContinueWatchingRow` follows as the second section. The row also appears in Library. It renders progress and a resume label; the progress track is shown only when a real unfinished checkpoint with a known duration exists and is constrained to the thumbnail's bottom overlay so it cannot become a top-of-card decoration. Removing a card clears only its local checkpoint.

Source boundaries:

- `Stores/YouTubeStorePlayback.swift`
- `Views/Home/HomeLibraryViews.swift`
- `Views/Home/YouTubeHomeView.swift`

## 2. Player workspace

`YouTubeStoreQueue` prepares a bounded queue from the selected video, existing queue, feed candidates, history, and saved videos, then can append late-loaded player recommendations after the current tail. `YouGlassPlaybackQueuePolicy` preserves the order of an item already in the queue so the selected video remains the cursor; the native media `ended` event crosses the playback bridge and completion advances to the following item without page-level looping. A card's Play Next action inserts directly after that cursor and remains present when the 24-item bound is reached, while Add to Queue appends normally. `PlayerQueuePanel` exposes autoplay, remove, clear, and direct selection. The native watch screen handles queue auto-advance, playback speed, mini-player, full screen, PIP, save, and Share. Player state remains usable for playable cached videos even when the network is unavailable.

The full watch page has one outer vertical AppKit scroll owner. The media/details column and Up Next rail use intrinsic-height stacks, while the comments panel is a bounded 360-point AppKit scroll box hosting SwiftUI rows; scrolling over comments stays inside that box instead of moving the page. The expanded player uses the window's full-size content region so its header has no standalone title-bar cap; regular feed mode retains the shell's top breathing room. The fixed header and scroll document share one low-contrast root fade, with no independent page-start rectangle or divider; preserve the small media top inset needed for the perimeter glow. The header title is intentionally the focal point: it uses a black-weight solid active-theme accent, wraps to at most two readable lines, and expands through the flexible space before the fixed action shelf, with `NOW PLAYING` directly below in a quieter accent treatment and the channel as tertiary context. Keep the primary playback controls centered on the media independently of status/PIP chrome, use one continuous rounded shelf for the header actions, and preserve the shared media radius plus centered glow when changing the player boundary. Keep player scroll surfaces on the AppKit bridge on macOS 26+; nested SwiftUI vertical `ScrollView` values have caused AttributeGraph `initializeWithCopy` crashes in this workspace.

## 3. Personal Library

Collections store video IDs and remain independent of YouTube account playlists. Notes are local, capped, editable through the store API, and may include the current playback timestamp. The catalog resolves metadata from history, saved/liked videos, the queue, and current feed data. Do not put account credentials or raw API responses into this store.

## 4. Command palette and keyboard flow

`CommandPaletteView` is opened by the toolbar command button, `⌘K`, the application menu, or the Dock menu. It supports search, arrow-key selection, Return, Escape, Home/Library/History navigation, global search focus, Settings, resume, refresh, theme cycling, and selected-player commands. The palette waits until its modal is mounted before claiming keyboard focus; Escape always dismisses it, and command execution dismisses the overlay before running the action so focus/window changes do not race its teardown. Its modal surface uses an opaque theme-colored base with a restrained material/tint layer so the Home feed, desktop windows, and other translucent layers cannot show through the command list. The overlay is a sibling of the horizontal Home shell, which keeps the palette centered in the full window instead of placing it at the shell's trailing edge. Each command row has a visible accent-backed pointer hover state, and hovering a row makes it the active selection for Return. Keep actions routed through `YouTubeStore` so the palette does not duplicate state transitions.

## 5. Smarter Home recommendations

`RecommendationRanker` combines subscription, history, local likes, saved videos, search seeds, recency, and view signals while diversifying channels. YouGlass permanently excludes YouTube Shorts from recommendations and from the feed/API/WebKit/channel ingestion paths that supply them. Search and direct-open reject Shorts URLs and Shorts-oriented queries, the Shorts navigation/settings surfaces are removed, and known Short entries are sanitized from local history, library references, queue, playback checkpoints, recommendation seeds, and feed caches when they are loaded or written. YouTube account-side history, likes, and playlists are not modified.

The Data API does not expose a reliable Shorts flag, so API results use the shared title marker policy; WebKit and channel extraction additionally reject `/shorts/` and reel renderer entries before they become `VideoItem` values.

Home refreshes are deliberately split into two paths. The active-window task checks once per minute, which keeps the feed current without repeatedly spending Data API quota. A user-requested refresh has a 15-second safety throttle and bypasses the in-memory API-key response cache. It refreshes account signals immediately, while a persisted subscription snapshot is refreshed in the background when it is missing from the current load or older than the five-minute subscription window; the Home load only waits when there is no subscription snapshot to use. Signed-in subscription RSS enrichment is capped at twelve channels and two uploads per channel with a four-second timeout. When subscriptions are available, that RSS/account path avoids expensive search fan-out; a single recommendation seed is used only when search is needed as a fallback. Independent API sources overlap while the shared request gate continues to space requests, and an active YouTube 429 cooldown fails immediately so saved candidates remain usable rather than waiting through the cooldown. Every successful live refresh records only the IDs of the latest 24 visible `For You` candidates in `UserDefaults`; the local ranker then favors other valid candidates on the next refresh while retaining its subscription, recency, history, and diversity signals. If the available source pool is smaller than the rotation window, the prior candidates remain available as a safe fallback.

Home uses the packaged YouGlass application icon and product name rather than imitating YouTube branding. The featured card exposes real Play, Queue, and Save actions; inert carousel dots are intentionally absent. Video cards and subscription/sidebar rows share explicit pointer hover feedback, readable section context, and accessibility labels. Card hover targets remain stable while inner visuals animate, and play badges stay mounted with hit testing disabled so repeated pointer entry reliably reactivates the affordance even as the card scales or the feed refreshes. `Command-L` requests focus for the global search field, which exposes clear/run controls and a visible focused state. Settings provides independent tokenized page/feature search, including terms such as captions, API key, queue, privacy, and theme; filtering does not alter preferences.

The normal Home scroll owner supports native pull/drag-down refresh. On macOS 27 and later, `Views/Home/YouGlassHomeRefreshController.swift` installs AppKit's `NSRefreshController` on the underlying scroll view; older systems use SwiftUI's `.refreshable` fallback. The gesture invokes the same forced Home load as the toolbar refresh, so the existing 15-second manual-refresh safety floor and feed rotation policy remain in force. Completion ends the retained native controller and re-anchors the document at the top, including a next-run-loop correction for the macOS refresh animation. The controller is mounted for Home only; Library, Search, and a selected Custom Feed do not accidentally reload the normal Home feed.

## 6. Reliability and performance

`YouGlassNetworkMonitor` publishes online/offline status to the main-actor store. Home restores cached feed candidates before attempting a live refresh and reports an offline state without clearing local data. `RemoteImage` uses a bounded `NSCache` (count and cost limits) for thumbnails and avatars; failed requests keep a stable placeholder. Player auto-advance is guarded against duplicate ended events.

## 7. Native macOS integration

`YouGlassNativeIntegration.swift` owns Now Playing metadata, remote transport commands, Dock menu actions, and the native sharing picker. The store registers handlers once and clears Now Playing when playback is dismissed. Keep remote commands scoped to the selected player and never place secrets or account state in Now Playing metadata.

## 8. Theme editor

`YouGlassThemeCustomization` currently provides a validated six-digit hex accent override. Settings edits it through the Accent editor; `Palette` applies it to selection, accent, pink/highlight, and progress treatments while preserving each theme family's coordinated Light/Dark palette. Reset removes the override and returns to the environment default.

## 9. YouGlass 2.0 Theme Center

The Theme Center now contains 24 selectable environment families. The original twelve families retain their existing raw values and exact Light/Dark palettes so saved preferences remain compatible. Twelve new families live in `Models/YouGlassThemeCatalogExpansion.swift` and provide paired palettes for Aurora Bloom, Midnight Velvet, Ocean Drive, Desert Rose, Alpine Sage, Copper Noir, Lavender Haze, Ruby Signal, Monochrome Studio, Cosmic Coral, Indigo Harbor, and Paper Lantern.

Each family exposes a stable title, subtitle, SF Symbol, collection, and optional NEW/FEATURED badge. Appearance adds a collection menu, case-insensitive search over the title/subtitle/collection, a matching-result count, an empty state, and a Surprise me action. These controls only filter or choose the catalog; the store continues to persist the selected `visualTheme` through the existing preference key.

## 10. Native Custom Feeds

Home exposes a Custom Feeds strip beside the normal recommendation surfaces. A user can describe a feed in a sentence, optionally provide a name, and save up to eight feed definitions. Saved definitions contain only the bounded prompt, its interpreted intent, and creation/update dates; video candidates are fetched and ranked at runtime and are not persisted as a second feed cache.

`Models/CustomFeedModels.swift` keeps the interpretation deterministic and testable. It extracts a search query, subscription-only scope, recency window, duration preference, and the always-on Shorts exclusion. `YouGlassCustomFeedRanker` applies those constraints before reusing `RecommendationRanker` for subscription, history, saved, local-like, freshness, and channel-diversity signals. Unknown duration or age metadata remains eligible so a sparse API response does not make the surface unusable.

`Stores/YouTubeStoreCustomFeeds.swift` owns selection, cancellation/generation checks, persistence, and retrieval. API-key or OAuth sessions use the existing Data API search client with the deliberate-refresh cache bypass; subscription-scoped feeds also use the quota-light Atom channel client. API-less installs use the existing signed-in web search fallback when enabled and otherwise rank the local catalog. The result surface is `Views/Home/CustomFeedViews.swift`, with create/edit/delete actions available from the Home toolbar, command palette, chip context menus, and the focused feed detail.

This is intentionally not a clone of YouTube's private experimental Custom Feed ranking. No documented Data API resource exposes that prompt-based feed, and no AI service is required for the native MVP. An AI interpreter can be added later only as an explicit opt-in enhancement with separately managed runtime credentials; it must not move prompts or API keys into source, UserDefaults, diagnostics, Git, or Sparkle artifacts.

The approved YouGlass 2.0 Glass Prism artwork is packaged in the Icon Composer resource, the fallback ICNS, and the source preview PNG. Unrelated legacy artwork is not part of the YouGlass resource set.

## Validation checklist

After a UI-affecting change, rebuild the staged app bundle with `./script/build_and_run.sh --verify` and inspect the actual window. Cover Home, Library, player controls, `⌘K`, Settings Accent/Recommendations, and a relaunch. For visual Theme Center work, verify every family exposes both Light and Dark colors and that the Appearance page scrolls through the expanded catalog. When the player ambient boundary is touched, test all 24 families in both color schemes.
