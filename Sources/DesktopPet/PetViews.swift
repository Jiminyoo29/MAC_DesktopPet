import AppKit
import SwiftUI

// MARK: - Root View

struct PetRootView: View {
    @ObservedObject var viewModel: PetViewModel
    @State private var floatPhase: CGFloat = 0
    @State private var blink = false

    let floatTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    let blinkTimer = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // 드래그/클릭 오버레이 (최상단, 투명)
            DraggableOverlay(
                onTap: viewModel.tap,
                onDoubleClick: viewModel.openLinkedApp,
                onSetName: viewModel.setName,
                onSetUserName: viewModel.setUserName,
                onSetFriendlyTone: { viewModel.setTone(.friendly) },
                onSetPoliteTone: { viewModel.setTone(.polite) },
                onSetCuteTone: { viewModel.setTone(.cute) },
                onSetChicTone: { viewModel.setTone(.chic) },
                onSetVisibleOnlyMode: { viewModel.setReactionMode(.visibleOnly) },
                onSetIncludeHiddenMode: { viewModel.setReactionMode(.includeHidden) },
                onToggleNotificationContent: viewModel.toggleNotificationContent,
                onSetCustomNotificationMessage: viewModel.setCustomNotificationMessage,
                onChooseLinkedApp: viewModel.chooseLinkedApp,
                onChooseImage: viewModel.choosePetImage,
                onResetImage: viewModel.resetPetImage,
                onSetSmallSize: viewModel.setSmallSize,
                onSetMediumSize: viewModel.setMediumSize,
                onSetLargeSize: viewModel.setLargeSize,
                onSetCustomScale: viewModel.setCustomScale,
                currentScale: viewModel.scale,
                currentReactionMode: viewModel.reactionMode,
                showsNotificationContent: viewModel.showsNotificationContent,
                onCreatePet: viewModel.createPet,
                onClosePet: viewModel.closePet,
                onOpenFullDiskAccessSettings: viewModel.openFullDiskAccessSettings,
                onOpenAccessibilitySettings: viewModel.openAccessibilitySettings,
                onShowNotificationStatus: viewModel.showNotificationStatus,
                onShowTestNotification: viewModel.showTestNotification
            )
                .zIndex(10)

            VStack(spacing: 0) {
                // 말풍선 영역
                ZStack {
                    if viewModel.showDialogue, let text = viewModel.dialogue {
                        SpeechBubble(text: text)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.6, anchor: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .frame(height: 85)

                // 캐릭터
                PetAvatar(imagePath: viewModel.petImagePath, blink: blink)
                    .offset(y: sin(floatPhase) * 7)
                    .scaleEffect(viewModel.isBouncing ? 1.18 : 1.0)
                    .frame(width: 160, height: 135)
            }
            .frame(width: 160, height: 220)
        }
        .scaleEffect(viewModel.scale)
        .frame(width: 160 * viewModel.scale, height: 220 * viewModel.scale)
        .onReceive(floatTimer) { _ in floatPhase += 0.042 }
        .onReceive(blinkTimer) { _ in triggerBlink() }
    }

    private func triggerBlink() {
        blink = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { blink = false }
    }
}

// MARK: - Speech Bubble

struct SpeechBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color(white: 0.15))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.97))
                        .shadow(color: .black.opacity(0.13), radius: 6, x: 0, y: 3)
                )
            // 말풍선 꼬리
            ArrowDown()
                .fill(Color.white.opacity(0.97))
                .frame(width: 12, height: 7)
                .offset(y: -1)
        }
    }
}

struct ArrowDown: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - Pet Character

struct PetAvatar: View {
    let imagePath: String?
    var blink: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: 76, height: 13)
                .blur(radius: 4)
                .offset(y: 58)

            if let imagePath, let image = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.11), radius: 7, x: 0, y: 4)
            } else {
                ZStack {
                    Text("🐰")
                        .font(.system(size: 92))
                        .shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 4)

                    if blink {
                        Text("˘  ˘")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.28, green: 0.18, blue: 0.18))
                            .offset(y: -8)
                    }
                }
                .accessibilityLabel("토끼 펫")
            }
        }
    }
}

struct PetCharacter: View {
    var blink: Bool

    // 고양이 색상
    private let skinColor   = Color(red: 1.0,  green: 0.89, blue: 0.76)
    private let bodyColor   = Color(red: 0.96, green: 0.79, blue: 0.89)
    private let bellyColor  = Color(red: 1.0,  green: 0.93, blue: 0.97)
    private let earPinkColor = Color(red: 1.0,  green: 0.68, blue: 0.76)

    var body: some View {
        ZStack {
            // 그림자
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: 68, height: 12)
                .blur(radius: 4)
                .offset(y: 62)

            VStack(spacing: -6) {
                // ── 머리 ──
                ZStack {
                    // 귀 (머리 뒤)
                    HStack(spacing: 50) {
                        CatEar(skinColor: skinColor, innerColor: earPinkColor, flip: false)
                        CatEar(skinColor: skinColor, innerColor: earPinkColor, flip: true)
                    }
                    .offset(y: -20)

                    // 머리 베이스
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(skinColor)
                        .frame(width: 82, height: 76)

                    // 볼터치
                    HStack(spacing: 44) {
                        Ellipse().fill(Color.pink.opacity(0.32)).frame(width: 18, height: 11)
                        Ellipse().fill(Color.pink.opacity(0.32)).frame(width: 18, height: 11)
                    }
                    .offset(y: 12)

                    // 눈
                    HStack(spacing: 24) {
                        CatEye(blink: blink)
                        CatEye(blink: blink)
                    }
                    .offset(y: -2)

                    // 코
                    CatNose().offset(y: 16)

                    // 입
                    CatMouth().offset(y: 23)

                    // 수염
                    Whiskers()
                }

                // ── 몸통 ──
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(bodyColor)
                        .frame(width: 72, height: 58)

                    // 배
                    Ellipse()
                        .fill(bellyColor)
                        .frame(width: 38, height: 30)
                        .offset(y: 7)

                    // 팔
                    HStack(spacing: 66) {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(bodyColor)
                            .frame(width: 15, height: 26)
                            .rotationEffect(.degrees(12))
                            .offset(y: 8)
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(bodyColor)
                            .frame(width: 15, height: 26)
                            .rotationEffect(.degrees(-12))
                            .offset(y: 8)
                    }
                }

                // ── 발 ──
                HStack(spacing: 22) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bodyColor)
                        .frame(width: 24, height: 15)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bodyColor)
                        .frame(width: 24, height: 15)
                }
                .offset(y: -4)
            }
        }
    }
}

// MARK: - Sub-components

struct CatEye: View {
    var blink: Bool

    var body: some View {
        if blink {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(red: 0.22, green: 0.16, blue: 0.14))
                .frame(width: 17, height: 4)
        } else {
            ZStack {
                Circle()
                    .fill(Color(red: 0.22, green: 0.16, blue: 0.14))
                    .frame(width: 15, height: 15)
                // 하이라이트
                Circle()
                    .fill(Color.white)
                    .frame(width: 5.5, height: 5.5)
                    .offset(x: 3.5, y: -3.5)
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: -2.5, y: 3)
            }
        }
    }
}

struct CatEar: View {
    let skinColor: Color
    let innerColor: Color
    var flip: Bool

    var body: some View {
        ZStack {
            Triangle()
                .fill(skinColor)
                .frame(width: 24, height: 26)
                .scaleEffect(x: flip ? -1 : 1)
            Triangle()
                .fill(innerColor)
                .frame(width: 13, height: 15)
                .scaleEffect(x: flip ? -1 : 1)
                .offset(y: 5)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

struct CatNose: View {
    var body: some View {
        Triangle()
            .fill(Color(red: 1.0, green: 0.58, blue: 0.62))
            .frame(width: 9, height: 7)
    }
}

struct CatMouth: View {
    var body: some View {
        Path { p in
            p.move(to:    CGPoint(x: 4.5, y: 0))
            p.addLine(to: CGPoint(x: 0,   y: 4))
            p.addLine(to: CGPoint(x: -4.5, y: 0))
        }
        .stroke(Color(red: 0.72, green: 0.38, blue: 0.42), lineWidth: 2)
    }
}

struct Whiskers: View {
    private let whiskerColor = Color.gray.opacity(0.38)

    var body: some View {
        ZStack {
            // 왼쪽 수염 3개
            ForEach(0..<3) { i in
                Rectangle()
                    .fill(whiskerColor)
                    .frame(width: 26, height: 1)
                    .rotationEffect(.degrees(Double(i - 1) * 12))
                    .offset(x: -34, y: 14)
            }
            // 오른쪽 수염 3개
            ForEach(0..<3) { i in
                Rectangle()
                    .fill(whiskerColor)
                    .frame(width: 26, height: 1)
                    .rotationEffect(.degrees(Double(1 - i) * 12))
                    .offset(x: 34, y: 14)
            }
        }
    }
}
