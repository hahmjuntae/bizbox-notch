# Bizbox Notch

macOS 상단바에서 Bizbox 출근/퇴근을 실행하는 메뉴바 앱입니다.

## 설치

설치:

```bash
brew tap hahmjuntae/bizbox-notch
brew install --cask bizbox-notch
```

업데이트:

```bash
brew update
brew upgrade --cask bizbox-notch
```

삭제:

```bash
brew uninstall --cask bizbox-notch
```

## macOS 보안 경고

아래 경고가 뜨면 앱이 Apple notarization을 거치지 않은 빌드입니다.

```text
Apple은 'Bizbox Notch.app'에 악성 코드가 없음을 확인할 수 없습니다.
```

경고 없이 배포하려면 Apple Developer Program 계정의 `Developer ID Application` 인증서로 서명하고 notarization을 완료한 DMG를 배포해야 합니다.

## 설정

설치 후 앱을 실행하면 macOS 상단바에 `근태`가 표시됩니다.

상단바 `근태` 메뉴에서 `설정`을 열고 아래 값을 저장합니다.

- 사이트 URL: `https://gw.forbiz.co.kr/gw/userMain.do`
- 아이디
- 비밀번호
- 로그인 시 실행 여부
- 월요일부터 금요일까지의 출근/퇴근 알림 시간

비밀번호는 macOS Keychain에 저장됩니다.

기본 알림 시간은 다음과 같습니다.

- 월/금: 출근 08:50, 퇴근 18:10
- 화/수/목: 출근 08:20, 퇴근 17:40

## 사용법

상단바의 `근태`를 클릭해서 메뉴를 엽니다.

- `출근`: Bizbox에 로그인하고 출근 처리를 실행합니다.
- `퇴근`: Bizbox에 로그인하고 퇴근 처리를 실행합니다.
- `시간 새로고침`: Bizbox에서 현재 출근/퇴근 시간을 다시 가져옵니다.
- `설정`: 사이트 URL, 아이디, 비밀번호, 알림 시간을 수정합니다.
- `종료`: 앱을 종료합니다.

스케줄 알림은 앱이 실행 중일 때만 동작합니다. 출근 알림은 설정된 출근 시간 5분 전부터 표시되고, 퇴근 알림은 설정된 퇴근 시간부터 표시됩니다. 알림 창은 버튼을 누르거나 닫기 전까지 유지됩니다.

처리 중에는 상단바 문구가 단계별로 바뀝니다.

```text
접속 준비 중...
세션 초기화 중...
접속 중...
로그인 확인 중...
로그인 중...
확인 중...
시간 반영 중...
```

실패하면 상단바에 `실패`가 잠시 표시된 뒤 다시 `근태`로 돌아갑니다.

## 표시 정보

메뉴에는 다음 값이 표시됩니다.

- `출근시간`: Bizbox에서 읽어온 실제 출근 시간
- `퇴근시간`: Bizbox에서 읽어온 실제 퇴근 시간
- `최근 업데이트`: 앱이 Bizbox에서 시간을 마지막으로 읽어온 시각