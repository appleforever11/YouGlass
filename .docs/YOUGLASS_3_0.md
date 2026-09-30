# YouGlass 3.0 — local release

Version 3.0.0 (300001) completes the local browsing and reliability release on September 29, 2026. Publication is a separate action.

## Experience

- Floating native Liquid Glass navigation and controls on supported macOS versions, with opaque Reduce Transparency and older-system fallbacks.
- An editorial Home, shorter featured stage, immediate resume action, compact custom feeds, and explicit recommendation-source status.
- Signed-in Home ingestion preserves the sequence returned by YouTube after Shorts filtering, stable deduplication, and the 40-item bound. Separate YouTube requests can return different recommendations.
- Thumbnail-entry haptics with an 80 ms global rate bound and a persisted Playback preference. Physical sensation requires verification on supported hardware.
- Offline search uses real library, queue, and cached content. Search results never replace Home recommendations.
- Queue menus offer Play Next and adjacent reordering. Commands hide unavailable queue navigation.
- Unplayable cards report their error instead of opening an unrelated demonstration video. Notifications provide an explicit YouTube destination.
- Compact and comfortable window commands support predictable desktop sizing.
- Picture in Picture retains the existing WebKit page. Playback-only CSS neutralizes YouTube's responsive visibility and transforms so the floating video fills its viewport.

## Architecture delivered

| Responsibility | Implemented boundary |
| --- | --- |
| Navigation | Stable typed route identities and a shared transition that cancels competing destination loads |
| Search | Observable search state and an injectable service protocol; production resolves the current API client |
| Requests | Shared section request lifecycle; account-session generation checks prevent obsolete account and Home responses from publishing |
| Startup | Separate restoration/runtime connection with injectable defaults and clients; isolated tests avoid production credentials |
| Queue | Versioned repository accepting legacy payloads; stable deduplication, Shorts exclusion, 24-item bound, corrupt/future bytes retained during restoration |
| Checkpoints | Existing persistence keys retained; newest bounded entries survive and unreadable startup payloads are not overwritten |
| Presentation | Semantic window/sidebar/surface/media metrics, isolated recommendation composition, and focused AppKit window actions |

The central store remains a compatibility facade. Library, account, appearance, and playback still use their established owners; converting all of them to new observable stores is future work, not a 3.0 release claim.

## Validation and limits

The release reliability suite covers delayed responses after navigation/account changes, isolated search observation, offline matching, route identities, queue migration/reordering/bounds, corrupt/future payloads, and relaunch restoration of saved videos, collection/note identities, and playback position. The complete suite contains 125 tests.

Computer Use inspected live signed-in Home, resume playback, speed selection, mini-player, floating video/captions, return to the main surface, compact 560 × 400 browsing and scrolling, comfortable 1160 × 740 browsing, and both appearance modes. Startup and refresh did not request a Keychain password. Keychain records and access permissions remain intact; inaccessible credentials fail without authentication UI.

The macOS 27 host required a validation restart after full-screen window transitions made Computer Use lose its target. Main-window full-screen exit and subsequent browsing were inspected; this is not a claim of exhaustive Spaces or multi-display testing.

One playback snapshot used roughly 505 MB RSS and 0.1% process CPU; these point samples are not a performance benchmark or evidence of a speed improvement. Older supported macOS versions, physical haptics, every display arrangement, and a real network-disconnection UI rehearsal remain outside this host's verification.

Local release builds use ad-hoc signing because no Developer ID identity is available. A valid local signature does not establish notarization or Gatekeeper acceptance for public distribution. Public release, appcast changes, and upload remain unauthorized.

## Local artifact verification

- Final release build and all 125 tests passed. The final release bundle launched and displayed signed-in Home without a Keychain prompt.
- Bundle and extracted ZIP passed deep, strict signature verification; extracted version is 3.0.0 and the executable is arm64.
- The generated DMG passed `hdiutil verify`.
- ZIP SHA-256: `d61bf438965757d43db785b6f8d18282c15017f0c2029e6613e65c975a517c2b`.
- DMG SHA-256: `228b81c74bbe0f04ccee78f611059d6b3f4102bc63f2a47b88b3d1175680e43e`.
