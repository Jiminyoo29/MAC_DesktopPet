import Foundation

enum NotificationReactionMode: String, Codable, CaseIterable, Equatable {
    case visibleOnly
    case includeHidden

    var title: String {
        switch self {
        case .visibleOnly: "표시된 알림만"
        case .includeHidden: "숨겨진 알림도"
        }
    }
}

struct NotificationMonitorTarget: Equatable {
    let bundleIdentifier: String
    let reactionMode: NotificationReactionMode
    let showsNotificationContent: Bool

    init(
        bundleIdentifier: String,
        reactionMode: NotificationReactionMode,
        showsNotificationContent: Bool = false
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.reactionMode = reactionMode
        self.showsNotificationContent = showsNotificationContent
    }

    var normalizedBundleIdentifier: String {
        bundleIdentifier.lowercased()
    }
}

struct NotificationMonitorEvent: Equatable {
    let bundleIdentifier: String
    let content: String?
}

enum NotificationMonitorPolicy {
    static func includesRecord(reactionMode: NotificationReactionMode, presentedValue: String?) -> Bool {
        guard reactionMode == .visibleOnly else { return true }
        guard let presentedValue else { return true }
        return presentedValue == "1" || presentedValue.lowercased() == "true"
    }
}
