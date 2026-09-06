import Foundation

extension YouTubeStore {
    static let subscriptionGroupsKey = "YouGlass.subscriptionGroups.v1"

    var selectedSubscriptionGroup: SubscriptionGroup? {
        subscriptionGroups.first { $0.id == selectedSubscriptionGroupID }
    }

    func decodeSubscriptionGroups() -> [SubscriptionGroup] {
        guard let data = defaults.data(forKey: Self.subscriptionGroupsKey),
              let groups = try? JSONDecoder().decode([SubscriptionGroup].self, from: data) else { return [] }
        var seen = Set<UUID>()
        return Array(groups.map(\.normalized).filter { !$0.name.isEmpty && seen.insert($0.id).inserted }
            .prefix(SubscriptionGroup.maximumGroups))
    }

    func saveSubscriptionGroup(_ group: SubscriptionGroup) {
        let value = group.normalized
        guard !value.name.isEmpty else { return }
        if let index = subscriptionGroups.firstIndex(where: { $0.id == value.id }) {
            subscriptionGroups[index] = value
        } else if subscriptionGroups.count < SubscriptionGroup.maximumGroups {
            subscriptionGroups.append(value)
        }
        persistSubscriptionGroups()
        if selectedSubscriptionGroupID == value.id { showSubscriptionGroup(value) }
    }

    func persistSubscriptionGroups() {
        guard let data = try? JSONEncoder().encode(subscriptionGroups) else { return }
        defaults.set(data, forKey: Self.subscriptionGroupsKey)
    }

    func editSubscriptionGroup(_ group: SubscriptionGroup? = nil) {
        editingSubscriptionGroup = group
        subscriptionGroupEditorPresented = true
    }

    func deleteSubscriptionGroup(_ group: SubscriptionGroup) {
        subscriptionGroups.removeAll { $0.id == group.id }
        persistSubscriptionGroups()
        if selectedSubscriptionGroupID == group.id { showSection("Subscriptions") }
    }

    func toggleSubscriptionGroup(_ group: SubscriptionGroup) {
        guard let index = subscriptionGroups.firstIndex(where: { $0.id == group.id }) else { return }
        subscriptionGroups[index].isExpanded.toggle()
        persistSubscriptionGroups()
    }

    func addChannel(_ channelID: String, to groupID: UUID) {
        guard let index = subscriptionGroups.firstIndex(where: { $0.id == groupID }),
              subscriptions.contains(where: { ($0.canonicalChannelID ?? $0.id) == channelID }),
              !subscriptionGroups[index].channelIDs.contains(channelID),
              subscriptionGroups[index].channelIDs.count < SubscriptionGroup.maximumChannels else { return }
        subscriptionGroups[index].channelIDs.append(channelID)
        persistSubscriptionGroups()
        if selectedSubscriptionGroupID == groupID { showSubscriptionGroup(subscriptionGroups[index]) }
    }

    func showSubscriptionGroup(_ group: SubscriptionGroup) {
        selectedSubscriptionGroupID = group.id
        showSection("Subscription Group")
    }

    func loadSubscriptionGroup(generation: Int?) async {
        guard let group = selectedSubscriptionGroup, canPublishSectionLoad(generation) else { return }
        let channels = group.channels(in: subscriptions)
        let localVideos = mergeVideos(recentlyWatched + savedVideos + subscriptionGroupVideos)
            .filter { video in channels.contains { $0.matches(channelID: video.channelID, channelName: video.channel) } }
        subscriptionGroupVideos = localVideos
        guard isNetworkAvailable else {
            subscriptionGroupMessage = "Offline — showing saved videos from this group."
            return
        }
        guard !channels.isEmpty else {
            subscriptionGroupMessage = "Add subscribed channels to this group to see their latest uploads."
            return
        }
        isLoading = true
        subscriptionGroupMessage = nil
        defer { if canPublishSectionLoad(generation) { isLoading = false } }
        let sources = channels.compactMap { channel -> SafariHomeFeedClient.Channel? in
            let url = channel.channelURL ?? channel.canonicalChannelID.flatMap {
                URL(string: "https://www.youtube.com/channel/\($0)")
            }
            guard let url else { return nil }
            return .init(name: channel.name, source: url, category: group.name, channelID: channel.canonicalChannelID)
        }
        let videos = await safariHomeFeed.loadFeed(channels: sources, maxResultsPerChannel: 4, timeout: 8)
        guard canPublishSectionLoad(generation), selectedSubscriptionGroupID == group.id else { return }
        if videos.isEmpty {
            subscriptionGroupMessage = "No new uploads were available. Saved group videos remain below."
        } else {
            subscriptionGroupVideos = nonShortVideos(videos)
        }
    }
}
