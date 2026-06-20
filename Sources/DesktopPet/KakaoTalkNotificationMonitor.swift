import Foundation
import SQLite3
import Darwin
import AppKit
import ApplicationServices

final class KakaoTalkNotificationMonitor {
    private let interval: TimeInterval
    private let targetBundleIdentifiers: () -> [String]
    private let onNotification: (String) -> Void
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
        targetBundleIdentifiers: @escaping () -> [String],
        onNotification: @escaping (String) -> Void,
        onAccessDenied: @escaping () -> Void,
        onStatusChanged: @escaping (String) -> Void
    ) {
        self.interval = interval
        self.targetBundleIdentifiers = targetBundleIdentifiers
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
            let targets = self.targetBundleIdentifiers()
            let result = Self.latestNotificationFingerprints(targetBundleIdentifiers: targets)
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
                    let bundleIdentifiers = Set(newFingerprints.compactMap { fingerprint in
                        fingerprint.split(separator: "|", maxSplits: 1).first.map(String.init)
                    })
                    for bundleIdentifier in bundleIdentifiers {
                        self.onNotification(bundleIdentifier)
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

    private static func latestNotificationFingerprints(targetBundleIdentifiers: [String]) -> PollResult {
        let targets = Array(Set(targetBundleIdentifiers)).filter { !$0.isEmpty }
        guard !targets.isEmpty else {
            return .fingerprints([], "연결된 앱 없음")
        }

        if let visibleResult = latestVisibleNotificationFingerprints(targetBundleIdentifiers: targets) {
            return visibleResult
        }

        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db"),
            home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db/db")
        ]

        for databaseURL in candidates where fileManager.fileExists(atPath: databaseURL.path) {
            switch queryKnownNotificationSchema(databaseURL: databaseURL, targetBundleIdentifiers: targets) {
            case let .rows(rows) where !rows.isEmpty:
                return .fingerprints(rows, "연결 앱 알림 기록 \(rows.count)개 감지")
            case .accessDenied:
                return .accessDenied
            default:
                break
            }

            switch queryFallbackNotificationRows(databaseURL: databaseURL, targetBundleIdentifiers: targets) {
            case let .rows(rows) where !rows.isEmpty:
                return .fingerprints(rows, "연결 앱 알림 흔적 \(rows.count)개 감지")
            case .accessDenied:
                return .accessDenied
            default:
                break
            }
        }

        return .fingerprints([], "알림 DB 접근 가능, 연결 앱 기록 없음")
    }

    private static func latestVisibleNotificationFingerprints(targetBundleIdentifiers: [String]) -> PollResult? {
        guard AXIsProcessTrusted() else { return nil }
        let targetNames = targetBundleIdentifiers.flatMap { bundleIdentifier -> [(String, String)] in
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
            return names.map { (bundleIdentifier, $0) }
        }

        let notificationCenterApps = NSWorkspace.shared.runningApplications.filter { app in
            let name = app.localizedName?.lowercased() ?? ""
            let bundleIdentifier = app.bundleIdentifier?.lowercased() ?? ""
            return name.contains("notification")
                || bundleIdentifier.contains("notificationcenter")
                || bundleIdentifier.contains("usernoted")
        }

        var matches: [String] = []

        for app in notificationCenterApps {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            let texts = visibleTexts(in: appElement, depth: 0)
            for text in texts {
                let lowercased = text.lowercased()
                if let target = targetNames.first(where: { lowercased.contains($0.1) }) {
                    matches.append("\(target.0)|visible|\(text.hashValue)")
                }
            }
        }

        guard !matches.isEmpty else { return nil }
        return .fingerprints(matches, "화면 알림 배너 \(matches.count)개 감지")
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

    private static func queryKnownNotificationSchema(databaseURL: URL, targetBundleIdentifiers: [String]) -> SQLiteResult {
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
        let escapedTargets = targetBundleIdentifiers
            .map { "'\($0.lowercased().replacingOccurrences(of: "'", with: "''"))'" }
            .joined(separator: ",")

        let sql = """
        SELECT a.\(appIdentifierColumn) || '|' || r.rowid || '|' || \(dateExpression)
        FROM record r
        LEFT JOIN app a ON r.app_id = a.app_id
        WHERE lower(a.\(appIdentifierColumn)) IN (\(escapedTargets))
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

    private static func queryFallbackNotificationRows(databaseURL: URL, targetBundleIdentifiers: [String]) -> SQLiteResult {
        let tableResult = runSQLite(databaseURL: databaseURL, sql: "SELECT name FROM sqlite_master WHERE type='table';")
        guard case let .rows(tables) = tableResult else { return tableResult }

        let targetNeedles = targetBundleIdentifiers.flatMap { bundleIdentifier -> [(bundleIdentifier: String, needle: String)] in
            let appName = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)?
                .deletingPathExtension()
                .lastPathComponent ?? ""
            var needles = [bundleIdentifier.lowercased(), appName.lowercased()].filter { !$0.isEmpty }
            if bundleIdentifier.lowercased().contains("kakao") {
                needles.append("카카오")
                needles.append("카카오톡")
                needles.append("kakao")
            }
            return needles.map { (bundleIdentifier, $0) }
        }

        var matches: [String] = []

        for table in tables.prefix(12) {
            let safeTable = table.replacingOccurrences(of: "\"", with: "\"\"")
            let sql = "SELECT * FROM \"\(safeTable)\" LIMIT 40;"
            let result = runSQLite(databaseURL: databaseURL, sql: sql)
            if case .accessDenied = result { return .accessDenied }
            guard case let .rows(rows) = result else { continue }

            let filteredRows = rows.compactMap { row -> String? in
                let lowered = row.lowercased()
                guard let target = targetNeedles.first(where: { lowered.contains($0.needle) }) else {
                    return nil
                }
                return "\(target.bundleIdentifier)|fallback|\(table)|\(row.hashValue)"
            }
            matches.append(contentsOf: filteredRows)
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
