import Foundation
import SQLite3

final class KakaoTalkNotificationMonitor {
    private let interval: TimeInterval
    private let onNotification: () -> Void
    private let onAccessDenied: () -> Void
    private var timer: Timer?
    private var seenFingerprints = Set<String>()
    private var hasSeededInitialState = false
    private var hasReportedAccessDenied = false

    init(interval: TimeInterval = 2.5, onNotification: @escaping () -> Void, onAccessDenied: @escaping () -> Void) {
        self.interval = interval
        self.onNotification = onNotification
        self.onAccessDenied = onAccessDenied
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
            let result = Self.latestKakaoTalkNotificationFingerprints()

            DispatchQueue.main.async {
                guard case let .fingerprints(fingerprints) = result else {
                    if !self.hasReportedAccessDenied {
                        self.hasReportedAccessDenied = true
                        self.onAccessDenied()
                    }
                    return
                }

                self.hasReportedAccessDenied = false

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

    private enum PollResult {
        case fingerprints([String])
        case accessDenied
    }

    private enum SQLiteResult {
        case rows([String])
        case accessDenied
        case failed
    }

    private static func latestKakaoTalkNotificationFingerprints() -> PollResult {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db"),
            home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db/db")
        ]

        for databaseURL in candidates where fileManager.fileExists(atPath: databaseURL.path) {
            switch queryKnownNotificationSchema(databaseURL: databaseURL) {
            case let .rows(rows) where !rows.isEmpty:
                return .fingerprints(rows)
            case .accessDenied:
                return .accessDenied
            default:
                break
            }

            switch queryFallbackNotificationRows(databaseURL: databaseURL) {
            case let .rows(rows) where !rows.isEmpty:
                return .fingerprints(rows)
            case .accessDenied:
                return .accessDenied
            default:
                break
            }
        }

        return .fingerprints([])
    }

    private static func queryKnownNotificationSchema(databaseURL: URL) -> SQLiteResult {
        let tableResult = runSQLite(databaseURL: databaseURL, sql: "SELECT name FROM sqlite_master WHERE type='table';")
        guard case let .rows(tableRows) = tableResult else { return tableResult }

        let tables = Set(tableRows)
        guard tables.contains("record"), tables.contains("app") else { return .rows([]) }

        let recordColumns = tableColumns(databaseURL: databaseURL, table: "record")
        let appColumns = tableColumns(databaseURL: databaseURL, table: "app")
        guard recordColumns.contains("app_id"), appColumns.contains("app_id") else { return .rows([]) }

        let appIdentifierColumn = ["identifier", "bundleid", "bundle_id"].first { appColumns.contains($0) }
        guard let appIdentifierColumn else { return .rows([]) }

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
        switch runSQLite(databaseURL: databaseURL, sql: sql) {
        case let .rows(rows):
            return .rows(rows.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        case .accessDenied:
            return .accessDenied
        case .failed:
            return .failed
        }
    }

    private static func tableColumns(databaseURL: URL, table: String) -> Set<String> {
        let safeTable = table.replacingOccurrences(of: "'", with: "''")
        let sql = "PRAGMA table_info('\(safeTable)');"
        guard case let .rows(rows) = runSQLite(databaseURL: databaseURL, sql: sql) else { return [] }
        let names = rows.compactMap { row -> String? in
            let parts = row.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count > 1 else { return nil }
            return String(parts[1])
        }
        return Set(names)
    }

    private static func queryFallbackNotificationRows(databaseURL: URL) -> SQLiteResult {
        let tableResult = runSQLite(databaseURL: databaseURL, sql: "SELECT name FROM sqlite_master WHERE type='table';")
        guard case let .rows(tables) = tableResult else { return tableResult }

        var matches: [String] = []

        for table in tables.prefix(12) {
            let safeTable = table.replacingOccurrences(of: "\"", with: "\"\"")
            let sql = "SELECT * FROM \"\(safeTable)\" LIMIT 40;"
            let result = runSQLite(databaseURL: databaseURL, sql: sql)
            if case .accessDenied = result { return .accessDenied }
            guard case let .rows(rows) = result else { continue }

            let filteredRows = rows.filter { row in
                    let lowered = row.lowercased()
                    return lowered.contains("kakao") || lowered.contains("카카오")
            }
            matches.append(contentsOf: filteredRows.map { "\(table)|\($0)" })
        }

        return .rows(Array(matches.prefix(20)))
    }

    private static func runSQLite(databaseURL: URL, sql: String) -> SQLiteResult {
        var database: OpaquePointer?
        let openCode = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
        defer {
            if database != nil {
                sqlite3_close(database)
            }
        }

        guard openCode == SQLITE_OK, let database else {
            if isAccessDeniedMessage(database.map(sqliteErrorMessage) ?? "") {
                return .accessDenied
            }
            return .failed
        }

        var statement: OpaquePointer?
        let prepareCode = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }

        guard prepareCode == SQLITE_OK, let statement else {
            if isAccessDeniedMessage(sqliteErrorMessage(database)) {
                return .accessDenied
            }
            return .failed
        }

        var rows: [String] = []

        while true {
            let stepCode = sqlite3_step(statement)
            switch stepCode {
            case SQLITE_ROW:
                let columnCount = sqlite3_column_count(statement)
                let values = (0..<columnCount).map { index -> String in
                    switch sqlite3_column_type(statement, index) {
                    case SQLITE_NULL:
                        return ""
                    case SQLITE_BLOB:
                        guard let bytes = sqlite3_column_blob(statement, index) else { return "" }
                        let count = Int(sqlite3_column_bytes(statement, index))
                        let buffer = UnsafeRawBufferPointer(start: bytes, count: count)
                        return buffer.map { String(format: "%02x", $0) }.joined()
                    default:
                        guard let text = sqlite3_column_text(statement, index) else { return "" }
                        return String(cString: text)
                    }
                }
                rows.append(values.joined(separator: "|"))
            case SQLITE_DONE:
                return .rows(rows)
            default:
                if isAccessDeniedMessage(sqliteErrorMessage(database)) {
                    return .accessDenied
                }
                return .failed
            }
        }
    }

    private static func sqliteErrorMessage(_ database: OpaquePointer) -> String {
        guard let message = sqlite3_errmsg(database) else { return "" }
        return String(cString: message).lowercased()
    }

    private static func isAccessDeniedMessage(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("authorization denied")
            || lowercased.contains("not authorized")
            || lowercased.contains("operation not permitted")
            || lowercased.contains("permission denied")
            || lowercased.contains("unable to open database")
    }
}
