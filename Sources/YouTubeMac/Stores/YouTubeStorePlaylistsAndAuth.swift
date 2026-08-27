import AppKit
import Foundation
import SwiftUI

extension YouTubeStore {
        func openPlaylist(_ playlist: YouTubePlaylist) {
            if selectedVideo != nil {
                isPlayerCompact = true
            }
            selectedChannelItem = nil
            channelPage = nil
            channelError = nil
            channelLoading = false
            selectedPlaylist = playlist
            selectedSection = playlist.title
            playlistItems = []
            playlistError = nil
            sectionEmptyMessage = nil
            playlistLoading = true

            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { playlistLoading = false }
                do {
                    let items = try await client.playlistVideos(playlistID: playlist.id, maxResults: 100)
                    guard selectedPlaylist?.id == playlist.id else { return }
                    playlistItems = items
                    if items.isEmpty {
                        playlistError = "This playlist does not contain playable videos."
                    } else {
                        connectionMessage = "Loaded \(items.count) videos from \(playlist.title)"
                    }
                } catch {
                    guard selectedPlaylist?.id == playlist.id else { return }
                    playlistError = error.localizedDescription
                    connectionMessage = error.localizedDescription
                }
            }
        }

        func closePlaylist() {
            selectedPlaylist = nil
            playlistItems = []
            playlistError = nil
            playlistLoading = false
            selectedSection = "Playlists"
            Task { @MainActor [weak self] in
                await self?.loadPlaylists()
            }
        }

        func login() {
            guard oauth.hasClientID else {
                connectionMessage = "OAuth client ID needed for personalized account feed"
                let continueURL = "https%3A%2F%2Fwww.youtube.com%2F"
                openURL(URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=\(continueURL)")!, title: "Sign in")
                return
            }

            Task {
                do {
                    // A valid cached access token is the normal relaunch path. It
                    // avoids opening a new Google window and keeps the account
                    // session available after the app is quit and reopened.
                    if try await oauth.validAccessToken() == nil {
                        _ = try await oauth.signIn()
                    }
                    isSignedIn = true
                    defaults.set(true, forKey: DefaultsKey.isSignedIn)
                    connectionMessage = "Connected with YouTube OAuth"
                    await loadHome(force: true)
                } catch {
                    connectionMessage = error.localizedDescription
                }
            }
        }

        func legacyLogin() {
            let continueURL = "https%3A%2F%2Fwww.youtube.com%2F"
            openURL(URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=\(continueURL)")!, title: "Sign in")
        }

        func openSearchPage() {
            let searchTerm = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let queryValue = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
            openURL(URL(string: "https://www.youtube.com/results?search_query=\(queryValue)")!, title: "Search")
        }
}
