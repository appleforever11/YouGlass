# YouGlass local history and change record

This file records durable project context, not every line edit. The local Git history remains the authoritative detailed record.

## 2026-08-29 — refresh app icon registration after Sparkle updates

- Added a best-effort `NSWorkspace` LaunchServices refresh during every app launch, which also covers the relaunch after Sparkle installs an update. The refresh uses the running bundle path and records only the bundle/build icon metadata in diagnostics.
- Documented that external dock applications can keep a separate icon preview cache. On this Mac, DockDoor's pinned YouGlass entry resolves the current `dist/YouGlass.app` by bundle ID/path with no custom icon override; restarting DockDoor caused it to display the current Glass Prism icon.
- Cross-Mac guarantee: the signed Sparkle archive contains the new Icon Composer/ICNS resources and YouGlass prompts LaunchServices to re-read them, but YouGlass cannot directly invalidate DockDoor's private cache. DockDoor may still need to refresh/restart itself.
- Validation: current 2.0.0 bundle metadata and icon resources were inspected; DockDoor was restarted and its pinned preview visibly changed to the current icon. Full build/test validation follows this patch.

## 2026-08-29 — lower expanded captions beside the hover controls

- Reduced only the normal-player control-visible caption inset from 178 to 110 points so captions remain close to, and clearly above, the transport shelf when it returns on hover.
- The lower resting inset and all compact/PIP caption constants remain unchanged.

## 2026-08-29 — keep main-player captions visible through hover dismissal

- Decoupled the normal-player native caption surface from transport visibility. The caption view now stays mounted and text-driven while hover only changes its bottom inset, so the current line remains visible after the playback controls fade and lifts above them on re-hover.
- Hosted the expanded caption above the AppKit-backed WebKit representable at the watch-layout level, avoiding remote-layer occlusion when the transport fades. Hardened playback-message handling so an intermediate `captionsEnabled: false` read or empty disabled poll without an explicit caption-off/no-track status cannot clear the current native line. Explicit off/no-track states and empty active-track updates still clear it normally.
- PIP layout and interaction behavior remain unchanged; its existing lower resting caption inset and transient control shelf are preserved.

## 2026-08-29 — begin the YouGlass 2.0 release milestone

- Promoted the app metadata to 2.0.0 (build 200000) for the major product relaunch. Theme Center now contains the original 12 environments plus 12 new paired Light/Dark families, with collection filters, search, NEW/FEATURED badges, result counts, an empty state, and Surprise me navigation.
- Integrated the approved Glass Prism identity into the Icon Composer source, packaged fallback ICNS, and preview artwork. Removed the unrelated legacy icon resource from the project resource set.
- Kept the 2.0 presentation layer compatible with the established `visualTheme` persistence contract: existing selections and palette behavior remain stable while the catalog and browsing metadata expand around them.
- Validation: `./script/test.sh` passed all 47 tests; `./script/build_and_run.sh --verify` passed and produced the 2.0.0 staged bundle. Computer Use opened the rebuilt app, confirmed 2.0.0 in Settings > General, confirmed the Appearance page is top-aligned with `Theme Center 24 of 24 environments`, and reached the final new-theme rows through the native scroll action. A Home smoke check showed `For You` first and the conditional Continue Watching behavior intact.

## 2026-08-29 — remove YouTube Shorts from YouGlass

- Removed the Shorts navigation route and recommendation preference. A shared `YouGlassContentPolicy` now excludes Shorts from API, WebKit, Safari, channel, recommendation, search, direct-open, playback, queue, and presentation boundaries.
- Existing known Short entries are removed from local feed/history/save/like/queue caches and related playback, collection, note, and recommendation-seed references during load/write migration. This does not modify the user's YouTube account data.
- Because the YouTube Data API does not provide a reliable Shorts flag, API filtering uses title markers while WebKit/channel extraction also rejects Shorts URLs and reel renderers.

## 2026-08-28 — stabilize the command palette surface

- Added an opaque, theme-colored base to the command palette and kept the surrounding scrim theme-aware. The command list remains readable when the app's translucent window is over Home content or another desktop window, while the normal glass treatment returns after dismissal. Moved the modal overlay outside the horizontal Home shell so it centers in the full window instead of being laid out at the trailing edge. Command rows now receive a visible accent-backed hover highlight and become the active keyboard selection when hovered.
- Rebuilt and inspected the staged `dist/YouGlass.app`; the palette opened from the toolbar without exposing the underlying Home feed through its panel. `./script/test.sh` passed all 45 tests and `./script/build_and_run.sh --verify` passed.

## 2026-08-28 — make compact PIP controls transient

- Fixed the compact desktop PIP window shelf and bottom playback transport so both honor the player hover state. They reveal immediately on hover, fade after a short pointer-exit grace period, and stop intercepting pointer input while hidden so the PIP surface remains draggable.

## 2026-08-28 — lower captions in compact PIP

- Compact/PIP captions now use a lower resting inset when the transient controls are hidden, then animate back above the playback shelf when the pointer returns. This keeps captions from floating too high in the clean PIP frame while preserving clearance from the controls during interaction.

## 2026-08-28 — isolate the full-player surface from Home

- Added an opaque theme-colored base inside `PlayerAmbientSurface`, the root ambience layer behind the full player. Existing translucent gradients and materials still provide the themed flow, but the Home feed can no longer show through the clear portions of the player overlay.
- Runtime validation of the rebuilt `dist/YouGlass.app` confirmed the player surface stays self-contained in the light theme, with no Home headings or recommendation cards visible beneath the watch page. `./script/test.sh` passed all 45 tests and `./script/build_and_run.sh --verify` passed.

## 2026-08-28 — begin the cross-cutting app overhaul

- Captured the pre-overhaul staged arm64 app, committed source archive, and dirty-worktree patch in `backups/YouGlass-pre-overhaul-20260828T152754Z/`; `RESTORE_POINT.txt` records the verified hashes and restore procedure.
- Added stable connection-state UX, cancellation/generation guards for navigable async work, cancellation-safe and coalesced image loading, lazy subscription rendering, and Reduce Motion support for Home ambience and card hover.
- Stabilized the full-window Home/player ambience after runtime sampling showed the continuously animated gradient consuming roughly half a CPU core while idle. The palette remains themed and video-responsive without a perpetual render loop.
- Runtime validation confirmed Home's `For You` ordering, end-to-end Appearance scrolling, and top-aligned General settings. The rebuilt app remained running with no new crash diagnostic.

## 2026-08-28 — make native player controls follow hover state

- Normal-player transport chrome now starts hidden, appears when the pointer enters the media surface or the player is explicitly interacted with, and fades after pointer exit. Compact/PIP transport remains independently available.
- Native captions share the transport visibility state: they sit above the controls while the shelf is visible and animate into a lower resting position as the controls dismiss, avoiding captions colliding with or floating unnecessarily far above the media controls.
- Validation: `swift build --product YouGlass`, `./script/test.sh` (43 tests), and the rebuilt `dist/YouGlass.app` runtime smoke check passed; the live player showed controls plus captions on hover and a clean media frame after hover ended.

## 2026-08-28 — shorten hover-exit dismissal

- Reduced the normal-player pointer-exit grace period from 0.55 seconds to 0.12 seconds. The controls and caption inset still use the coordinated fade, but the media frame returns to its resting state much sooner after hover ends.
- Validation: `git diff --check`, `./script/test.sh` (43 tests), and `./script/build_and_run.sh --verify` passed against the rebuilt staged bundle.

## 2026-08-28 — make hover re-entry and dismissal immediate

- Reduced the remaining edge grace period to 0.04 seconds and shortened the coordinated control/caption transition to 0.08 seconds. Re-hover now restores the controls and caption position quickly while pointer exit returns to the clean media frame almost immediately.
- Validation: `git diff --check`, `./script/test.sh` (43 tests), and `./script/build_and_run.sh --verify` passed against the rebuilt staged bundle.

## 2026-08-27 — render captions in the native player surface

- Kept YouTube responsible for caption-track selection and timing, but moved visible caption presentation into a SwiftUI layer above the WebKit media surface. The bridge now sends changed active-track text to the native player, which clears it when captions are disabled and positions it above the transport controls.
- This avoids the hidden/remote WebKit caption compositing path that left the caption button active while no words appeared on-screen. The selected-track fallback remains scoped to the active media player and missing tracks remain ordinary caption status.
- Caption-only bridge messages no longer reset `isSurfaceReady`; this prevents the decoded WebKit frame from flickering back to the thumbnail whenever subtitle text changes.
- Validation: `swift test --disable-sandbox` passed all 43 tests, `./script/build_and_run.sh --verify` passed, and the rebuilt player displayed live caption text on a ready video while the caption control remained active; an eight-sample live check confirmed the WebKit frame stayed visible during caption updates.

## 2026-08-27 — restore captions and polish playback speed selection

- Scoped caption discovery to the active WebKit media/player instead of the first page-level subtitle button. Caption toggling now tries YouTube's native control, then its player caption API when a hidden DOM click is ignored; missing caption tracks remain a normal caption status and cannot trigger playback retry UI.
- Replaced the raw system speed menu with a themed popover that uses readable `0.75×`, `Normal`, `1.25×`, `1.5×`, and `2×` labels, descriptive pace hints, an active checkmark, and a compact current-rate indicator in the player header.
- Validation: `./script/test.sh` passed all 41 tests, `./script/build_and_run.sh --verify` passed, and the rebuilt bundle toggled captions on/off and applied 1.5× playback in the live player.

## 2026-08-27 — extend the outer player page beyond comments

- Kept the comments panel as its own bounded 360-point AppKit scroll box and added a reachable trailing document inset after it. The outer watch-page scroll can now move a little farther when the pointer is outside the comments box, leaving the lower page content and stopping area accessible without changing inner comment scrolling.
- Replaced the full-player SwiftUI `GeometryReader` size path with a small AppKit size reader and kept the watch hierarchy mounted during resize. This avoids the macOS 26 presentation crash observed while SwiftUI copied the geometry/scroll hierarchy. The Home indicator ranges were also made stable arrays for the same `ClosedRange` copy failure path.
- Validation: `./script/test.sh` passed all 40 tests, `./script/build_and_run.sh --verify` passed, and the rebuilt player accepted an outer-page scroll from approximately 0.82 to 1.00 while the process remained running.

## 2026-08-27 — stop player scroll crashes and isolate comments scrolling

- The supplied runtime reports showed repeated `EXC_BAD_ACCESS` failures during SwiftUI `initializeWithCopy for ScrollView` work in the player view graph, including the mounted `LiveChatPanel` path. The failure appeared after adding a nested comments scroller and was reproducible when launching the staged bundle on macOS 26.6.2.
- Added the small `YouGlassBoundedScrollView` AppKit bridge and moved the watch-page, comments, compact related rail, live chat, and queue scroll surfaces onto stock `NSScrollView` instances with hosted SwiftUI content. Comments retain a bounded 360-point viewport; Up Next remains intrinsic-height in the outer page document.
- A clean Swift package rebuild was required because stale opaque-result metadata continued to contain the removed SwiftUI scroll types. The rebuilt `dist/YouGlass.app` stayed running, opened the native player, and accepted a real downward page scroll without a new diagnostic report. `git diff --check`, `./script/test.sh` (40 tests), and `./script/build_and_run.sh --verify` passed.

## 2026-08-27 — bound bridge extraction work and organize Swift sources

- Reduced avoidable WebKit bridge work: comments loading no longer scans every page element or dispatches two click events for one continuation control; comments extraction caches shadow-root search roots, reuses continuation queries, and avoids rescanning the DOM while a continuation request is pending. Feed extraction now avoids normalizing each card anchor twice.
- Moved the remaining root-level Swift files into `Models/`, `Services/`, `Views/Home/`, and `Views/Shared/`. Split `YouTubeHomeView` into root, content, and compact-player files; the root view is now 111 lines. Theme catalog data and visual ambience remain separate because they have distinct model/rendering responsibilities.
- Added bridge payload decoding/mapping, merge, ID validation, and script-regression tests. The comments script builder now uses `JSONEncoder` for continuation-token literals so quoted tokens cannot trigger `JSONSerialization` top-level-string failure.

## 2026-08-27 — place For You before Continue Watching on Home

- Reordered the Home recommendation rows so `For You` is the first section below the hero and the enabled/populated Continue Watching row follows it. Continue Watching remains conditional on the user's visibility setting and real playback checkpoints.

## 2026-08-27 — let long player titles use the full header width

- Removed the artificial 640-point title cap and redundant spacer from the expanded-player header. The title now uses the flexible area between the close button and the fixed action shelf, preventing premature wrapping and left-side compression while preserving the title-first themed hierarchy.
- Rebuilt and opened `dist/YouGlass.app`; the native smoke check confirmed a long title expands across the header without colliding with the control shelf, while the player rail remains populated. `./script/test.sh` passed all 32 tests.

## 2026-08-27 — strengthen the expanded-player title hierarchy

- Reworked the shared player header title block so the video title is the primary visual anchor: it is larger, heavy-weight, and filled with a gradient derived from the active theme. `NOW PLAYING` now sits immediately below the title in the theme accent, while the channel remains subdued; the detail title below the media is unchanged.
- Rebuilt and opened `dist/YouGlass.app`; the native smoke check confirmed the title-first ordering, themed color treatment, readable wrapping, smooth header shelf, and ten-item Up Next rail. `./script/test.sh` passed all 32 tests.

## 2026-08-27 — blend the player header into the watch page

- Removed the independent page-start and header lower-edge rectangles. A single low-contrast watch-screen fade now sits behind the fixed header and scroll document, allowing the media halo to transition continuously into the header while retaining the small top inset needed to keep the perimeter glow visible.
- Rebuilt and opened `dist/YouGlass.app`; the native smoke check confirmed the highlighted band is a soft surface transition, the header shelf remains smooth, and the ten-item Up Next rail is unchanged. `./script/test.sh` passed all 32 tests.

## 2026-08-27 — remove expanded-player title-bar cap and smooth header controls

- Enabled the main SwiftUI window's full-size content region with a transparent hidden title bar and made expanded player mode use a zero top shell inset. The custom player header now reaches the window edge instead of sitting below a separate dark AppKit strip; regular feed mode keeps its original inset.
- Replaced the expanded-player header's mixed capsule/circle chrome with one continuous rounded glass control shelf and consistent pressed states, spacing, typography, and hit targets.
- Rebuilt and opened `dist/YouGlass.app`; the live native smoke check confirmed the cap was gone, the header shelf was smooth, and the player still exposed all ten Up Next items. `./script/test.sh` passed all 32 tests.

## 2026-08-27 — repair full-player edge flow, controls, and scrolling

- Made the watch header part of the shared ambient surface by masking its material and fading the lower edge instead of drawing a hard divider. The media receives matching top breathing room, a shared 24-point media/WebKit/native radius, and centered ambient/neutral perimeter shadows.
- Centered the five primary playback controls against the media frame itself. Status text and PIP remain trailing secondary chrome, so their width no longer shifts the Play cluster to the left.
- Reduced the wide watch page to one vertical scroll owner. Comments and the ten-item Up Next rail render as intrinsic-height stacks; the comments panel has a small bounded minimum so its fallback/API states participate in the page document instead of disappearing below a short scroll range.
- Expanded the recommendation fallback to merge sparse API results with the loaded local/history/saved catalog, preventing Up Next from collapsing to a single card.
- Runtime evidence after rebuilding `dist/YouGlass.app`: the rebuilt player shows centered transport controls, a seamless header-to-page transition, a populated ten-item Up Next rail, and a bottom scroll position with the comments heading/message reachable. `git diff --check`, `./script/test.sh` (32 tests), and `./script/build_and_run.sh --verify` passed.

## 2026-08-27 — product foundation milestone: eight app improvements

- Added a local-first Continue Watching flow with bounded playback durations, a persistent queue with autoplay, and a Library for Watch Later, local likes, named collections, and timestamped notes.
- Added a stronger player workspace: queue panel, next/previous navigation, playback-rate menu, mini-player/full-screen actions, native Share, macOS Now Playing/media-key commands, and Dock actions.
- Added a `⌘K` command palette plus app-menu and keyboard shortcuts for navigation, refresh, playback, queue actions, themes, and window controls.
- Added Home recommendation controls for Continue Watching visibility and Shorts filtering, with cached/offline feed behavior, cached thumbnails, and a network status indicator.
- Added an Appearance accent editor that persists a validated hex accent through the shared `Palette` without replacing the selected theme family.
- Validation before documentation cleanup: `./script/test.sh` passed with 32 tests and the source-size check remained clean. The final rebuilt-bundle smoke pass is recorded with the milestone commit below.

### Follow-up visual correction

- Moved the Continue Watching progress track to the bottom of each thumbnail and made it conditional on a real, unfinished playback checkpoint with a known duration. The measuring `GeometryReader` had been constrained on its child instead of on the reader itself, which caused a translucent track to render at the top of every card; unwatched or duration-less cards now render no resume track at all.
- Rebuilt `dist/YouGlass.app` and verified Home, Library, Settings General, Settings Appearance top alignment, Appearance bottom scrolling, and the native player workspace with Computer Use. The corrected Home capture shows no top bars.

## 2026-08-27 — smooth player theme flow and safe video opening

- Removed the opaque watch-page fills and duplicate outer media clip that made the player ambience stop abruptly at the video/page boundary. The shared `PlayerAmbientSurface` now flows through the player header, page margins, metadata, and recommendation rail while only the media content is clipped.
- Added `YouTubeStore.openFromUserInteraction(_:)` and routed home/player video buttons through it. The one-turn MainActor deferral prevents the macOS 26 accessibility-press crash path observed in the supplied report while `selectedVideo` and `YouGlassVideoTitleBlock` geometry are being copied.
- Validation: `./script/test.sh` passed with 28 tests; `./script/build_and_run.sh --verify` passed; all 12 theme families in both Light and Dark opened the rebuilt player successfully and produced 24 post-fix visual captures. Preferences were restored to YouGlass Original / Dark after the sweep.

## 2026-08-27 — repair settings document sizing and scrolling

- Replaced the unstable settings document wrapper and re-entrant `NSScrollView.layout()` callback with a stock `NSScrollView` whose document is an `NSHostingController` view.
- Measure the hosted page with `NSHostingController.sizeThatFits(in:)` at the actual detail viewport width, then assign that measured height directly to the document. This prevents Appearance from being centered inside an oversized document, which previously produced a blank lower region and made scrollbar value `0` show the wrong visual position.
- Keep the SwiftUI detail root directly top-leading with its normal content height. Reset to the visual top only when the selected settings page changes; after the initial layout passes, native user scrolling owns the position.
- Runtime evidence after rebuilding `dist/YouGlass.app`: General shows its header and connection/This Mac sections without clipping; Appearance opens with its header, current environment, controls, and Theme Center aligned to the top; native scroll moves through the catalog to Solar Desk and Peach Chrome without blank space; switching General -> Appearance returns to the top.
- Validation: `./script/build_and_run.sh --verify` passed, followed by Computer Use verification of Appearance top, bottom, page reset, and native scroll behavior.

## 2026-08-27 — comprehensive source modularization

- Reorganized the app entry point, models, home window, settings window, store, native player, inline WebKit player, API client, WebKit feed/comments bridges, and debug engine into focused responsibility-based files.
- Split the inline player JavaScript into ordered script parts and kept the existing runtime behavior through a small joining facade.
- Removed the former 700+ line monoliths. Every Swift file under `Sources/` and `Tests/` is now below the 500-line maintainability target.
- Preserved the AppKit scroll-container boundary for settings and the existing native/WebKit player separation.
- Validation: `swift build --product YouGlass` passes after the complete source split.

## 2026-08-27 — settings document alignment

- Kept the settings detail root explicitly top-leading inside its AppKit-hosted document view.
- Reset the detail scroll position using the clip view's actual coordinate direction so Appearance and other pages reopen at their visual top without removing scrolling.

## 2026-08-26 — project guidance setup

- Repository resolved to `/Users/kevinhowe/Codex Projects Restored/YouGlass` from the iCloud-visible workspace path.
- Current branch: `codex/theme-center`.
- Baseline: `3a096d9` (`Prepare YouGlass 1.13.2 signed DMG release`, tag `v1.13.2`).
- Toolchain observed: Apple Silicon, macOS 26.6.2, Swift 6.4, Xcode 27.0.
- Added root `AGENTS.md` and the `.docs/` project knowledge base. The setup commit must contain only those documentation files.
- Existing dirty application work was intentionally preserved. Before the setup commit, the worktree already included settings/theme catalog work, visual/theme changes, player/feed/stability changes, and model tests. Inspect `git status` before staging anything.

## Historical settings investigation at setup

The live settings window reproduced an Appearance-page geometry bug: the detail scroll bar reported value `0`, but the Appearance content began several hundred points below the viewport. Scrolling downward worked, so the primary defect was document/root alignment rather than a missing scroll range. The corrected AppKit `NSScrollView` bridge now lives under `Views/Settings/` and should be validated against the rebuilt app bundle after future geometry changes.

## How to recall a prior change

Use local history when the user asks what changed, wants an earlier implementation, or asks for a revert:

```sh
git log --all --oneline --decorate -- Sources/YouTubeMac/YouGlassSettingsView.swift
git log --all -S'YouGlassSettingsScrollView' -- Sources/YouTubeMac/YouGlassSettingsView.swift
git show <commit> -- Sources/YouTubeMac/YouGlassSettingsView.swift
git reflog --date=iso
```

Compare the committed version with the current dirty worktree. A commit cannot show edits that have not been committed. Prefer a new patch or a named `git revert`; do not discard a dirty worktree with `reset --hard` or destructive checkout.

## Historical release context

The repository contains tagged release commits through `v1.13.2`, public release notes under `RELEASE_NOTES/`, and local build/recovery artifacts under `backups/` and `dist/`. Release artifacts are useful for comparison or recovery, but the Git source tree and current worktree are the source of truth.
