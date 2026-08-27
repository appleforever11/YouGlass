# YouGlass project overview

## Identity and scope

YouGlass is a native Apple Silicon macOS YouTube client. It combines a SwiftUI desktop shell, native navigation, an in-app player, desktop Picture in Picture, account-aware feeds, YouTube API/OAuth integration, local playback state, and Sparkle updates.

The app supports macOS 14.0 and later. The current development host is Apple Silicon running macOS 26.6.2 with Swift 6.4 and Xcode 27.0. The package resolves Sparkle 2.9.5.

The repository is a SwiftPM executable package. The product is `YouGlass`; the executable target is `YouTubeMac`. The app bundle staged for local development is `dist/YouGlass.app`.

## Runtime boundaries

- YouTube Data API calls are handled by `YouTubeAPIClient`.
- OAuth client credentials and tokens are handled by `YouTubeOAuthClient` and stored through the macOS Keychain path used by the app.
- Visible browser sign-in and session behavior are handled by `YouTubeBrowserWindow`.
- WebKit is used for the visible playback surface and selected compatibility bridges. Hidden metadata bridges are controlled by the runtime stability policy and are disabled by default on macOS 26 and later.
- Local preferences, caches, playback checkpoints, saved videos, and account flags use `UserDefaults` through `YouTubeStore`.
- Redacted diagnostics and session breadcrumbs live under `~/Library/Application Support/YouGlass/Diagnostics` and are exported by the settings debug controls or `script/export_debug_report.sh`.
- Sparkle reads the signed appcast configured in `Sources/YouTubeMac/Info.plist` for stable update checks.

## Current UI model

The main app uses a `WindowGroup` with a shell/sidebar and content surface. The app exposes a separate `Settings` scene with a native sidebar/detail layout. Settings pages are selected by `YouGlassSettingsPage` and rendered by `YouGlassSettingsView`.

The Appearance page contains:

- a page header;
- color mode and ambient-glass controls;
- the selected theme summary;
- a 12-family theme catalog with paired light/dark previews;
- an AppKit-backed scroll view because the private SwiftUI hosting scroll path has been unstable on the current macOS 27 beta/runtime.

The settings scroll bridge keeps the Appearance document top-aligned while preserving real scrolling. Its AppKit boundary resolves the visual top against the clip view's coordinate system, and the SwiftUI document root is explicitly top-leading aligned.

## Current Git state at documentation setup

- Branch: `codex/theme-center`
- Baseline commit: `3a096d9`, tagged `v1.13.2`
- The worktree already contains uncommitted theme, visual, player, feed, stability, settings, and test changes, plus new theme catalog/icon resources. Those changes belong to the existing work and should not be mixed into the initial project-docs commit.
- The iCloud-visible project path and the resolved Git path are equivalent on this machine. Prefer the resolved Git root for diagnostics and file links.

## Recovery and archive rule

The Git source tree is authoritative. Local build archives and the `backups/` restore point are references only. The current recovery note identifies an equivalent historical workspace and older verified release artifacts; compare source files and commit dates before restoring anything.
