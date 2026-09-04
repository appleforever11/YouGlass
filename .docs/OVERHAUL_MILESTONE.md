# YouGlass overhaul milestone

## 2026-09-04 — bold browsing redesign

- User selected the bolder redesign direction. Local restore tag: `safety/before-redesign-20260904`, pointing to `7461193`. Source archive and staged app copy: `backups/YouGlass-before-redesign-20260904/`. This backup contains no exported runtime credentials; Keychain and user defaults were not copied or changed by the backup.
- Home now has a dashboard with Watch Later, Library, and Subscriptions shortcuts, a full-width cinematic spotlight, and adaptive 260-point-minimum video grids. The old hero recommendation rail is removed from presentation only; queue ingestion and autoplay are unchanged.
- Library provides Overview, Saved, Liked, Collections, and Notes tabs. Dedicated Saved/Liked/Notes tabs show all available items rather than preview caps. Local multiword title/channel search uses `YouGlassLibrarySearch` and preserves catalog order without network calls; unrelated feed candidates are excluded from its input.
- Card typography, persistent themed surfaces, section headings, metadata separators, Settings branding/grouping, and the player queue surface were refined. Minimal-width Home puts secondary actions in an overflow menu. The empty Library note sheet now has a dismissal action.
- Runtime QA caught cross-section scroll-position retention; feed viewport identity now follows the navigation section, not changing recommendations.
- Validation: 66 tests passed; staged signed app build/launch verified. Computer Use confirmed Home in dark/light modes, adaptive cards at a smaller window size, Library tabs and matching local search results, Home-to-Library opening at the top, Settings General and Appearance top alignment, and theme-card access through the scrollbar. Wheel scrolling in Settings was not established by the automation; the scrollbar moved correctly. Queue visual verification was interrupted by concurrent live app interactions, so it remains an explicit follow-up. No remote publication performed.

## 2026-08-28 — reliability, responsiveness, and recovery baseline

This milestone begins the broad app overhaul requested after the player/settings polish work. It deliberately starts with cross-cutting behavior that can make every surface feel unstable: stale asynchronous loads, unclear connection state, unnecessary image work, and motion that ignores accessibility preferences.

### Safety restore point

Before source edits began, the staged `dist/YouGlass.app`, the committed source tree, and the pre-existing dirty-worktree patch were saved here:

`backups/YouGlass-pre-overhaul-20260828T152754Z/`

The checkpoint records:

- branch: `codex/theme-center`
- source commit: `59eb5efe6eeecb5d1f9b1f081b675e791aa43afb55`
- app version: `1.13.4` (`113004`)
- bundle: `com.kevinhowe.YouGlass`
- arm64 app archive SHA-256: `8969223b678d5c100f042cc1ca31d1b0d660f343c2a94c4922167d7e7a1e0e29`
- committed-source archive SHA-256: `5fbc5966c7c3e13cc8d944368d81a508d63e834dbe6d68b6b4fea239f13336f3`
- dirty-worktree patch SHA-256: `1d0c168959aa87831a57a13012b7e8249a6e4b2b9fe2929d5c93749239e56827`

`RESTORE_POINT.txt` in that directory contains the exact restore instructions. The `backups/` directory is ignored and must remain local.

### First overhaul batch

- Added `YouGlassConnectionMode` so Home and empty states use stable Offline, Syncing, Connected, Setup Required, or Local Mode labels instead of exposing a long, layout-breaking diagnostic string as primary chrome.
- Added a compact Home connection-status capsule with accessibility help and a detailed diagnostic available on demand.
- Made Home refresh controls visibly show progress and reject duplicate refresh presses while a load is active.
- Added generation/cancellation guards for Home section navigation, search, account refresh, channel loading, playlist loading, and non-playable-card resolution. A slow request can no longer publish into a newer page or clear its loading state.
- Made remote image loads cancellation-safe and coalesced duplicate thumbnail/avatar downloads while a render pass is in flight. The in-memory image cache remains bounded.
- Switched the subscription sidebar list to `LazyVStack` so large accounts do not eagerly construct hundreds of rows and avatar requests.
- Made Home card hover scaling and ambient parallax honor both macOS Reduce Motion and the YouGlass ambient-motion preference.
- Stabilized the Home and player ambient backdrops instead of continuously animating full-window gradients. Sampling showed the previous animation repeatedly spent the main thread in SwiftUI gradient/ColorSync rendering; the stable palette keeps the visual treatment while leaving CPU available for WebKit playback and interaction.

### Validation evidence

- `./script/test.sh`: 45 tests passed in the final verification run.
- `./script/build_and_run.sh --verify`: passed after the final source batch and produced a signed staged app bundle.
- Runtime smoke check: Home opened with `For You` first; Settings > Appearance scrolled to the end; Settings > General opened top-aligned with its headers visible. The app process remained running after the UI automation service briefly timed out while changing windows.
- Current redacted diagnostics showed normal player/feed events and no crash or fatal event. Public comments remained unavailable because local YouTube API credentials were not configured; this is a separate account/setup concern, not a renderer crash.
- Idle Home sampling after the stable-ambience change remained at 0% CPU across five one-second samples, compared with roughly 38–54% while the animated gradient was active.

## 2026-08-29 — YouGlass 2.0 identity and Theme Center

- The approved Glass Prism icon is now the release identity in both the layered Icon Composer source and the packaged ICNS fallback. Unrelated legacy artwork has been removed.
- Theme Center is now a 24-family catalog with paired Light/Dark previews, searchable collections, stable metadata, NEW/FEATURED badges, and Surprise me browsing. Existing theme identities remain compatible with persisted settings.
- Version metadata, README, changelog, release notes, internal knowledge base, and the public screenshot contract are aligned to 2.0.0.
- The release smoke check covers the rebuilt Home and Settings surfaces; the full 24-family Light/Dark player sweep remains a release QA target when the player boundary changes.

### Next review targets

Continue the overhaul in small verified batches: player interaction polish and frame stability, settings consistency, bounded network/image work, local-data resilience, and release-quality packaging. Each batch should preserve the restore point, run focused tests, rebuild the staged app, and add a local-only commit before moving on.

## 2026-08-30 — desktop experience revamp

- Replaced borrowed YouTube sidebar branding with the packaged YouGlass icon and product identity.
- Made the featured Home card an actual command surface with Play, Queue, and Save actions; removed inert carousel indicators; added richer section context and consistent pointer feedback to video, continue-watching, navigation, and subscription surfaces.
- Added explicit global-search focus with `Command-L`, a visible focused state, clear/run controls, richer no-results and empty-section recovery, and stable accessibility identifiers for runtime verification.
- Expanded the command palette with Search, Settings, and Resume commands, made it claim modal focus after mounting, guaranteed Escape dismissal, and deferred each action until after the overlay is removed.
- Added feature-keyword search across all ten Settings pages, including recoverable unmatched-query states that do not mutate settings.
- Added a distinct Play Next queue operation that inserts directly after the active cursor and preserves the insertion at the bounded queue limit.
- Added focused policy/search regression coverage in `DesktopExperienceTests` rather than enlarging the general model-test suite.

### Validation evidence

- `DesktopExperienceTests`: 4 focused queue/search tests passed.
- `./script/test.sh`: all 57 tests passed, including the established captions, autoplay, no-Shorts, credential-identity, bridge, and crash-diagnostic coverage.
- `./script/build_and_run.sh --verify`: passed and produced the staged `dist/YouGlass.app`; `codesign --verify --deep --strict` accepted the bundle and the rebuilt process remained running with no error/fault log entries during the post-build diagnostic window.
- The final visible Home/command/Settings/player interaction pass could not run because the Mac locked before Computer Use attached. These surfaces remain intentionally unclaimed as runtime-verified until an unlocked session is available.
