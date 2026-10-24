# Codex / Claude Code 공유 스킬

2026-10-22 v10.0.67: 기존 roguelike-game-designer의 전투 가독성/의도적인 장착 선택 원칙을 적용했다.3무기×4위치의 실제 장착 UI·이동·공격을 독립 웹 프로필로 비교하고, 그림/포구/발사 섬광/미사일 교대·낙하/드론 조준의 불일치를 수정했다. 현재 브라우저 직접 연결 부재와 자동 플레이·모델 검사의 증거 범위를 구분한다. 외부 이미지 생성/유료 호출/스킬 변경 없음.

2026-10-21 v10.0.66: 공유 roguelike-game-designer를 적용해 사용자 제공 단일 Loadout/위치별 선택/런 성장 구분을 구현했다. `F:/Download/ship-module`의 설계서와3개 콘셉트는 구조 참고이며 최종 아트가 아님을 확인했다. 유일 정본과 이전15슬롯 폐기를 우선하고 Flutter Canvas 본체/소켓/파츠 레이어를 분리했다. 이미지 생성·유료 호출·외부 스킬 설치는 하지 않았다. `V66_SHIP_MODULE_SYSTEM.md` 참고.

2026-10-21 v10.0.65: 기존 roguelike-game-designer의 시각적 식별/의도적인 장비 선택 원칙을 적용해 모든 슬롯을 공개하고 겹친 부품을 이름·그림으로 고르게 했다. 기체 원본/기하/전투 기능을 교체하지 않으며 기존 UI 부품을 재사용한다.

2026-10-21 v10.0.64: 기존 roguelike-game-designer의 시각적 식별/장비 선택 원칙을 유지하며 원본 기체3종의 실제 실루엣을 확인한 후 장착점과 비율을 교정했다. 새 이미지 생성 없이 기존 PNG, 실제 장착 사각형, 공통 화면 변환을 사용한다.

2026-10-21 v10.0.63: 공유 roguelike-game-designer의 단계별 정보 공개/장비 선택 지침으로 슬롯→보유→특성→장착을 연결했다. 다른 역할을 임의 전투력으로 단정하지 않고 실제 공통 기본 수치/고유 효과를 분리해 비교한다. 기존 PNG를 코드로 합성하고 부품 레일 제거/추종을 구현해 신규 이미지 생성은 사용하지 않았다.

2026-10-21 v10.0.62: `game-balance`와 `roguelike-game-designer`의 전투 페이싱·적 조합·런타임 공정성 지침으로 수집/성장/보스/회피의 전후 시뮬레이션을 연결했다. `~/.agents/skills/reverse-engineer-anything/SKILL.md`로 공급된 XAPK를 REA에 열어 식별하고 UnityPy로 선택 리소스4개를 정적으로 확인했다. 원작 수치 미복구 범위를 명시했으며 게임 수치는 독립 설계다. `V62_RUN_FLOW_REBUILD.md` 참고.

2026-10-20 v10.0.50: 공유 roguelike-game-designer와 item-content-design/runtime-performance-fairness/subgenre-guide로 부품 역할/표적/이관 경계를 설계하고 space-shooter는 탑뷰 슈터 장착/공통 조립 참고로만 사용했다. Three.js/assetgen으로 교체하지 않았다. 런타임 imagegen 스킬과 built-in 도구로 새 본체3/부품 아틀라스/통합 시안을 만들고 벡터 첫 결과를 재제작했다. 특수 능력은 문서 기획뿐이다. MODULAR_AIRCRAFT_DESIGN.md에 정본·출처·검증 범위를 기록한다.

2026-10-20 v10.0.36은 공유 `roguelike-game-designer/SKILL.md`와 `references/runtime-performance-fairness.md`로 반복음/필수 알림·지연/대기열 예산을 분리하고, 실제 웹 보스전·정지·저장/재개·귀환을 비교했다. 관측용 출력 신호와 사람/Android 청취를 구분한다. 원본/설치·출처는 변경하지 않았으며 근거는 `V36_AUDIO_MIX_REVIEW.md`다.

2026-10-20 v10.0.35는 공유 `roguelike-game-designer/SKILL.md`와 `references/runtime-performance-fairness.md`의 음향/필수 피드백 예산을 적용했다. 반복 발사/회수와 중요한 알림 채널·벽시계·대기열/재생기 상한을 구분하며 전투 판정/저장을 음향에 종속시키지 않는다. 원본·출처/설치는 변경하지 않았다. 자체 합성 음원·검증 범위는 `V35_AUDIO_OVERHAUL.md`에 기록한다.

설치일: 2026-10-15. 프로젝트 범위 설치이며 전역 스킬은 변경하지 않았다.

## 경로와 사용

- 원본: `F:\NKW\App\Shootingstar\.agents\skills\<스킬명>`
- Claude Code: `F:\NKW\App\Shootingstar\.claude\skills\<스킬명>` → 해당 원본으로 연결되는 Windows 디렉터리 정션
- Codex 진입 지침: `AGENTS.md`
- Claude Code 진입 지침: `CLAUDE.md`
- 공통 방향 및 엔진별 적용 범위: `docs/GAME_DIRECTION.md`
- UI 작업 공통 규격: `docs/UI_DESIGN_SYSTEM.md`, 구현 토큰: `lib/ui/game_ui.dart` (스킬 예시보다 프로젝트 규격을 우선)

스킬 검색 목록에 아직 나타나지 않으면 새 세션에서 확인한다. 검색과 무관하게 프로젝트 지침의 원본 경로로 `SKILL.md`를 직접 읽어 사용할 수 있다.
`space-shooter` 원본은 `disable-model-invocation: true`를 선언한다. 자동 호출에 의존하지 말고 사용자가 이름을 지정하거나 해당 파일을 명시적으로 읽는 방식으로 사용한다.

요청 예: “roguelike-game-designer를 사용해 현재 무기 진화 구조를 검토해 줘. docs/GAME_DIRECTION.md 기준을 적용해.”

## 출처와 갱신

| 스킬 | 공개 원본 |
|---|---|
| roguelike-game-designer | https://github.com/Hanjo92/roguelike-game-designer-skill |
| space-shooter | https://github.com/shipshitgames/skills/tree/master/skills/space-shooter |
| game-balance | https://github.com/rbergman/dark-matter-marketplace/tree/main/plugins/game-dev/skills/game-balance |

설치한 정확한 커밋과 원본 경로는 `.agents/skills/sources.json`에 기록한다. 스킬 폴더는 원본과 함께 제공되는 참고 자료를 포함한다. 프로젝트 전용 해석은 공통 문서에 두고 외부 스킬 원문은 유지한다.

`game-balance` 끝의 다른 스킬 안내는 상위 컬렉션의 선택적 연계다. 그 컬렉션 전체를 설치한 것은 아니므로 미설치 항목을 사용할 수 있다고 가정하지 않는다.

갱신할 때는 원본 변경 내용을 검토하고 커밋 기록과 파일 해시를 함께 갱신한다. 자동 업데이트하지 않는다.
정션은 이 Windows PC의 절대 경로를 가리킨다. 프로젝트를 다른 경로 또는 PC로 옮기면 `.claude/skills` 연결을 새 원본 위치로 다시 만들어야 한다.

## 2026-10-18 Wing Fighter 시스템 분석에 사용한 스킬

`reverse-engineer-anything`의 `~/.agents/skills/reverse-engineer-anything/SKILL.md`와 Android/managed 참고 자료를 적용해 사용자 제공 XAPK를 정적으로 분석했다. REA 도구의 파일 식별·Android 메타데이터·CIL 관찰과 Unity 자산 파싱을 구분하고, 스킬의 독립 조사 분담 지침에 따라 현재 코드·언어/장비 연결·Lua 성장 규칙을 분담했다. 대상 코드는 실행하지 않았다. 공유 `roguelike-game-designer`는 기존 성장·진화와 융합안을 설계하는 데 사용했다. 결과는 `WING_FIGHTER_ANALYSIS.md`, `WING_FIGHTER_INTEGRATION.md`, 분석 원문은 `.local/reference/wing-fighter-1.7.850/`에 둔다. 공유 스킬 원문과 설치 구성을 변경하지 않았다.

## 2026-10-18 V10 그래픽 작업에 사용한 런타임 스킬

`imagegen`은 프로젝트 공유 스킬과 별도로 Codex 런타임이 제공하는 내장 스킬이다. 이번 작업에서는 `D:/Programs/codex-home/skills/.system/imagegen/SKILL.md`를 읽고 내장 `image_gen` 도구로 독립 PNG를 생성했다. 외부 API 키/이미지 생성 CLI는 사용하지 않았다. 원본 프롬프트·파일 경로는 `assets/art/game_v10/generation.json`, 반영 범위·원본 비교·검증은 `docs/GAME_V10_IMPLEMENTATION.md`에 기록한다. `.agents/skills/`의 공유 스킬 원문과 설치 출처는 변경하지 않았다.


## 2026-10-18 V16 미술 재작업

런타임 `imagegen` 스킬을 사용해 내장 image_gen으로 기체3·배경·핵심 메뉴4개의 독립 PNG를 제작했다. 도전 배지는 프레임 밖 날개 끝을 교정하는1회 재시도를 포함한다. 제작 원본/프롬프트는 `assets/art/refit_v16/generation.json`과 `refinement.json`, 분석/구현은 `docs/V16_VISUAL_REFIT.md`에 둔다. 외부 API/CLI와 공유 스킬 원본은 변경하지 않았다.

## 2026-10-19 세계 전투/이어하기 적용

공유 `.agents/skills/roguelike-game-designer/SKILL.md`와 `enemy-encounter-design.md`, `runtime-performance-fairness.md`, `accessibility-difficulty.md`를 읽고 세계별 대응·필수 예고와 도색/판정 공유·저장/종료의 진행/보상 경계를 설계했다. Flutter와 기존 입력 해제5%를 유지하며 스킬의 다른 엔진 예시는 가져오지 않았다. 원본/출처 구성은 변경하지 않았다. 구현·근거·남은 검사는 `V24_WORLD_COMBAT_AND_RESUME.md`다.

## 2026-10-19 완성도 후속 작업

공유 `roguelike-game-designer`로 출격 전 목표와 실패 뒤 다음 행동을 연결하고, `game-balance/SKILL.md`로 무기10종의 같은 조건·거리별 피해와 진화 전후를 비교했다. 고정 표적 DPS를 이용자 승률이나 전체 효용으로 간주하지 않았다. 근접 무장의 실제 선체 겹침 판정 오류를 고치고, 단일 수치 순위만으로 피해/가격을 일괄 변경하지 않았다. `runtime-performance-fairness.md`에 따라 액터·체크포인트 크기·프레임과 시뮬레이션 시간을 분리해 기록한다. 소스/실행 근거는 `V25_COMPLETION_FLOW.md`, `V26_ACCOUNT_AND_COMBAT_QUALITY.md`다. 스킬 원문/설치 출처는 변경하지 않았다.

v10.0.28의 Google Play 수익 모델 초안에도 공유 `game-balance`를 적용했다. 실제 `RunRewards`·연구·보급 교환 비용과 제안 광고 보상을 비교하고, 유료 권리를 클라이언트의 무료 재화와 분리하도록 설계했다. 제안 가격/광고 수치는 확정이나 이용자 검증 결과가 아니며 게임에 적용하지 않았다. 구체안과 공식 구현 출처는 `GOOGLE_PLAY_MONETIZATION_PLAN.md`다.

2026-10-20 사용자가 해당 초안대로 진행하도록 승인했다. v10.0.29는 기존 수치와 무료 진행을 보존하며 외형·구매 검증/복원/회수·선택 광고20 C의 서버 원장과 상한을 구현했다. 공유 스킬 원문은 수정하지 않았다. 검증 출처는 `V29_COMMERCE_FOUNDATION.md`이며 실제 ID/Android 검증과 격리 시험을 구분한다.

2026-10-20 v10.0.30~32는 공유 `roguelike-game-designer/SKILL.md`와 `references/accessibility-difficulty.md`를 적용해 직접 진행 백업·확인 복원·실패 시 원본 보호와 조작 반응 거리/손떨림 범위/좌우 능력 배치를 구현했다. 기본 조작·전투 난도·보상을 보존하고 UI/입력/저장 검증을 분리했다. 원본 스킬은 변경하지 않았으며 결과는 `V30_RECOVERY_AND_CONTROLS.md`다.

2026-10-20 v10.0.33은 공유 `game-balance/SKILL.md`, `roguelike-game-designer/SKILL.md`와 `enemy-encounter-design.md`, `run-architecture-pacing.md`, `runtime-performance-fairness.md`를 적용했다. 같은 조건의 최종 보스120행/실제 경험치와 선택을 사용하는36행 자동 출격을 측정하고, 중복 위협 배율·기뢰 원인·최종 완주 안내를 교정했다. 자동 조작과 큰 선체의 피해 분리 시험을 인간 난도 승인으로 간주하지 않았으며, 근거 없는 무기 일괄 하향은 하지 않았다. 원본/출처 구성은 유지한다. `V33_LATE_COMBAT_REVIEW.md` 참고.

2026-10-20 v10.0.34는 공유 `roguelike-game-designer/SKILL.md`와 `references/runtime-performance-fairness.md`를 적용해 장시간 상태/저장 상한과 필수 경험치 보존, 캐시 그림의 픽셀/상태 비교, 같은 렌더 조건의 CPU 감속 비교와 정식 앱 흐름을 검사했다. 시뮬레이션 시간·실제 웹 시간·대상 휴대폰 증거를 구분한다. 그림을 생략하거나 무기 수치를 줄이지 않고 복원 결함과 반복 그리기 비용을 교정했다. 원본 스킬/출처 구성은 유지한다. `V34_ENDURANCE_AND_FLOW.md` 참고.


2026-10-20 v10.0.51은 game-balance와 roguelike-game-designer의 item-content-design/runtime-performance-fairness 지침을 적용했다. 승인된 탑뷰 본체/부품을 실전 편성으로 전환하고 5개 발사 역할·공중/지상 판정·비공격 지원·이관/이어하기를 구현했다. 실제 보유/투자를 보존하며 8분 자동 전투와 실제 웹 조작을 사람의 난도 승인과 구별한다. 수치·검증·범위는 V51_MODULAR_LIVE.md가 정본이며 스킬 원문은 변경하지 않았다.

2026-10-22 v10.0.68은 공유 game-balance와 roguelike-game-designer를 적용해 기존 12개 무기/위치 선택의 범위·방향·보스·요격 효용을 비교했다. 폭발 중복만 수정한 중간값과 대안 보강 후 값을 분리했으며 기존 투자/위치/보스 단계는 유지한다. 단일 표적 DPS를 전체 편성의 우위로 확대하지 않고 4슬롯 편성을 별도로 검증했다. 수치/근거/자동 시험의 한계는 V68_MODULE_BALANCE.md에 기록한다. 스킬 원문/출처 구성은 변경하지 않았다.

2026-10-22 v10.0.69는 공유 roguelike-game-designer의 run-architecture-pacing/enemy-encounter-design과 game-balance를 적용했다. 무적 표적DPS와 정상 선체의 실제 XP/성장/보스 완주, 적정 투자와 과성장 재도전의 방치 예외를 구분하고 회복의 중복 성장·주포 단계 역전을 고쳤다. 실제 새 계정 구성은 Profile에서 별도로 확인했다. V69_NATURAL_RUN_REVIEW.md에 자동 조종/실시간 웹의 증거와 실패를 기록하며 스킬 원본/출처 구성은 변경하지 않았다.
