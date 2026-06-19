import Foundation

final class KakaoTalkNotificationMonitor {
    private let interval: TimeInterval
    private let onNotification: () -> Void
    private var timer: Timer?
    private var seenFingerprints = Set<String>()
    private var hasSeededInitialState = false

    init(interval: TimeInterval = 2.5, onNotification: @escaping () -> Void) {
        self.interval = interval
        self.onNotification = onNotification
    }

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let fingerprints = Self.latestKakaoTalkNotificationFingerprints()

            DispatchQueue.main.async {
                if self.hasSeededInitialState {
                    let newFingerprints = fingerprints.filter { !self.seenFingerprints.contains($0) }
                    if !newFingerprints.isEmpty {
                        self.onNotification()
                    }
                } else {
                    self.hasSeededInitialState = true
                }

                self.seenFingerprints.formUnion(fingerprints)
                if self.seenFingerprints.count > 200 {
                    self.seenFingerprints = Set(self.seenFingerprints.suffix(80))
                }
            }
        }
    }

    private static func latestKakaoTalkNotificationFingerprints() -> [String] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db"),
            home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db/db")
        ]

        for databaseURL in candidates where fileManager.fileExists(atPath: databaseURL.path) {
            let rows = queryKnownNotificationSchema(databaseURL: databaseURL)
            if !rows.isEmpty { return rows }

            let fallbackRows = queryFallbackNotificationRows(databaseURL: databaseURL)
            if !fallbackRows.isEmpty { return fallbackRows }
        }

        return []
    }

    private static func queryKnownNotificationSchema(databaseURL: URL) -> [String] {
        let tables = Set(runSQLite(databaseURL: databaseURL, sql: "SELECT name FROM sqlite_master WHERE type='table';"))
        guard tables.contains("record"), tables.contains("app") else { return [] }

        let recordColumns = tableColumns(databaseURL: databaseURL, table: "record")
        let appColumns = tableColumns(databaseURL: databaseURL, table: "app")
        guard recordColumns.contains("app_id"), appColumns.contains("app_id") else { return [] }

        let appIdentifierColumn = ["identifier", "bundleid", "bundle_id"].first { appColumns.contains($0) }
        guard let appIdentifierColumn else { return [] }

        let dateColumn = ["delivered_date", "presented_date", "date"].first { recordColumns.contains($0) }
        let payloadColumn = ["data", "request", "uuid"].first { recordColumns.contains($0) }

        let dateExpression = dateColumn.map { "r.\($0)" } ?? "0"
        let payloadExpression = payloadColumn.map { "hex(r.\($0))" } ?? "''"
        let sql = """
        SELECT \(dateExpression) || '|' || a.\(appIdentifierColumn) || '|' || \(payloadExpression)
        FROM record r
        LEFT JOIN app a ON r.app_id = a.app_id
        WHERE a.\(appIdentifierColumn) LIKE '%kakao%'
        ORDER BY \(dateExpression) DESC
        LIMIT 20;
        """
        return runSQLite(databaseURL: databaseURL, sql: sql)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func tableColumns(databaseURL: URL, table: String) -> Set<String> {
        let safeTable = table.replacingOccurrences(of: "'", with: "''")
        let sql = "PRAGMA table_info('\(safeTable)');"
        let rows = runSQLite(databaseURL: databaseURL, sql: sql)
        let names = rows.compactMap { row -> String? in
            let parts = row.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count > 1 else { return nil }
            return String(parts[1])
        }
        return Set(names)
    }

    private static func queryFallbackNotificationRows(databaseURL: URL) -> [String] {
        let tables = runSQLite(databaseURL: databaseURL, sql: "SELECT name FROM sqlite_master WHERE type='table';")
        var matches: [String] = []

        for table in tables.prefix(12) {
            let safeTable = table.replacingOccurrences(of: "\"", with: "\"\"")
            let sql = "SELECT * FROM \"\(safeTable)\" LIMIT 40;"
            let rows = runSQLite(databaseURL: databaseURL, sql: sql)
                .filter { row in
                    let lowered = row.lowercased()
                    return lowered.contains("kakao") || lowered.contains("카카오")
                }
            matches.append(contentsOf: rows.map { "\(table)|\($0)" })
        }

        return Array(matches.prefix(20))
    }

    private static func runSQLite(databaseURL: URL, sql: String) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-batch", "-noheader", databaseURL.path, sql]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let string = String(data: data, encoding: .utf8) else { return [] }
        return string
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }
}
