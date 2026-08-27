import SwiftUI

struct YouTubeHomeView: View {
    @EnvironmentObject var store: YouTubeStore
    @Environment(\.colorScheme) var colorScheme
    @State var compactDragOffset: CGSize = .zero

    var palette: Palette {
        Palette(colorScheme, theme: store.visualTheme, customization: store.themeCustomization)
    }

    var body: some View {
        GeometryReader { geometry in
            let compactShell = geometry.size.width < 980
            let shellInset: CGFloat = compactShell ? 8 : 14
            let sidebarWidth: CGFloat = compactShell ? 76 : 236
            let mainContentWidth = max(
                1,
                geometry.size.width - shellInset * 2 - sidebarWidth
            )
            // Base the content breakpoint on the space left after the
            // sidebar. This keeps medium windows from forcing desktop-sized
            // grids into a layout that cannot hold them.
            let compactContent = mainContentWidth < 1_000
            let fullPlayerPresented = store.selectedVideo != nil &&
                !store.isDesktopPIPActive &&
                !store.isPlayerCompact
            let shellTopInset: CGFloat = fullPlayerPresented
                ? 0
                : (compactShell ? 8 : 12)

            ZStack {
                YouGlassAmbientBackdrop(palette: palette, ambientPalette: store.ambientPalette, intensity: 1.15)
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    SidebarView(palette: palette, compact: compactShell)
                        .frame(width: sidebarWidth)
                        .frame(maxHeight: .infinity, alignment: .top)

                    ZStack(alignment: .topLeading) {
                        if store.selectedChannelItem != nil {
                            channelContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        } else {
                            mainContent(compact: compactContent)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }

                        if let video = store.selectedVideo {
                            if store.isDesktopPIPActive {
                                // Playback is hosted by the separate desktop PIP
                                // panel. Keep the feed interactive underneath it.
                                Color.clear
                                    .allowsHitTesting(false)
                            } else if store.isPlayerCompact {
                                GeometryReader { playerGeometry in
                                    compactPlayer(video: video, in: playerGeometry.size)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                YouTubePlayerOverlay(
                                    video: video,
                                    palette: palette,
                                    isCompact: false,
                                    onCompactDragChanged: nil,
                                    onCompactDragEnded: nil
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }

                if store.commandPalettePresented {
                    Color.black.opacity(colorScheme == .dark ? 0.42 : 0.22)
                        .ignoresSafeArea()
                        .onTapGesture { store.commandPalettePresented = false }
                        .zIndex(20)

                    CommandPaletteView(
                        palette: palette,
                        dismiss: { store.commandPalettePresented = false }
                    )
                    .environmentObject(store)
                    .zIndex(21)
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.stroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.12), radius: 24, y: 10)
                // The main window is full-size under its hidden title bar. Give
                // the regular feed a small shell inset, but let the expanded
                // player header reach the top edge so no separate title-bar cap
                // interrupts the watch surface.
                .padding(.horizontal, shellInset)
                .padding(.top, shellTopInset)
                .padding(.bottom, compactShell ? 8 : 14)
            }
        }
        .onChange(of: store.compactPlayerCorner) { _, _ in
            compactDragOffset = .zero
        }
        .onChange(of: store.selectedVideo?.id) { _, _ in
            compactDragOffset = .zero
        }
    }
}
