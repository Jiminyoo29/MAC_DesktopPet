import AppKit

enum OnboardingPresenter {
    private static let hasSeenOnboardingKey = "hasSeenOnboarding"

    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: hasSeenOnboardingKey) else { return }
        show()
    }

    static func show() {
        let alert = NSAlert()
        alert.messageText = "MAC DesktopPet 시작하기"
        alert.informativeText = """
        알림 반응을 사용하려면 전체 디스크 접근에서 MAC DesktopPet을 허용해 주세요.

        카톡 알림 내용을 그대로 보여주는 기능은 기본으로 꺼져 있고, 펫 우클릭 메뉴에서 직접 켤 수 있어요.
        빠른 배너 감지는 손쉬운 사용 권한을 허용하면 동작합니다.
        """
        alert.addButton(withTitle: "전체 디스크 접근 열기")
        alert.addButton(withTitle: "손쉬운 사용 열기")
        alert.addButton(withTitle: "확인")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            openFullDiskAccessSettings()
        case .alertSecondButtonReturn:
            openAccessibilitySettings()
        default:
            break
        }

        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
    }

    static func openFullDiskAccessSettings() {
        openSettings([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security"
        ])
    }

    static func openAccessibilitySettings() {
        openSettings([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security"
        ])
    }

    private static func openSettings(_ values: [String]) {
        for value in values {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
