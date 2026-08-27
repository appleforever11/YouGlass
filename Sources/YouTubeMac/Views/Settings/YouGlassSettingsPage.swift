import SwiftUI

enum YouGlassSettingsPage: String, CaseIterable, Identifiable, Hashable {
    case general
    case appearance
    case account
    case recommendations
    case playback
    case commentsAndChat
    case notifications
    case privacy
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .account: "Account & API"
        case .recommendations: "Recommendations"
        case .playback: "Playback"
        case .commentsAndChat: "Comments & Chat"
        case .notifications: "Notifications"
        case .privacy: "Privacy & Data"
        case .advanced: "Advanced"
        case .about: "About & Help"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Connection, app identity, and this Mac."
        case .appearance: "Theme, ambient glass, and motion."
        case .account: "Google sign-in, API access, and credentials."
        case .recommendations: "Account signals and personalized feed refresh."
        case .playback: "Mute behavior, compact player, and PIP."
        case .commentsAndChat: "Comments, live chat, and community access."
        case .notifications: "YouTube notification center and account status."
        case .privacy: "Cached data, credentials, and local storage."
        case .advanced: "Diagnostics and account recovery tools."
        case .about: "Version details and useful resources."
        }
    }

    var systemName: String {
        switch self {
        case .general: "gearshape.fill"
        case .appearance: "paintbrush.pointed.fill"
        case .account: "person.crop.circle.fill"
        case .recommendations: "wand.and.stars"
        case .playback: "play.circle.fill"
        case .commentsAndChat: "bubble.left.and.bubble.right.fill"
        case .notifications: "bell.fill"
        case .privacy: "lock.fill"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .appearance: .purple
        case .account: .blue
        case .recommendations: .pink
        case .playback: .indigo
        case .commentsAndChat: .cyan
        case .notifications: .red
        case .privacy: .green
        case .advanced: .orange
        case .about: .pink
        }
    }
}
