import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

var cooldown = NotificationCooldown(interval: 3.0)
let first = Date(timeIntervalSince1970: 100)

expect(cooldown.allows(bundleIdentifier: "com.kakao.KakaoTalkMac", at: first), "first notification should be allowed")
expect(!cooldown.allows(bundleIdentifier: "com.kakao.KakaoTalkMac", at: first.addingTimeInterval(1.2)), "same app notification inside cooldown should be blocked")
expect(cooldown.allows(bundleIdentifier: "com.apple.MobileSMS", at: first.addingTimeInterval(1.2)), "different app should keep its own cooldown")
expect(cooldown.allows(bundleIdentifier: "COM.KAKAO.KAKAOTALKMAC", at: first.addingTimeInterval(3.1)), "same app should be allowed after cooldown")

print("notification cooldown checks passed")
