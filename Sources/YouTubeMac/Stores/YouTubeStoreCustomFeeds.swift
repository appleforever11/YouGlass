import Foundation

extension YouTubeStore {
    static let maxCustomFeeds = 8

    var selectedCustomFeed: YouGlassCustomFeed? {
        guard let selectedCustomFeedID else { return nil }
        return customFeeds.first { $0.id == selectedCustomFeedID }
    }

    var editingCustomFeed: YouGlassCustomFeed? {
        guard let editingCustomFeedID else { return nil }
        return customFeeds.first { $0.id == editingCustomFeedID }
    }

    func presentNewCustomFeedComposer() {
        editingCustomFeedID = nil
        customFeedComposerPresented = true
    }

    func presentCustomFeedComposer(for feed: YouGlassCustomFeed) {
        editingCustomFeedID = feed.id
        customFeedComposerPresented = true
    }

    func decodeCustomFeeds() -> [YouGlassCustomFeed] {
        guard let data = defaults.data(forKey: DefaultsKey.customFeeds),
              let decoded = try? JSONDecoder().decode([YouGlassCustomFeed].self, from: data) else {
            return []
        }

        let valid = decoded.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let bounded = Array(valid.prefix(Self.maxCustomFeeds))
        if bounded != decoded {
            persistCustomFeeds(bounded)
        }
        return bounded
    }

    func persistCustomFeeds(_ feeds: [YouGlassCustomFeed]? = nil) {
        let values = feeds ?? customFeeds
        guard let data = try? JSONEncoder().encode(Array(values.prefix(Self.maxCustomFeeds))) else {
            return
        }
        defaults.set(data, forKey: DefaultsKey.customFeeds)
    }

    @discardableResult
    func createCustomFeed(name rawName: String?, prompt rawPrompt: String) -> YouGlassCustomFeed? {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            customFeedMessage = "Describe the videos you want to see first."
            return nil
        }

        let requestedName = rawName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = requestedName.isEmpty
            ? YouGlassCustomFeedPromptInterpreter.suggestedName(for: prompt)
            : requestedName
        let feed = YouGlassCustomFeed(name: name, prompt: prompt)

        customFeeds.removeAll { $0.id == feed.id }
        customFeeds.insert(feed, at: 0)
        customFeeds = Array(customFeeds.prefix(Self.maxCustomFeeds))
        persistCustomFeeds()
        selectCustomFeed(feed, force: true)
        return feed
    }

    func updateCustomFeed(_ feed: YouGlassCustomFeed, name: String?, prompt: String) {
        guard let index = customFeeds.firstIndex(where: { $0.id == feed.id }) else { return }
        let requestedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            customFeedMessage = "Describe the videos you want to see first."
            return
        }

        let resolvedName = requestedName.isEmpty
            ? YouGlassCustomFeedPromptInterpreter.suggestedName(for: trimmedPrompt)
            : requestedName
        customFeeds[index].update(name: resolvedName, prompt: trimmedPrompt)
        persistCustomFeeds()
        if selectedCustomFeedID == feed.id {
            selectCustomFeed(customFeeds[index], force: true)
        }
    }

    func deleteCustomFeed(_ feed: YouGlassCustomFeed) {
        customFeeds.removeAll { $0.id == feed.id }
        persistCustomFeeds()
        guard selectedCustomFeedID == feed.id else { return }
        clearSelectedCustomFeed()
    }

    func selectCustomFeed(_ feed: YouGlassCustomFeed, force: Bool = false) {
        guard customFeeds.contains(where: { $0.id == feed.id }) else { return }
        selectedSubscriptionGroupID = nil
        subscriptionGroupVideos = []
        selectedSection = "Home"
        selectedPlaylist = nil
        selectedCustomFeedID = feed.id
        customFeedVideos = []
        customFeedMessage = "Building \(feed.name)…"
        customFeedTask?.cancel()
        customFeedGeneration &+= 1
        let generation = customFeedGeneration
        customFeedLoading = true
        customFeedTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.loadCustomFeed(id: feed.id, generation: generation, force: force)
        }
    }

    func refreshSelectedCustomFeed() {
        guard let feed = selectedCustomFeed else { return }
        selectCustomFeed(feed, force: true)
    }

    func clearSelectedCustomFeed() {
        customFeedTask?.cancel()
        customFeedTask = nil
        customFeedGeneration &+= 1
        selectedCustomFeedID = nil
        customFeedVideos = []
        customFeedLoading = false
        customFeedMessage = nil
    }

    private func loadCustomFeed(id: UUID, generation: Int, force: Bool) async {
        guard canPublishCustomFeed(generation),
              let feed = customFeeds.first(where: { $0.id == id }) else { return }

        let intent = feed.intent
        if intent.subscribedOnly, subscriptions.isEmpty {
            publishCustomFeed(
                [],
                message: "Connect YouTube subscriptions to use this feed.",
                generation: generation
            )
            return
        }

        var candidates = customFeedLocalCandidates()
        var usedLiveSource = false

        if intent.subscribedOnly {
            let channels = subscriptionChannels()
            if !channels.isEmpty {
                let uploads = await safariHomeFeed.loadFeed(
                    channels: Array(channels.prefix(24)),
                    maxResultsPerChannel: 4
                )
                guard canPublishCustomFeed(generation) else { return }
                candidates.append(contentsOf: uploads)
                usedLiveSource = usedLiveSource || !uploads.isEmpty
            }
        }

        let hasCredentials = await client.hasCredentials()
        guard canPublishCustomFeed(generation) else { return }

        if !intent.searchQuery.isEmpty {
            if hasCredentials {
                do {
                    candidates.append(contentsOf: try await client.searchVideos(
                        query: intent.searchQuery,
                        maxResults: 24,
                        order: intent.freshnessHours == nil ? "relevance" : "date",
                        videoDuration: intent.duration?.apiValue,
                        forceFresh: force
                    ))
                    usedLiveSource = true
                } catch {
                    // A custom feed remains useful from its local catalog when
                    // the API is rate-limited or temporarily offline.
                }
            } else {
                let webResult = await YouTubeWebFeedBridge.shared.searchVideos(
                    query: intent.searchQuery,
                    maxResults: 24
                )
                guard canPublishCustomFeed(generation) else { return }
                candidates.append(contentsOf: webResult.videos)
                usedLiveSource = usedLiveSource || !webResult.videos.isEmpty
            }
        }

        let ranked = YouGlassCustomFeedRanker.rank(
            mergeVideos(candidates),
            feed: feed,
            subscriptions: subscriptions,
            history: recentlyWatched,
            liked: locallyLikedVideos,
            saved: savedVideos,
            limit: 24
        )
        let message: String
        if ranked.isEmpty {
            message = intent.subscribedOnly
                ? "No matching uploads were found from your subscriptions yet."
                : "No matching long-form videos were found. Try a broader prompt."
        } else if usedLiveSource {
            message = force ? "Custom feed refreshed from YouTube" : "Custom feed built from your prompt"
        } else {
            message = "Showing saved matches while YouTube reconnects"
        }
        publishCustomFeed(ranked, message: message, generation: generation)
    }

    private func publishCustomFeed(_ videos: [VideoItem], message: String, generation: Int) {
        guard canPublishCustomFeed(generation) else { return }
        customFeedVideos = videos
        customFeedMessage = message
        customFeedLoading = false
        customFeedTask = nil
    }

    private func canPublishCustomFeed(_ generation: Int) -> Bool {
        !Task.isCancelled && generation == customFeedGeneration
    }

    private func customFeedLocalCandidates() -> [VideoItem] {
        mergeVideos(
            [feed.hero] + feed.forYou + feed.trending + feed.more + feed.queue
                + recentlyWatched + savedVideos + locallyLikedVideos
        )
    }

    private func subscriptionChannels() -> [SafariHomeFeedClient.Channel] {
        subscriptions.compactMap { subscription in
            let source = subscription.channelURL
                ?? (subscription.id.hasPrefix("UC")
                    ? URL(string: "https://www.youtube.com/channel/\(subscription.id)")
                    : nil)
            guard let source else { return nil }
            return SafariHomeFeedClient.Channel(
                name: subscription.name,
                source: source,
                category: "Custom Feed",
                channelID: subscription.canonicalChannelID
            )
        }
    }
}
