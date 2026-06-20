import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [UUID: NSWindow] = [:]
    var viewModels: [UUID: PetViewModel] = [:]
    var configurations: [PetConfiguration] = []
    var notificationMonitor: KakaoTalkNotificationMonitor!
    private var statusItem: NSStatusItem?
    private var petsHidden = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        configurations = PetConfigurationStore.load()
        for (index, configuration) in configurations.enumerated() {
            createWindow(for: configuration, offsetIndex: index)
        }

        notificationMonitor = KakaoTalkNotificationMonitor(
            targetConfigurations: { [weak self] in
                self?.configurations.map {
                    NotificationMonitorTarget(
                        bundleIdentifier: $0.bundleIdentifier,
                        reactionMode: $0.reactionMode,
                        showsNotificationContent: $0.showsNotificationContent
                    )
                } ?? []
            },
            onNotification: { [weak self] event in
                guard let self else { return }
                let matchedViewModels = self.viewModels.values
                    .filter { $0.matches(bundleIdentifier: event.bundleIdentifier) }

                if matchedViewModels.isEmpty, self.viewModels.count == 1 {
                    self.viewModels.values.forEach { $0.showNotification(content: event.content) }
                } else {
                    matchedViewModels.forEach { $0.showNotification(content: event.content) }
                }
            },
            onAccessDenied: { [weak self] in
                self?.viewModels.values.forEach { $0.showNotificationAccessHelp() }
            },
            onStatusChanged: { [weak self] status in
                self?.viewModels.values.forEach { $0.updateNotificationStatus(status) }
            }
        )

        notificationMonitor.start()
        setupStatusItem()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            OnboardingPresenter.showIfNeeded()
        }
    }

    private func createWindow(for configuration: PetConfiguration, offsetIndex: Int) {
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = CGSize(width: 160 * configuration.scale, height: 220 * configuration.scale)
        let origin = CGPoint(
            x: screen.maxX - size.width - 60 - CGFloat(offsetIndex * 36),
            y: screen.midY - size.height / 2 - CGFloat(offsetIndex * 30)
        )

        let window = NSWindow(
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

        let viewModel = PetViewModel(
            configuration: configuration,
            onConfigurationChanged: { [weak self] updated in
                self?.updateConfiguration(updated)
                self?.resizeWindow(for: updated)
            },
            onCreatePet: { [weak self] in
                self?.addPet()
            },
            onClosePet: { [weak self] id in
                self?.closePet(id: id)
            }
        )

        window.contentView = NSHostingView(rootView: PetRootView(viewModel: viewModel))
        window.makeKeyAndOrderFront(nil)
        windows[configuration.id] = window
        viewModels[configuration.id] = viewModel
    }

    private func addPet() {
        var configuration = PetConfiguration.defaultPet
        configuration.id = UUID()
        configurations.append(configuration)
        PetConfigurationStore.save(configurations)
        createWindow(for: configuration, offsetIndex: configurations.count - 1)
        petsHidden = false
        refreshStatusMenu()
    }

    private func closePet(id: UUID) {
        guard configurations.count > 1 else {
            viewModels[id]?.showTestNotification()
            return
        }

        windows[id]?.close()
        windows[id] = nil
        viewModels[id] = nil
        configurations.removeAll { $0.id == id }
        PetConfigurationStore.save(configurations)
        refreshStatusMenu()
    }

    private func updateConfiguration(_ updated: PetConfiguration) {
        if let index = configurations.firstIndex(where: { $0.id == updated.id }) {
            configurations[index] = updated
        } else {
            configurations.append(updated)
        }
        PetConfigurationStore.save(configurations)
    }

    private func resizeWindow(for configuration: PetConfiguration) {
        guard let window = windows[configuration.id] else { return }
        let size = CGSize(width: 160 * configuration.scale, height: 220 * configuration.scale)
        var frame = window.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        window.setFrame(frame, display: true, animate: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "🐰"
        refreshStatusMenu()
    }

    private func refreshStatusMenu() {
        let menu = NSMenu()

        let visibilityTitle = petsHidden ? "펫 보이기" : "펫 숨기기"
        let visibility = NSMenuItem(title: visibilityTitle, action: #selector(togglePetsVisibility), keyEquivalent: "")
        visibility.target = self
        menu.addItem(visibility)

        let newPet = NSMenuItem(title: "새 펫 만들기", action: #selector(addPetFromMenuBar), keyEquivalent: "")
        newPet.target = self
        menu.addItem(newPet)

        menu.addItem(.separator())

        let launchAtLogin = NSMenuItem(title: "Mac 시작 시 자동 실행", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLogin.target = self
        launchAtLogin.state = LoginItemController.isEnabled ? .on : .off
        menu.addItem(launchAtLogin)

        let onboarding = NSMenuItem(title: "권한 안내 보기", action: #selector(showOnboarding), keyEquivalent: "")
        onboarding.target = self
        menu.addItem(onboarding)

        let fullDisk = NSMenuItem(title: "알림 감지 권한 열기", action: #selector(openFullDiskAccessSettings), keyEquivalent: "")
        fullDisk.target = self
        menu.addItem(fullDisk)

        let accessibility = NSMenuItem(title: "빠른 감지 권한 열기", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibility.target = self
        menu.addItem(accessibility)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem?.menu = menu
    }

    @objc private func togglePetsVisibility() {
        petsHidden.toggle()
        for window in windows.values {
            if petsHidden {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
        }
        refreshStatusMenu()
    }

    @objc private func addPetFromMenuBar() {
        addPet()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LoginItemController.setEnabled(!LoginItemController.isEnabled)
        } catch {
            viewModels.values.first?.showNotification(content: "시작 프로그램 설정을 바꾸지 못했어요.")
        }
        refreshStatusMenu()
    }

    @objc private func showOnboarding() {
        OnboardingPresenter.show()
    }

    @objc private func openFullDiskAccessSettings() {
        OnboardingPresenter.openFullDiskAccessSettings()
    }

    @objc private func openAccessibilitySettings() {
        OnboardingPresenter.openAccessibilitySettings()
    }
}
