# Native player hover controls

Updated 2026-08-28.

The normal expanded player keeps its native transport chrome out of the resting frame. The player root owns pointer hover, so the transport appears when the pointer enters the media surface and remains available while the pointer is over the player. A minimal 0.04-second exit grace period prevents an edge-crossing flicker; after that, the controls and their bottom gradient fade out with a fast 0.08-second transition. Explicit transport interactions still reveal the controls and use the existing delayed hide fallback when the pointer is not over the player.

The native caption overlay reads the same `transportControlsVisible` state as the transport. While controls are visible, captions sit above the circular control shelf. When the shelf fades, captions animate down into the lower resting position. The shared visibility animation keeps the caption movement and chrome transition synchronized. Compact/PIP mode uses the same transient contract for both the top-left window shelf and bottom playback transport: controls start visible briefly, reveal immediately on hover, and fade after a short exit grace period. Hidden PIP controls stop intercepting pointer input so the player can still be dragged. Its caption overlay uses a lower resting inset when the controls are hidden and rises above the compact shelf when the pointer returns.

The implementation is split across:

- `Sources/YouTubeMac/Views/Player/NativeYouTubePlayerBody.swift` — root hover handling, caption placement, and coordinated animation.
- `Sources/YouTubeMac/Views/Player/NativeYouTubePlayerTransport.swift` — visibility state, hide scheduling, and normal/compact-player chrome visibility.
- `Sources/YouTubeMac/Views/Player/PlayerInteractionLayer.swift` — shared caption/control inset constants and media interaction geometry.

Validation for this behavior must use the rebuilt `dist/YouGlass.app`: the resting player should show no transport chrome, pointer hover should reveal the centered controls and caption above them, pointer exit should return to a clean media frame, and compact/PIP should hide both control groups and lower the caption after pointer exit while keeping the surface draggable.
