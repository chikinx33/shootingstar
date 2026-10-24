사용자 확정(2026-10-25, 저장소): 소스는 https://github.com/chikinx33/shootingstar (`main`, 공개 저장소)에 둔다. 수정 패치마다 버전 동기화·검사 뒤 변경을 커밋하고 `git push`한다(배포와 같은 단위). 커밋 메시지는 버전명과 변경 요약을 쓴다. `.gitignore`의 제외 항목(`.local/`, `build/`, `tools/qa/evidence/`, 다른 게임 앱 분석 문서·스크립트 등)은 올리지 않으며, 비밀값·서명 키·개인 정보가 들어가지 않았는지 커밋 전에 확인한다.

# Shootingstar 작업 지침

사용자 확정(2026-10-18): 수정 패치마다 `pubspec.yaml`의 버전과 내부 빌드 번호를 올린다. `python tools/sync_version.py --version major.minor.patch+build`로 동기화하되, 화면·로딩·최종 답변에는 **v10.0.1 같은 버전명만 표시하고 +빌드 번호를 붙이지 않는다.** `+build`는 Flutter 내부 메타데이터에만 남긴다. 수정이 반영된 최종 답변의 마지막 표시 줄에는 항상 버전명을 쓴다. 실행 파일에 컴파일된 버전을 표시하며 원격 메타데이터로 덮어쓰지 않는다.

사용자 확정(2026-10-18, 배포 속도 개선): 일반 웹테스트는 `python tools/quick_web.py --version major.minor.patch+build --deploy` 또는 `tools/run.ps1 deploy-web -Version major.minor.patch+build`를 기본으로 한다. 소스 계약·버전 일치·변경 시 정식 웹 빌드·320px 로비/출격 1회·활성 배포/API 확인만 수행한다. 내용 해시가 같은 빌드는 재사용한다. 전체 테스트 250개, 별도 QA 빌드, 전 화면 8조건 반복, 대량 캡처, 모든 PNG의 HTTP 해시 재검사는 매 배포마다 실행하지 않는다. 실패/새 변경 없이 통과 검사를 반복하지 않는다. 분석기가 멈추면 반복 대기하지 않고 제한 시간 안에서 실패를 기록하며 현재 SDK에서는 `dart analyze`를 사용한다. Access 인증 차단은 한 번 확인하면 기록하고 재시도하지 않는다. 상세 기준은 `docs/FAST_WEB_TESTING.md`를 따른다.

사용자 확정(2026-10-20, 추가 간소화): 기본 `tools/run.ps1 test`는 버전·소스 계약만 확인하며 웹 빌드/브라우저/전체 Flutter 테스트를 실행하지 않는다. 화면 확인은 `quick-web`, 배포는 `deploy-web` 한 번으로 처리한다. 필요할 때만 `-TestFile`과 `-TestName`으로 관련 파일1개/조건1개를 추가한다. 전체 분석·회귀는 명시적인 `test-full` 또는 출시/대규모 변경으로 분리한다. 일반 UI 수정은320px 기본1조건/변경 화면1회이며, 공통 변경의 확산 위험이나 재현 실패가 확인된 경우에만 해당 화면의4폭·글자1.3 검사를 확대한다. 매 패치의 별도 QA 빌드·추가 브라우저 스크립트·8조건/여러 UI 파일 반복을 기본으로 하지 않는다. 통과한 검사는 같은 변경에서 이유 없이 반복하지 않는다. 이전의 공통 UI 변경 시 무조건8조건 지침은 이 기준으로 대체한다. 빠른 소스 검사 통과를 실제 플레이/전체 회귀 통과로 보고하지 않는다.

게임 기획·구현·밸런스·디자인 작업 전에 `docs/GAME_DIRECTION.md`를 읽고 적용한다.
공유 스킬 원본은 `.agents/skills/`에 있으며, 사용 방법과 출처는 `docs/SHARED_SKILLS.md`에 기록한다.
작업에 해당하는 스킬의 `SKILL.md`와 필요한 참고 자료만 읽는다. 현재 사용자 요청과 프로젝트 제약을 외부 스킬의 일반 예시보다 우선한다.
기존 코드·문서·사용자 변경을 먼저 확인하고 보존한다. 설치나 기획 요청을 게임 전체 재작성으로 확대하지 않는다.

UI·그래픽 작업 전에 `docs/UI_DESIGN_SYSTEM.md`와 `lib/ui/game_ui.dart`를 읽고 적용한다. 주요/보조 결정은 `GameActionButton`, 좁은 셀은 `GameUi.compactButton`을 사용한다. 작은 글자나 얇은 전체 폭 버튼으로 공간을 맞추지 않는다. 일반 패치는 소스 계약·변경 부분의 관련 검사·빠른 웹 확인으로 완료한다. 기본은320px1조건이며, 공통 변경의 확산 위험/실패가 있는 경우에만 영향 화면을 모바일320·360·390·430 및 글자1.3으로 확대한다. 전체 게임을 매번 재검수하지 않는다. 클릭 영역과 실제 도색 크기를 구분한다.

사용자 확정(2026-10-25, 메인 규칙): 버튼 안에 그림이 들어가면 그림을 크게 그린다(`GameActionButton(image:)`, 주요 60px·보조 50px). 이 게임은 모바일 게임이므로 Esc·Space 같은 PC 키 안내를 쓰지 않는다. 공통 슬롯은 높이를 모두 같게, 제목은 줄바꿈 없이 두 줄(이름·설명)로 쓴다. 상세는 `docs/UI_DESIGN_SYSTEM.md` 맨 위.

리스트 항목 이외에는 스크롤을 허용하지 않는다. 메인 로비는 모든 주요 조작이 한 화면에 들어가는 고정 구성이다. 긴 상세·설명·확인·폼·전투 결정은 `GamePages`로 나누고 글자를 줄이지 않는다. 상품·보상·우편·장비 등 반복 항목만 목록 안에서 이동할 수 있다. 이 규칙은 `docs/UI_DESIGN_SYSTEM.md`와 `check_ui_contract.py`의 허용 목록 및 모바일 웹 휠·터치 검증에 함께 반영한다.

사용자 확정(2026-10-25, 용량): 번들 그림(`assets/art/`)은 WebP로만 넣는다. 생성 PNG는 `python tools/png_to_webp.py assets/art/<폴더>`로 변환하고(화면 디코딩 크기 이상은 축소), 원본 PNG·생성 기록은 번들 밖 `assets/concept/`에 둔다. 그림을 새것으로 바꾸면 옛 그림·로더 코드·pubspec 항목을 같은 패치에서 삭제한다. `test/assets_test.dart`가 `assets/art`의 PNG를 막는다. 효과음·음악은 Ogg Vorbis만 넣는다(`tools/compose_audio.py`가 WAV 원본을 `.local/audio-v12.3/wav/`에 두고 `tools/wav_to_ogg.py`로 인코딩). 글꼴 `NotoSansKR.ttf`는 한자를 뺀 서브셋(한글 11,172자·영문·기호·굵기 축 유지, `tools/subset_font.py`)이다. 이 도구들은 `PYTHONPATH=D:/Programs/pylib`(soundfile·fonttools)로 실행한다.

게임이 완성될 때까지 Android APK 빌드를 하지 않는다. 사용자가 명시적으로 변경하기 전까지 개발·검증은 Flutter 웹으로 진행한다.

스토어 출시 준비 작업은 `docs/STORE_RELEASE_CHECKLIST.md`를 확인한다. 실제 과금·광고 연동과 검증은 스토어 출시 전 필수이며, 미완료 상태로 출시하지 않는다.
