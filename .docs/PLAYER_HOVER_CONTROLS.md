# Native player hover controls

Updated 2026-08-29.

The normal expanded player keeps its native transport chrome out of the resting frame. The player root owns pointer hover, so the transport appears when the pointer enters the media surface and remains available while the pointer is over the player. A minimal 0.04-second exit grace period prevents an edge-crossing flicker; after that, the controls and their bottom gradient fade out with a fast 0.08-second transition. Explicit transport interactions still reveal the controls and use the existing delayed hide fallback when the pointer is not over the player.

The expanded caption overlay is hosted by the watch-layout player wrapper, outside the AppKit-backed WebKit representable. This keeps the native caption above WebKit's remote layer tree even after the transport fades. While controls are visible, captions sit just above the circular control shelf using the dedicated 110-point control inset; when the shelf fades, the caption remains visible and animates down into its lower resting position. Hover changes the caption inset, not caption visibility. The caption layer is text-driven so a transient bridge read of the hidden YouTube caption button, including an empty disabled poll, cannot blank an already-rendered line; explicit caption-off/no-track states and an empty active-track update still clear it. Compact/PIP mode keeps the existing transient contract for both the top-left window shelf and bottom playback transport: controls start visible briefly, reveal immediately on hover, and fade after a short exit grace period. Hidden PIP controls stop intercepting pointer input so the player can still be dragged. Its caption overlay retains the lower resting inset when controls are hidden and rises above the compact shelf when the pointer returns.

The implementation is split across:

- `Sources/YouTubeMac/Views/Player/NativeYouTubePlayerBody.swift` — root hover handling, caption placement, and coordinated animation.
- `Sources/YouTubeMac/Views/Player/NativePlayerCaptionOverlay.swift` — shared text-driven caption surface and inset animation.
- `Sources/YouTubeMac/Views/Player/NativeYouTubePlayerTransport.swift` — visibility state, hide scheduling, and normal/compact-player chrome visibility.
- `Sources/YouTubeMac/Views/Player/NativeWatchScreenLayout.swift` — expanded-player caption wrapper above the WebKit representable.
- `Sources/YouTubeMac/Views/Player/PlayerInteractionLayer.swift` — shared caption/control inset constants and media interaction geometry.

Validation for this behavior must use the rebuilt `dist/YouGlass.app`: the resting player should show no transport chrome while an active caption line remains visible at its lower inset, pointer hover should reveal the centered controls and lift the caption above them, pointer exit should return the controls to a clean hidden state without removing the caption, and compact/PIP should preserve its existing lower-caption/draggable behavior.
