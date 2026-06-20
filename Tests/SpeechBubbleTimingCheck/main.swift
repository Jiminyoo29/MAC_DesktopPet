import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let short = SpeechBubbleTiming.displayDuration(for: "카톡이 왔어요")
let long = SpeechBubbleTiming.displayDuration(for: String(repeating: "긴 알림 내용입니다 ", count: 12))
let veryLong = SpeechBubbleTiming.displayDuration(for: String(repeating: "아주 긴 알림 내용입니다 ", count: 40))

expect(short == 3.2, "short messages should keep the current display time")
expect(long > short, "long messages should stay visible longer")
expect(veryLong == 7.5, "very long messages should cap display time")

print("speech bubble timing checks passed")
