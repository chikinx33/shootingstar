# 웹테스트 버전과 배포 규칙

2026-10-18 사용자 확정: 수정 패치마다 버전/빌드 번호를 올리고 랜딩(메인 로비) 화면 하단에서 육안으로 확인한다. 수정이 반영된 최종 답변의 마지막 표시 줄에도 반영 버전을 적는다. Codex와 Claude Code 모두 `AGENTS.md`의 같은 규칙을 따른다.

`pubspec.yaml`이 버전 원본이다. 예를 들어 `python tools/sync_version.py --version 10.0.1+17`로 올린다. 화면과 답변에는 **v10.0.1**만 표시한다. `+17`은 Flutter 내부 빌드 번호이며 사용자에게 표시하지 않는다. 이 도구는 `lib/app_version.dart`, 로딩 화면의 버전, Worker의 `APP_VERSION`을 동기화하며 UI 계약 검사는 `--check`로 불일치를 차단한다.

메인 로비의 `BuildVersionFooter`는 하단 탭 바로 아래, 안전 영역 안에 버전을 표시한다. 글자 14px와 시스템 글자 확대를 유지한다. 로비 전체를 스크롤하지 않으며 필요한 공간은 기존 가변 그림 영역이 양보한다. 버전 문자열은 게임 JavaScript에 컴파일하므로 이전 파일이 캐시에 남으면 이전 버전을 보여 준다. 원격 `version.json`을 가져와 오래된 실행 파일 위에 새 버전을 표시하지 않는다. 로딩 화면의 버전은 게임 첫 프레임 이후 제거된다.

정식 배포 순서:

1. 버전/빌드 번호를 올리고 `python tools/sync_version.py --check`를 실행한다.
2. 기본 명령 `python tools/quick_web.py --deploy`를 사용한다. 버전 변경도 함께 하려면 `--version 10.0.1+17`을 붙인다. 변경 범위에 필요한 검사만 `--analyze`, `--test test/관련_test.dart`로 추가한다. 전체 테스트·전 화면 검수는 매 배포마다 실행하지 않는다.
3. 도구가 정식 `lib/main.dart`만 웹 release 빌드하고 320px에서 로비 버전·실제 출격을 한 번 확인한다. 입력/출력 내용 해시가 같으면 빌드를 재사용한다. QA/글자 확대 진입점과 Android APK는 기본 경로에서 빌드하지 않는다.
4. 배포 시 npm predeploy가 버전·최신 빌드 여부를 한 번 검사한다. `verify_web_release.py`를 직전에 별도로 반복 실행할 필요는 없다.
5. 활성 Worker 100%와 API health를 확인한다. 공개 파일은 버전/JS를 한 번 확인하며 Access 로그인으로 차단되면 기록하고 멈춘다. 모든 PNG의 HTTP 해시와 공개 브라우저 재시도를 반복하지 않는다. 로컬 화면 확인을 공개 화면 확인으로 보고하지 않는다. 확대 검증 조건은 `FAST_WEB_TESTING.md`를 따른다.

V10 배포의 별도 증거는 `tools/qa/evidence/v10-release/`에 둔다. 기존 `game-v10/`의 2026-10-18 새벽 결과는 당시 로컬 빌드의 역사적 증거로 보존한다.
