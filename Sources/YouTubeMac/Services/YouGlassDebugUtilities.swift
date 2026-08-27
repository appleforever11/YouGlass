import Foundation
import OSLog

extension YouGlassDebugEngine {
    static func defaultDiagnosticsDirectory(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("YouGlass", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
    }

    static func messageWithMetadata(_ message: String, metadata: [String: String]) -> String {
        let safeMessage = sanitize(message)
        guard !metadata.isEmpty else { return safeMessage }

        let details = metadata.keys.sorted().compactMap { key -> String? in
            guard let value = metadata[key] else { return nil }
            return "\(sanitize(key))=\(sanitize(value))"
        }.joined(separator: ", ")
        guard !details.isEmpty else { return safeMessage }
        return sanitize("\(safeMessage) [\(details)]")
    }

    static func sanitize(_ value: String) -> String {
        let compact = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let redacted = compact.replacingOccurrences(
            of: #"(?i)(?:authorization|cookie|set-cookie)\s*[:=]\s*[^,;\]]+|(?:api[_-]?key|key|access[_-]?token|refresh[_-]?token|client[_-]?secret)\s*[:=]\s*[^\s,;]+"#,
            with: "<redacted>",
            options: .regularExpression
        )
        return String(redacted.prefix(700))
    }

    static func filenameTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
