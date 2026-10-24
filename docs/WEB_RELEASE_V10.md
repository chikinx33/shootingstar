# V10 웹테스트 배포 — v10.0.0+16

2026-10-18 15:27 KST, 사용자 요청으로 최신 V10을 기존 Cloudflare 웹테스트에 배포했다. 이전 6.1.0+15 배포를 교체했으며 정식 진입점은 `lib/main.dart`다. 로컬 게임은 <http://127.0.0.1:8797/>, 공개 웹은 <https://shootingstar-online.chikinx1.workers.dev>다.

## 변경

- 버전 원본 `pubspec.yaml`을 10.0.0+16으로 올렸다. `tools/sync_version.py`가 컴파일할 `AppVersion`, 로딩 HTML, Worker 버전을 같은 값으로 동기화한다.
- 메인 로비 하단 탭 아래에 `BuildVersionFooter`로 **v10.0.0+16**을 표시한다. 14px 글자와 시스템 글자 확대·안전 영역을 유지한다. 목록 밖 스크롤을 추가하지 않았다. 원격 버전 파일로 실행 파일의 버전을 덮어쓰지 않는다.
- `tools/run.ps1`, UI 계약 검사, `npm run deploy`의 predeploy에 버전 검사를 연결했다. 배포 검사는 메타데이터/HTML/컴파일된 버전 문자열과 소스 변경 시간을 확인한다.
- 이후 수정 패치의 버전/빌드 증가, 로비 표시, 최종 답변 마지막 버전 표기 규칙을 공통 `AGENTS.md`에 기록했다. Claude Code도 동일한 지침을 읽는다.
- 기존 Dart 66파일 중 변경은 로비에 푸터를 넣은 `home.dart` 하나다. 새 파일은 버전 상수와 푸터 두 개이며, 전투 규칙·모델·콘텐츠 ID·저장 스키마는 그대로다.

## 검증

| 검증 | 결과 |
|---|---|
| 버전 동기화 / 정식 웹 배포 전 검사 | 통과 |
| UI 계약 검사 | 29파일 통과 |
| 정적 분석 | `dart analyze lib`, `test`, `tools/qa` 모두 문제 없음 |
| Flutter 전체 테스트 | 250개 통과, 경고/예외 없음 |
| 모바일 실제 로비 → 출격 → 정지/재개/터치/재실행 | 320/360/390/430 × 글자 1.0/1.3, 8조건 통과 |
| 하단 버전 | 위 8조건에서 화면 안에 보이며 휠/터치 후 위치 고정 |
| 공통 메뉴·전투 결정 | 17개 그룹 통과 |
| 보급·시즌·우편·수집품 | 8조건 통과, 반복 수령 방지/저장 보존 |
| V10 원본 PNG | 51/51 원본·알파·안전 여백 검사 통과 |
| 실제 로컬 제공 파일 | 정식 게임/별도 QA 서버의 코드·메타데이터·PNG 142개 해시 일치 |
| 최종 캡처 | 통과한 세 묶음의 PNG 241장 |

현재 SDK의 `flutter analyze`는 LSP 초기화/분석 완료 응답을 기다리며 두 번 멈췄다. 해당 작업의 분석 프로세스만 종료하고, 같은 SDK의 `dart analyze`로 소스·테스트·QA를 각각 검사했다. Flutter 테스트와 두 웹 빌드는 정상 완료됐다. SDK를 변경하지 않았다.

첫 공통 메뉴 검사는 한 Chrome 프로세스에서 많은 CanvasKit 컨텍스트를 반복한 뒤 새 화면 초기화가 멈췄다. 검증 도구를 각 시나리오마다 새 Chrome으로 실행하도록 고친 후 17개 그룹이 모두 통과했다. `ui/`의 부분 결과는 완료 근거에서 제외하며 `ui-final/`만 최종 통과 자료다. 실제 글자 확대는 별도 QA 진입점의 Flutter TextScaler다. QA 진입점은 공개 배포하지 않았다.

## 공개 배포 근거와 제한

- Worker 버전: `3451e1d2-7243-4b71-a853-c4de5d7f5284`
- 활성 배포: `f62a6e7c-a04c-4a11-8e48-58897667aea8`, 해당 버전에 트래픽 100%
- 태그: `v10.0.0-16`; 배포 메시지에 `v10.0.0+16` 기록
- 업로드: 새 정적 파일 113개 성공, 기존 일치 파일 65개 재사용
- 공개 `/api/health`: HTTP 200, `ok:true`, `version:10.0.0`, `storage:D1`
- 기존 D1 ID와 Worker 바인딩 유지. DB 초기화·원격 마이그레이션·Android APK 빌드를 하지 않았다.
- 정식 로컬/로컬 제공 JS SHA-256: `391efea0ebe1bfcbec87bf9f2f2f9144055a78473b5b5f68a92dd26c6ba175e6`

공개 `/`, `/version.json`, `/main.dart.js`, 새 PNG는 Cloudflare Access 로그인으로 이동한다. 반환된 HTML 200은 게임/그림 성공 응답으로 계산하지 않았다. 연결된 인증 브라우저나 기존 Access 클라이언트 자격이 없어 **공개 정적 파일 해시 일치와 인증 후 공개 화면/조작은 직접 확인하지 못했다.** 로그인 보호는 변경하지 않았다. 로컬 화면의 정상 동작과 실제 Cloudflare 배포/API 확인을 공개 브라우저 확인으로 혼동하지 않는다. 공개 접속자는 정상 로그인 후 메인 하단의 **v10.0.0+16**으로 확인한다.

집계: `tools/qa/evidence/v10-release/final-validation.json`. 공개 응답: `public-check.json`, 활성 배포: `deployments.json`, 버전/바인딩: `worker-version.json`, 로컬 파일 해시: `runtime-hashes.json`, 소스 보존: `source-proof.json`. 검사·빌드·배포 로그는 같은 묶음의 `checks/`에 보존했다.

대표 화면: [320px·글자 130%](../tools/qa/evidence/v10-release/game/main-320-scale-1.3.png), [390px](../tools/qa/evidence/v10-release/game/main-390-scale-1.png), [430px·글자 130%](../tools/qa/evidence/v10-release/game/main-430-scale-1.3.png).
