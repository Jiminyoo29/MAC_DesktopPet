import AppKit
import SwiftUI

// 투명하지만 마우스 이벤트를 처리하는 NSView
// - 드래그: 윈도우 이동
// - 클릭(거의 안 움직인 경우): onTap 콜백
class PetInteractionView: NSView {
    var onTap: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onSetName: (() -> Void)?
    var onSetUserName: (() -> Void)?
    var onSetFriendlyTone: (() -> Void)?
    var onSetPoliteTone: (() -> Void)?
    var onSetCuteTone: (() -> Void)?
    var onSetChicTone: (() -> Void)?
    var onSetVisibleOnlyMode: (() -> Void)?
    var onSetIncludeHiddenMode: (() -> Void)?
    var onToggleNotificationContent: (() -> Void)?
    var onSetCustomNotificationMessage: (() -> Void)?
    var onChooseLinkedApp: (() -> Void)?
    var onChooseImage: (() -> Void)?
    var onResetImage: (() -> Void)?
    var onSetSmallSize: (() -> Void)?
    var onSetMediumSize: (() -> Void)?
    var onSetLargeSize: (() -> Void)?
    var onSetCustomScale: ((Double) -> Void)?
    var currentScale: Double = 1.0
    var currentReactionMode: NotificationReactionMode = .visibleOnly
    var showsNotificationContent = false
    var onCreatePet: (() -> Void)?
    var onClosePet: (() -> Void)?
    var onOpenFullDiskAccessSettings: (() -> Void)?
    var onOpenAccessibilitySettings: (() -> Void)?
    var onShowNotificationStatus: (() -> Void)?
    var onShowTestNotification: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }

        let startOrigin = window?.frame.origin
        // performDrag는 드래그가 끝날 때까지 블록, 클릭이면 즉시 반환
        window?.performDrag(with: event)
        if let start = startOrigin, let end = window?.frame.origin {
            let moved = hypot(end.x - start.x, end.y - start.y)
            if moved < 5 { onTap?() }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let open = NSMenuItem(title: "연결 앱 열기", action: #selector(openLinkedApp), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let chooseApp = NSMenuItem(title: "연결 앱 바꾸기...", action: #selector(chooseLinkedApp), keyEquivalent: "")
        chooseApp.target = self
        menu.addItem(chooseApp)

        let setName = NSMenuItem(title: "이름 바꾸기...", action: #selector(setName), keyEquivalent: "")
        setName.target = self
        menu.addItem(setName)

        let setUserName = NSMenuItem(title: "사용자 호칭 바꾸기...", action: #selector(setUserName), keyEquivalent: "")
        setUserName.target = self
        menu.addItem(setUserName)

        let toneMenu = NSMenu()
        let friendly = NSMenuItem(title: "기본", action: #selector(setFriendlyTone), keyEquivalent: "")
        friendly.target = self
        toneMenu.addItem(friendly)

        let polite = NSMenuItem(title: "공손", action: #selector(setPoliteTone), keyEquivalent: "")
        polite.target = self
        toneMenu.addItem(polite)

        let cute = NSMenuItem(title: "애교", action: #selector(setCuteTone), keyEquivalent: "")
        cute.target = self
        toneMenu.addItem(cute)

        let chic = NSMenuItem(title: "시크", action: #selector(setChicTone), keyEquivalent: "")
        chic.target = self
        toneMenu.addItem(chic)

        let toneItem = NSMenuItem(title: "말투", action: nil, keyEquivalent: "")
        toneItem.submenu = toneMenu
        menu.addItem(toneItem)

        let reactionMenu = NSMenu()
        let visibleOnly = NSMenuItem(title: "표시된 알림만", action: #selector(setVisibleOnlyMode), keyEquivalent: "")
        visibleOnly.target = self
        visibleOnly.state = currentReactionMode == .visibleOnly ? .on : .off
        reactionMenu.addItem(visibleOnly)

        let includeHidden = NSMenuItem(title: "숨겨진 알림도", action: #selector(setIncludeHiddenMode), keyEquivalent: "")
        includeHidden.target = self
        includeHidden.state = currentReactionMode == .includeHidden ? .on : .off
        reactionMenu.addItem(includeHidden)

        let reactionItem = NSMenuItem(title: "알림 반응", action: nil, keyEquivalent: "")
        reactionItem.submenu = reactionMenu
        menu.addItem(reactionItem)

        let content = NSMenuItem(title: "알림 내용 그대로 표시", action: #selector(toggleNotificationContent), keyEquivalent: "")
        content.target = self
        content.state = showsNotificationContent ? .on : .off
        menu.addItem(content)

        let customMessage = NSMenuItem(title: "알림 문구 바꾸기...", action: #selector(setCustomNotificationMessage), keyEquivalent: "")
        customMessage.target = self
        menu.addItem(customMessage)

        let chooseImage = NSMenuItem(title: "이미지 바꾸기...", action: #selector(chooseImage), keyEquivalent: "")
        chooseImage.target = self
        menu.addItem(chooseImage)

        let resetImage = NSMenuItem(title: "토끼로 되돌리기", action: #selector(resetImage), keyEquivalent: "")
        resetImage.target = self
        menu.addItem(resetImage)

        menu.addItem(.separator())

        let sizeMenu = NSMenu()
        let slider = NSSlider(value: currentScale, minValue: 0.55, maxValue: 1.6, target: self, action: #selector(sizeSliderChanged(_:)))
        slider.frame = NSRect(x: 0, y: 0, width: 180, height: 28)
        slider.isContinuous = true
        let sliderItem = NSMenuItem()
        sliderItem.view = slider
        sizeMenu.addItem(sliderItem)

        sizeMenu.addItem(.separator())

        let small = NSMenuItem(title: "작게", action: #selector(setSmallSize), keyEquivalent: "")
        small.target = self
        sizeMenu.addItem(small)

        let medium = NSMenuItem(title: "기본", action: #selector(setMediumSize), keyEquivalent: "")
        medium.target = self
        sizeMenu.addItem(medium)

        let large = NSMenuItem(title: "크게", action: #selector(setLargeSize), keyEquivalent: "")
        large.target = self
        sizeMenu.addItem(large)

        let sizeItem = NSMenuItem(title: "크기", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let createPet = NSMenuItem(title: "새 펫 만들기", action: #selector(createPet), keyEquivalent: "")
        createPet.target = self
        menu.addItem(createPet)

        let privacy = NSMenuItem(title: "알림 감지 권한 열기", action: #selector(openFullDiskAccessSettings), keyEquivalent: "")
        privacy.target = self
        menu.addItem(privacy)

        let accessibility = NSMenuItem(title: "빠른 감지 권한 열기", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibility.target = self
        menu.addItem(accessibility)

        let status = NSMenuItem(title: "알림 감지 상태 보기", action: #selector(showNotificationStatus), keyEquivalent: "")
        status.target = self
        menu.addItem(status)

        let test = NSMenuItem(title: "테스트 알림 띄우기", action: #selector(showTestNotification), keyEquivalent: "")
        test.target = self
        menu.addItem(test)

        menu.addItem(.separator())
        let closePet = NSMenuItem(title: "이 펫 닫기", action: #selector(closePet), keyEquivalent: "")
        closePet.target = self
        menu.addItem(closePet)

        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func openLinkedApp() {
        onDoubleClick?()
    }

    @objc private func chooseLinkedApp() {
        onChooseLinkedApp?()
    }

    @objc private func setName() {
        onSetName?()
    }

    @objc private func setUserName() {
        onSetUserName?()
    }

    @objc private func setFriendlyTone() {
        onSetFriendlyTone?()
    }

    @objc private func setPoliteTone() {
        onSetPoliteTone?()
    }

    @objc private func setCuteTone() {
        onSetCuteTone?()
    }

    @objc private func setChicTone() {
        onSetChicTone?()
    }

    @objc private func setVisibleOnlyMode() {
        onSetVisibleOnlyMode?()
    }

    @objc private func setIncludeHiddenMode() {
        onSetIncludeHiddenMode?()
    }

    @objc private func toggleNotificationContent() {
        onToggleNotificationContent?()
    }

    @objc private func setCustomNotificationMessage() {
        onSetCustomNotificationMessage?()
    }

    @objc private func chooseImage() {
        onChooseImage?()
    }

    @objc private func resetImage() {
        onResetImage?()
    }

    @objc private func setSmallSize() {
        onSetSmallSize?()
    }

    @objc private func setMediumSize() {
        onSetMediumSize?()
    }

    @objc private func setLargeSize() {
        onSetLargeSize?()
    }

    @objc private func sizeSliderChanged(_ sender: NSSlider) {
        onSetCustomScale?(sender.doubleValue)
    }

    @objc private func createPet() {
        onCreatePet?()
    }

    @objc private func closePet() {
        onClosePet?()
    }

    @objc private func openFullDiskAccessSettings() {
        onOpenFullDiskAccessSettings?()
    }

    @objc private func openAccessibilitySettings() {
        onOpenAccessibilitySettings?()
    }

    @objc private func showNotificationStatus() {
        onShowNotificationStatus?()
    }

    @objc private func showTestNotification() {
        onShowTestNotification?()
    }

    // 투명해도 히트테스트 통과
    override func hitTest(_ point: NSPoint) -> NSView? { self }
}

struct DraggableOverlay: NSViewRepresentable {
    let onTap: () -> Void
    let onDoubleClick: () -> Void
    let onSetName: () -> Void
    let onSetUserName: () -> Void
    let onSetFriendlyTone: () -> Void
    let onSetPoliteTone: () -> Void
    let onSetCuteTone: () -> Void
    let onSetChicTone: () -> Void
    let onSetVisibleOnlyMode: () -> Void
    let onSetIncludeHiddenMode: () -> Void
    let onToggleNotificationContent: () -> Void
    let onSetCustomNotificationMessage: () -> Void
    let onChooseLinkedApp: () -> Void
    let onChooseImage: () -> Void
    let onResetImage: () -> Void
    let onSetSmallSize: () -> Void
    let onSetMediumSize: () -> Void
    let onSetLargeSize: () -> Void
    let onSetCustomScale: (Double) -> Void
    let currentScale: Double
    let currentReactionMode: NotificationReactionMode
    let showsNotificationContent: Bool
    let onCreatePet: () -> Void
    let onClosePet: () -> Void
    let onOpenFullDiskAccessSettings: () -> Void
    let onOpenAccessibilitySettings: () -> Void
    let onShowNotificationStatus: () -> Void
    let onShowTestNotification: () -> Void

    func makeNSView(context: Context) -> PetInteractionView {
        let v = PetInteractionView()
        v.onTap = onTap
        v.onDoubleClick = onDoubleClick
        v.onSetName = onSetName
        v.onSetUserName = onSetUserName
        v.onSetFriendlyTone = onSetFriendlyTone
        v.onSetPoliteTone = onSetPoliteTone
        v.onSetCuteTone = onSetCuteTone
        v.onSetChicTone = onSetChicTone
        v.onSetVisibleOnlyMode = onSetVisibleOnlyMode
        v.onSetIncludeHiddenMode = onSetIncludeHiddenMode
        v.onToggleNotificationContent = onToggleNotificationContent
        v.onSetCustomNotificationMessage = onSetCustomNotificationMessage
        v.onChooseLinkedApp = onChooseLinkedApp
        v.onChooseImage = onChooseImage
        v.onResetImage = onResetImage
        v.onSetSmallSize = onSetSmallSize
        v.onSetMediumSize = onSetMediumSize
        v.onSetLargeSize = onSetLargeSize
        v.onSetCustomScale = onSetCustomScale
        v.currentScale = currentScale
        v.currentReactionMode = currentReactionMode
        v.showsNotificationContent = showsNotificationContent
        v.onCreatePet = onCreatePet
        v.onClosePet = onClosePet
        v.onOpenFullDiskAccessSettings = onOpenFullDiskAccessSettings
        v.onOpenAccessibilitySettings = onOpenAccessibilitySettings
        v.onShowNotificationStatus = onShowNotificationStatus
        v.onShowTestNotification = onShowTestNotification
        return v
    }
    func updateNSView(_ nsView: PetInteractionView, context: Context) {
        nsView.onTap = onTap
        nsView.onDoubleClick = onDoubleClick
        nsView.onSetName = onSetName
        nsView.onSetUserName = onSetUserName
        nsView.onSetFriendlyTone = onSetFriendlyTone
        nsView.onSetPoliteTone = onSetPoliteTone
        nsView.onSetCuteTone = onSetCuteTone
        nsView.onSetChicTone = onSetChicTone
        nsView.onSetVisibleOnlyMode = onSetVisibleOnlyMode
        nsView.onSetIncludeHiddenMode = onSetIncludeHiddenMode
        nsView.onToggleNotificationContent = onToggleNotificationContent
        nsView.onSetCustomNotificationMessage = onSetCustomNotificationMessage
        nsView.onChooseLinkedApp = onChooseLinkedApp
        nsView.onChooseImage = onChooseImage
        nsView.onResetImage = onResetImage
        nsView.onSetSmallSize = onSetSmallSize
        nsView.onSetMediumSize = onSetMediumSize
        nsView.onSetLargeSize = onSetLargeSize
        nsView.onSetCustomScale = onSetCustomScale
        nsView.currentScale = currentScale
        nsView.currentReactionMode = currentReactionMode
        nsView.showsNotificationContent = showsNotificationContent
        nsView.onCreatePet = onCreatePet
        nsView.onClosePet = onClosePet
        nsView.onOpenFullDiskAccessSettings = onOpenFullDiskAccessSettings
        nsView.onOpenAccessibilitySettings = onOpenAccessibilitySettings
        nsView.onShowNotificationStatus = onShowNotificationStatus
        nsView.onShowTestNotification = onShowTestNotification
    }
}
