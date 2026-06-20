import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

expect(NotificationMonitorTiming.watchdogInterval >= 5.0, "watchdog interval should avoid sub-second polling")
expect(NotificationMonitorTiming.watchdogInterval <= 10.0, "watchdog interval should still recover missed file events promptly")

print("notification timing checks passed")
