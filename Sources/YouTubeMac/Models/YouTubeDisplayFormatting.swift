import Foundation

extension Int {
    var abbreviated: String {
        if self >= 1_000_000 { return "\(self / 1_000_000)M" }
        if self >= 1_000 { return "\(self / 1_000)K" }
        return "\(self)"
    }
}

extension String {
    var abbreviatedCount: String {
        guard let value = Int(self) else { return self }
        if value >= 1_000_000_000 { return String(format: "%.1fB", Double(value) / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    var abbreviatedViews: String {
        guard let value = Int(self) else { return "YouTube" }
        if value >= 1_000_000 { return "\(value / 1_000_000)M views" }
        if value >= 1_000 { return "\(value / 1_000)K views" }
        return "\(value) views"
    }
}

func relativeDate(_ value: String) -> String {
    guard let date = ISO8601DateFormatter().date(from: value) else { return "now" }
    let seconds = max(1, Int(Date().timeIntervalSince(date)))
    if seconds < 60 { return "now" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    return "\(hours / 24)d"
}

extension String {
    var htmlDecoded: String {
        replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
