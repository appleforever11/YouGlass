# YouGlass local history and change record

This file records durable project context, not every line edit. The local Git history remains the authoritative detailed record.

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
