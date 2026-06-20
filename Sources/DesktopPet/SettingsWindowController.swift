import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?
    private let model: SettingsWindowModel

    init(
        onUpdate: @escaping (PetConfiguration) -> [PetConfiguration],
        onAddPet: @escaping () -> [PetConfiguration],
        onChooseApp: @escaping (UUID) -> [PetConfiguration],
        onOpenApp: @escaping (UUID) -> Void
    ) {
        model = SettingsWindowModel(
            onUpdate: onUpdate,
            onAddPet: onAddPet,
            onChooseApp: onChooseApp,
            onOpenApp: onOpenApp
        )
    }

    func show(configurations: [PetConfiguration]) {
        model.refresh(configurations)

        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "DesktopPet 설정"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsWindowView(model: model))
            window.center()
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class SettingsWindowModel: ObservableObject {
    @Published var configurations: [PetConfiguration] = []

    private let onUpdate: (PetConfiguration) -> [PetConfiguration]
    private let onAddPet: () -> [PetConfiguration]
    private let onChooseApp: (UUID) -> [PetConfiguration]
    private let onOpenApp: (UUID) -> Void

    init(
        onUpdate: @escaping (PetConfiguration) -> [PetConfiguration],
        onAddPet: @escaping () -> [PetConfiguration],
        onChooseApp: @escaping (UUID) -> [PetConfiguration],
        onOpenApp: @escaping (UUID) -> Void
    ) {
        self.onUpdate = onUpdate
        self.onAddPet = onAddPet
        self.onChooseApp = onChooseApp
        self.onOpenApp = onOpenApp
    }

    func refresh(_ configurations: [PetConfiguration]) {
        self.configurations = configurations
    }

    func save(_ configuration: PetConfiguration) {
        configurations = onUpdate(configuration)
    }

    func addPet() {
        configurations = onAddPet()
    }

    func chooseApp(for id: UUID) {
        configurations = onChooseApp(id)
    }

    func openApp(for id: UUID) {
        onOpenApp(id)
    }
}

struct SettingsWindowView: View {
    @ObservedObject var model: SettingsWindowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("펫 설정")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Button("새 펫") {
                    model.addPet()
                }
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach($model.configurations) { $configuration in
                        SettingsPetRow(
                            configuration: $configuration,
                            onSave: { model.save($0) },
                            onChooseApp: { model.chooseApp(for: configuration.id) },
                            onOpenApp: { model.openApp(for: configuration.id) }
                        )
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .padding(18)
        .frame(minWidth: 520, minHeight: 540)
    }
}

struct SettingsPetRow: View {
    @Binding var configuration: PetConfiguration
    let onSave: (PetConfiguration) -> Void
    let onChooseApp: () -> Void
    let onOpenApp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField("펫 이름", text: $configuration.name)
                    .textFieldStyle(.roundedBorder)
                TextField("사용자 호칭", text: $configuration.userName)
                    .textFieldStyle(.roundedBorder)
                Button("저장") {
                    onSave(configuration)
                }
            }

            HStack(spacing: 10) {
                Text(configuration.appName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("열기") {
                    onOpenApp()
                }
                Button("앱 바꾸기") {
                    onChooseApp()
                }
            }

            HStack(spacing: 12) {
                Picker("말투", selection: $configuration.tone) {
                    ForEach(PetTone.allCases, id: \.self) { tone in
                        Text(tone.title).tag(tone)
                    }
                }
                .onChange(of: configuration.tone) { _ in onSave(configuration) }

                Picker("성격", selection: $configuration.personality) {
                    ForEach(PetPersonality.allCases, id: \.self) { personality in
                        Text(personality.title).tag(personality)
                    }
                }
                .onChange(of: configuration.personality) { _ in onSave(configuration) }
            }

            HStack(spacing: 12) {
                Text("크기")
                    .frame(width: 34, alignment: .leading)
                Slider(value: $configuration.scale, in: 0.55...1.6)
                    .onChange(of: configuration.scale) { _ in onSave(configuration) }
                Text("\(Int(configuration.scale * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .frame(width: 44, alignment: .trailing)
            }

            HStack(spacing: 12) {
                Picker("알림", selection: $configuration.reactionMode) {
                    ForEach(NotificationReactionMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .onChange(of: configuration.reactionMode) { _ in onSave(configuration) }

                Toggle("내용 표시", isOn: $configuration.showsNotificationContent)
                    .onChange(of: configuration.showsNotificationContent) { _ in onSave(configuration) }
            }

            TextField("알림 문구", text: Binding(
                get: { configuration.customNotificationMessage ?? "" },
                set: { configuration.customNotificationMessage = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .onSubmit { onSave(configuration) }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
        )
    }
}
