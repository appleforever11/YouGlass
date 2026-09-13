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
                // Keep the shell's ambient colors stable while idle. Continuous
                // gradient animation makes the entire Home view re-render even
                // when no content is changing; the player can still provide its
                // own video-driven ambience when it is presented.
                YouGlassAmbientBackdrop(
                    palette: palette,
                    ambientPalette: store.ambientPalette,
                    intensity: 1.15,
                    animated: false
                )
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
                                .disabled(fullPlayerPresented)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }

                        if let video = store.selectedVideo {
                            if store.isDesktopPIPActive || store.isInlinePlayerTransitioning {
                                // Playback is hosted by the separate desktop PIP
                                // panel. Keep the feed interactive underneath it.
                                Color.clear
                                    .allowsHitTesting(false)
                            } else if store.isPlayerCompact {
                                compactPlayer(video: video, in: CGSize(
                                    width: mainContentWidth,
                                    height: max(1, geometry.size.height - shellTopInset - shellInset)
                                ))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                YouTubePlayerOverlay(
                                    video: video,
                                    palette: palette,
                                    isCompact: false,
                                    initialAvailableSize: CGSize(width: mainContentWidth, height: geometry.size.height),
                                    onCompactDragChanged: nil,
                                    onCompactDragEnded: nil
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }

                } // Keep modal overlays out of the horizontal shell layout.

                if store.commandPalettePresented {
                    // Keep the modal state legible on translucent themes. The
                    // palette has its own opaque surface; this scrim only dims
                    // the active window and leaves the normal Home glass
                    // behavior unchanged after dismissal.
                    palette.window.opacity(colorScheme == .dark ? 0.76 : 0.84)
                        .overlay {
                            Color.black.opacity(colorScheme == .dark ? 0.18 : 0.10)
                        }
                        .ignoresSafeArea()
                        .onTapGesture { store.commandPalettePresented = false }
                        .zIndex(20)

                    CommandPaletteView(
                        palette: palette,
                        dismiss: { store.commandPalettePresented = false }
                    )
                    .environmentObject(store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        .onChange(of: store.compactPlayerCorner) { _, _ in
            compactDragOffset = .zero
        }
        .onChange(of: store.selectedVideo?.id) { _, _ in
            compactDragOffset = .zero
        }
        .sheet(isPresented: Binding(
            get: { store.subscriptionGroupEditorPresented },
            set: { store.subscriptionGroupEditorPresented = $0 }
        )) {
            SubscriptionGroupEditor(group: store.editingSubscriptionGroup)
                .environmentObject(store)
        }
        .sheet(isPresented: Binding(
            get: { store.customFeedComposerPresented },
            set: { store.customFeedComposerPresented = $0 }
        )) {
            CustomFeedComposerView(
                palette: palette,
                feed: store.editingCustomFeed
            )
            .environmentObject(store)
        }
    }
}
