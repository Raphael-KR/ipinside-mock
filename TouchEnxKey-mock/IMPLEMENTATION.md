# 티머니 설치 확인 구현 계획

## 확정 범위

목표: `https://pay.tmoney.co.kr`의 TouchEn nxKey 설치 안내 강제 이동을 해소한다.
범위: 설치 확인용 WSS 서버, 공통 프로세스·TLS 재사용, 기존 메뉴바 제어 연결.
이번 완료 조건: 공개 계약 기반 구현, 정적 검사, 앱 빌드와 번들 검증을 마친다.
제외 범위: 로그인·결제, 키 입력 수집·암호화, 원본 프로그램 설치·삭제, 실행 검증.
검증: 사용자 최종 결정에 따라 정적 검사와 빌드만 수행하고 실제 동작은 미확인으로 남긴다.

## 확인한 계약 (2026-10-30)

- ego-browser 공간 2의 공개 로그인 흐름에서 설치 안내 페이지로 이동하는 현상을 확인했다.
- 공식 설정: `wss://127.0.0.1`, 포트 `34581`부터 3개를 순서대로 검사한다.
- 포트 탐색은 `/`에 WebSocket을 열어 `WebSocket.send({})`를 호출한다.
  브라우저가 보내는 문자열은 `[object Object]`이며, 응답이 오면 포트를 저장한다.
- 실제 호출 경로는 `/raon/touchenex/Call`이다.
- `get_versions` 요청의 모듈은 `nxkey`이며, 설치 여부는 데몬·프로토콜·모듈 버전으로
  판정한다. 이 설치 검사 응답에 서명된 인증 증명은 요구하지 않는다.
- macOS 기준 최소 버전은 데몬 `1.0.1.8`, 프로토콜 `1.0.1.1550`, 모듈 `1.0.0.18`이다.
- 설치 판정 후 `setcallback`과 `Key_Init` 호출이 이어진다. 사이트는 초기화·입력 준비
  응답이 없으면 입력란의 포커스를 해제하거나 일반 입력을 지운다. `Key_Init`과
  `Key_Start`에는 초기화·준비 확인만 응답하고 실제 키보드 보호·암호화는 구현하지 않는다.
- 데몬과 사이트 인터페이스가 각각 한 단계씩 응답을 해제하므로 native 결과는
  `response.reply.reply.reply`에 둔다. 전송 성공 상태와 실제 함수 결과를 구분한다.
- 티머니 현재 설정의 `defaultenc`와 `allcrypt`는 `false`이며 로그인 입력란에는 E2E
  암호화 속성이 없다. 다른 사이트나 암호화 필드의 호환성을 주장하지 않는다.
- `Key_Start`의 인자에는 현재 필드 값이 포함될 수 있다. 서버는 `exfunc.args`를
  사용하거나 로그·파일로 기록하지 않으며 외부로 전송하지 않는다.

공개 원본은 조사용 `.cache/research/`에만 저장하며 배포하지 않는다. 라이선스 문자열,
세션 키, 입력값과 요청 인자는 보고서·진단 로그에 포함하지 않는다.

### 공개 근거

- [티머니 설정](https://pay.tmoney.co.kr/js/keyboardSecurity/raonnx/cmn/TouchEnNx.js)
- [데몬 계약](https://pay.tmoney.co.kr/js/keyboardSecurity/raonnx/cmn/TouchEnNx_daemon.js)
- [버전 설정](https://pay.tmoney.co.kr/js/keyboardSecurity/raonnx/nxKey/js/nxkey_config.js)
- [호출 인터페이스](https://pay.tmoney.co.kr/js/keyboardSecurity/raonnx/nxKey/js/TouchEnNxKey_Interface.js)
- [초기화 응답 처리](https://pay.tmoney.co.kr/js/keyboardSecurity/raonnx/nxKey/js/TouchEnNxKey.js)

위 공개 JavaScript의 SHA-256:

| 파일 | SHA-256 |
| --- | --- |
| TouchEnNx.js | `0c0d636f52c678b1475f52d17858f7e0eac1a64a2a47ddbea06745d3738f4764` |
| TouchEnNx_daemon.js | `0ac3ce5f9e1a6746400f5b22bf3b183200e8efafb03e25c18631d70db81e1e7b` |
| nxkey_config.js | `bc1ddaaa70ae066487e6411b8a6f80a140c2b4f450977c6aac6d99cb441997fe` |
| TouchEnNxKey_Interface.js | `a0563384b3ccd9099c00c3d3cb5dd57e3021c9ce71f9e390f0d2cf8edc0b704c` |
| TouchEnNxKey.js | `dea11fcb1195a33e82f6a5719ceccc450b4752819dcc2ae4f8f88ad94fe2399f` |

## 구현 경계

- `src/Shared/PythonServerProcess.swift`: Python 자식 프로세스 시작·중지·종료 상태.
- `TouchEnxKey-mock/TouchEnNxKeyServer.swift`: 전용 서버와 공통 인증서 연결.
- `TouchEnxKey-mock/touchen_nxkey_server.py`: Python 표준 라이브러리로 독립 구현한
  TLS/WebSocket 및 설치 확인 응답. 외부 연결이나 캡처 데이터 저장은 없다.
- `src/main.swift`: 기존 메뉴바에 TouchEn nxKey 상태·시작·중지와 공통 인증서 설정 연결.
- `build.sh`: 전용 Python 파일을 앱 리소스로 포함하고 설치 없는 별도 출력 경로 지원.
- 인증서는 기존 IPinside의 공통 `interezen.crt`·`interezen.key`를 재사용한다.
  IPinside의 `captured.json`은 TouchEn 기능에서 읽거나 변경하지 않는다.
- 초기 설정이 필요한 경우 사용자가 메뉴에서 기존 인증서 복사·신뢰 등록을 선택한다.
  개발 중에는 키체인·설치본·운영 서버를 자동 변경하지 않는다.

## 검증 상태

- 공개 설치 안내 이동 재현: 확인.
- 기존 Swift 소스 타입 검사: macOS 27.2 SDK, arm64, deployment target 12.0에서 통과.
- 사용자 최종 검증 범위: **정적 검사와 빌드만**.
- 합성 요청 생성·실행, 기존 인증서·개인 키 읽기, 임시 서버 시작, 실제 페이지 재검사는
  수행하지 않는다. 이 제한은 이번 검증에 적용하며 향후 기능 자체를 제한하는 정책이 아니다.
- 추가 기능의 정적 검사·최종 앱 빌드 결과는 아래에 기록한다. 실제 설치 검사 통과,
  TLS 연결, 입력 동작, 자식 프로세스 정리는 실행 검증 전까지 미확인이다.

## 최종 정적 검사·빌드 결과 (2026-10-30)

- Swift 6.4, arm64, macOS 27.2 환경에서 아래 명령이 종료 코드 0으로 끝났다.

  ```bash
  ./build.sh --no-install --output-dir build/touchen-nxkey \
    --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX27.2.sdk
  ```

- 산출물: `build/touchen-nxkey/IPinsideMock.app`.
- `bash -n build.sh`, 시스템 Python 3.9.6의 소스 파싱·컴파일, `git diff --check` 통과.
  Python 코드는 컴파일만 했으며 모듈·서버 코드를 실행하지 않았다.
- `plutil -lint` 통과. 바이너리는 arm64이며 `LC_BUILD_VERSION`의 최소 macOS는 12.0이다.
  최소 버전의 macOS에서 실행한 결과를 의미하지 않는다.
- 세 버전 상수를 다운로드한 티머니 공개 설정과 정적으로 대조하여 일치를 확인했다.
- 기존 IPinside `createServerScript()`는 HEAD와 텍스트가 동일하다.
- Python 전용 서버의 소스와 앱 번들 리소스 SHA-256이 일치한다.
  `8179a79945a15955c33f03780dcc52962550bfb1e9836f8e433061bec8c03d98`
- 앱 실행 파일 SHA-256:
  `1446092e3bed17defc51c615c4c884cae5095ce922234c3120d1354a54c55439`
- `/Applications` 설치본, 키체인, 기존 인증서·개인 키와 캡처 데이터는 변경하지 않았다.
- 합성 시험 요청은 생성하지 않았고, 로컬 서버·로그인·결제를 실행하지 않았다.
- ego-browser 조사 공간 2는 페이지를 남기지 않고 정상 종료했다.
- 이 구현 검증 시점에는 Git 변경이 작업 트리에 있었으며 커밋·push는 하지 않았다.

## 사용자 확인과 릴리스 준비 (2026-10-31 기록)

- 개발 결과 전달 후 사용자가 티머니에서 정상 동작한다고 보고했다. 사용자가 실행한
  파일의 정확한 SHA, 브라우저 버전, 로그인 완료 여부와 종료 동작은 추가 수집하지 않았다.
- 사용자 실사용 확인과 에이전트의 정적 검사·빌드를 구분하여 v1.1.0 릴리스에 반영한다.
- 기존 정적 검사 제한을 새 실행 시험의 승인으로 확대하지 않는다. 릴리스 작업에서도
  인증서·개인 키 읽기, 서버 실행, 로그인·결제 시험은 하지 않는다.
- 기능 코드는 유지하고 버전 메타데이터를 1.1.0으로 갱신하며 MIT 라이선스를 앱 리소스에
  포함한다. 배포 ZIP은 Apple Silicon용이다.
- 최종 검증·배포 범위와 서명 상태는 [릴리스 기록](../docs/releases/v1.1.0.md)에 기록한다.
