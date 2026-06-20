import Foundation

struct NotificationCooldown {
    let interval: TimeInterval
    private var lastNotificationDates: [String: Date] = [:]

    init(interval: TimeInterval) {
        self.interval = interval
    }

    mutating func allows(bundleIdentifier: String, at date: Date = Date()) -> Bool {
        let key = bundleIdentifier.lowercased()
        if let lastDate = lastNotificationDates[key],
           date.timeIntervalSince(lastDate) < interval {
            return false
        }

        lastNotificationDates[key] = date
        return true
    }
}
