import Foundation

struct SubscriptionGroup: Identifiable, Codable, Equatable {
    enum SortOrder: String, Codable, CaseIterable {
        case alphabetical = "Alphabetical"
        case manual = "Manual"
    }

    static let maximumGroups = 24
    static let maximumChannels = 40
    var id = UUID()
    var name = ""
    var channelIDs: [String] = []
    var sortOrder: SortOrder = .alphabetical
    var isExpanded = true

    var normalized: Self {
        var result = self
        result.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        var seen = Set<String>()
        result.channelIDs = Array(channelIDs.filter { !$0.isEmpty && seen.insert($0).inserted }
            .prefix(Self.maximumChannels))
        return result
    }

    func channels(in subscriptions: [SubscriptionItem]) -> [SubscriptionItem] {
        let channels = channelIDs.compactMap { id in
            subscriptions.first { ($0.canonicalChannelID ?? $0.id) == id }
        }
        return sortOrder == .manual ? channels : channels.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    mutating func moveChannel(_ id: String, by offset: Int) {
        guard let index = channelIDs.firstIndex(of: id),
              channelIDs.indices.contains(index + offset) else { return }
        channelIDs.swapAt(index, index + offset)
        sortOrder = .manual
    }
}
