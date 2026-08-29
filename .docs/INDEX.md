# YouGlass internal knowledge base

This directory is the tracked, non-skill reference layer for the project. `AGENTS.md` contains the binding project workflow; these files hold the detail an agent needs to work without relying on chat history.

## Documents

- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) — product scope, runtime boundaries, toolchain, persistence, and current project state.
- [BUILD_AND_RUN.md](BUILD_AND_RUN.md) — exact dependency, test, debug, packaging, signing, and runtime validation commands.
- [ARCHITECTURE.md](ARCHITECTURE.md) — SwiftUI/AppKit structure, state ownership, data flow, and platform safety boundaries.
- [PLAYER_HOVER_CONTROLS.md](PLAYER_HOVER_CONTROLS.md) — transient native-player controls, caption placement, and runtime validation notes.
- [FEATURES_AND_WORKFLOWS.md](FEATURES_AND_WORKFLOWS.md) — the eight product foundations, their source boundaries, persistence, and smoke-test expectations.
- [THEME_CENTER_2_0.md](THEME_CENTER_2_0.md) — the 2.0 theme catalog, collection metadata, browser controls, compatibility, and QA contract.
- [ICON_AND_DOCKDOOR.md](ICON_AND_DOCKDOOR.md) — shipped icon resources, LaunchServices refresh behavior, DockDoor cache evidence, and cross-Mac update expectations.
- [OVERHAUL_MILESTONE.md](OVERHAUL_MILESTONE.md) — the current app-overhaul baseline, safety restore point, validation evidence, and next review targets.
- [HISTORY_AND_CHANGELOG.md](HISTORY_AND_CHANGELOG.md) — local Git baseline, dirty-worktree notes, durable investigations, and instructions for recalling or reverting work.

## How to use this directory

1. Read `AGENTS.md` first.
2. Read this index and only the reference files relevant to the task.
3. Verify drift-prone facts such as the current branch, build output, SDK, and runtime behavior locally.
4. Update the relevant file when a durable project fact changes, and add a dated history entry for meaningful work.

## Related project material

- `README.md` is user-facing installation and release documentation.
- `CHANGELOG.md` and `RELEASE_NOTES/` describe shipped versions.
- `.codex/YOUGLASS_SESSION_RECOVERY.md` is local recovery metadata and may be useful for historical context, but it is ignored and is not application source.
- `docs/` contains public screenshots.
- `backups/` contains local recovery artifacts. Compare them with Git before using them.
