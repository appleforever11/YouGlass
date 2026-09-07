# YouGlass local history and change record

This file records durable project context, not every line edit. The local Git history remains the authoritative detailed record.

## 2026-09-06 — Xcode 27 Home refresh and theme tint

- Rebuilt the local optimized app using the installed Xcode 27.0 build 27A5252f / Swift 6.4 toolchain, re-enabling the compiler-gated native Home refresh controller on macOS 27.
- The refresh indicator now follows `palette.accent`, including custom accents. Theme updates retint the retained controller instead of recreating it or reverting to the system's static accent.
- All 91 tests pass under Xcode 27, including controller tint updates and identity retention. The signed bundle launched successfully; Kevin confirmed that the trackpad pull refresh works and its indicator is purple in the current purple theme.
- This is a local build. Global toolchain selection, release version, and the Xcode 26 GitHub publication workflow are unchanged.

## 2026-09-06 — 2.2.2 hover hotfix preparation

- Kevin confirmed that the latest local hover recovery build works much better and authorized GitHub/Sparkle publication. Prepared version 2.2.2, build 202002, without further playback changes.
- All 90 implementation tests passed before release preparation. The existing release workflow provides Developer ID signing, Apple notarization, and Sparkle archive signing.

## 2026-09-06 — Main-player hover recovery

- Replaced event-only hover state with coordinate validation plus an 80-millisecond reconciliation timer while the normal player is attached. Stops the timer on detach/dismantle and clears hover for inactive, hidden, or minimized surfaces.
- Restricted tracking and pointer containment to both view bounds and the visible rect. An AppKit test demonstrated that a non-clipping view's visible rect can extend outside its bounds. Stale entry events now use their coordinates rather than unconditionally revealing controls.
- Preserved existing hover during player appearance so startup cannot hide controls after entry has already been detected.
- All 90 tests pass, including omitted entry events, media movement beneath a stationary pointer, out-of-bounds entry events, reentry, and click pass-through. The optimized local bundle was inspected with live playback and caption/control separation. Repeated physical hover confirmation remains separate from these automated checks. No release or Git push was requested for this correction.

## 2026-09-06 — 2.2.1 hotfix preparation

- Kevin confirmed the rebuilt main-player hover reveal, clickable buttons, and hide-on-exit behavior. Prepared 2.2.1, build 202001, for the explicitly requested GitHub and Sparkle hotfix publication.
- All 89 tests pass. The optimized arm64 bundle has the configured Developer ID signature and matching release metadata. GitHub's tag workflow owns release notarization and Sparkle signing.

## 2026-09-06 — Normal player controls and hover

- Anchored the normal transport row to the media bottom, removed the palette-dependent vertical lift, and reserved a separate caption band. Applied explicit media bounds before overlays and isolated the loading thumbnail from layout in both player modes.
- Added a click-through AppKit hover tracker with a 450-millisecond exit grace period. Tracking areas preserve their inside state across layout changes so the next pointer exit is delivered. Kept compact/PiP sizing and transport constants separate.
- Bounded the AppKit scroll document's interaction region after runtime samples showed expensive window-drag region synthesis across rounded descendants.
- All 89 tests pass with Xcode 26.6, including hover exit/re-entry and click pass-through. The rebuilt optimized app displayed the corrected normal control placement and caption separation. Live mouse automation intermittently failed with `noWindowsAvailable`, so the final physical hover cycle remains to be confirmed. A PiP return encountered first-frame recovery; Retry restored normal video. Do not treat this check as full playback regression clearance.

## 2026-09-06 — 2.2.0 release preparation

- Prepared version 2.2.0, build 202000, covering Subscription Groups, live YouTube Home ordering, and the PiP resize corrections. Added end-user release notes and a current Home screenshot.
- The existing 88-test implementation check passed. Verified the rebuilt Developer ID bundle, matching ZIP and DMG metadata, archive integrity, embedded Sparkle/resources, and live Home presentation. GitHub's tag workflow owns Apple notarization and Sparkle signing before publication.

## 2026-09-06 — Subscription Groups and YouTube Home recommendations

- Added local subscription groups with named sidebar folders, channel assignment, alphabetical/manual ordering, collapse state, and latest-upload views. Definitions use stable channel IDs and bounded storage; deleting a folder leaves YouTube subscriptions intact.
- Home now reads the actual YouTube homepage using the existing app web session and preserves its recommendation order. Supports both signed-in and viewing-personalized signed-out web sessions, classic and modern video cards, and excludes ads, playlists, and Shorts routes. The previous account/RSS/API mix remains available when the web response is unavailable, without re-enabling hidden WebKit surfaces.
- Home displays its recommendation source and provides a YouTube Home shortcut to view or sign into that web session. Other destinations no longer overwrite the Home recommendation cache, and returning Home restores its saved order before refreshing.
- Live optimized-bundle checks covered group creation, manual/alpha order, collapse, persistence across relaunch, group uploads, and cleanup. Compared the real YouTube web session with the app and confirmed the live homepage source replaced the fallback mix.
- All 88 tests pass, including homepage order, classic/modern cards, ad/playlist/Shorts exclusion, malformed responses, bounded group membership, stable channel identities, and persisted manual ordering. Canceled subscription requests no longer publish stale errors into the next destination.

## 2026-09-06 — PiP resize and transport correction

- Isolated the compact loading thumbnail from player sizing so its fill-scaled image cannot push playback controls outside the PiP bounds. Removed compensating vertical offsets, anchored the controls to the window edges, and aligned caption/drag reservations. Preserved the normal player's existing layout.
- Fixed the black video above YouTube's wide-layout breakpoint: runtime measurements showed the video displaced downward by exactly one viewport height. Anchored the web player to the viewport, retaining the same playback surface and position during resize.
- The optimized development bundle built and launched successfully; Kevin confirmed that PiP sizing, enlarged video, and normal playback were fixed. All 81 tests passed, including a real WebKit layout regression across 240–1600-point widths and back to the default size. Temporary layout diagnostics were removed. The existing macOS beta debug SwiftUI view-copy crash remains outside this fix.

## 2026-09-05 — 2.1.1 SDK compatibility correction

The 2.1.0 CI workflow stopped before distribution because Xcode 26 cannot compile macOS 27-only NSRefreshController declarations inside runtime availability guards. Added compile-time gates while preserving the older-SDK toolbar refresh path. Prepared 2.1.1 build 201001 without moving the existing failed tag. All 80 tests pass locally with Xcode 26.6; the matching optimized Developer ID bundle builds and launches successfully.

## 2026-09-05 — 2.1.0 release preparation

- Prepared version 2.1.0, build 201000, release notes and the refreshed Theme Center screenshot. Accounts, data, update feed, and signing keys are unchanged.
- Kept WebKit renderable behind the startup thumbnail, addressing compact/PIP first-frame stalls without adding retries or overlapping player ownership. The optimized Developer ID build passed real compact/PIP playback and caption checks without Retry.
- All 80 tests passed; local arm64 ZIP integrity, DMG checksums, embedded resources, and Developer ID signatures passed. A debug build on macOS 27 beta crashed in SwiftUI view copying; the optimized release candidate did not reproduce that crash during playback checks. This is not a claim that the beta debug runtime issue is resolved.

## 2026-09-05 — Theme Center and native input milestone

- Reorganized Appearance into Environments and Customize, with compact headers, consistent groups, and accessible theme adjustments. A bounded exact-height theme grid fixes the clipped last catalog row observed in the expanded Settings window.
- Fixed a reproduced macOS 27 native Settings selection stall: deferred mouse-down/up events now replay as an ordered batch so AppKit tracking can consume its pending mouse-up. Preserved the existing actor-isolation and mouse-movement workarounds.
- Added native-hosted theme-grid and pointer-ordering regression tests. All 80 tests pass. Rebuilt staged app inspected with real theme search/application, Light/Dark changes, subsection navigation, scrolling to the complete final row, and repeated native Settings selection.

## 2026-09-05 — discovery, channels and playback milestone

- Explore now offers six useful topic entry points without an automatic search request. Dedicated browsing destinations show correctly titled grids and contextual refresh. Channels reuse stable shared video cards and display all already-loaded videos with more readable sizing.
- Consolidated the player control shelf into system Liquid Glass with an opaque Reduce Transparency fallback, improved hover/press and queue feedback, and added compact-player context actions plus Command-Option-M expansion from mini-player or desktop PIP.
- The build/run script now restarts only this checkout's staged executable after a successful compile, preserving installed and archived copies.
- All 80 tests pass; signed staged build and launch pass. Computer Use verified real search/topic results, channel browsing, Library transitions, playback with captions, queue presentation, speed changes and restoration, compact/PIP transitions, and full-screen entry/exit. Intermittent compact/PIP load watchdog timeouts recovered using Retry; their underlying cause remains unresolved. Original Lavender Haze/Dark appearance and Normal playback speed were restored. Native speed menu labels use compact decimal formatting. Existing data and installations were preserved; no remote publication occurred.

## 2026-09-05 — everyday experience, navigation and Library milestone

- Compact sidebar rows and flexible subscription height keep all navigation and the subscription footer reachable. Shared section typography, quieter video-card surfaces, independent accessible section actions, and Reduce Motion-aware toolbar feedback establish a consistent media-first direction.
- Fixed a live Library defect where switching to an empty tab moved the page halfway down the window: child-local geometry changes now coalesce natural document remeasurement, and a narrow clip view top-aligns short documents. Long-document scroll positions and Home refresh/pointer contracts remain intact.
- Library has specific Saved, Liked, Collections, and no-match guidance with useful actions; blank collection names cannot be submitted. Local Library no longer exposes a network refresh; Search refresh reruns the search.
- All 77 tests passed, including short-document alignment and preserved long-document scrolling. Signed staged bundle rebuilt and launched; Computer Use verified populated-to-empty Library transitions, collection action/blank-name validation, reachable sidebar footer, and real YouTube search results. No user collections were created during validation.

## 2026-09-05 — search response decoding repair

- Runtime reproduction identified a missing `items.Index 0.id.videoId` field as the cause of whole-search decoding failure. Search IDs now allow non-video resources; only nonempty video IDs advance to enrichment and result mapping. Empty ID lists skip enrichment. Corrected snippet channel identity mapping to the API's `channelId`.
- Added mixed channel/video/playlist and empty-response regression fixtures. All 75 tests pass. The normal signed-bundle build/launch verification passed, and Computer Use observed 11 Chris Cuomo results followed by 11 results for the user's subsequent search.
- Search failure UI no longer claims that no long-form videos exist and now surfaces the available failure explanation. Missing-field diagnostics record schema paths only, never response contents, query URLs, or credentials. The hidden-WebKit stability safeguard remains unchanged.

## 2026-09-05 — shared decoded images and regression-suite organization

- Clean starting restore point: local commit `4d7fd87`. No credentials, installed copies, or remote release state changed.
- Extracted image networking/cache ownership from HomeImageViews into Services/YouGlassImageLoader. Concurrent consumers now share an eagerly decoded CGImage, not only downloaded bytes. ImageIO applies orientation and bounds previews to 1600 pixels; the actor-owned 180-entry/80-MiB advisory NSCache accounts actual decoded row bytes. Cancelled views never publish their old result; failed loads are not cached.
- Split the 846-line ModelsTests into model, playback/feed-policy, recommendation, and custom-feed suites. All source and test Swift files are now below 500 lines (largest 459). Existing tests retained; three new tests cover shared image identity/cache reuse, aspect-preserving downsampling, and retry after decode failure.
- Narrow image tests and all 73 tests passed. The staged signed app rebuilt/launched through the normal verification script. Computer Use showed Home hero/cards/account avatar and player recommendation images rendering correctly, followed by playing video and visible captions.
- This is the first scoped refactoring milestone, not a completed whole-app overhaul. No controlled latency/CPU benchmark was performed; sustained playback/compositor profiling, startup measurement, and broader navigation/lifecycle regression coverage remain open.

## 2026-09-04 — initial player geometry

- Seed expanded watch-page dimensions from the existing Home geometry instead of first laying out a fixed 900-by-680 page. The AppKit size reader remains responsible for subsequent size corrections and live resizing; no new SwiftUI geometry reader was introduced into the watch hierarchy.
- Skip redundant WebKit frame/layer writes when its host bounds have not changed. Preserve the first-frame thumbnail guard and the one-turn safe presentation deferral.
- All 70 tests pass. This removes an avoidable initial layout correction, not YouTube network or decode latency; no instant-play timing claim is made.

## 2026-09-04 — playback update and layout overhead

- Coalesced bounded-scroll measurements and removed forced synchronous subtree layout and unchanged frame assignments. The original runtime sample repeatedly entered `resizeDocument`; the subsequent three-second sample did not contain that path.
- Introduced a stable non-forwarding playback owner plus small caption and side-effect observers, keeping transport ticks out of the full watch page. Preserved Now Playing, completion, and ambient callbacks. Equal bridge values no longer republish; regression coverage verifies duplicate updates and caption-only frame preservation.
- Covered Home disables pointer monitors/prewarming and skips automatic refresh during expanded playback. Mini-player/PIP leave browsing active. Disabled captions use a one-second fallback poll; enabled captions retain the 120 ms cadence and existing text deduplication.
- Retained the existing once-per-video ambient sampling and visual effects; no video-quality or credential changes. All 70 tests passed and the signed development bundle rebuilt. Computer Use verified playing video, changing native caption text, and separate outer/inner comment scrolling.
- Resource validation is incomplete as an overall performance target: initial process CPU was about 80%, subsequent playback about 75%, on different playback sessions, not a controlled same-video benchmark. Window-region/compositor work remains prominent. Do not advertise a measured percentage reduction from these samples.

## 2026-09-04 — atomic hover feedback

- Shared card hover state now updates in an animation-disabled transaction, so the card highlight, scale, and play badge switch together rather than inheriting the card's 80 ms or a feed transition animation. Both native document tracking and the SwiftUI fallback use the same path.
- Kept synchronous pointer tracking, stable hit bounds, and the separate 150 ms speculative prewarming dwell unchanged. Network prewarming does not gate the play badge.

## 2026-09-04 — restore Home header pointer actions

- Bounded the featured image and hero interaction shapes to their visible frames. Pixel clipping alone allowed the scaled-to-fill image to intercept pointer input over the Home shortcuts and Custom Feed strip. The decorative hero border no longer participates in hit testing.
- Removed investigation-only input probes and restored the original adaptive header and accessibility grouping; no navigation or credential changes were needed.
- Rebuilt and launched the signed development bundle. Computer Use coordinate clicks verified Watch Later, Library, Subscriptions, Create (opened and cancelled without saving), and Analysis (opened its results), including Create and Analysis with a loaded hero below them.

## 2026-09-04 — preview-first Home spacing

- Replaced the large welcome banner, decorative icon, and tall shortcut tiles with a compact Home heading and inline shortcuts (with a narrow-width fallback).
- Preserved Custom Feed creation, prompts, saved feed chips, selection, editing, and deletion. Tightened panel padding/chip spacing and reduced page section spacing from 28 to 16 points so the video preview appears much higher.
- No feed, playback, credential, or hover behavior changes. All 69 tests and the signed build/launch workflow passed. Computer Use confirmed the compact header, both saved prompt-feed chips, full preview, and beginning of For You visible together at the top of the rebuilt Home window.

## 2026-09-04 — native card pointer tracking

- User confirmed the immediate-animation patch still missed hover transitions. Replaced SwiftUI `onContinuousHover` in the shared card modifier with `YouGlassCardPointerRegion`, an AppKit visible-rect tracking region at the unscaled button boundary.
- Pointer enter/move/exit events update the boolean directly; layout/update reconciliation is deferred to avoid publishing inside SwiftUI layout. The region returns nil from hit testing, replaces old tracking areas, and drops callbacks on teardown. Tracking also works without requiring the app to be key.
- Added tests for non-intercepting hit testing and tracking-area replacement/options. Fast physical pointer-sweep behavior remains a manual validation requirement, not something proven by unit tests.
- Runtime iteration found that native representable bounds and SwiftUI global coordinates did not match the scrolled document. The AppKit Home container now names its document coordinate space explicitly; the tracker compares those card frames with native document-relative pointer positions. A local event monitor reconciles all mounted cards without consuming events and is removed on teardown. Non-AppKit browsing containers retain SwiftUI hover handling.
- Synchronize the native reported-hover cache with SwiftUI on every update, so feed replacement cannot leave the badge hidden while the tracker incorrectly thinks it already reported entry. A 100-crossing test also covers this reset and offscreen clearing. Temporary geometry-only logging was removed.
- Use the incoming event location, with one bounded shared sample and weak window reference, so newly mounted cards inherit the latest pointer position during a feed diff. Validation: all 69 tests and the signed bundle build/launch passed. Computer Use small-scroll pointer placements confirmed second-to-third card transfer with the old highlight clearing during a live feed replacement; this is not a measured rapid physical mouse sweep.

## 2026-09-04 — immediate card hover feedback

- Home video cards and Continue Watching share `YouGlassVideoCardHover`: continuous pointer activity repairs hover state, duplicate state writes are suppressed, and disappearing cards clear their state.
- Play badges bypass inherited animation, decorative card feedback is shortened from 160 ms to 80 ms, and regular cards no longer run a second thumbnail hover/parallax animation.
- Prewarming waits for a cancellable 150 ms dwell instead of starting work for every card crossed during a pointer sweep. Playback actions and player/PIP controls are unchanged.
- Validation: all 66 tests passed; `./script/build_and_run.sh --verify` passed; inspected the rebuilt Home grid in Computer Use. Rapid pointer-sweep timing remains a manual QA item because the available native UI control surface does not expose pointer movement without another action.

## 2026-09-04 — bold Home and Library redesign

- Saved a local source/app restore point before implementing the user-selected bold visual direction.
- Replaced the split hero with a cinematic spotlight and dashboard shortcuts; added width-adaptive cards, stronger section hierarchy, and a useful end-of-feed refresh action.
- Added Library tabs and offline local video search, removed preview caps in dedicated tabs, and corrected navigation scroll retention discovered during runtime QA.
- Refined Settings branding/group spacing, queue readability/accessibility, and narrow-toolbar actions. Existing player/caption, Keychain, Shorts exclusion, and refresh policies remain unchanged.
- Validation and remaining QA boundaries are recorded in `OVERHAUL_MILESTONE.md`.

## 2026-09-04 — simplify expanded-player title treatment

- Replaced the expanded-player title gradient with one solid active-theme accent color and a subtler accent shadow.
- Strengthened the title hierarchy with black weight, controlled two-line wrapping, reduced line spacing, and limited scaling so long titles remain prominent without becoming cramped. `NOW PLAYING` remains directly beneath the title with quieter accent opacity, while the channel stays tertiary.
- Preserved the flexible title column, continuous header fade, and fixed rounded control shelf. Validation: `./script/test.sh` passed all 64 tests, `./script/build_and_run.sh --verify` passed, and the rebuilt staged player opened in Computer Use with the solid accent title hierarchy.

## 2026-09-03 — stabilize Home hover-to-play feedback

- Kept Home card hit targets at their layout bounds while animating only the inner card visuals. Hover play badges remain mounted and ignore pointer events, preventing their appearance or the card scale effect from stealing the next hover transition.
- Applied the same boundary stabilization to the featured card, Continue Watching cards, and the macOS 26 stable-hover thumbnail wrapper. The card action, prewarm trigger, and accessibility behavior remain unchanged.
- Validation: `swift build --product YouGlass` and `./script/build_and_run.sh --verify` passed; the rebuilt staged bundle showed the expected Home card and featured-card layout in Computer Use after relaunch. The final repeated pointer-hover pass is limited by the current Computer Use surface exposing drag/click but no direct pointer-move action.

## 2026-09-03 — speed up Home feed refresh

- Prevented repeated Home pulls from blocking on a redundant full subscription sync: a persisted subscription snapshot is reused immediately and refreshed in the background when it is missing or outside the five-minute freshness window, while account signals still refresh in the foreground.
- Bounded signed-in subscription RSS enrichment to twelve channels, two uploads per channel, and four seconds. Subscribed feeds now avoid a burst of expensive search requests and use one recommendation seed only when search is needed as a fallback; independent sources still overlap behind the shared request gate and Shorts filtering.
- Changed the shared API cooldown to fail fast during YouTube HTTP 429 backoff instead of making each later request sleep for the full 30-second window. Cached/local recommendations therefore remain responsive while YouTube recovers.
- Validation: the targeted ModelsTests workflow passed with 41 tests and 0 failures; the full `./script/test.sh` workflow passed with 64 tests and 0 failures; `./script/build_and_run.sh --verify` produced the signed staged bundle; Computer Use confirmed a manual Home refresh returned to a non-busy connected state in about one to two seconds of runtime load time and rotated the visible recommendations.

## 2026-09-03 — finish Home pull-to-refresh at the top

- Corrected native Home refresh completion so the retained AppKit controller is explicitly ended after the async feed load and the document clip view is re-anchored at the top. A next-run-loop top anchor covers the macOS refresh animation that could otherwise leave the indicator visibly spinning until the next scroll.
- Validated with a full async pull refresh: the Home status returned to connected, recommendations updated, and the indicator was absent while the document remained at the top.

## 2026-09-03 — add Home pull-to-refresh

- Added a Home pull-to-refresh bridge. On macOS 27+, AppKit's native `NSRefreshController` is attached to the existing single Home scroll owner; older systems use SwiftUI's `.refreshable` fallback. Pulling or dragging down at the top of Home runs the existing forced refresh path and its quota-safe manual-refresh floor.
- The action is scoped to the normal Home feed; Library, Search, and selected Custom Feeds retain their separate boundaries. Validated with the targeted/full test workflow, the rebuilt staged bundle, a runtime top-edge drag that rotated the Home feed, and a Library navigation check with no refresh controller exposed.

## 2026-09-03 — add native prompt-driven Custom Feeds

- Added a deterministic local prompt interpreter for topic keywords, subscription-only scope, recency, duration, and the always-on Shorts exclusion. The parser and custom-feed ranker are pure model-layer code with XCTest coverage.
- Added a bounded store flow for creating, editing, selecting, refreshing, and deleting up to eight feed definitions. Only the prompt, interpreted intent, and timestamps persist in UserDefaults; candidate videos remain transient and use the existing Data API, Atom channel, signed-in web fallback, and local catalog boundaries.
- Added the Home Custom Feeds strip, focused results surface, composer sheet, toolbar action, command-palette action, and context-menu management. This native MVP does not require an AI API and does not pretend YouTube's private experimental feed endpoint is public.
- Validation: the targeted ModelsTests workflow and full `./script/test.sh` workflow pass with 40 and 63 tests respectively, both with 0 failures. The rebuilt signed staged bundle passed strict code-signature verification. Computer Use confirmed the Home Custom Feeds strip, composer interpretation, saved feed selection, 24 transient results, and the filtered command-palette `Create Custom Feed` action reopening the composer.

## 2026-08-31 — improve Home recommendation freshness and rotation

- Kept the automatic foreground refresh at a quota-safe one-minute cadence, added a 15-second manual-refresh safety throttle, and made deliberate API-backed refreshes bypass the short-lived response cache.
- Deliberate refreshes now refresh account signals and subscriptions, while live Home ranking favors candidates outside a bounded window of the 24 most recently presented `For You` IDs. Only those non-secret IDs are persisted locally; watched history, library data, queue state, credentials, and account data remain unchanged.
- Added model coverage for freshness ordering and bounded rotation-state persistence. Validation: the targeted ModelsTests and full `./script/test.sh` workflow passed (59 tests, 0 failures); `./script/build_and_run.sh --verify` produced the signed 2.0.0 staged bundle and the rebuilt app remained running. Computer Use confirmed the rebuilt Home surface, the `For You`/Continue Watching ordering, and that a manual refresh completed and replaced the visible personalized candidates.

## 2026-08-30 — blend the player halo beneath the title shelf

- Changed the expanded watch layout so its AppKit page viewport continues behind the translucent title shelf instead of starting in a clipped sibling row below it.
- The scroll document now reserves the shelf's measured runtime height plus media-halo breathing room. The player and Up Next content stay below the controls, while the centered glow can fade upward through the header material without becoming a flat horizontal band.
- The playback queue panel follows the measured header height, and the existing AppKit scroll ownership, WebKit media boundary, captions, and compact/PIP behavior remain unchanged.
- Validation: `swift build --product YouGlass`, all 57 tests in `./script/test.sh`, `./script/build_and_run.sh --verify`, and strict deep code-signature verification passed. Computer Use opened the same featured video before and after rebuilding; the post-fix player retained its header and Up Next layout while the previously clipped horizontal halo edge continued behind the title shelf as a soft fade.

## 2026-08-30 — revamp the desktop discovery experience

- Reworked Home around the YouGlass identity, actionable featured content, richer section context, and consistent pointer/accessibility feedback without changing the local-first ordering or no-Shorts policy.
- Added `Command-L` global-search focus, clear/run controls, richer search/empty recovery, and feature-keyword filtering across all Settings pages.
- Hardened the command palette's modal focus, Escape dismissal, and action sequencing, and added Search, Settings, and Resume commands.
- Added a true Play Next queue policy that inserts after the active cursor and survives the bounded queue limit; Add to Queue remains a tail append.
- Added focused desktop-experience regression tests. No credentials, account data, player bridge behavior, or persistence identity changed.
- Validation: all 57 tests and `./script/build_and_run.sh --verify` passed; strict deep code-signature verification accepted `dist/YouGlass.app`, the rebuilt process remained running, and no error/fault entries appeared in the post-build app log window. The Mac locked before Computer Use could perform the final visible Home/command/Settings/player interaction pass, so that runtime UI evidence remains explicitly pending.

## 2026-08-30 — complete native queue autoplay after video completion

- Fixed the playback bridge dropping the JavaScript `ended` field before it reached the native controller, which prevented the SwiftUI auto-advance observer from running even though the WebKit listener was installed.
- Queue preparation now preserves an existing cursor while backfilling a one-item persisted queue and appending recommendations that finish loading after the player starts. The native media element is explicitly kept out of loop mode so a missing next item cannot replay the current video.
- Added regression coverage for ended-message propagation, one-item queue backfill, and the no-loop script contract. No API keys or account data are recorded.

## 2026-08-30 — keep the YouTube Data API key across rebuilds

- Hardened `KeychainStore` so each credential is read from both preferred data-protection storage and the login-Keychain compatibility path, and written to both when available. This covers macOS SwiftPM/ad-hoc rebuilds where one Keychain storage class can reject or lose access while the other remains available.
- Removed the persistent missing-credential migration marker that could suppress a later compatible lookup after an initially empty read. Legacy `com.kevinhowe.YouTubeMac` credentials still migrate into the stable `com.kevinhowe.YouGlass` identity.
- Keychain write success now reaches Settings. A failed save no longer claims success, replaces the active client, or clears the entered draft. No credential value is recorded here or anywhere else in the repository.
- Regression coverage verifies the stable credential identity and the two storage modes; the targeted test passed after rebuilding the package.

## 2026-08-30 — advance autoplay to the next queued video

- Fixed queue preparation so opening a video that is already in `playbackQueue` preserves its existing order. Previously, selecting the next item moved it to index zero, causing the queue cursor to point back at an earlier video when the item finished.
- Added an explicit native media `ended` listener so the player reports completion immediately to the Swift auto-advance handler. The existing autoplay toggle remains respected; when it is disabled, the current video stops at completion.
- Added model and bridge regression coverage for queue order and completion-event wiring.

## 2026-08-29 — preserve private API credentials and restore the account avatar

- Centralized the YouTube Data API key in a stable macOS Keychain service/account boundary. Existing keys from the legacy service migrate forward on read, and credential reset removes both identities; no API key is written to source, UserDefaults, diagnostics, Git, Sparkle artifacts, or `.docs/`.
- Added authenticated account-channel profile resolution, signed-in web-feed URL propagation, and bounded visible-browser capture retries so the Home toolbar can use the signed-in YouTube profile thumbnail instead of a generic stock portrait. The persisted value is only the non-secret image URL, and the last valid image remains available through transient image/network failures.
- Added a channel-response decoding regression test and documented the secure handoff: enter the key directly in Settings → Account & API → YouTube Data API; never send it through chat or commit it.

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

## 2026-09-05 — Instruction cleanup

Reduced AGENTS.md to shared workflow and invariants. Moved existing Home, player, appearance, and state contracts into task-specific references without changing application code. Removed the completed initial-setup commit instruction and replaced drift-prone current-version/toolchain snapshots with source lookup guidance. Documentation-only edits use documentation validation; affected GUI changes still require rebuilt-bundle live verification. Local-only commit and explicit remote-publication boundaries remain.

## 2026-09-07 — Preserve active development bundles

Build/run now validates its mode before any work and refuses to replace a running staged app. This closes the build-only path that previously unlinked the running bundle, and preserves active playback during development. Quit the staged app before rebuilding it. Process checks match the literal executable path, including canonical directory aliases and launch arguments, and verification checks that exact instance. Signed disposable-process tests cover unrelated same-name apps, punctuation in paths, and symlinks. No player or account behavior was changed.
