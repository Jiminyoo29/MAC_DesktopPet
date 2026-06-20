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
    var reactionMode: NotificationReactionMode
    var showsNotificationContent: Bool
    var customNotificationMessage: String?

    init(
        id: UUID,
        name: String,
        userName: String,
        tone: PetTone,
        appName: String,
        bundleIdentifier: String,
        imagePath: String?,
        scale: Double,
        reactionMode: NotificationReactionMode,
        showsNotificationContent: Bool,
        customNotificationMessage: String?
    ) {
        self.id = id
        self.name = name
        self.userName = userName
        self.tone = tone
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.imagePath = imagePath
        self.scale = scale
        self.reactionMode = reactionMode
        self.showsNotificationContent = showsNotificationContent
        self.customNotificationMessage = customNotificationMessage
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
        reactionMode = try container.decodeIfPresent(NotificationReactionMode.self, forKey: .reactionMode) ?? .visibleOnly
        showsNotificationContent = try container.decodeIfPresent(Bool.self, forKey: .showsNotificationContent) ?? false
        customNotificationMessage = try container.decodeIfPresent(String.self, forKey: .customNotificationMessage)
    }

    static let defaultPet = PetConfiguration(
        id: UUID(),
        name: "토끼",
        userName: "사용자",
        tone: .friendly,
        appName: "KakaoTalk",
        bundleIdentifier: "com.kakao.KakaoTalkMac",
        imagePath: nil,
        scale: 1.0,
        reactionMode: .visibleOnly,
        showsNotificationContent: false,
        customNotificationMessage: nil
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

    func clickLines(name: String, userName: String, appName: String) -> [String] {
        let user = Self.formattedUserName(userName)
        let app = appName.isEmpty ? "연결 앱" : appName

        switch self {
        case .friendly:
            return [
                "\(user), 저 여기 있어요!",
                "오늘도 같이 가봐요.",
                "\(name)이 응원 중이에요.",
                "잠깐 어깨 펴고 숨 쉬어요.",
                "물 한 모금 마실 시간이에요.",
                "\(app)도 제가 보고 있을게요.",
                "좋아요, 다음 할 일도 차근차근.",
                "집중 모드 들어갑니다.",
                "괜찮아요. 천천히 해도 돼요.",
                "지금 흐름 좋아요.",
                "쉬고 싶으면 제가 신호 줄게요.",
                "작은 일부터 하나씩 끝내봐요.",
                "\(user), 오늘도 꽤 잘하고 있어요.",
                "\(name)이 옆에서 대기 중이에요."
            ]

        case .polite:
            return [
                "\(user), 필요하시면 말씀해 주세요.",
                "잠시 쉬어가셔도 좋습니다.",
                "\(name)이 조용히 대기하고 있습니다.",
                "오늘 일정도 차분히 정리해 보세요.",
                "물 한 잔 드시는 것도 좋겠습니다.",
                "\(app) 알림은 제가 살펴보겠습니다.",
                "무리하지 마시고 천천히 진행하세요.",
                "좋은 흐름입니다. 계속 이어가 보세요.",
                "작은 작업부터 정리해 보시면 좋겠습니다.",
                "집중하실 수 있게 곁에 있겠습니다.",
                "\(user), 충분히 잘하고 계십니다.",
                "필요하실 때 다시 불러 주세요.",
                "잠깐 자세를 바로잡아 보세요.",
                "오늘도 안정적으로 진행해 보겠습니다."
            ]

        case .cute:
            return [
                "\(user)! 나 불렀어용?",
                "\(name) 뿅 등장!",
                "히히, 같이 힘내봐용.",
                "물 마시면 칭찬해줄게용.",
                "잠깐 스트레칭 뿅!",
                "\(app)도 내가 지켜볼게용.",
                "오늘도 반짝반짝 해보자용.",
                "우와, 지금 집중력 멋져용.",
                "쉬어도 괜찮아용. 내가 기다릴게용.",
                "\(name)이 응원 빔 발사!",
                "작은 성공 하나 만들러 가봐용.",
                "기분 체크 뿅. 괜찮아용?",
                "\(user), 너무 무리하지 말아용.",
                "나 여기서 얌전히 대기 중이야용."
            ]

        case .chic:
            return [
                "대기 중.",
                "불렀어?",
                "좋아. 계속.",
                "물 마셔.",
                "자세 확인.",
                "\(app) 감시 중.",
                "\(name). 준비됨.",
                "쉬어도 됨.",
                "집중.",
                "다음.",
                "\(user). 괜찮아.",
                "천천히.",
                "할 수 있음.",
                "보고 있음."
            ]
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

    private static func formattedUserName(_ userName: String) -> String {
        if userName.hasSuffix("님") || userName.hasSuffix("씨") {
            return userName
        }
        return "\(userName)님"
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
