import SwiftUI

/// The recommendation document has one owner, independent of destination routing.
struct HomeRecommendationContent: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            sourceStatus
            if store.homeWebSessionNeedsSignIn && store.isNetworkAvailable {
                sessionPrompt
            }

            if videos.isEmpty {
                if store.isLoading {
                    HomeLoadingView(palette: palette)
                } else {
                    HomeUnavailableView(store: store, palette: palette) {
                        Task { await store.loadHome(force: true) }
                    }
                }
            } else {
                HeroSection(palette: palette, compact: compact)
                if !store.feed.forYou.isEmpty {
                    VideoRow(title: "For You", videos: store.feed.forYou,
                             palette: palette, compact: compact)
                }
                if store.showContinueWatching && !store.continueWatching.isEmpty {
                    ContinueWatchingRow(palette: palette, compact: compact)
                }
                if !store.feed.trending.isEmpty {
                    VideoRow(title: "Trending", videos: store.feed.trending,
                             palette: palette, compact: compact)
                }
                if !store.feed.more.isEmpty {
                    VideoRow(title: "More to watch", videos: store.feed.more,
                             palette: palette, compact: compact, showsSeeAll: false)
                }
                Button(action: store.refreshCurrentDestination) {
                    Label("Refresh recommendations", systemImage: "arrow.clockwise")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(DashboardActionStyle(palette: palette))
                .disabled(!store.canRefreshCurrentDestination)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }

    private var videos: [VideoItem] {
        store.feed.forYou + store.feed.trending + store.feed.more
    }

    private var sourceStatus: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                sourceLabel
                Spacer(minLength: 0)
                sessionAction
            }
            VStack(alignment: .leading, spacing: 8) {
                sourceLabel
                sessionAction
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(palette.secondaryText)
    }

    private var sourceLabel: some View {
        Label {
            if !store.isNetworkAvailable {
                Text("Offline · Saved recommendations")
            } else if store.isLoading {
                Text("Updating your recommendations…")
            } else if store.homeRecommendationsAreFromYouTube {
                Text("From YouTube Home · Original recommendation order")
            } else {
                Text("Suggested for you · Based on your channels and interests")
            }
        } icon: {
            Image(systemName: store.homeRecommendationsAreFromYouTube ? "play.rectangle" : "sparkles")
                .foregroundStyle(palette.accent)
        }
        .accessibilityElement(children: .combine)
    }

    private var sessionAction: some View {
        Button {
            store.openURL(URL(string: "https://www.youtube.com/")!, title: "YouTube Home")
        } label: {
            Label("YouTube Home", systemImage: "arrow.up.right")
        }
        .buttonStyle(.plain)
        .help("Open YouTube Home using your YouGlass browser session")
    }

    private var sessionPrompt: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                sessionExplanation
                Spacer(minLength: 0)
                connectButton
            }
            VStack(alignment: .leading, spacing: 12) {
                sessionExplanation
                connectButton
            }
        }
        .padding(16)
        .youGlassSurface(palette: palette, cornerRadius: 18)
    }

    private var sessionExplanation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bring your YouTube Home with you")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("Sign in to YouTube in the YouGlass browser to see your Home recommendations. Your connected account and browser sign-in are separate.")
                .font(.system(size: 12))
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var connectButton: some View {
        Button {
            store.openURL(URL(string: "https://www.youtube.com/")!, title: "YouTube Home")
        } label: {
            Label("Connect YouTube Home", systemImage: "arrow.up.right")
        }
        .buttonStyle(.borderedProminent)
        .tint(palette.accent)
        .fixedSize()
    }
}
