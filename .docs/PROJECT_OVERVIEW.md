# YouGlass project overview

## Identity and scope

YouGlass is a native Apple Silicon macOS YouTube client. It combines a SwiftUI desktop shell, native navigation, an in-app player, desktop Picture in Picture, account-aware feeds, YouTube API/OAuth integration, local playback state, and Sparkle updates.

The app supports macOS 14.0 and later. The current development host is Apple Silicon running macOS 26.6.2 with Swift 6.4 and Xcode 27.0. The package resolves Sparkle 2.9.5.

The repository is a SwiftPM executable package. The product is `YouGlass`; the executable target is `YouTubeMac`. The app bundle staged for local development is `dist/YouGlass.app`.

## Runtime boundaries

- YouTube Data API calls are handled by `YouTubeAPIClient`.
- OAuth client credentials and tokens are handled by `YouTubeOAuthClient` and stored through the macOS Keychain path used by the app. `YouGlassCredentialStore` owns the stable YouTube Data API key identity, uses both preferred data-protection and login-Keychain compatibility storage, and migrates the legacy service without placing the key in source, diagnostics, Git, Sparkle, or project documentation.
- Visible browser sign-in and session behavior are handled by `YouTubeBrowserWindow`.
- WebKit is used for the visible playback surface and selected compatibility bridges. Hidden metadata bridges are controlled by the runtime stability policy and are disabled by default on macOS 26 and later.
- Local preferences, caches, playback checkpoints, saved videos, and account flags use `UserDefaults` through `YouTubeStore`.
- Redacted diagnostics and session breadcrumbs live under `~/Library/Application Support/YouGlass/Diagnostics` and are exported by the settings debug controls or `script/export_debug_report.sh`.
- Sparkle reads the signed appcast configured in `Sources/YouTubeMac/Info.plist` for stable update checks.

## Current UI model

The main app uses a `WindowGroup` with a shell/sidebar and content surface. The app exposes a separate `Settings` scene with a native sidebar/detail layout. Settings pages are selected by `YouGlassSettingsPage` and rendered by `YouGlassSettingsView`.

Home also includes a native Custom Feeds layer. Users can save up to eight local prompt definitions, inspect the interpreted scope, and retrieve fresh results through the existing YouTube API/OAuth/Atom boundaries. The default prompt parser is local and deterministic; candidate results remain transient, and the global Shorts exclusion still applies.

The Appearance page contains:

- a page header;
- color mode and ambient-glass controls;
- the selected theme summary;
- a 24-family Theme Center with paired light/dark previews, collection filters, search, NEW/FEATURED badges, and Surprise me;
- an AppKit-backed scroll view because the private SwiftUI hosting scroll path has been unstable on the current macOS 27 beta/runtime. The bridge measures the `NSHostingController` document at the viewport width, keeps the page at the visual top, and preserves native scrolling through the entire catalog.

The settings scroll bridge keeps every detail page top-aligned while preserving real scrolling. Its AppKit boundary uses a stock `NSScrollView` and `NSHostingController.sizeThatFits(in:)` to give the document its actual content height; it resolves the visual top from the document view's coordinate system and resets only when the selected page changes. The SwiftUI document root is explicitly top-leading aligned.

## Current Git state and local baseline

- Branch: `codex/theme-center`
- The current local baseline includes the settings-scroll repair, smooth player ambience, local-first library/player workspace, cached/offline feed improvements, and command/theme foundations. Use `git log --oneline --decorate` for the exact milestone hashes; remote state remains separate.
- Remote state is separate from local history. Inspect `git status --short` and `git log --oneline --decorate` before making a new change; never assume a local commit has been pushed.
- The iCloud-visible project path and the resolved Git path are equivalent on this machine. Prefer the resolved Git root for diagnostics and file links.

## Recovery and archive rule

The Git source tree is authoritative. Local build archives and the `backups/` restore point are references only. The current recovery note identifies an equivalent historical workspace and older verified release artifacts; compare source files and commit dates before restoring anything.
