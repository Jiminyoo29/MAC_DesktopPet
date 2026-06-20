import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

expect(NotificationMonitorDiagnostics.isAccessDeniedMessage("authorization denied"), "authorization denied should be treated as access denied")
expect(NotificationMonitorDiagnostics.isAccessDeniedMessage("operation not permitted"), "operation not permitted should be treated as access denied")
expect(NotificationMonitorDiagnostics.isAccessDeniedMessage("permission denied"), "permission denied should be treated as access denied")

expect(!NotificationMonitorDiagnostics.isAccessDeniedMessage("database is locked"), "database locks should not become permission errors")
expect(!NotificationMonitorDiagnostics.isAccessDeniedMessage("no such column: presented_date"), "schema errors should not become permission errors")
expect(!NotificationMonitorDiagnostics.isAccessDeniedMessage("unable to open database file"), "generic open failures should keep their own diagnostic")

let status = NotificationMonitorDiagnostics.userFacingAccessDeniedStatus(sqliteMessage: "authorization denied")
expect(status.contains("전체 디스크 접근"), "status should tell the user to fix Full Disk Access")
expect(status.contains("DB"), "status should mention DB access")

let detail = NotificationMonitorDiagnostics.sqliteFailureDetail(
    stage: "prepare",
    code: 1,
    message: "no such column: payload",
    databasePath: "/Users/example/Library/Group Containers/group.com.apple.usernoted/db2/db",
    queryLabel: "known-schema"
)
expect(detail.contains("known-schema"), "detail should keep the query label")
expect(detail.contains("no such column: payload"), "detail should keep the SQLite error")
expect(!detail.contains("SELECT"), "detail should not log raw SQL")
expect(!detail.contains("메시지 내용"), "detail should not include notification content")

print("notification diagnostics checks passed")
