import Foundation
import SQLite3
import Darwin
import AppKit
import ApplicationServices

final class KakaoTalkNotificationMonitor {
    private let interval: TimeInterval
    private let targetConfigurations: () -> [NotificationMonitorTarget]
    private let onNotification: (NotificationMonitorEvent) -> Void
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
    private var lastDiagnosticDetail: String?
    private let pollQueue = DispatchQueue(label: "io.github.mac-desktoppet.notification-monitor", qos: .userInitiated)

    init(
        interval: TimeInterval = NotificationMonitorTiming.watchdogInterval,
        targetConfigurations: @escaping () -> [NotificationMonitorTarget],
        onNotification: @escaping (NotificationMonitorEvent) -> Void,
        onAccessDenied: @escaping () -> Void,
        onStatusChanged: @escaping (String) -> Void
    ) {
        self.interval = interval
        self.targetConfigurations = targetConfigurations
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
            let targets = self.targetConfigurations()
            let result = Self.latestNotificationEvents(targetConfigurations: targets)
            self.isPolling = false

            DispatchQueue.main.async {
                switch result {
                case let .accessDenied(sqliteMessage, detail):
                    let status = NotificationMonitorDiagnostics.userFacingAccessDeniedStatus(sqliteMessage: sqliteMessage)
                    self.updateStatus(status, detail: detail)
                    if !self.hasReportedAccessDenied {
                        self.hasReportedAccessDenied = true
                        self.onAccessDenied()
                    }
                    return

                case let .failed(status, detail):
                    self.hasReportedAccessDenied = false
                    self.updateStatus(status, detail: detail)
                    return

                case let .records(records, status, detail):
                    self.hasReportedAccessDenied = false
                    self.updateStatus(status, detail: detail)

                    if self.hasSeededInitialState {
                        let newRecords = records.filter { !self.seenFingerprints.contains($0.fingerprint) }
                        for record in newRecords {
                            self.onNotification(
                                NotificationMonitorEvent(
                                    bundleIdentifier: record.bundleIdentifier,
                                    content: record.content
                                )
                            )
                        }
                    } else {
                        self.hasSeededInitialState = true
                    }

                    self.seenFingerprints.formUnion(records.map(\.fingerprint))
                    if self.seenFingerprints.count > 200 {
                        self.seenFingerprints = Set(self.seenFingerprints.suffix(80))
                    }
                }
            }

            if self.shouldPollAgain {
                self.shouldPollAgain = false
                self.poll()
            }
        }
    }

    private func updateStatus(_ status: String, detail: String? = nil) {
        if status != lastStatus {
            lastStatus = status
            Self.writeDiagnostic(status)
            onStatusChanged(status)
        }

        guard let detail, detail != lastDiagnosticDetail else { return }
        lastDiagnosticDetail = detail
        Self.writeDiagnostic("진단: \(detail)")
    }

    private enum PollResult {
        case records([NotificationRecord], String, String?)
        case accessDenied(String, String?)
        case failed(String, String?)
    }

    private struct NotificationRecord {
        let fingerprint: String
        let bundleIdentifier: String
        let content: String?
    }

    private enum SQLiteResult {
        case rows([String])
        case accessDenied(String)
        case failed(String)
    }

    private static func latestNotificationEvents(targetConfigurations: [NotificationMonitorTarget]) -> PollResult {
        let targets = deduplicatedTargets(targetConfigurations)
        guard !targets.isEmpty else {
            return .records([], "연결된 앱 없음", nil)
        }

        if let visibleResult = latestVisibleNotificationFingerprints(targetConfigurations: targets) {
            return visibleResult
        }

        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db"),
            home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db/db")
        ]

        var failureDetails: [String] = []

        for databaseURL in candidates where fileManager.fileExists(atPath: databaseURL.path) {
            let snapshot = NotificationMonitorDiagnostics.databaseSnapshot(databaseURL: databaseURL)
            switch queryKnownNotificationSchema(databaseURL: databaseURL, targetConfigurations: targets) {
            case let .rows(rows) where !rows.isEmpty:
                let records = notificationRecords(from: rows)
                let detail = NotificationMonitorDiagnostics.querySummary(
                    targetBundleIdentifiers: targets.map(\.bundleIdentifier),
                    databaseURL: databaseURL,
                    note: "known-schema rows=\(rows.count)"
                )
                return .records(records, "연결 앱 알림 기록 \(records.count)개 감지", detail)
            case let .accessDenied(detail):
                return .accessDenied(detail, "\(detail); \(snapshot)")
            case let .failed(detail):
                failureDetails.append(detail)
            default:
                break
            }

            switch queryNotificationActivityLists(databaseURL: databaseURL, targetConfigurations: targets) {
            case let .rows(rows) where !rows.isEmpty:
                let records = notificationRecords(from: rows)
                let detail = NotificationMonitorDiagnostics.querySummary(
                    targetBundleIdentifiers: targets.map(\.bundleIdentifier),
                    databaseURL: databaseURL,
                    note: "activity-list rows=\(rows.count)"
                )
                return .records(records, "연결 앱 알림 목록 \(records.count)개 감지", detail)
            case let .accessDenied(detail):
                return .accessDenied(detail, "\(detail); \(snapshot)")
            case let .failed(detail):
                failureDetails.append(detail)
            default:
                break
            }

            failureDetails.append(
                NotificationMonitorDiagnostics.querySummary(
                    targetBundleIdentifiers: targets.map(\.bundleIdentifier),
                    databaseURL: databaseURL,
                    note: "target rows=0"
                )
            )
        }

        if !failureDetails.isEmpty {
            return .records([], "알림 DB 접근 가능, 연결 앱 기록 없음", failureDetails.joined(separator: " | "))
        }

        return .failed("알림 DB 파일을 찾지 못했어요.", nil)
    }

    private static func latestVisibleNotificationFingerprints(targetConfigurations: [NotificationMonitorTarget]) -> PollResult? {
        guard AXIsProcessTrusted() else { return nil }
        let targetNames = targetConfigurations.flatMap { target -> [(NotificationMonitorTarget, String)] in
            let bundleIdentifier = target.bundleIdentifier
            let appName = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)?
                .deletingPathExtension()
                .lastPathComponent
                .lowercased() ?? bundleIdentifier.lowercased()
            var names = [appName, bundleIdentifier.lowercased()]
            if bundleIdentifier.lowercased().contains("kakao") {
                names.append("카카오")
                names.append("카카오톡")
                names.append("kakao")
            }
            return names.map { (target, $0) }
        }

        let notificationCenterApps = NSWorkspace.shared.runningApplications.filter { app in
            let name = app.localizedName?.lowercased() ?? ""
            let bundleIdentifier = app.bundleIdentifier?.lowercased() ?? ""
            return name.contains("notification")
                || bundleIdentifier.contains("notificationcenter")
                || bundleIdentifier.contains("usernoted")
        }

        var matches: [NotificationRecord] = []

        for app in notificationCenterApps {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            let textGroups = visibleTextGroups(in: appElement)
            for texts in textGroups {
                let content = notificationContent(from: texts)
                let lowercased = content.lowercased()
                guard let target = targetNames.first(where: { lowercased.contains($0.1) }) else {
                    continue
                }
                let targetConfiguration = target.0
                matches.append(
                    NotificationRecord(
                        fingerprint: "\(targetConfiguration.bundleIdentifier)|visible|\(content.hashValue)",
                        bundleIdentifier: targetConfiguration.bundleIdentifier,
                        content: targetConfiguration.showsNotificationContent ? content : nil
                    )
                )
            }
        }

        guard !matches.isEmpty else { return nil }
        return .records(matches, "화면 알림 배너 \(matches.count)개 감지", "accessibility visible rows=\(matches.count)")
    }

    private static func deduplicatedTargets(_ targets: [NotificationMonitorTarget]) -> [NotificationMonitorTarget] {
        var byIdentifier: [String: NotificationMonitorTarget] = [:]
        for target in targets where !target.bundleIdentifier.isEmpty {
            let key = target.normalizedBundleIdentifier
            if let existing = byIdentifier[key] {
                let reactionMode: NotificationReactionMode = (
                    existing.reactionMode == .includeHidden || target.reactionMode == .includeHidden
                ) ? .includeHidden : .visibleOnly
                byIdentifier[key] = NotificationMonitorTarget(
                    bundleIdentifier: existing.bundleIdentifier,
                    reactionMode: reactionMode,
                    showsNotificationContent: existing.showsNotificationContent || target.showsNotificationContent
                )
            } else {
                byIdentifier[key] = target
            }
        }
        return Array(byIdentifier.values)
    }

    private static func notificationRecords(from rows: [String]) -> [NotificationRecord] {
        rows.compactMap { row in
            let parts = row.split(separator: "|", omittingEmptySubsequences: false)
            guard let first = parts.first else { return nil }
            let bundleIdentifier = String(first)
            return NotificationRecord(
                fingerprint: row,
                bundleIdentifier: bundleIdentifier,
                content: nil
            )
        }
    }

    private static func visibleTextGroups(in element: AXUIElement) -> [[String]] {
        var roots: [AXUIElement] = []
        var windowsValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windowsValue) == .success,
           let windows = windowsValue as? [AXUIElement],
           !windows.isEmpty {
            roots = windows
        } else {
            roots = [element]
        }

        return roots.map { visibleTexts(in: $0, depth: 0) }.filter { !$0.isEmpty }
    }

    private static func notificationContent(from texts: [String]) -> String {
        var seen = Set<String>()
        let lines = texts.compactMap { text -> String? in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return nil }
            seen.insert(trimmed)
            return trimmed
        }
        return lines.joined(separator: "\n")
    }

    private static func visibleTexts(in element: AXUIElement, depth: Int) -> [String] {
        guard depth < 5 else { return [] }

        var texts: [String] = []
        let textAttributes = [
            kAXTitleAttribute,
            kAXValueAttribute,
            kAXDescriptionAttribute,
            kAXHelpAttribute
        ]

        for attribute in textAttributes {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
               let value {
                if let string = value as? String, !string.isEmpty {
                    texts.append(string)
                } else if let attributedString = value as? NSAttributedString {
                    let string = attributedString.string
                    if !string.isEmpty { texts.append(string) }
                }
            }
        }

        var childrenValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
           let children = childrenValue as? [AXUIElement] {
            for child in children {
                texts.append(contentsOf: visibleTexts(in: child, depth: depth + 1))
            }
        }

        var windowsValue: CFTypeRef?
        if depth == 0,
           AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windowsValue) == .success,
           let windows = windowsValue as? [AXUIElement] {
            for window in windows {
                texts.append(contentsOf: visibleTexts(in: window, depth: depth + 1))
            }
        }

        return texts
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

    private static func queryKnownNotificationSchema(databaseURL: URL, targetConfigurations: [NotificationMonitorTarget]) -> SQLiteResult {
        let tableResult = runSQLite(
            databaseURL: databaseURL,
            sql: "SELECT name FROM sqlite_master WHERE type='table';",
            queryLabel: "schema-tables"
        )
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
        let targetByIdentifier = Dictionary(
            uniqueKeysWithValues: targetConfigurations.map { ($0.normalizedBundleIdentifier, $0) }
        )
        let escapedTargets = targetConfigurations
            .map { "'\($0.normalizedBundleIdentifier.replacingOccurrences(of: "'", with: "''"))'" }
            .joined(separator: ",")
        let presentedExpression = recordColumns.contains("presented") ? "r.presented" : "1"

        let sql = """
        SELECT lower(a.\(appIdentifierColumn)) || '|' || r.rowid || '|' || \(dateExpression) || '|' || \(presentedExpression)
        FROM record r
        LEFT JOIN app a ON r.app_id = a.app_id
        WHERE lower(a.\(appIdentifierColumn)) IN (\(escapedTargets))
        ORDER BY \(dateExpression) DESC
        LIMIT 8;
        """
        switch runSQLite(databaseURL: databaseURL, sql: sql, queryLabel: "known-schema") {
        case let .rows(rows):
            let filteredRows = rows.filter { row in
                let parts = row.split(separator: "|", omittingEmptySubsequences: false)
                guard let bundle = parts.first else { return false }
                let target = targetByIdentifier[String(bundle)]
                let presentedValue = parts.count > 3 ? String(parts[3]) : nil
                return NotificationMonitorPolicy.includesRecord(
                    reactionMode: target?.reactionMode ?? .visibleOnly,
                    presentedValue: presentedValue
                )
            }
            return .rows(filteredRows.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        case let .accessDenied(detail):
            return .accessDenied(detail)
        case let .failed(detail):
            return .failed(detail)
        }
    }

    private static func tableColumns(databaseURL: URL, table: String) -> Set<String> {
        let safeTable = table.replacingOccurrences(of: "'", with: "''")
        let sql = "PRAGMA table_info('\(safeTable)');"
        guard case let .rows(rows) = runSQLite(
            databaseURL: databaseURL,
            sql: sql,
            queryLabel: "table-info-\(table)"
        ) else { return [] }
        let names = rows.compactMap { row -> String? in
            let parts = row.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count > 1 else { return nil }
            return String(parts[1])
        }
        return Set(names)
    }

    private static func queryNotificationActivityLists(databaseURL: URL, targetConfigurations: [NotificationMonitorTarget]) -> SQLiteResult {
        let hiddenTargets = targetConfigurations.filter { $0.reactionMode == .includeHidden }
        guard !hiddenTargets.isEmpty else { return .rows([]) }

        let tableResult = runSQLite(
            databaseURL: databaseURL,
            sql: "SELECT name FROM sqlite_master WHERE type='table';",
            queryLabel: "activity-schema-tables"
        )
        guard case let .rows(tables) = tableResult else { return tableResult }

        let tableSet = Set(tables)
        guard tableSet.contains("app") else { return .rows([]) }

        var matches: [String] = []
        let appColumns = tableColumns(databaseURL: databaseURL, table: "app")
        guard let appIdentifierColumn = ["identifier", "bundleid", "bundle_id"].first(where: { appColumns.contains($0) }) else {
            return .rows([])
        }

        let escapedTargets = hiddenTargets
            .map { "'\($0.normalizedBundleIdentifier.replacingOccurrences(of: "'", with: "''"))'" }
            .joined(separator: ",")

        for table in ["delivered", "displayed", "requests"] where tableSet.contains(table) {
            let columns = tableColumns(databaseURL: databaseURL, table: table)
            guard columns.contains("app_id"), columns.contains("list") else { continue }
            let safeTable = table.replacingOccurrences(of: "\"", with: "\"\"")
            let sql = """
            SELECT a.\(appIdentifierColumn) || '|activity|\(safeTable)|' || t.rowid || '|' || length(t.list) || '|' || hex(substr(t.list, 1, 16))
            FROM "\(safeTable)" t
            LEFT JOIN app a ON t.app_id = a.app_id
            WHERE lower(a.\(appIdentifierColumn)) IN (\(escapedTargets))
              AND t.list IS NOT NULL
              AND length(t.list) > 0
            ORDER BY t.rowid DESC
            LIMIT 8;
            """
            let result = runSQLite(databaseURL: databaseURL, sql: sql, queryLabel: "activity-list-\(table)")
            if case let .accessDenied(detail) = result { return .accessDenied(detail) }
            if case let .failed(detail) = result { return .failed(detail) }
            guard case let .rows(rows) = result else { continue }
            matches.append(contentsOf: rows)
        }

        return .rows(Array(matches.prefix(20)))
    }

    private static func runSQLite(databaseURL: URL, sql: String, queryLabel: String) -> SQLiteResult {
        var database: OpaquePointer?
        let openCode = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
        defer {
            if database != nil {
                sqlite3_close(database)
            }
        }

        guard openCode == SQLITE_OK, let database else {
            let message = database.map(sqliteErrorMessage) ?? "sqlite open failed"
            let detail = NotificationMonitorDiagnostics.sqliteFailureDetail(
                stage: "open",
                code: openCode,
                message: message,
                databasePath: databaseURL.path,
                queryLabel: queryLabel
            )
            if NotificationMonitorDiagnostics.isAccessDeniedMessage(message) {
                return .accessDenied(detail)
            }
            return .failed(detail)
        }

        var statement: OpaquePointer?
        let prepareCode = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }

        guard prepareCode == SQLITE_OK, let statement else {
            let message = sqliteErrorMessage(database)
            let detail = NotificationMonitorDiagnostics.sqliteFailureDetail(
                stage: "prepare",
                code: prepareCode,
                message: message,
                databasePath: databaseURL.path,
                queryLabel: queryLabel
            )
            if NotificationMonitorDiagnostics.isAccessDeniedMessage(message) {
                return .accessDenied(detail)
            }
            return .failed(detail)
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
                let message = sqliteErrorMessage(database)
                let detail = NotificationMonitorDiagnostics.sqliteFailureDetail(
                    stage: "step",
                    code: stepCode,
                    message: message,
                    databasePath: databaseURL.path,
                    queryLabel: queryLabel
                )
                if NotificationMonitorDiagnostics.isAccessDeniedMessage(message) {
                    return .accessDenied(detail)
                }
                return .failed(detail)
            }
        }
    }

    private static func sqliteErrorMessage(_ database: OpaquePointer) -> String {
        guard let message = sqlite3_errmsg(database) else { return "" }
        return String(cString: message)
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
