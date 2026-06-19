import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var viewModel: PetViewModel!
    var notificationMonitor: KakaoTalkNotificationMonitor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = CGSize(width: 160, height: 220)
        let origin = CGPoint(x: screen.maxX - size.width - 60, y: screen.midY - size.height / 2)

        window = NSWindow(
            contentRect: CGRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        viewModel = PetViewModel()
        notificationMonitor = KakaoTalkNotificationMonitor(
            onNotification: { [weak self] in
                self?.viewModel.showKakaoTalkNotification()
            },
            onAccessDenied: { [weak self] in
                self?.viewModel.showNotificationAccessHelp()
            }
        )

        window.contentView = NSHostingView(rootView: PetRootView(viewModel: viewModel))
        window.makeKeyAndOrderFront(nil)
        notificationMonitor.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
