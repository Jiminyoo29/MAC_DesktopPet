import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

expect(PetConfiguration.defaultPet.personality == .balanced, "balanced personality should be the default")
expect(PetConfiguration.defaultPet.windowOrigin == nil, "new pets should not have a saved window origin")

let configuration = PetConfiguration(
    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
    name: "모찌",
    userName: "사용자",
    tone: .cute,
    personality: .playful,
    appName: "KakaoTalk",
    bundleIdentifier: "com.kakao.KakaoTalkMac",
    imagePath: "/tmp/mochi.png",
    scale: 1.2,
    windowOrigin: WindowOrigin(x: 120, y: 240),
    reactionMode: .includeHidden,
    showsNotificationContent: true,
    customNotificationMessage: "{user}! {app} 왔어요"
)

let encoded = try JSONEncoder().encode(configuration)
let decoded = try JSONDecoder().decode(PetConfiguration.self, from: encoded)

expect(decoded.personality == .playful, "personality should round-trip through saved configuration")
expect(decoded.windowOrigin == WindowOrigin(x: 120, y: 240), "window origin should round-trip through saved configuration")
expect(decoded.scale == 1.2, "scale should keep existing behavior")

let oldJSON = """
{
  "id": "22222222-2222-2222-2222-222222222222",
  "name": "토끼",
  "userName": "사용자",
  "tone": "friendly",
  "appName": "KakaoTalk",
  "bundleIdentifier": "com.kakao.KakaoTalkMac",
  "scale": 1.0,
  "reactionMode": "visibleOnly",
  "showsNotificationContent": false
}
""".data(using: .utf8)!

let oldDecoded = try JSONDecoder().decode(PetConfiguration.self, from: oldJSON)
expect(oldDecoded.personality == .balanced, "old saved configurations should decode with the default personality")
expect(oldDecoded.windowOrigin == nil, "old saved configurations should decode without a saved window position")

print("pet configuration feature checks passed")
