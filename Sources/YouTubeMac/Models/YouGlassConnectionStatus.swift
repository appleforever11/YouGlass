import Foundation

/// The short connection state shown in the home toolbar and empty states.
/// Keep this separate from the detailed store message so a long API or WebKit
/// diagnostic cannot make the primary navigation chrome jump or truncate.
enum YouGlassConnectionMode: Equatable, Sendable {
    case offline
    case syncing
    case connected
    case setupRequired
    case local

    var title: String {
        switch self {
        case .offline: "Offline"
        case .syncing: "Syncing YouTube"
        case .connected: "YouTube connected"
        case .setupRequired: "Connect YouTube"
        case .local: "Local mode"
        }
    }

    var subtitle: String {
        switch self {
        case .offline: "Showing saved data"
        case .syncing: "Refreshing your feed"
        case .connected: "Account feed ready"
        case .setupRequired: "Open Settings to connect"
        case .local: "Saved recommendations"
        }
    }

    var systemImage: String {
        switch self {
        case .offline: "wifi.slash"
        case .syncing: "arrow.triangle.2.circlepath"
        case .connected: "checkmark.circle.fill"
        case .setupRequired: "person.crop.circle.badge.plus"
        case .local: "internaldrive.fill"
        }
    }

    var isSetupActionRecommended: Bool {
        self == .setupRequired
    }

    static func resolve(
        isNetworkAvailable: Bool,
        isSignedIn: Bool,
        isSyncing: Bool,
        detailMessage: String
    ) -> Self {
        guard isNetworkAvailable else { return .offline }
        if isSyncing { return .syncing }
        if isSignedIn { return .connected }

        let normalizedMessage = detailMessage.lowercased()
        let setupSignals = [
            "api key",
            "credentials",
            "sign in",
            "connect youtube",
            "oauth",
            "client id"
        ]
        if setupSignals.contains(where: normalizedMessage.contains) {
            return .setupRequired
        }
        return .local
    }
}
