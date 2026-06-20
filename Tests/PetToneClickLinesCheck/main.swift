import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func containsEmoji(_ text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
        scalar.properties.isEmojiPresentation || scalar.properties.isEmoji
    }
}

for tone in PetTone.allCases {
    let lines = tone.clickLines(name: "토끼", userName: "사용자", appName: "KakaoTalk")
    expect(lines.count >= 12, "\(tone.rawValue) should have at least 12 click lines")
    expect(Set(lines).count == lines.count, "\(tone.rawValue) click lines should be unique")
    expect(lines.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "\(tone.rawValue) click lines should not be empty")
    expect(lines.allSatisfy(containsEmoji), "\(tone.rawValue) click lines should always include emoji")
}

let friendly = Set(PetTone.friendly.clickLines(name: "토끼", userName: "사용자", appName: "KakaoTalk"))
let polite = Set(PetTone.polite.clickLines(name: "토끼", userName: "사용자", appName: "KakaoTalk"))
let cute = Set(PetTone.cute.clickLines(name: "토끼", userName: "사용자", appName: "KakaoTalk"))
let chic = Set(PetTone.chic.clickLines(name: "토끼", userName: "사용자", appName: "KakaoTalk"))

expect(friendly.isDisjoint(with: polite), "friendly and polite click lines should differ")
expect(friendly.isDisjoint(with: cute), "friendly and cute click lines should differ")
expect(friendly.isDisjoint(with: chic), "friendly and chic click lines should differ")
expect(cute.contains { $0.contains("용") || $0.contains("뿅") }, "cute tone should sound cute")
expect(polite.contains { $0.contains("습니다") || $0.contains("세요") }, "polite tone should sound polite")
expect(chic.contains { $0.count <= 12 }, "chic tone should include short lines")

print("pet tone click line checks passed")
