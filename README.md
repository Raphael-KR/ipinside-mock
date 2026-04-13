# IPinside Mock

**IPinside 없이 한국 인터넷뱅킹을 이용하기 위한 macOS 메뉴바 앱**

한국의 은행 웹사이트는 로그인 시 [IPinside LWS Agent](https://palant.info/2023/01/25/ipinside-koreas-mandatory-spyware/)를 필수로 요구합니다. IPinside는 사용자의 하드웨어 정보, 실행 중인 프로세스 목록, 네트워크 정보 등을 광범위하게 수집하며, [심각한 보안 취약점](https://palant.info/2023/01/25/ipinside-koreas-mandatory-spyware/)이 존재합니다.

이 앱은 IPinside의 응답을 한 번 캡처한 뒤, 로컬 HTTPS 서버에서 해당 응답을 재전송(replay)합니다. IPinside를 설치하지 않고도 인터넷뱅킹을 이용할 수 있습니다.

## IPinside의 문제점

Wladimir Palant(AdBlock Plus 개발자)의 [분석](https://palant.info/2023/01/25/ipinside-koreas-mandatory-spyware/)에 따르면:

- **과도한 정보 수집**: 하드드라이브 시리얼, MAC 주소, 실행 프로세스, CPU 정보 등
- **취약한 암호화**: wdata는 320비트 RSA (노트북에서 약 2시간 반 만에 크래킹 가능)
- **타임스탬프/챌린지 없음**: 리플레이 공격이 가능하여, 사기 방지 효과도 의문
- **구식 OpenSSL**: 지원 종료된 OpenSSL 1.0.1j 사용
- **모든 웹사이트가 접근 가능**: 어떤 사이트든 사용자 시스템 정보를 요청 가능

## 작동 원리

1. **최초 1회**: IPinside를 설치하고 앱이 응답 데이터를 캡처
2. **이후**: `https://127.0.0.1:21300`에서 캡처된 응답을 반환하는 HTTPS 서버 실행
3. 은행 웹사이트의 JavaScript가 이 서버에 요청하면 유효한 응답을 받음
4. **IPinside 삭제 후에도** 정상 작동

이 앱은 IPinside의 기술(시스템 정보 수집, 암호화 등)을 구현하지 않습니다. 단순히 이전에 수집된 응답을 재전송할 뿐입니다.

## 설치

### 요구사항

- macOS 12.0 이상
- Swift 5.5 이상 (`xcode-select --install`)
- Python 3 (macOS 기본 포함)

### 빌드

```bash
git clone https://github.com/Raphael-KR/ipinside-mock.git
cd ipinside-mock
chmod +x build.sh
./build.sh
```

`/Applications/IPinsideMock.app`에 설치됩니다.

### 초기 설정

앱을 처음 실행하면 셋업 화면이 나타납니다:

1. **IPinside 설치** - 은행 사이트의 보안프로그램 설치 페이지에서 다운로드
2. **인증서 복사** - 관리자 비밀번호 입력 (1회)
3. **응답 캡처** - 자동으로 진행
4. **IPinside 삭제** - 더 이상 필요 없습니다

## 사용법

메뉴바의 **IP** 아이콘을 클릭하세요:

| 아이콘 색상 | 상태 |
|------------|------|
| 주황색 | 초기 설정 필요 |
| 회색 | 서버 꺼짐 |
| 초록색 | 서버 켜짐 |

- **서버 시작** → 인터넷뱅킹 이용
- **서버 중지** → 사용 완료 후
- **데이터 재캡처** → IP 변경 등의 경우

### 로그인 항목 등록 (선택)

시스템 설정 → 일반 → 로그인 항목에 IPinside Mock을 추가하면 부팅 시 자동 실행됩니다.

## 호환 은행

IBK 기업은행에서 테스트되었습니다. IPinside LWS Agent를 사용하는 다른 은행에서도 동일하게 작동할 것으로 예상됩니다.

작동 확인된 은행이 있으면 Issue로 알려주세요.

## FAQ

### 보안에 문제가 없나요?

이 앱은 한 번 캡처된 고정 응답만 반환합니다. IPinside처럼 시스템 정보를 실시간으로 수집하거나 외부로 전송하지 않습니다. 오히려 IPinside를 설치하지 않음으로써 [알려진 보안 취약점](https://palant.info/2023/01/25/ipinside-koreas-mandatory-spyware/)으로부터 시스템을 보호합니다.

### 캡처된 데이터에 개인정보가 포함되나요?

네. wdata/ndata/udata에는 MAC 주소, 디스크 시리얼, IP 주소 등이 암호화되어 있습니다. 이 데이터는 `~/Library/Application Support/IPinsideMock/captured.json`에 로컬 저장되며, 앱 외부로 전송되지 않습니다. 소스 코드에 개인 데이터는 포함되어 있지 않습니다.

### 리플레이가 왜 가능한가요?

IPinside 프로토콜에 타임스탬프, nonce, challenge-handshake 등의 재전송 방지 메커니즘이 없기 때문입니다. 이는 Palant의 분석에서 지적된 설계 결함입니다.

## 면책 조항

이 소프트웨어는 **보안 연구 및 개인 프라이버시 보호 목적**으로 제작되었습니다.

- 이 앱은 IPinside의 기술을 구현하지 않으며, 특허 기술을 실시하지 않습니다
- 사용에 따른 모든 책임은 사용자에게 있습니다
- 은행 이용약관에 따라 서비스 이용이 제한될 수 있습니다
- 이 프로젝트는 Interezen 또는 어떤 금융기관과도 관련이 없습니다

## 기여 (Contributing)

다른 OS(Windows, Linux) 포팅, 추가 은행 호환 테스트, 버그 리포트 등 모든 기여를 환영합니다.

- **다른 OS 포팅**: IPinside의 로컬 서버 프로토콜은 OS와 무관하게 동일합니다. `127.0.0.1:21300`에서 HTTPS JSONP 응답을 반환하는 서버만 구현하면 됩니다.
- **은행 호환 테스트**: 작동 확인된 은행이 있으면 Issue로 알려주세요.
- **버그 리포트**: Issue를 열어주세요.
- **PR**: Fork 후 PR을 보내주시면 검토하겠습니다.

## 참고 자료

- [IPinside: Korea's mandatory spyware](https://palant.info/2023/01/25/ipinside-koreas-mandatory-spyware/) - Wladimir Palant의 기술 분석
- [South Korea's online security dead end](https://palant.info/2023/01/02/south-koreas-online-security-dead-end/) - 한국 온라인 보안의 구조적 문제

## 라이선스

[MIT License](LICENSE)
