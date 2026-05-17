# Bizbox Notch for Windows

Windows 작업표시줄 트레이에서 Bizbox 출근/퇴근을 실행하는 앱입니다.

## 기능

- 트레이 메뉴의 `출근`, `퇴근`, `새로고침`
- Bizbox 로그인 및 출근/퇴근 처리 자동화
- Bizbox에서 읽은 실제 출근/퇴근 시간 표시
- 월요일부터 금요일까지 출근/퇴근 알림 발생 시간 설정
- 설정한 시간 정각에 유지되는 알림창 표시
- 알림창의 `출근` / `퇴근` 버튼으로 처리 실행
- Windows 로그인 시 실행 옵션
- 비밀번호 DPAPI 암호화 저장

## 요구 사항

- Windows 10 이상
- .NET 8 SDK 또는 Windows Desktop Runtime
- Microsoft Edge WebView2 Runtime

## 개발 실행

```powershell
cd windows\BizboxNotch.Windows
dotnet run -c Release
```

## 배포 빌드

```powershell
cd windows\BizboxNotch.Windows
dotnet publish -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true `
  -p:PublishReadyToRun=true
```

출력 파일은 아래 경로에 생성됩니다.

```text
bin\Release\net8.0-windows10.0.19041.0\win-x64\publish\BizboxNotch.exe
```

## 설정 저장 위치

```text
%APPDATA%\Bizbox Notch\settings.json
```

비밀번호는 현재 Windows 사용자 계정 범위로 암호화되어 저장됩니다.
