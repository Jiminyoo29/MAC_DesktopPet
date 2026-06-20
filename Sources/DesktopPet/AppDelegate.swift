import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [UUID: NSWindow] = [:]
    var viewModels: [UUID: PetViewModel] = [:]
    var configurations: [PetConfiguration] = []
    var notificationMonitor: KakaoTalkNotificationMonitor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        configurations = PetConfigurationStore.load()
        for (index, configuration) in configurations.enumerated() {
            createWindow(for: configuration, offsetIndex: index)
        }

        notificationMonitor = KakaoTalkNotificationMonitor(
            targetBundleIdentifiers: { [weak self] in
                self?.configurations.map(\.bundleIdentifier) ?? []
            },
            onNotification: { [weak self] bundleIdentifier in
                self?.viewModels.values
                    .filter { $0.matches(bundleIdentifier: bundleIdentifier) }
                    .forEach { $0.showNotification() }
            },
            onAccessDenied: { [weak self] in
                self?.viewModels.values.forEach { $0.showNotificationAccessHelp() }
            },
            onStatusChanged: { [weak self] status in
                self?.viewModels.values.forEach { $0.updateNotificationStatus(status) }
            }
        )

        notificationMonitor.start()
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
}
