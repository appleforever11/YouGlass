# YouGlass appearance contracts

Read when changing themes, command palette, icons, settings, or shared appearance. These preserve the operational rules moved from AGENTS.md. Follow the user's requested scope; verify current source when implementation details may have changed.

- Appearance separates Environments from Customize using presentation-only state; changing that subpage resets the settings viewport just like a page change. The bounded catalog uses `YouGlassThemeGrid` to measure every row exactly for AppKit scrolling, including the last row and bottom inset. Do not substitute an estimated lazy height that makes the final labels unreachable. Theme controls retain stable persistence keys; sliders expose names and percentages to accessibility.

- Theme Center owns 24 selectable environment families. Each family must provide coordinated Light/Dark colors, collection metadata, and stable Codable identity; search, collection filtering, badges, and Surprise me are presentation affordances over that catalog and must not replace the persisted `visualTheme` key.

- The command palette is a modal surface: keep its theme base opaque so Home content, desktop windows, and other translucent layers cannot show through the command list; keep the overlay outside the horizontal Home shell so it can center in the full window, while the surrounding scrim may retain the active theme tint. Every command row must have a visible pointer hover highlight and make the hovered row the active keyboard selection. The palette owns keyboard focus while open, Escape must always dismiss it, and command execution dismisses the modal before performing a navigation, focus, or window action.

- `YouGlassThemeCustomization` is an optional accent override layered through `Palette`; preserve the selected theme family's light/dark colors and keep the blank/reset state equivalent to the environment default.

- App icon releases must ship both the Icon Composer source and the checked-in ICNS fallback under the stable `YouGlass` resource name. App launch performs a best-effort LaunchServices refresh after Sparkle installation, but external docks own their preview cache and may require their own refresh or restart.

- Home and player ambient backdrops are stable palette surfaces; do not reintroduce continuous full-window gradient animation that competes with WebKit playback and main-thread UI work. Motion remains opt-in through the shared backdrop API and must honor Reduce Motion.

- Keep SwiftUI as the source of truth and use the smallest AppKit bridge necessary for behavior SwiftUI cannot provide reliably on this macOS release.

- Settings uses a sidebar/detail layout. The Appearance page is intentionally taller than the default settings window and must open at the top while remaining scrollable. Its detail viewport uses a stock `NSScrollView` with an `NSHostingController` document measured by `sizeThatFits(in:)`; keep the document top-leading, do not add a max-height fill or custom scroll-view layout callback, and reset the scroll position only when the selected page changes.
