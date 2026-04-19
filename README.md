# bizbox-notch

macOS 상단바에 뜨는 Swift 메뉴바 앱입니다. 상단바의 `근태`를 클릭하면 `출근` / `퇴근` 두 메뉴가 나오고, 각각 Bizbox에 로그인한 뒤 실제 근태 처리 버튼을 클릭합니다. 처리에 성공하면 메뉴에 `출근시간` / `퇴근시간`이 기록됩니다.

macOS에는 서드파티 앱이 시스템 Dynamic Island 자체를 확장하는 공개 API가 없습니다. 그래서 이 버전은 노치 주변에서 가장 자연스럽게 접근할 수 있는 native 상단바 앱으로 구현했습니다.

## 설치

```bash
swift build
```

## 설정

상단바 `근태` 메뉴에서 `설정...`을 열고 다음 값을 저장합니다.

- 사이트 URL: 기본값 `https://gw.forbiz.co.kr/gw/userMain.do`
- 아이디
- 비밀번호

아이디와 마지막 출퇴근 시간은 `UserDefaults`에 저장하고, 비밀번호는 macOS Keychain에 저장합니다.

## 실행

```bash
swift run BizboxNotch
```

앱은 Dock에 표시되지 않고 상단바에 `근태`로 표시됩니다.

## 확인된 Bizbox 클릭 대상

Playwright로 실제 로그인 후 확인한 DOM입니다.

```text
로그인 아이디 input: #userId
로그인 비밀번호 input: #userPw
로그인 실행: actionLogin()
출근 탭: li[onclick="fnSetAttOption(1)"]
퇴근 탭: li[onclick="fnSetAttOption(4)"]
출근 처리 앵커: #attHref1
퇴근 처리 앵커: #attHref2
```

`fnSetAttOption(1/4)`는 탭을 활성화하면서 실제 처리 앵커의 `onclick`을 `fnAttendCheck(1/4)`로 설정합니다. 앱은 탭 클릭 후 `#attHref1` 또는 `#attHref2`를 클릭하고 사이트의 확인 팝업을 자동 승인합니다.

## DMG 빌드

```bash
chmod +x scripts/build-dmg.sh
scripts/build-dmg.sh
```

빌드 결과는 `dist/` 아래에 생성됩니다.

```text
dist/Bizbox-Notch-0.2.12.dmg
dist/Bizbox Notch.dmg
```

현재 설정은 로컬 배포용 ad-hoc signed DMG입니다. 다른 사람에게 Gatekeeper 경고 없이 배포하려면 Apple Developer ID 서명과 notarization 설정이 추가로 필요합니다.

## Homebrew 설치

단일 private repo `hahmjuntae/bizbox-notch`를 앱 소스와 tap으로 함께 씁니다.

최초 설치:

```bash
export HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)"
brew tap hahmjuntae/bizbox-notch https://github.com/hahmjuntae/bizbox-notch.git
brew install --cask bizbox-notch
```

private GitHub Release asset을 받기 때문에 `HOMEBREW_GITHUB_API_TOKEN`에는 `hahmjuntae/bizbox-notch`를 읽을 수 있는 token이 필요합니다.

업데이트:

```bash
brew update
brew upgrade --cask bizbox-notch
```

릴리스할 때는 `dist/Bizbox-Notch-<version>.dmg`를 GitHub Release asset으로 올리고, `Casks/bizbox-notch.rb`의 `version`과 `sha256`을 갱신합니다.

## 테스트

```bash
swift build
```