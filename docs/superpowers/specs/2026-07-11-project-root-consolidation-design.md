# IPinside Mock Project Root Consolidation Design

## 목적

IPinside Mock의 소스, Git 메타데이터, 빌드 스크립트와 문서를
`/Users/raphael/Playground/ipinside-mock` 하나의 프로젝트 루트로 통합한다.
설치된 애플리케이션과 사용자별 런타임 데이터는 macOS 표준 위치에 유지한다.

## 현재 상태

- `/Users/raphael/ipinside-mock-repo`
  - GitHub `Raphael-KR/ipinside-mock`의 정식 Git 저장소다.
  - 작업 트리는 깨끗하고 `main`은 `origin/main`과 동기화되어 있다.
- `/Users/raphael/ipinside-mock`
  - 초기 실험용 서버, 시작·중지 스크립트, 인증서와 개인 키, 빌드 산출물이 섞여 있다.
  - 정식 저장소와 중복된 `main.swift`, `build.sh`, `generate_icon.swift`는 현재 동일하다.
- `/Applications/IPinsideMock.app`
  - 사용자가 실행하는 설치본이다.
- `/Users/raphael/Library/Application Support/IPinsideMock`
  - `captured.json`, `interezen.crt`, `interezen.key`를 보관하는 사용자별 런타임 디렉터리다.

## 최종 구조

프로젝트 파일은 다음 위치에만 둔다.

```text
/Users/raphael/Playground/ipinside-mock/
├── .git/
├── .gitignore
├── LICENSE
├── README.md
├── build.sh
├── generate_icon.swift
├── docs/
│   └── superpowers/
│       └── specs/
└── src/
    └── main.swift
```

다음 위치는 프로젝트 루트 밖에 그대로 유지한다.

```text
/Applications/IPinsideMock.app
/Users/raphael/Library/Application Support/IPinsideMock/
├── captured.json
├── interezen.crt
└── interezen.key
```

## 정리 전략

정식 Git 저장소를 새 프로젝트 루트로 승격한다. 기존 실험 폴더를 정식 저장소에
병합하지 않는다. 이 방식은 Git 이력과 원격 설정을 그대로 보존하고, 인증서와 개인
키가 실수로 Git 작업 트리에 들어오는 위험을 줄인다.

1. `/Users/raphael/Playground`의 기존 상태와 대상 경로 충돌 여부를 확인한다.
2. `/Users/raphael/ipinside-mock`을 같은 파일시스템의 임시 백업 경로로 이름 변경한다.
3. `/Users/raphael/ipinside-mock-repo`를
   `/Users/raphael/Playground/ipinside-mock`으로 이동한다.
4. 새 루트에서 빌드 경로와 아이콘 출력 경로를 수정한다.
5. 빌드, 설치, 실행, HTTPS 응답, 종료와 Git 상태를 검증한다.
6. 임시 백업에만 존재하는 파일 목록과 런타임 데이터 복사본을 확인한다.
7. 자동 검증 게이트를 모두 통과하고 승인된 수동 확인 검증 유예를 적용한 뒤 임시
   백업을 삭제한다.

각 이동은 이름 변경 또는 단일 디렉터리 이동으로 수행한다. 검증 완료 전에는 기존
실험 폴더의 내용을 개별 삭제하지 않는다.

## 빌드 경로 정합성

현재 정식 저장소의 `build.sh`는 존재하지 않는 `IPinsideMock/main.swift`를 참조한다.
새 구조에서는 `src/main.swift`를 컴파일하도록 수정한다.

현재 `generate_icon.swift`는 아이콘을
`/Users/raphael/ipinside-mock/AppIcon.icns`에 고정 출력한다. 새 구조에서는 스크립트가
실행된 프로젝트 루트의 `AppIcon.icns`를 생성하도록 변경한다. 빌드 스크립트는 해당
파일을 앱 번들의 `Contents/Resources`로 복사한다.

`IPinsideMock.app`, `AppIcon.icns`, 인증서, 개인 키와 캡처 데이터는 계속 Git에서
제외한다.

## 데이터 및 보안 경계

- `captured.json`, `interezen.crt`, `interezen.key`는
  `/Users/raphael/Library/Application Support/IPinsideMock`에서 이동하거나 수정하지 않는다.
- `/Users/raphael/ipinside-mock`에 남아 있는 인증서와 개인 키는 정식 프로젝트로
  복사하지 않는다.
- 정리 전후에 `git status --short`와 `git ls-files`를 확인해 비밀 파일이 추적되지
  않았음을 검증한다.
- 임시 백업은 로컬 검증을 위한 한시적 복구 지점이며 GitHub에 업로드하지 않는다.

## 검증 기준

정리는 아래 조건을 모두 만족해야 완료된다.

1. `/Users/raphael/Playground/ipinside-mock`에서 `git status --short --branch`가 정상이며
   `origin`이 `https://github.com/Raphael-KR/ipinside-mock.git`을 가리킨다.
2. `build.sh`가 새 루트에서 성공하고 `/Applications/IPinsideMock.app`을 갱신한다.
3. 앱을 실행하고 메뉴에서 서버를 시작하면 `127.0.0.1:21300`이 열린다.
4. `t=V` 요청이 `result: "I"`인 JSONP 응답을 반환한다.
5. 서버를 중지하거나 앱을 종료하면 포트 21300과 Python 자식 프로세스가 사라진다.
6. `/Users/raphael/Library/Application Support/IPinsideMock`의 세 런타임 파일이 그대로
   존재하며 체크섬이 정리 전과 같다.
7. 프로젝트 Git 인덱스에 `*.key`, `*.crt`, `captured.json`, `*.app`이 없다.
8. `/Users/raphael/ipinside-mock`과 `/Users/raphael/ipinside-mock-repo`가 최종적으로
   존재하지 않는다.

## 검증 유예 (Verification waiver)

통합 중에는 계정 인증이 필요하고 계정 상태를 변경할 수 있으므로 인증된 IBK 에이전트
확인 흐름을 다시 실행하지 않았다. 사용자는 이 확인을 통합 후 수동 인수 확인(manual
acceptance check)으로 취급하는 것을 명시적으로 승인했다.

백업 삭제는 성공한 로컬 루프백 HTTPS/JSONP 응답 검증, 성공한 프로세스 정리 검증,
변경되지 않은 `src/main.swift`, 변경되지 않은 런타임 데이터 체크섬, 그리고 사용자의
기존 성공 IBK 사용을 근거로 승인되었다. 이 유예는 이 통합 실행에만 적용되며, 인증된
IBK 흐름이 통과했다는 주장을 하지 않는다.

## 롤백

새 루트에서 검증이 실패하면 정식 저장소를 원래
`/Users/raphael/ipinside-mock-repo`로 되돌리고, 임시 백업을
`/Users/raphael/ipinside-mock`으로 복원한다. `/Applications/IPinsideMock.app`과
Application Support 데이터는 이동 대상이 아니므로 폴더 정리 롤백과 독립적이다.

## 범위 밖

- IPinside Mock 기능 변경
- 캡처 데이터 또는 인증서 형식 변경
- 앱 번들 식별자 변경
- 패키지 관리자나 DMG 설치 프로그램 추가
- `/Applications/IPinsideMock.app`을 프로젝트 폴더 안으로 이동
