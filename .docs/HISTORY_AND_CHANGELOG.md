# YouGlass local history and change record

This file records durable project context, not every line edit. The local Git history remains the authoritative detailed record.

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
