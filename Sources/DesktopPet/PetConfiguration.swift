import CoreGraphics
import Foundation

struct PetConfiguration: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var userName: String
    var tone: PetTone
    var personality: PetPersonality
    var appName: String
    var bundleIdentifier: String
    var imagePath: String?
    var scale: Double
    var windowOrigin: WindowOrigin?
    var reactionMode: NotificationReactionMode
    var showsNotificationContent: Bool
    var customNotificationMessage: String?

    init(
        id: UUID,
        name: String,
        userName: String,
        tone: PetTone,
        personality: PetPersonality,
        appName: String,
        bundleIdentifier: String,
        imagePath: String?,
        scale: Double,
        windowOrigin: WindowOrigin?,
        reactionMode: NotificationReactionMode,
        showsNotificationContent: Bool,
        customNotificationMessage: String?
    ) {
        self.id = id
        self.name = name
        self.userName = userName
        self.tone = tone
        self.personality = personality
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.imagePath = imagePath
        self.scale = scale
        self.windowOrigin = windowOrigin
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
        personality = try container.decodeIfPresent(PetPersonality.self, forKey: .personality) ?? .balanced
        windowOrigin = try container.decodeIfPresent(WindowOrigin.self, forKey: .windowOrigin)
        reactionMode = try container.decodeIfPresent(NotificationReactionMode.self, forKey: .reactionMode) ?? .visibleOnly
        showsNotificationContent = try container.decodeIfPresent(Bool.self, forKey: .showsNotificationContent) ?? false
        customNotificationMessage = try container.decodeIfPresent(String.self, forKey: .customNotificationMessage)
    }

    static let defaultPet = PetConfiguration(
        id: UUID(),
        name: "토끼",
        userName: "사용자",
        tone: .friendly,
        personality: .balanced,
        appName: "KakaoTalk",
        bundleIdentifier: "com.kakao.KakaoTalkMac",
        imagePath: nil,
        scale: 1.0,
        windowOrigin: nil,
        reactionMode: .visibleOnly,
        showsNotificationContent: false,
        customNotificationMessage: nil
    )
}

struct WindowOrigin: Codable, Equatable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(point: CGPoint) {
        x = point.x
        y = point.y
    }

    var point: CGPoint {
        CGPoint(x: x, y: y)
    }
}

enum PetPersonality: String, Codable, CaseIterable, Equatable {
    case balanced
    case supportive
    case playful
    case focused

    var title: String {
        switch self {
        case .balanced: "균형형"
        case .supportive: "다정형"
        case .playful: "장난꾸러기"
        case .focused: "집중형"
        }
    }

    func clickLines(name: String, userName: String, appName: String, tone: PetTone) -> [String] {
        let user = PetTone.formattedUserName(userName)
        let app = appName.isEmpty ? "연결 앱" : appName

        switch (tone, self) {
        case (.friendly, .balanced):
            return [
                "\(user), 속도랑 휴식 둘 다 챙겨볼게요. ⚖️",
                "\(name)이 오늘 리듬을 같이 맞춰볼게요. 🎵",
                "\(app)도 보고, 집중도 같이 지킬게요. 🧭",
                "할 일과 쉬는 시간, 둘 다 소중해요. 🌤️"
            ]
        case (.friendly, .supportive):
            return [
                "\(user), 지금 충분히 잘하고 있어요. 💛",
                "\(name)이 옆에서 든든하게 볼게요. 🤝",
                "조금 늦어도 괜찮아요. 같이 가요. 🌿",
                "마음 급해지면 제가 작게 신호 줄게요. 🫶"
            ]
        case (.friendly, .playful):
            return [
                "\(name)이 살짝 장난 모드예요. ✨",
                "\(user), 오늘도 반짝이는 순간 잡아봐요. 🎈",
                "\(app) 알림 오면 제가 톡 하고 알려줄게요. 💬",
                "작은 성공 하나 사냥하러 가요. 🍀"
            ]
        case (.friendly, .focused):
            return [
                "\(user), 지금은 집중 흐름을 지켜볼게요. 🎧",
                "\(name)이 방해 요소를 조용히 감시 중이에요. 👀",
                "\(app) 알림만 필요한 만큼 챙길게요. 🔔",
                "하나씩 끝내면 충분해요. ✅"
            ]

        case (.polite, .balanced):
            return [
                "\(user), 균형 있게 도와드리겠습니다. ⚖️",
                "작업과 휴식을 함께 챙기겠습니다. 🌤️",
                "\(name)이 차분히 리듬을 맞추겠습니다. 🎵",
                "\(app) 알림도 필요한 만큼 살피겠습니다. 🧭"
            ]
        case (.polite, .supportive):
            return [
                "\(user), 안정적으로 잘하고 계십니다. 💛",
                "\(name)이 곁에서 조용히 돕겠습니다. 🤝",
                "천천히 진행하셔도 괜찮습니다. 🌿",
                "필요하실 때 편하게 불러주세요. 🫶"
            ]
        case (.polite, .playful):
            return [
                "\(name)이 조금 밝은 모드로 대기하겠습니다. ✨",
                "\(user), 작은 즐거움도 챙겨보겠습니다. 🎈",
                "\(app) 알림은 가볍게 알려드리겠습니다. 💬",
                "오늘의 작은 성과를 함께 찾아보겠습니다. 🍀"
            ]
        case (.polite, .focused):
            return [
                "\(user), 집중을 우선으로 돕겠습니다. 🎧",
                "\(name)이 조용히 상황을 살피겠습니다. 👀",
                "\(app) 알림은 필요한 때 알려드리겠습니다. 🔔",
                "하나씩 정리해 보시면 좋겠습니다. ✅"
            ]

        case (.cute, .balanced):
            return [
                "\(user)! 쉬는 것도 일하는 것도 같이 챙겨용. ⚖️",
                "\(name)이 리듬 맞춰줄게용. 🎵",
                "\(app)도 살피고 기분도 살필게용. 🧭",
                "오늘은 말랑하게 가보자용. 🌤️"
            ]
        case (.cute, .supportive):
            return [
                "\(user)! 진짜 잘하고 있어용. 💛",
                "\(name)이 꼭 붙어서 응원할게용. 🤝",
                "늦어도 괜찮아용, 같이 가용. 🌿",
                "마음 힘들면 나한테 톡 해용. 🫶"
            ]
        case (.cute, .playful):
            return [
                "\(name) 장난 모드 뿅! ✨",
                "\(user), 오늘도 통통 튀게 해봐용. 🎈",
                "\(app) 오면 내가 톡톡 알려줄게용. 💬",
                "작은 성공 찾으러 출발 뿅. 🍀"
            ]
        case (.cute, .focused):
            return [
                "\(user), 집중 모드 뿅 들어가용. 🎧",
                "\(name)이 방해 요소 감시할게용. 👀",
                "\(app) 알림은 필요한 것만 콕 알려줄게용. 🔔",
                "하나씩 끝내면 최고예용. ✅"
            ]

        case (.chic, .balanced):
            return [
                "\(user). 균형 유지. ⚖️",
                "\(name). 리듬 확인. 🎵",
                "\(app) 확인 중. 🧭",
                "일도 휴식도 챙김. 🌤️"
            ]
        case (.chic, .supportive):
            return [
                "\(user). 잘하고 있음. 💛",
                "\(name). 옆에 있음. 🤝",
                "천천히 가도 됨. 🌿",
                "필요하면 부르면 됨. 🫶"
            ]
        case (.chic, .playful):
            return [
                "\(name). 장난 모드. ✨",
                "\(user). 흐름 좋음. 🎈",
                "\(app) 오면 알림. 💬",
                "작은 성공 찾기. 🍀"
            ]
        case (.chic, .focused):
            return [
                "\(user). 집중. 🎧",
                "\(name). 감시 중. 👀",
                "\(app) 필요한 것만. 🔔",
                "하나씩. ✅"
            ]
        }
    }
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

    func clickLines(
        name: String,
        userName: String,
        appName: String,
        personality: PetPersonality = .balanced
    ) -> [String] {
        let user = Self.formattedUserName(userName)
        let app = appName.isEmpty ? "연결 앱" : appName

        let baseLines: [String]
        switch self {
        case .friendly:
            baseLines = [
                "\(user), 저 여기 있어요! 🐰",
                "오늘도 같이 가봐요. ✨",
                "\(name)이 응원 중이에요. 🌟",
                "잠깐 어깨 펴고 숨 쉬어요. 🍃",
                "물 한 모금 마실 시간이에요. 💧",
                "\(app)도 제가 보고 있을게요. 👀",
                "좋아요, 다음 할 일도 차근차근. ✅",
                "집중 모드 들어갑니다. 🎧",
                "괜찮아요. 천천히 해도 돼요. 🌿",
                "지금 흐름 좋아요. 🚀",
                "쉬고 싶으면 제가 신호 줄게요. ☕",
                "작은 일부터 하나씩 끝내봐요. 📝",
                "\(user), 오늘도 꽤 잘하고 있어요. 💛",
                "\(name)이 옆에서 대기 중이에요. 🐾"
            ]

        case .polite:
            baseLines = [
                "\(user), 필요하시면 말씀해 주세요. 🌼",
                "잠시 쉬어가셔도 좋습니다. ☕",
                "\(name)이 조용히 대기하고 있습니다. 🐰",
                "오늘 일정도 차분히 정리해 보세요. 📋",
                "물 한 잔 드시는 것도 좋겠습니다. 💧",
                "\(app) 알림은 제가 살펴보겠습니다. 🔔",
                "무리하지 마시고 천천히 진행하세요. 🌿",
                "좋은 흐름입니다. 계속 이어가 보세요. ✨",
                "작은 작업부터 정리해 보시면 좋겠습니다. 📝",
                "집중하실 수 있게 곁에 있겠습니다. 🎧",
                "\(user), 충분히 잘하고 계십니다. 💛",
                "필요하실 때 다시 불러 주세요. 🤍",
                "잠깐 자세를 바로잡아 보세요. 🪑",
                "오늘도 안정적으로 진행해 보겠습니다. ✅"
            ]

        case .cute:
            baseLines = [
                "\(user)! 나 불렀어용? 🐰",
                "\(name) 뿅 등장! ✨",
                "히히, 같이 힘내봐용. 💖",
                "물 마시면 칭찬해줄게용. 💧",
                "잠깐 스트레칭 뿅! 🙆",
                "\(app)도 내가 지켜볼게용. 👀",
                "오늘도 반짝반짝 해보자용. 🌟",
                "우와, 지금 집중력 멋져용. 🎀",
                "쉬어도 괜찮아용. 내가 기다릴게용. ☁️",
                "\(name)이 응원 빔 발사! 🪄",
                "작은 성공 하나 만들러 가봐용. 🍀",
                "기분 체크 뿅. 괜찮아용? 💗",
                "\(user), 너무 무리하지 말아용. 🫶",
                "나 여기서 얌전히 대기 중이야용. 🐾"
            ]

        case .chic:
            baseLines = [
                "대기 중. 🐰",
                "불렀어? 👀",
                "좋아. 계속. ✅",
                "물 마셔. 💧",
                "자세 확인. 🪑",
                "\(app) 감시 중. 🔔",
                "\(name). 준비됨. ⚡",
                "쉬어도 됨. ☕",
                "집중. 🎧",
                "다음. ➡️",
                "\(user). 괜찮아. 🤍",
                "천천히. 🌿",
                "할 수 있음. ✨",
                "보고 있음. 👁️"
            ]
        }

        return baseLines + personality.clickLines(name: name, userName: userName, appName: appName, tone: self)
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
        case (.friendly, .personalityChanged):
            return "\(name)의 성격을 바꿨어요. ✨"

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
        case (.polite, .personalityChanged):
            return "\(name)의 성격 설정을 변경했습니다. ✨"

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
        case (.cute, .personalityChanged):
            return "\(name) 성격 변신 뿅! ✨"

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
        case (.chic, .personalityChanged):
            return "성격 변경. ✨"
        }
    }

    static func formattedUserName(_ userName: String) -> String {
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
    case personalityChanged
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
