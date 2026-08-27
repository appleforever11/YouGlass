import Foundation
import SwiftUI

/// A small local-first collection. Collections intentionally store video IDs,
/// while the store keeps the latest known `VideoItem` metadata beside them.
/// This keeps the feature portable without making YouTube account playlists
/// look like local data.
struct YouGlassLibraryCollection: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var videoIDs: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        videoIDs: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.videoIDs = Array(NSOrderedSet(array: videoIDs).compactMap { $0 as? String })
        self.createdAt = createdAt
    }

    mutating func add(videoID: String) {
        guard !videoID.isEmpty, !videoIDs.contains(videoID) else { return }
        videoIDs.insert(videoID, at: 0)
    }

    mutating func remove(videoID: String) {
        videoIDs.removeAll { $0 == videoID }
    }
}

struct YouGlassVideoNote: Codable, Hashable, Identifiable {
    let id: UUID
    let videoID: String
    var text: String
    var timestamp: Double?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        videoID: String,
        text: String,
        timestamp: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.videoID = videoID
        self.text = text
        self.timestamp = timestamp?.isFinite == true ? max(0, timestamp ?? 0) : nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct YouGlassThemeCustomization: Codable, Equatable {
    var accentHex: String?

    static let empty = YouGlassThemeCustomization(accentHex: nil)

    var normalizedAccentHex: String? {
        guard let accentHex else { return nil }
        return Self.normalizeHex(accentHex)
    }

    var accentColor: Color? {
        guard let normalized = normalizedAccentHex else { return nil }
        let value = String(normalized.dropFirst())
        guard let number = UInt64(value, radix: 16) else { return nil }
        return Color(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }

    static func normalizeHex(_ rawValue: String) -> String? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        guard value.count == 6,
              value.allSatisfy({ $0.isHexDigit }) else { return nil }
        return "#" + value.uppercased()
    }
}
