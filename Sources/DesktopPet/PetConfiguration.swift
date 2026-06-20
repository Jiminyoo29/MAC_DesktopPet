import Foundation

struct PetConfiguration: Codable, Identifiable, Equatable {
    var id: UUID
    var appName: String
    var bundleIdentifier: String
    var imagePath: String?
    var scale: Double

    static let defaultPet = PetConfiguration(
        id: UUID(),
        appName: "KakaoTalk",
        bundleIdentifier: "com.kakao.KakaoTalkMac",
        imagePath: nil,
        scale: 1.0
    )
}

enum PetConfigurationStore {
    private static let key = "petConfigurations"

    static func load() -> [PetConfiguration] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let configurations = try? JSONDecoder().decode([PetConfiguration].self, from: data),
              !configurations.isEmpty else {
            return [.defaultPet]
        }
        return configurations
    }

    static func save(_ configurations: [PetConfiguration]) {
        guard let data = try? JSONEncoder().encode(configurations) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
