import Foundation

struct PetConfiguration: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var userName: String
    var tone: PetTone
    var appName: String
    var bundleIdentifier: String
    var imagePath: String?
    var scale: Double

    init(
        id: UUID,
        name: String,
        userName: String,
        tone: PetTone,
        appName: String,
        bundleIdentifier: String,
        imagePath: String?,
        scale: Double
    ) {
        self.id = id
        self.name = name
        self.userName = userName
        self.tone = tone
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.imagePath = imagePath
        self.scale = scale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        appName = try container.decode(String.self, forKey: .appName)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "토끼"
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? "사용자"
        tone = try container.decodeIfPresent(PetTone.self, forKey: .tone) ?? .friendly
    }

    static let defaultPet = PetConfiguration(
        id: UUID(),
        name: "토끼",
        userName: "사용자",
        tone: .friendly,
        appName: "KakaoTalk",
        bundleIdentifier: "com.kakao.KakaoTalkMac",
        imagePath: nil,
        scale: 1.0
    )
}

enum PetTone: String, Codable, CaseIterable, Equatable {
    case friendly
    case polite
    case cute
    case chic

    var title: String {
        switch self {
        case .friendly: "기본"
        case .polite: "공손"
        case .cute: "애교"
        case .chic: "시크"
        }
    }

    func line(name: String, event: PetLineEvent, appName: String? = nil) -> String {
        let app = appName ?? "앱"

        switch (self, event) {
        case (.friendly, .hello):
            return "\(name)이 왔어요!"
        case (.friendly, .notification):
            return "\(app) 알림이 왔어요!"
        case (.friendly, .test):
            return "\(name)의 테스트 알림이에요!"
        case (.friendly, .imageChanged):
            return "새 모습 마음에 들어요?"
        case (.friendly, .imageReset):
            return "\(name)로 돌아왔어요! 🐰"
        case (.friendly, .small):
            return "작게 변했어요."
        case (.friendly, .medium):
            return "기본 크기예요."
        case (.friendly, .large):
            return "크게 변했어요."
        case (.friendly, .appLinked):
            return "\(app)에 연결했어요."
        case (.friendly, .nameChanged):
            return "이제 \(name)(이)라고 불러주세요."
        case (.friendly, .toneChanged):
            return "말투를 바꿨어요."

        case (.polite, .hello):
            return "안녕하세요. \(name)입니다."
        case (.polite, .notification):
            return "\(app) 알림이 도착했습니다."
        case (.polite, .test):
            return "테스트 알림입니다."
        case (.polite, .imageChanged):
            return "새 이미지로 변경했습니다."
        case (.polite, .imageReset):
            return "기본 이미지로 되돌렸습니다."
        case (.polite, .small):
            return "작은 크기로 변경했습니다."
        case (.polite, .medium):
            return "기본 크기로 변경했습니다."
        case (.polite, .large):
            return "큰 크기로 변경했습니다."
        case (.polite, .appLinked):
            return "\(app)에 연결했습니다."
        case (.polite, .nameChanged):
            return "이름을 \(name)(으)로 변경했습니다."
        case (.polite, .toneChanged):
            return "말투 설정을 변경했습니다."

        case (.cute, .hello):
            return "\(name) 등장! 히히 🐰"
        case (.cute, .notification):
            return "\(app)에서 알림 왔어용!"
        case (.cute, .test):
            return "테스트 알림 뿅!"
        case (.cute, .imageChanged):
            return "새 모습 어때용?"
        case (.cute, .imageReset):
            return "다시 토끼로 뿅! 🐰"
        case (.cute, .small):
            return "쪼꼬매졌어용."
        case (.cute, .medium):
            return "딱 좋은 크기!"
        case (.cute, .large):
            return "커졌다아!"
        case (.cute, .appLinked):
            return "\(app)이랑 친구 됐어용."
        case (.cute, .nameChanged):
            return "내 이름은 이제 \(name)!"
        case (.cute, .toneChanged):
            return "말투 바꿨지롱."

        case (.chic, .hello):
            return "\(name). 대기 중."
        case (.chic, .notification):
            return "\(app) 알림."
        case (.chic, .test):
            return "테스트."
        case (.chic, .imageChanged):
            return "이미지 변경 완료."
        case (.chic, .imageReset):
            return "기본값."
        case (.chic, .small):
            return "작게."
        case (.chic, .medium):
            return "기본."
        case (.chic, .large):
            return "크게."
        case (.chic, .appLinked):
            return "\(app) 연결."
        case (.chic, .nameChanged):
            return "\(name)."
        case (.chic, .toneChanged):
            return "말투 변경."
        }
    }
}

enum PetLineEvent {
    case hello
    case notification
    case test
    case imageChanged
    case imageReset
    case small
    case medium
    case large
    case appLinked
    case nameChanged
    case toneChanged
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
