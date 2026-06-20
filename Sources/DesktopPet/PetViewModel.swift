import AppKit
import SwiftUI
import UniformTypeIdentifiers

class PetViewModel: ObservableObject {
    @Published var dialogue: String? = nil
    @Published var showDialogue = false
    @Published var isBouncing = false
    @Published var petImagePath: String?
    @Published var petName: String
    @Published var userName: String
    @Published var tone: PetTone
    @Published var appName: String
    @Published var scale: Double
    private(set) var notificationStatus = "알림 감지 준비 중"

    let id: UUID
    private var bundleIdentifier: String
    private let onConfigurationChanged: (PetConfiguration) -> Void
    private let onCreatePet: () -> Void
    private let onClosePet: (UUID) -> Void

    private let dialogues = [
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
        petName = configuration.name
        userName = configuration.userName
        tone = configuration.tone
        appName = configuration.appName
        bundleIdentifier = configuration.bundleIdentifier
        petImagePath = configuration.imagePath
        scale = configuration.scale
        self.onConfigurationChanged = onConfigurationChanged
        self.onCreatePet = onCreatePet
        self.onClosePet = onClosePet
    }

    func tap() {
        let line = Bool.random()
            ? tone.line(name: petName, event: .hello)
            : (dialogues.randomElement() ?? tone.line(name: petName, event: .hello))
        speak(line)
    }

    func openLinkedApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.open(url)
        } else {
            speak("\(appName)을 찾지 못했어요.")
        }
    }

    func showNotification() {
        speak(notificationLine())
    }

    func showTestNotification() {
        speak(tone.line(name: petName, event: .test, appName: appName))
    }

    func createPet() {
        onCreatePet()
    }

    func closePet() {
        onClosePet(id)
    }

    func setSmallSize() {
        setScale(0.8)
        speak(tone.line(name: petName, event: .small))
    }

    func setMediumSize() {
        setScale(1.0)
        speak(tone.line(name: petName, event: .medium))
    }

    func setLargeSize() {
        setScale(1.25)
        speak(tone.line(name: petName, event: .large))
    }

    func setCustomScale(_ value: Double) {
        setScale(min(1.6, max(0.55, value)))
    }

    func setName() {
        let alert = NSAlert()
        alert.messageText = "펫 이름"
        alert.informativeText = "이 펫을 뭐라고 부를까요?"
        alert.addButton(withTitle: "저장")
        alert.addButton(withTitle: "취소")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.stringValue = petName
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                speak("이름을 입력해 주세요.")
                return
            }
            petName = trimmed
            saveConfiguration()
            speak(tone.line(name: petName, event: .nameChanged))
        }
    }

    func setUserName() {
        let alert = NSAlert()
        alert.messageText = "사용자 호칭"
        alert.informativeText = "펫이 사용자를 뭐라고 부르면 좋을까요?"
        alert.addButton(withTitle: "저장")
        alert.addButton(withTitle: "취소")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.stringValue = userName
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                speak("호칭을 입력해 주세요.")
                return
            }
            userName = trimmed
            saveConfiguration()
            speak("\(formattedUserName())! 이렇게 불러드릴게요.")
        }
    }

    func setTone(_ tone: PetTone) {
        self.tone = tone
        saveConfiguration()
        speak(tone.line(name: petName, event: .toneChanged))
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
            speak(tone.line(name: petName, event: .appLinked, appName: appName))
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
            speak(tone.line(name: petName, event: .imageChanged))
        }
    }

    func resetPetImage() {
        petImagePath = nil
        saveConfiguration()
        speak(tone.line(name: petName, event: .imageReset))
    }

    func configuration() -> PetConfiguration {
        PetConfiguration(
            id: id,
            name: petName,
            userName: userName,
            tone: tone,
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            imagePath: petImagePath,
            scale: scale
        )
    }

    func matches(bundleIdentifier: String) -> Bool {
        self.bundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
    }

    private func setScale(_ value: Double) {
        scale = value
        saveConfiguration()
    }

    private func saveConfiguration() {
        onConfigurationChanged(configuration())
    }

    private func formattedUserName() -> String {
        if userName.hasSuffix("님") || userName.hasSuffix("씨") {
            return userName
        }
        return "\(userName)님"
    }

    private func notificationLine() -> String {
        let user = formattedUserName()
        let message = appSpecificNotificationMessage()

        switch tone {
        case .friendly:
            return "\(user)! \(message)"
        case .polite:
            return "\(user), \(message)"
        case .cute:
            return "\(user)! \(message)용"
        case .chic:
            return "\(user). \(message)"
        }
    }

    private func appSpecificNotificationMessage() -> String {
        let loweredBundle = bundleIdentifier.lowercased()
        let loweredName = appName.lowercased()

        if loweredBundle.contains("kakao") || loweredName.contains("kakao") || appName.contains("카카오") {
            return "카톡이 왔어요"
        }
        if loweredBundle.contains("calendar") || loweredName.contains("calendar") || appName.contains("캘린더") {
            return "오늘 일정이 있어요"
        }
        if loweredBundle.contains("mail") || loweredName.contains("mail") || appName.contains("메일") {
            return "메일이 왔어요"
        }
        if loweredBundle.contains("slack") || loweredName.contains("slack") {
            return "Slack 알림이 왔어요"
        }
        if loweredBundle.contains("discord") || loweredName.contains("discord") {
            return "Discord 알림이 왔어요"
        }
        if loweredBundle.contains("reminder") || loweredName.contains("reminder") || appName.contains("미리 알림") {
            return "할 일이 있어요"
        }

        return "\(appName) 알림이 왔어요"
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
