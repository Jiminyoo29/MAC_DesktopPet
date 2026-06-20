import Foundation

enum NotificationMonitorDiagnostics {
    static func isAccessDeniedMessage(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("authorization denied")
            || lowercased.contains("not authorized")
            || lowercased.contains("operation not permitted")
            || lowercased.contains("permission denied")
    }

    static func userFacingAccessDeniedStatus(sqliteMessage: String) -> String {
        let trimmed = sqliteMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "전체 디스크 접근이 꺼져 있어 알림 DB를 읽지 못해요."
        }
        return "전체 디스크 접근이 꺼져 있어 알림 DB를 읽지 못해요."
    }

    static func sqliteFailureDetail(
        stage: String,
        code: Int32,
        message: String,
        databasePath: String,
        queryLabel: String
    ) -> String {
        let safeMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return "SQLite \(queryLabel) \(stage) 실패(code \(code)): \(safeMessage) @ \(displayPath(databasePath))"
    }

    static func databaseSnapshot(databaseURL: URL) -> String {
        let urls = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm")
        ]

        return urls.map(fileSnapshot).joined(separator: "; ")
    }

    static func querySummary(targetBundleIdentifiers: [String], databaseURL: URL, note: String) -> String {
        let targets = targetBundleIdentifiers.sorted().joined(separator: ",")
        return "targets=[\(targets)] \(note) \(databaseSnapshot(databaseURL: databaseURL))"
    }

    private static func fileSnapshot(_ url: URL) -> String {
        let path = displayPath(url.path)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return "\(path):missing"
        }

        let size = attributes[.size] as? NSNumber
        let modified = attributes[.modificationDate] as? Date
        let modifiedText = modified.map(formatDate) ?? "unknown"
        return "\(path):size=\(size?.intValue ?? 0),mtime=\(modifiedText)"
    }

    private static func displayPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
