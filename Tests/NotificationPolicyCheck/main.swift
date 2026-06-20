import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

expect(NotificationMonitorPolicy.includesRecord(reactionMode: .visibleOnly, presentedValue: "1"), "visible mode should include presented notifications")
expect(!NotificationMonitorPolicy.includesRecord(reactionMode: .visibleOnly, presentedValue: "0"), "visible mode should ignore hidden notifications")
expect(NotificationMonitorPolicy.includesRecord(reactionMode: .includeHidden, presentedValue: "0"), "hidden mode should include hidden notifications")
expect(!PetConfiguration.defaultPet.showsNotificationContent, "notification content should be off by default")
expect(PetConfiguration.defaultPet.reactionMode == .visibleOnly, "visible-only mode should be the default")

print("notification policy checks passed")
