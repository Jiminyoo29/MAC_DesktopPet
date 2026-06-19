import AppKit
import SwiftUI

// 투명하지만 마우스 이벤트를 처리하는 NSView
// - 드래그: 윈도우 이동
// - 클릭(거의 안 움직인 경우): onTap 콜백
class PetInteractionView: NSView {
    var onTap: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onChooseImage: (() -> Void)?
    var onResetImage: (() -> Void)?
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
        let open = NSMenuItem(title: "카카오톡 열기", action: #selector(openLinkedApp), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let chooseImage = NSMenuItem(title: "이미지 바꾸기...", action: #selector(chooseImage), keyEquivalent: "")
        chooseImage.target = self
        menu.addItem(chooseImage)

        let resetImage = NSMenuItem(title: "토끼로 되돌리기", action: #selector(resetImage), keyEquivalent: "")
        resetImage.target = self
        menu.addItem(resetImage)

        menu.addItem(.separator())

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
        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func openLinkedApp() {
        onDoubleClick?()
    }

    @objc private func chooseImage() {
        onChooseImage?()
    }

    @objc private func resetImage() {
        onResetImage?()
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
    let onChooseImage: () -> Void
    let onResetImage: () -> Void
    let onOpenFullDiskAccessSettings: () -> Void
    let onOpenAccessibilitySettings: () -> Void
    let onShowNotificationStatus: () -> Void
    let onShowTestNotification: () -> Void

    func makeNSView(context: Context) -> PetInteractionView {
        let v = PetInteractionView()
        v.onTap = onTap
        v.onDoubleClick = onDoubleClick
        v.onChooseImage = onChooseImage
        v.onResetImage = onResetImage
        v.onOpenFullDiskAccessSettings = onOpenFullDiskAccessSettings
        v.onOpenAccessibilitySettings = onOpenAccessibilitySettings
        v.onShowNotificationStatus = onShowNotificationStatus
        v.onShowTestNotification = onShowTestNotification
        return v
    }
    func updateNSView(_ nsView: PetInteractionView, context: Context) {
        nsView.onTap = onTap
        nsView.onDoubleClick = onDoubleClick
        nsView.onChooseImage = onChooseImage
        nsView.onResetImage = onResetImage
        nsView.onOpenFullDiskAccessSettings = onOpenFullDiskAccessSettings
        nsView.onOpenAccessibilitySettings = onOpenAccessibilitySettings
        nsView.onShowNotificationStatus = onShowNotificationStatus
        nsView.onShowTestNotification = onShowTestNotification
    }
}
