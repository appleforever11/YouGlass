# YouGlass 3.0 — architecture and experience

## Direction

The user selected a bold, cinematic, distinctive, immersive redesign on September 19, 2026. Artwork, readable typography, and clear actions lead the experience. Existing Light/Dark families and accent choices remain supported. Motion is purposeful and respects Reduce Motion; ambient surfaces remain stable during playback.

This document separates implemented foundations from the remaining release work. The current development bundle is not a finished 3.0 release and retains its existing release identity.

## Implemented foundation

- September 29 browsing pass: native Liquid Glass shared surfaces with accessibility/older-OS fallbacks, floating navigation, quieter chrome, shorter theme-aware spotlight, recommendation-source status and browser-session setup guidance.
- Homepage recommendations preserve YouTube's exact sequence; local ranking applies only to fallback sources. Signed-in live source validated after the user connected the browser session. Modern bylines keep channel identities.
- Recommendation composition is isolated in `HomeRecommendationContent`. Thumbnail haptics reuse the document-coordinate pointer bridge and a small AppKit performer; physical trackpad feedback is not remotely verifiable.

- Startup now calls explicit restoration and runtime-connection phases. `YouTubeStoreRestoration` owns durable decoding and stable defaults keys; `YouTubeStoreRuntime` owns network monitoring and authentication observers. The central store remains the compatibility facade.
- Sidebar destinations use a typed catalog instead of positional five-field tuples; labels, symbols, and grouping have one source of truth.
- `YouGlassBrowseToolbar` owns search and destination actions independently of the feed document. Secondary appearance, notification, and settings actions live in its overflow menu; command palette and account access remain visible.
- `YouGlassRefreshDestination` resolves refresh behavior without services or UI dependencies. The toolbar, application menu, and command palette execute the same store action. Command-R now has a real application command. Local destinations and open detail surfaces cannot accidentally refresh the obscured Home feed.
- Home introduces an editorial heading, direct resume action, compact personal-destination menu, and a larger featured stage with stronger typography and directional contrast.
- Existing navigation, persistence identifiers, theme identities, bounded caches, content policy, and playback ownership remain in place.

## Architecture migration

| Area | Existing constraint | Target boundary | Completion evidence |
| --- | --- | --- | --- |
| Navigation | Display strings and several selections describe one destination | Typed route carrying channel, playlist, custom feed, or group identity; one transition coordinator | Race tests switching destinations during delayed requests; correct viewport identity |
| State observation | One broad ObservableObject invalidates unrelated surfaces | Feature-owned browsing, library, appearance, account, and playback state behind the existing facade | Measured reduction in unrelated body updates; no duplicate player owner |
| Startup | Restoration and services were intertwined | Explicit restoration followed by runtime connection, then injectable dependencies | Isolated defaults and service fakes; no test touches production credentials |
| Requests | Independent cancellation/generation fields across extensions | Shared request lifecycle abstraction with per-feature ownership | Late response cannot publish after navigation, sign-out, or replacement |
| Persistence | Multiple bounded UserDefaults values | Versioned repositories preserving current identities and decoding | Fixture migrations, corrupt/truncated recovery, queue/checkpoint bounds |
| Services | Concrete clients and singleton bridges | Narrow protocols around existing clients, explicit session/account scope | Deterministic offline, quota, timeout, and cancellation tests |
| Presentation | Layout and action routing mixed in view extensions | Dedicated feature roots, semantic design tokens, explicit actions | Compact/wide runtime inspection, keyboard and accessibility checks |
| Delivery | Existing signed bundle and Sparkle flow | Same trusted pipeline with repeatable release gates | Release tests, signature validation, migration rehearsal, local packaged artifact |

Migrate one boundary at a time. Do not replace working WebKit or persistence code merely to make every file look new. Each migration needs before/after behavior evidence and a coherent local commit.

## Experience plan by surface

| Surface | 3.0 intent | Acceptance criteria |
| --- | --- | --- |
| Home | Cinematic featured stage, quieter chrome, immediately useful resume and discovery | First playable content remains easy to reach; all loaded rows accessible; stable hover targets |
| Navigation | Clear Browse, Your Library, and Channels hierarchy; coherent compact rail | Visible selected destination; icon-only controls named; keyboard paths match click paths |
| Search | One focused search experience with explicit pending, empty, offline, and failure states | Search cannot be replaced by an older request; Shorts remain excluded |
| Library | Personal workspace for saved videos, collections, notes, and checkpoints | Local search stays local; no destructive migration; actions and empty states are specific |
| Channels and feeds | Consistent identity headers, filters, and contextual actions | Group membership remains stable; refresh never switches destination |
| Watch | Video-led stage, readable metadata, intentional queue and discussion hierarchy | Existing single playback owner, native scroll boundaries, captions, PIP and fullscreen survive |
| Settings | Preview-led appearance controls and clear preference grouping | Scroll opens at top and stays user-controlled; live choices retain persisted identities |
| Commands | Searchable actions with accurate availability and shortcuts | No unavailable refresh action; Escape and keyboard selection work consistently |
| Recovery | Useful cached content with actionable connection status | Offline never erases local data; retry remains bounded and quota-safe |

## Design system work

Consolidate spacing, corner radii, typography, media aspect ratios, and control sizes into semantic tokens after validating the first browsing pass. Distinguish background, content surface, raised controls, and modal surfaces. Keep information legible without color alone. Avoid applying new clipping, animation, or geometry readers around the player bridge.

Evaluate both supported color schemes, increased contrast, reduced transparency, Reduce Motion, long titles, missing thumbnails, empty collections, narrow windows, and large subscription lists. A design is complete only when the corresponding runtime interaction has been exercised.

## Release gates

1. Complete the architecture migrations above with behavioral tests, rather than counting moved files as a full refactor.
2. Validate browsing at the minimum supported window size and a wide desktop size, including scrolling, search focus, menus, and hover.
3. Validate playback start/resume, queue progression, captions, speed, mini-player, PIP, fullscreen, and return to browsing. Player ambient changes require the existing 24-family Light/Dark matrix.
4. Exercise account boundaries, offline restoration, stale requests, quota cooldown, interrupted loads, and bounded persistence with isolated fixtures.
5. Capture comparable launch, browsing, and playback CPU/memory measurements. Establish budgets from those measurements; do not claim performance gains from structural changes alone.
6. Run the project tests and build/signature verification. Inspect the rebuilt bundle using Computer Use.
7. Set the 3.0 release version only after the release scope and gates are complete. Publishing remains a separate explicit user action.
