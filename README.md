# Bizbox Notch

macOS 상단바에서 Bizbox 출근/퇴근을 실행하는 메뉴바 앱입니다.

## 설치

설치:

```bash
brew tap hahmjuntae/bizbox-notch https://github.com/hahmjuntae/bizbox-notch.git
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

## 설정

설치 후 앱을 실행하면 macOS 상단바에 `근태`가 표시됩니다.

상단바 `근태` 메뉴에서 `설정...`을 열고 아래 값을 저장합니다.

- 사이트 URL: `https://gw.forbiz.co.kr/gw/userMain.do`
- 아이디
- 비밀번호

비밀번호는 macOS Keychain에 저장됩니다.

## 사용법

상단바의 `근태`를 클릭해서 메뉴를 엽니다.

- `출근`: Bizbox에 로그인하고 출근 처리를 실행합니다.
- `퇴근`: Bizbox에 로그인하고 퇴근 처리를 실행합니다.
- `시간 새로고침`: Bizbox에서 현재 출근/퇴근 시간을 다시 가져옵니다.
- `설정...`: 사이트 URL, 아이디, 비밀번호를 수정합니다.
- `종료`: 앱을 종료합니다.

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