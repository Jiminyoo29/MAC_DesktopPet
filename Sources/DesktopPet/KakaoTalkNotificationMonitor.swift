import Foundation
import SQLite3
import Darwin

final class KakaoTalkNotificationMonitor {
    private let interval: TimeInterval
    private let onNotification: () -> Void
    private let onAccessDenied: () -> Void
    private let onStatusChanged: (String) -> Void
    private var timer: Timer?
    private var seenFingerprints = Set<String>()
    private var hasSeededInitialState = false
    private var hasReportedAccessDenied = false
    private var lastStatus = "알림 감지 준비 중"
    private var fileEventSources: [DispatchSourceFileSystemObject] = []
    private var isPolling = false
    private var shouldPollAgain = false
    private let pollQueue = DispatchQueue(label: "io.github.mac-desktoppet.notification-monitor", qos: .userInitiated)

    init(
        interval: TimeInterval = 0.2,
        onNotification: @escaping () -> Void,
        onAccessDenied: @escaping () -> Void,
        onStatusChanged: @escaping (String) -> Void
    ) {
        self.interval = interval
        self.onNotification = onNotification
        self.onAccessDenied = onAccessDenied
        self.onStatusChanged = onStatusChanged
    }

    func start() {
        startFileWatchers()
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        fileEventSources.forEach { $0.cancel() }
        fileEventSources.removeAll()
    }

    private func startFileWatchers() {
        fileEventSources.forEach { $0.cancel() }
        fileEventSources.removeAll()

        for url in Self.notificationDatabaseWatchURLs() {
            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .extend, .attrib, .rename, .delete],
                queue: pollQueue
            )
            source.setEventHandler { [weak self] in
                self?.poll()
            }
            source.setCancelHandler {
                close(descriptor)
            }
            fileEventSources.append(source)
            source.resume()
        }
    }

    private func poll() {
        pollQueue.async { [weak self] in
            guard let self else { return }
            if self.isPolling {
                self.shouldPollAgain = true
                return
            }

            self.isPolling = true
            let result = Self.latestKakaoTalkNotificationFingerprints()
            self.isPolling = false

            DispatchQueue.main.async {
                guard case let .fingerprints(fingerprints, status) = result else {
                    self.updateStatus("알림 DB 접근 권한 없음")
                    if !self.hasReportedAccessDenied {
                        self.hasReportedAccessDenied = true
                        self.onAccessDenied()
                    }
                    return
                }

                self.hasReportedAccessDenied = false
                self.updateStatus(status)

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

            if self.shouldPollAgain {
                self.shouldPollAgain = false
                self.poll()
            }
        }
    }

    private func updateStatus(_ status: String) {
        guard status != lastStatus else { return }
        lastStatus = status
        Self.writeDiagnostic(status)
        onStatusChanged(status)
    }

    private enum PollResult {
        case fingerprints([String], String)
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
                return .fingerprints(rows, "카카오톡 알림 기록 \(rows.count)개 감지")
            case .accessDenied:
                return .accessDenied
            default:
                break
            }

            switch queryFallbackNotificationRows(databaseURL: databaseURL) {
            case let .rows(rows) where !rows.isEmpty:
                return .fingerprints(rows, "카카오톡 알림 흔적 \(rows.count)개 감지")
            case .accessDenied:
                return .accessDenied
            default:
                break
            }
        }

        return .fingerprints([], "알림 DB 접근 가능, 카카오톡 기록 없음")
    }

    private static func notificationDatabaseWatchURLs() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let databaseURLs = [
            home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db"),
            home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db/db")
        ]

        var urls: [URL] = []
        for databaseURL in databaseURLs {
            urls.append(databaseURL.deletingLastPathComponent())
            urls.append(databaseURL)
            urls.append(URL(fileURLWithPath: databaseURL.path + "-wal"))
            urls.append(URL(fileURLWithPath: databaseURL.path + "-shm"))
        }

        return urls.filter { FileManager.default.fileExists(atPath: $0.path) }
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
        let dateExpression = dateColumn.map { "r.\($0)" } ?? "0"
        let sql = """
        SELECT r.rowid || '|' || \(dateExpression) || '|' || a.\(appIdentifierColumn)
        FROM record r
        LEFT JOIN app a ON r.app_id = a.app_id
        WHERE a.\(appIdentifierColumn) LIKE '%kakao%'
        ORDER BY \(dateExpression) DESC
        LIMIT 8;
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

    private static func writeDiagnostic(_ status: String) {
        let formatter = ISO8601DateFormatter()
        let line = "[\(formatter.string(from: Date()))] \(status)\n"
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MAC DesktopPet.log")

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                _ = try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}
