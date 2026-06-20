# DesktopPet

<p align="center">
  <img src="docs/assets/app-icon.png" width="128" alt="MAC DesktopPet app icon">
</p>

macOS 화면 위에 항상 떠 있는 작은 pet 앱입니다. pet마다 앱을 연결할 수 있고, 연결한 앱의 알림을 감지하면 말풍선으로 반응합니다.

## 지금 되는 것

- 화면 위에 항상 떠 있는 토끼 pet
- 드래그로 위치 이동
- 앱을 다시 열어도 pet 위치 유지
- 한 번 클릭하면 랜덤 말풍선
- 더블클릭하면 연결한 앱 열기
- 연결한 앱 알림 흔적이 감지되면 말풍선 표시
- 우클릭 메뉴에서 개인 이미지로 pet 변경
- 우클릭 메뉴에서 기본 토끼 이모지로 복귀
- 우클릭 메뉴에서 연결 앱 변경
- 우클릭 메뉴에서 pet 크기 변경
- 우클릭 메뉴에서 pet 이름 변경
- 우클릭 메뉴에서 사용자 호칭 변경
- 우클릭 메뉴에서 말투 변경
- 우클릭 메뉴에서 성격 변경
- 우클릭 메뉴에서 연결 앱 액션 실행
- 크기 메뉴에서 슬라이더로 세밀한 크기 조절
- 여러 pet 생성 및 pet별 앱 연결
- 메뉴바 아이콘에서 설정 창 열기
- 알림 반응 모드 선택: 표시된 알림만 / 숨겨진 알림도
- 알림에 표시된 내용을 그대로 말풍선에 보여주기
- 앱별 기본 알림 문구 커스텀
- 긴 알림 말풍선 표시 시간 자동 조절
- 같은 앱의 짧은 중복 알림 반응 줄이기
- 첫 실행 권한 안내
- 메뉴바 아이콘에서 pet 숨기기, 새 pet 만들기, 권한 열기, 종료
- Mac 시작 시 자동 실행 설정

## 실행

```sh
swift run --disable-sandbox
```

빌드만 확인하려면:

```sh
swift build --disable-sandbox
```

## 배포용 앱 만들기

아래 명령은 release 빌드 후 더블클릭 가능한 macOS 앱 번들과 zip 파일을 만듭니다.

```sh
scripts/build_app.sh
```

생성되는 파일:

```text
dist/MAC DesktopPet.app
dist/MAC_DesktopPet-macOS.zip
```

로컬 설치:

```sh
mkdir -p ~/Applications
ditto "dist/MAC DesktopPet.app" "$HOME/Applications/MAC DesktopPet.app"
```

GitHub 배포 시에는 `dist/MAC_DesktopPet-macOS.zip`을 Release asset으로 올리면 됩니다.

현재 앱은 ad-hoc 서명 상태입니다. GitHub Release로 공개 배포하면 사용자가 처음 실행할 때 macOS Gatekeeper 경고를 볼 수 있습니다. 경고 없는 배포를 하려면 Apple Developer ID 인증서로 서명하고 notarization을 진행해야 합니다.

## 필요한 권한

알림 감지는 macOS Notification Center의 로컬 기록을 확인하는 방식입니다. macOS가 이 기록 접근을 막으면 pet이 알림에 반응할 수 없습니다. 처음 실행하면 필요한 권한 안내가 표시됩니다.

알림 반응을 사용하려면:

1. 시스템 설정을 엽니다.
2. 개인정보 보호 및 보안으로 이동합니다.
3. 전체 디스크 접근에서 예전 `MAC DesktopPet` 항목이 있다면 제거합니다.
4. `~/Applications/MAC DesktopPet.app` 또는 설치한 `MAC DesktopPet.app`을 다시 추가합니다.
5. `MAC DesktopPet`을 허용합니다.
6. 앱을 종료한 뒤 다시 실행합니다.

앱에서 우클릭 후 `알림 감지 권한 열기`를 선택하면 관련 설정 화면을 열 수 있습니다.

더 빠른 알림 반응을 원하면 `빠른 감지 권한 열기`를 선택한 뒤 손쉬운 사용에서 `MAC DesktopPet`을 허용합니다. 이 모드는 Notification Center DB에 기록되기를 기다리지 않고 화면에 뜬 알림 배너를 먼저 확인합니다.

## 알림 감지 방식

macOS는 다른 앱의 알림 내용을 직접 읽는 공식 API를 제공하지 않습니다. 이 앱은 Notification Center의 로컬 기록에서 연결 앱의 알림 흔적을 주기적으로 확인합니다.

기본값은 “표시된 알림만 반응”입니다. 앱 우클릭 메뉴에서 “숨겨진 알림도”로 바꾸면 화면에 표시되지 않은 Notification Center 기록에도 반응할 수 있습니다.

알림 내용 표시는 기본으로 꺼져 있습니다. 앱 우클릭 메뉴에서 `알림 내용 그대로 표시`를 켜면 macOS 알림 배너/알림센터에 실제로 표시된 텍스트만 말풍선에 잠깐 보여줍니다. 카카오톡 내부 데이터베이스나 숨겨진 메시지 본문은 읽지 않습니다. 알림 내용은 로그에 저장하지 않습니다.
