import Foundation

enum SpeechBubbleTiming {
    static func displayDuration(for text: String) -> TimeInterval {
        let trimmedCount = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard trimmedCount > 32 else { return 3.2 }
        return min(7.5, max(3.2, Double(trimmedCount) * 0.07))
    }
}
