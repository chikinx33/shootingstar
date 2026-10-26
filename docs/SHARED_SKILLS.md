# Codex / Claude Code 공유 스킬

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

적용 원칙: 스킬로 만든 수치·시뮬레이션은 사람의 난이도 평가로 간주하지 않는다. 고정 표적 DPS를 전체 편성의 우위로 확대하지 않는다. 스킬 원문과 설치 구성은 작업 중에 수정하지 않는다.

## 그 밖에 쓰는 스킬

- 그림 생성·편집: `codex-imagegen`(전역 지침). 그림은 래스터로 만들고 `UI_DESIGN_SYSTEM.md`의 '현재 그림만 사용' 규칙을 따른다. 유료 생성 도구는 사용자 승인 없이 쓰지 않는다.
- 참고 앱 정적 분석: `reverse-engineer-anything`. 대상 코드는 실행하지 않으며, 탄막 분석 결과는 `WING_FIGHTER_ENEMY_PATTERNS.md`에 둔다. 원작 디자인·자산은 가져오지 않는다.

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
