# YouGlass state contracts

- Subscription Group definitions persist locally under `YouGlass.subscriptionGroups.v1`: at most 24 groups, 40 unique channel IDs each, 60-character names, channel order, and expansion state. Keep temporarily unavailable IDs so refreshes do not erase membership; display only channels present in the current subscription snapshot. Persist no credentials or fetched group response payloads.
- Home's HTTP metadata client uses only unexpired root-path YouTube cookies from the existing default WebKit store, an ephemeral URLSession, no disk response cache, and same-host HTTPS redirects. Never log cookies, headers, HTML, or account identifiers; feed diagnostics contain only result counts and signed-in state.

Read when changing persistence, credentials, content policy, image loading, or network recovery. These preserve the operational rules moved from AGENTS.md. Follow the user's requested scope; verify current source when implementation details may have changed.

- macOS 27 pointer replay retains its main-actor safeguard, but batches events already captured before replay. Post queued successors back into AppKit before sending mouse-down, so native tracking loops can consume mouse-up without waiting on another actor task. Preserve event order and temporarily remove/reinstall the monitor; do not return to one actor task per already-captured event.

- YouGlass excludes YouTube Shorts globally: feed/API/WebKit/channel ingestion, recommendations, search/open, navigation, and local history/library/queue/cache persistence must use the shared content policy; do not reintroduce a Shorts route or opt-in preference.

- The YouTube Data API key is runtime-only state managed by `YouGlassCredentialStore` in the macOS Keychain under the stable YouGlass service/account identity. It prefers data-protection storage and keeps a login-Keychain compatibility copy so rebuilds and updates can recover it; it may migrate from the legacy service, but must never enter source, diagnostics, Git commits, Sparkle artifacts, or `.docs/`.

- Network recovery uses `NWPathMonitor`, cached feed data, and the bounded `RemoteImage` cache. Offline states must remain usable and must not erase local library or playback data.

- Remote thumbnail/avatar loading belongs in the actor-owned `YouGlassImageLoader` service. Share download and decoded results, eagerly downsample off the main actor (maximum 1600 pixels), and account cache cost using decoded row bytes times height. UI consumers check cancellation before publishing; failures remain retryable. This applies to preview images, never video stream resolution.
