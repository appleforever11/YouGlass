import Foundation

struct SubscriptionItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let avatarURL: URL?
    let channelURL: URL?
    let isLive: Bool

    init(
        id: String? = nil,
        name: String,
        avatarURL: URL?,
        channelURL: URL? = nil,
        isLive: Bool
    ) {
        self.id = id ?? "subscription:\(name.lowercased())"
        self.name = name
        self.avatarURL = avatarURL
        self.channelURL = channelURL
        self.isLive = isLive
    }
}

extension SubscriptionItem {
    /// Returns the stable YouTube channel ID when the item came from either
    /// the Data API or a channel URL extracted from the signed-in web session.
    var canonicalChannelID: String? {
        Self.canonicalChannelID(from: id) ?? Self.canonicalChannelID(from: channelURL?.absoluteString)
    }

    func matches(channelID: String?, channelName: String) -> Bool {
        let incomingChannelID = Self.canonicalChannelID(from: channelID)
        if let incomingChannelID, let canonicalChannelID {
            // Once both sources expose a stable ID, a display-name match is
            // unsafe: YouTube channel names are not unique.
            return canonicalChannelID == incomingChannelID
        }

        let targetName = Self.normalizedChannelName(channelName)
        guard !targetName.isEmpty else { return false }

        let candidates = [
            (name, Self.normalizedChannelName(name)),
            (Self.channelHandle(from: channelURL?.absoluteString), Self.normalizedChannelName(Self.channelHandle(from: channelURL?.absoluteString))),
            (Self.channelHandle(from: id), Self.normalizedChannelName(Self.channelHandle(from: id)))
        ].filter { !$0.1.isEmpty }

        return candidates.contains { rawCandidate, candidate in
            guard candidate == targetName || candidate.count >= 8 else { return false }
            if candidate == targetName { return true }

            // Web navigation labels can be shortened with an ellipsis. Only
            // allow a prefix match when that truncation is explicit; broad
            // fuzzy matching can incorrectly mark similarly named channels as
            // subscribed.
            let candidateWasTruncated = Self.hasTrailingTruncation(rawCandidate)
            let targetWasTruncated = Self.hasTrailingTruncation(channelName)
            guard candidateWasTruncated || targetWasTruncated else { return false }
            return candidate.hasPrefix(targetName) || targetName.hasPrefix(candidate)
        }
    }

    private static func canonicalChannelID(from value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let parts = value.split { character in
            !(character.isLetter || character.isNumber || character == "_" || character == "-")
        }
        return parts
            .map(String.init)
            .first { $0.hasPrefix("UC") && $0.count >= 24 }
    }

    private static func normalizedChannelName(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive], locale: .current)
            .lowercased()
        return folded.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func channelHandle(from value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        guard let atIndex = value.firstIndex(of: "@") else { return "" }
        let handle = value[atIndex...].dropFirst()
        return String(handle.prefix(while: { character in
            character.isLetter || character.isNumber || character == "_" || character == "-"
        }))
    }

    private static func hasTrailingTruncation(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("...") || trimmed.hasSuffix("\u{2026}")
    }
}
