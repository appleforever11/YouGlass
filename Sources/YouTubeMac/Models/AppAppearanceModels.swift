import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }
}

enum CompactPlayerCorner: String, CaseIterable, Identifiable, Equatable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeading: "Top Left"
        case .topTrailing: "Top Right"
        case .bottomLeading: "Bottom Left"
        case .bottomTrailing: "Bottom Right"
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }
}

enum PIPTransitionState: Equatable {
    case idle
    case presenting(videoID: String)
    case active(videoID: String)

    var isTransitioning: Bool {
        if case .presenting = self { return true }
        return false
    }

    func matches(videoID: String) -> Bool {
        switch self {
        case .idle:
            return false
        case .presenting(let currentID), .active(let currentID):
            return currentID == videoID
        }
    }
}

enum PIPTransitionPolicy {
    // Give the source WebView a full SwiftUI/AppKit transaction to tear down
    // before a new WebKit surface is created for the desktop PIP panel.
    static let sourceTeardownDelayNanoseconds: UInt64 = 180_000_000
    static let panelFadeDuration: TimeInterval = 0.18
}

enum PlaybackCheckpointPolicy {
    static let maxEntries = 200
    static let completionGraceSeconds = 3.0
    static let completionFraction = 0.98

    static func isResumable(position: Double, duration: Double) -> Bool {
        guard position.isFinite, duration.isFinite, position > 1, duration > 0 else {
            return false
        }
        return position / duration < completionFraction
    }
}

struct VideoAmbientColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}
