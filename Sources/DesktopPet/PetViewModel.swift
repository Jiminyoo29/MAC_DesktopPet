import AppKit
import SwiftUI
import UniformTypeIdentifiers

class PetViewModel: ObservableObject {
    @Published var dialogue: String? = nil
    @Published var showDialogue = false
    @Published var isBouncing = false
    @Published var petImagePath: String?
    @Published var appName: String
    @Published var scale: Double
    private(set) var notificationStatus = "알림 감지 준비 중"

    let id: UUID
    private var bundleIdentifier: String
    private let onConfigurationChanged: (PetConfiguration) -> Void
    private let onCreatePet: () -> Void
    private let onClosePet: (UUID) -> Void

    private let dialogues = [
        "안녕하세요! 😊",
        "오늘도 화이팅! 💪",
        "코딩 잘 되고 있어요? 🖥️",
        "잠깐 쉬어가요~ ☕",
        "배고파요 🍕",
        "같이 놀아요! 🎮",
        "졸려요... 😴",
        "오늘 날씨 좋다! ☀️",
        "열심히 응원할게요! 🌟",
        "헤헤, 귀엽죠? 🥰",
        "무엇을 도와드릴까요? ✨",
        "스트레칭 했나요? 🙆",
        "물 마시는 거 잊지 마요! 💧",
        "같이 힘내요! 🐾",
    ]

    init(
        configuration: PetConfiguration,
        onConfigurationChanged: @escaping (PetConfiguration) -> Void,
        onCreatePet: @escaping () -> Void,
        onClosePet: @escaping (UUID) -> Void
    ) {
        id = configuration.id
        appName = configuration.appName
        bundleIdentifier = configuration.bundleIdentifier
        petImagePath = configuration.imagePath
        scale = configuration.scale
        self.onConfigurationChanged = onConfigurationChanged
        self.onCreatePet = onCreatePet
        self.onClosePet = onClosePet
    }

    func tap() {
        speak(dialogues.randomElement() ?? "안녕하세요! 😊")
    }

    func openLinkedApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.open(url)
        } else {
            speak("\(appName)을 찾지 못했어요.")
        }
    }

    func showNotification() {
        speak("\(appName) 알림이 왔어요!")
    }

    func showTestNotification() {
        speak("테스트 알림이에요!")
    }

    func createPet() {
        onCreatePet()
    }

    func closePet() {
        onClosePet(id)
    }

    func setSmallSize() {
        setScale(0.8)
        speak("작게 변했어요.")
    }

    func setMediumSize() {
        setScale(1.0)
        speak("기본 크기예요.")
    }

    func setLargeSize() {
        setScale(1.25)
        speak("크게 변했어요.")
    }

    func chooseLinkedApp() {
        let panel = NSOpenPanel()
        panel.title = "연결할 앱 선택"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            guard let bundleIdentifier = bundle?.bundleIdentifier else {
                speak("앱 정보를 읽지 못했어요.")
                return
            }

            let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            appName = displayName ?? bundleName ?? url.deletingPathExtension().lastPathComponent
            self.bundleIdentifier = bundleIdentifier
            saveConfiguration()
            speak("\(appName)에 연결했어요.")
        }
    }

    func updateNotificationStatus(_ status: String) {
        notificationStatus = status
    }

    func showNotificationStatus() {
        speak(notificationStatus)
    }

    func showNotificationAccessHelp() {
        speak("알림 감지를 위해 전체 디스크 접근을 허용해 주세요.")
    }

    func openFullDiskAccessSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security"
        ]

        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }

        speak("시스템 설정에서 전체 디스크 접근을 열어주세요.")
    }

    func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security"
        ]

        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }

        speak("시스템 설정에서 손쉬운 사용 권한을 열어주세요.")
    }

    func choosePetImage() {
        let panel = NSOpenPanel()
        panel.title = "펫 이미지 선택"
        panel.allowedContentTypes = [.png, .jpeg, .gif, .heic, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            petImagePath = url.path
            saveConfiguration()
            speak("새 모습 마음에 들어요?")
        }
    }

    func resetPetImage() {
        petImagePath = nil
        saveConfiguration()
        speak("토끼로 돌아왔어요! 🐰")
    }

    func configuration() -> PetConfiguration {
        PetConfiguration(
            id: id,
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            imagePath: petImagePath,
            scale: scale
        )
    }

    func matches(bundleIdentifier: String) -> Bool {
        self.bundleIdentifier == bundleIdentifier
    }

    private func setScale(_ value: Double) {
        scale = value
        saveConfiguration()
    }

    private func saveConfiguration() {
        onConfigurationChanged(configuration())
    }

    private func speak(_ text: String) {
        dialogue = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            showDialogue = true
            isBouncing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring()) { self.isBouncing = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeOut(duration: 0.25)) { self.showDialogue = false }
        }
    }
}
