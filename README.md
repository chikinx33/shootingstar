# 수호묘 특공대 (Purrtectors) — v12.14.0

집사가 돌보는 반려묘들이 자기 기체를 타고 동네 집을 지키는 Flutter 세로 슈팅 게임입니다. 전투 중 선택 성장·무기 강화/진화/궁극과 전투 밖 장비·병아리 성장을 결합합니다. 내부 id·저장소 이름은 호환 때문에 `shootingstar`를 유지합니다.

공개 웹: https://shootingstar-online.chikinx1.workers.dev

## 먼저 읽을 문서

- 작업 지침: `AGENTS.md`(Codex), `CLAUDE.md`(Claude Code)
- 게임 방향·현재 규칙: [docs/GAME_DIRECTION.md](docs/GAME_DIRECTION.md)
- UI·그림 규격(현재 그림 폴더 목록 포함): [docs/UI_DESIGN_SYSTEM.md](docs/UI_DESIGN_SYSTEM.md)
- 세계관·고양이·적: [docs/CONCEPT_GUARDIAN_CATS.md](docs/CONCEPT_GUARDIAN_CATS.md)
- 무기 성장: [docs/WEAPON_EVOLUTION_DESIGN.md](docs/WEAPON_EVOLUTION_DESIGN.md) · 적 탄막 근거: [docs/WING_FIGHTER_ENEMY_PATTERNS.md](docs/WING_FIGHTER_ENEMY_PATTERNS.md)
- 빠른 테스트·배포: [docs/FAST_WEB_TESTING.md](docs/FAST_WEB_TESTING.md)
- 계정·클라우드 저장·길드: [docs/ONLINE.md](docs/ONLINE.md) · 언어: [docs/LOCALIZATION.md](docs/LOCALIZATION.md)
- 출시·수익: [docs/STORE_RELEASE_CHECKLIST.md](docs/STORE_RELEASE_CHECKLIST.md), [docs/GOOGLE_PLAY_MONETIZATION_PLAN.md](docs/GOOGLE_PLAY_MONETIZATION_PLAN.md)

## 개발 중 빌드 원칙

게임이 완성될 때까지 Android APK 빌드를 실행하지 않습니다. 개발·검증은 Flutter 웹으로 진행합니다. 화면과 답변에는 `v12.14.0`처럼 버전명만 표시하고 `+빌드 번호`는 내부에만 둡니다.

## 실행

`PLAY_SHOOTINGSTAR.cmd` 또는 `python tools/play_web.py` → http://127.0.0.1:8787

```powershell
.\tools\run.ps1 test                                   # 버전·소스 계약만 빠르게
.\tools\run.ps1 quick-web                              # 정식 웹 빌드 + 320px 로비/출격 1회
.\tools\run.ps1 deploy-web -Version major.minor.patch+build
.\tools\run.ps1 test-full                              # 전체 분석+Flutter 회귀(필요할 때만)
python -m unittest discover -s tools -p test_guild_service.py -v
```

결제·광고는 아직 실제 ID·기기 검증 전이라 운영에서 꺼져 있습니다. 출시 전 필수 작업은 `docs/STORE_RELEASE_CHECKLIST.md`에서 추적합니다.
