# Wing Fighter 1.7.850 적 공격 패턴 분석 (정적 분석)

조사일: 2026-10-25. 대상: `F:\Download\ETC\Wing+Fighter_1.7.850_APKPure.xapk` (Unity IL2CPP, `com.minigame.wszj.android.gp`).
범위: 일반 적, 중간 보스(엘리트), 스테이지 보스의 탄막 패턴. 플레이어 쪽 시스템은 다루지 않는다.
방법: OBB 안의 Unity 번들을 UnityPy로 읽었다(타입트리가 남아 있음). 게임은 실행하지 않았고 서버에도 접속하지 않았다. 그림은 복사하지 않았고, 숫자와 동작 방식만 가져왔다.

표기:
- **[관찰]** 데이터/에셋에서 직접 읽은 값
- **[추론]** 필드 이름·값의 조합·여러 사례의 일관성으로 해석한 내용. 네이티브 C# 코드(IL2CPP)는 디컴파일하지 않았다.

---

## 0. 한눈에 보기

| 항목 | 결과 |
|---|---|
| 탄막이 정의된 곳 | OBB의 `danmakudata` 번들. `EmittingSystemPreset` ScriptableObject 691개, 그중 플레이어·드론·장비용을 뺀 적 프리셋 343개 [관찰] |
| 적이 탄막을 쓰는 방식 | `battleunits` 번들의 적 프리팹 322개. 루트 `SkyObject`/`LandObject`/`LandLoopObject` → `m_UnitSteps`(단계) → `BattleEntity`(부위, HP id) → `EmittingSystem`(발사구) → `m_preset`(탄막 프리셋) [관찰] |
| 프리팹과 연결 확인된 적 프리셋 | 275개 (나머지 68개는 미사용·이벤트용·하위 발사체용으로 보임) |
| 일반 적 | 공중 잡몹 6종은 **총을 쏘지 않는다**(충돌만). 탄을 쏘는 것은 지상 포탑·전차·함선 약 55종과 소형 헬기 [관찰] |
| 중간 보스 | `unitType=3`. 헬기 계열 7종(HP 5배), `Sboss_*` 엘리트 8종(HP 30배), smallboss 1~5, CloudMaster [관찰] |
| 스테이지 보스 | 메인 스테이지 보스 11종 + 이벤트 모드 보스 6종. 모두 **부위 파괴로 단계가 넘어간다**(HP% 기준이 아님) [관찰/추론] |
| 신뢰도 | 탄 수·각도·속도·간격·지연·예고 시간은 **높음**(직접 읽음). 큐 실행 의미(병렬/순차), 수명 값의 단위, 화면 환산은 **중간**(추론). 회전 발사구의 실제 회전량은 일부만 확인(Legacy 애니메이션 2건) |

---

## 1. 근거 위치와 복원 방법

### 1.1 원본 위치 (OBB `main.2164813.com.minigame.wszj.android.gp.obb` 내부)

| 내용 | 번들 경로 (`assets/aa/Android/…`) | 클래스/형식 |
|---|---|---|
| 탄막 프리셋 | `danmakudata_assets_all_f8c3adce81098d0e2aad37b651c11179.bundle` | `FlightShooting.BattleCore.EmittingSystemPreset` ×691 |
| 적·보스 프리팹 | `battleunits_assets_all_1cc41f638d1ab228f66e220640e044b1.bundle` | `SkyObject`, `LandObject`, `LandLoopObject`, `BattleEntity`, `EmittingSystem` |
| 탄 프리팹 | `battlebullets_assets_all_739f422456c916955693cf2937b1c857.bundle` | `BattleBullet` + Sphere/Capsule/Box Collider, 463개 |
| 웨이브·스폰·HP 표 | `configstage_assets_{wave1..7,wavei*,wavet1,batchgroup1..3,entprop1..5,stagecommon,landbatchtrig1..2}_*.bundle` | TextAsset, `ENCODE16` 형식 (`decode_config.py`의 XOR16 키와 같음) |
| 이동 경로 | `pathdata_assets_all_fbe78640c6115b2ca61b56a58fe1f175.bundle` | 베지어 경로 88개 (`SmallPlane_001`, `helicopter_boss_1` 등) |
| 보스 애니메이션 | `battleunitres_assets_battleunitres_<boss>_*.bundle` | Legacy AnimationClip. 회전 발사구 곡선 |
| 클래스 이름 | `db69119a206c92bd0afc8f9579243d14_monoscripts_*.bundle` | MonoScript 1223개 |

탄막과 관계없는 단서도 확인해서 제외했다:
- `decoded-config/Cybertron_danmu_config.json`: 축제 투표 화면의 채팅 "탄막(弹幕)" UI 설정이다. 총알과는 관계없다.
- `fortress_skill_bullet.json`: 요새 미니게임 전용이다.
- Lua 299개: 플레이어 장비가 프리셋을 덮어쓰는 기능(`CSOverrideEmittingPresets`)만 있고 적 탄막 코드는 없다.

### 1.2 분석 산출물 (스크래치, `F:\NKW\App\Shootingstar\.local\reference\wing-fighter-1.7.850\enemy-patterns\`)

| 파일 | 내용 |
|---|---|
| `danmaku/*.json` | 프리셋 691개 원본 타입트리 |
| `units/*.json` | 적 프리팹 322개의 계층과 컴포넌트 데이터 |
| `danmaku_summary_all.txt` | 프리셋 한 줄 요약 (모든 수치) |
| `units_summary_all.txt` | 유닛 → 단계 → 부위 → 발사구 → 프리셋 요약 (203개 유닛) |
| `enemy_preset_catalog.json` | 적 프리셋 343개의 특성 태그와 사용 유닛 목록 |
| `stagecfg-decoded/*.json` | 웨이브, 배치, 스폰, HP 표 103개 복호화본 |
| `bullets_index.json` | 탄 프리팹 → 충돌체 모양·크기 |
| `anim_rot_all.txt` | 보스 Legacy 애니메이션 회전·이벤트 추출 |
| `scripts/` | `pull_obb.py`, `dump_mono.py`, `dump_prefabs.py`, `summarize.py`, `catalog.py`, `stage_flow.py`, `stage_bosses.py`, `hp_ratios.py`, `anim_rot.py`, `anim_raw.py` |

재현 방법: `.local\reference\unity-inspector\Scripts\python.exe -I scripts\dump_mono.py raw\danmakudata_…bundle danmaku`로 덤프한 뒤 `python -I scripts\summarize.py units <유닛명>`을 실행한다.

---

## 2. 탄막 데이터 모델 (`EmittingSystemPreset`)

### 2.1 구조

```
Unit (SkyObject / LandObject / LandLoopObject)
 ├ m_MoveSpeed, m_UnitSteps[]            ← 단계(페이즈)
 │    └ Step: m_Entities[](부위), m_Type, m_StepDuration, m_EnterAction(진입 애니)
 └ BattleEntity (부위)
      ├ m_PropertyId → ent_prop*.json (레벨별 hpMAX/atk)
      ├ m_AutoFire, m_LookAtPlayer, m_LookAtSpeed(°/s)
      ├ m_EmittingSysControllerParam (시간표 제어: 거의 미사용)
      └ m_EmittingSysList[] → EmittingSystem
             ├ m_preset → EmittingSystemPreset
             └ m_inherentEmitAttr (덮어쓰기: dot 등)
EmittingSystemPreset
 ├ m_startDelay, m_loop, m_atRandom, m_inheritAngle, m_atkAddition(탄 피해 계수)
 └ m_emitterQueues[] : { m_emitParam, m_afterDelay }
```

### 2.2 `m_emitParam` 필드와 의미

| 필드 | 의미 | 근거 |
|---|---|---|
| `m_emitRoot` | 발사 기준 하위 노드 이름(`Emitter1`, `sl`/`sr`(좌/우), `1`/`2`…) | [관찰] |
| `m_bulletPrefab` | 탄 모양 (2.4 참고) | [관찰] |
| `m_bulletNum` | **한 큐 항목의 총 탄 수**. `-1`은 무한, `1000000`은 사실상 무한 | [추론, 강] `sandanpao_8_03`(24발/8갈래/0.4s → 0.4s 간격 3겹) 등 일관 |
| `m_multiWay` + `m_wayNum` | 한 번에 나가는 갈래 수. 연발 수 = `num / way` | [추론, 강] |
| `m_distParam.m_betweenAngle` | 갈래 사이 각도(°). `way×step=360`이면 원형(링) | [관찰] |
| `m_distParam.m_betweenPos` | 갈래 사이 **평행 간격**(각도 0 + 위치 차이 → 평행탄) | [관찰] |
| `m_betweenDelay` | 연발(또는 단발 연사) 사이 간격(s) | [관찰] |
| `m_bulletSpeed` / `m_accelerationSpeed` / `m_max/minSpeed` | 속도(u/s), 가속(u/s²), 상·하한 | [관찰] |
| `m_angle` | 각도 오프셋(°). 링을 4°씩 비틀어 겹 링을 만들 때 씀 | [관찰] |
| `m_useShift` + `m_shiftParam` | 발마다 각도 변화. `anglePattern=0`: 발마다 `m_angle`씩 회전 → **나선/휘두르기**. `anglePattern=1`: 사인 왕복(`waveRange`°, `waveSpeed`) → **스윕** | [관찰]/[추론] |
| `m_atRandom` + `m_randomParam` | 속도·위치·각도·지연 무작위 범위 → **산탄 흩뿌리기** | [관찰] |
| `m_aimTarget` + `aimingPlayer=1` | 플레이어 조준 | [관찰] |
| `m_useTurn` + `m_turnParam` | `homingAngleSpeed`(°/s) 유도, `homingTime`(s), `homingEscapedRadius`(이 거리 안이면 유도 해제로 보임), `speedPattern=2`+`sinWaveSpeed/Range` → **사인 곡선탄** | [관찰]/[추론] |
| `m_useRestriction.m_allInLine` | 탄들이 한 줄로 이어짐 → **바늘 열차/가짜 레이저** | [추론] |
| `m_useRestriction.m_followEmitter` | 발사구에 붙어 따라감 → **빔 레이저**(지속형 탄 `m_IsPersistent=1` + 크기 0 충돌체) | [추론, 강] |
| `m_useWarning` + `m_warningParam` | 예고 표시. `m_timePoint`(발사 몇 초 전 시작으로 보임), `m_duration`(표시 시간) | [관찰]/[추론] |
| `m_releaseDuration` | 빔이 펼쳐지는 시간 또는 무한 발사의 지속 시간 | [추론] |
| `m_lifeWay`, `m_lifetime` | `lifeWay=1`이면 `lifetime`초 후 소멸(빔 지속, 근거리 탄). `lifeWay=0`이면 화면 밖까지 날아가는 것으로 보임 | [추론] |
| `m_speedCurveOverLT`, `m_sizeCurveOverLT` | 수명 대비 속도·크기 곡선 (기뢰: 1%만 이동 후 정지) | [관찰] |
| `m_afterDelay` | **다음 큐 항목 시작까지의 간격(이전 항목 시작 기준).** 큐 항목은 병렬로 진행된다 | [추론, 강] 아래 근거 |

`m_afterDelay`를 "시작 기준·병렬"로 본 근거:
1. `tanknew_keep02`: q0이 무한(`num=-1`)인데 0.4s 뒤 q1(무한)이 있다. 순차 실행이면 q1은 영원히 시작되지 않는다.
2. `DLS_Step2_010`: 무한 링 4개가 0/0/2/2s에 시작하고 마지막에 20s 대기가 있다.
3. 충돌체가 없는 시각 효과용 탄(`Bullet_laser_enemy_34_1`, `Bullet_sd_enemy_31`)이 `after=0`으로 본탄 바로 뒤 큐에 있다. 두 큐가 함께 돌아야 의미가 있다.

루프(`m_loop=1`)는 마지막 항목의 `afterDelay`가 끝나면 다시 시작하는 것으로 보인다. 앞 항목이 아직 진행 중일 때 어떻게 되는지는 확인하지 못했다. 재구현할 때는 **"한 사이클 = 마지막 항목 시작 시각 + 마지막 afterDelay"**로 두고, 무한 항목은 한 번만 띄우면 안전하다.

### 2.3 좌표와 단위 환산

- 전장은 XZ 평면이고 +Z가 화면 위쪽이다 [관찰: pathdata].
- 일반기는 z≈8.7~11.2에서 들어와 z≈-0.9로 나간다. 보스는 z≈6~7.8에 자리 잡는다(`FaceBoss` 6.0, `GeminiBoss` 7.0, `helicopter_boss_7` 8.7). 좌우 진입점은 x≈±4.5~5.8이다 [관찰].
- 따라서 **화면 세로 ≈ 9u(z -0.5~8.5)**, 가로 ≈ 7~8u로 추정한다 [추론]. 카메라가 원근 투영이라 정확한 값은 아니다.
- 비교 기준(관찰값): 플레이어 주포 `PlayerMain_1` spd=8, 아이템 낙하 `stageItemSpeedZ=-0.4`.
- **Flutter 환산 권장식:** `px/s = spd × (뷰포트 세로 px / 9)`. 예를 들어 spd 1이면 화면 세로를 약 9초에, 3이면 3초에, 6이면 1.5초에 지나간다.

### 2.4 탄 모양 분류 (충돌체 기준)

| 분류 | 예시 프리팹 | 충돌체 [관찰] | 비고 |
|---|---|---|---|
| 둥근 구슬(소) | `Bullet_sd_enemy_03/20/27/28/35` | Capsule r0.04~0.10, h=r | 링·부채꼴의 기본 |
| 큰 구체탄 | `SphereBullet`, `_1~_4` | Sphere r0.6 × 루트 스케일 0.1 ≈ **r0.06** | 그림만 크고 판정은 작다 |
| 긴 탄/바늘 | `Bullet_sd_enemy_05`(r0.06 h0.22), `_26`(h0.32), `bullet_bosszsj_01`(h0.80), `Bullet_laser_enemy_34`(h0.70) | Capsule, h ≫ r | 고속 저격, 바늘 열차 |
| 막대(바) | `Bullet_sd_enemy_06/37` | Box 0.18×0.08×1.0 | 짧은 "레이저 조각" |
| 미사일 | `Bullet_plane_us_03~09` | Capsule h0.15~0.34 | 유도 |
| 빔 레이저 | `tankboss_laser`, `bullet_general_laser`, `FaceBoss_laser`, `Boss_Spider_laser`, `SubmarineBoss_laser` | Capsule 0×0, `m_IsPersistent=1` | 판정은 코드에서 처리하는 것으로 보임 [추론] |
| 초승달 | `Bullet_Moon_*` | Capsule r0.22~0.31 | 크기 곡선으로 커짐 |
| 기뢰 | `Bullet_sd_enemy_40` | Sphere r0.11 | 속도 곡선으로 정지 |

`m_atkAddition`(탄 1발 피해 계수)도 패턴마다 다르다 [관찰]. 링·산탄은 0.5, 조준 연사는 0.15~0.4, 빔은 0.2에 0.05초 틱(`dot=1, dotCooldown=0.05`), 고속 저격 `bullet_enemy_superspeed`는 2.5, 단발 큰 탄은 1.0이다. **탄이 많은 패턴일수록 1발 피해가 낮다.**

---

## 3. 적 계층과 등장 구조

### 3.1 스폰 타입 (`stagecfg-decoded/batch_factory.json` `unitType`) [관찰]

| unitType | 유닛 | 등장 예 |
|---|---|---|
| 1 일반 | `base_small`(+green/yellow), `base_dish`, `EnemyPlaneWhite`, `Unit_Monster_Bomb` | 5~12기 편대, 0.5s 간격, 경로 비행 |
| 2 소형 헬기 | `helicopter_small` | `unitCount=10000, interval=3` → 웨이브 동안 3초마다 계속 등장 |
| 3 중간 보스 | `helicopter`, `helicopter_01/02_1/03/04`, `syzsj`, `changyifeiji`, `Sboss_helicopter_*`(8종), `smallboss3~5`, `CloudMaster`, `Unit_Conveyor` | 1기, 경로 끝에서 정지·배회(`unit_ai walkType=2`) |
| 4 보스 | 3.3 참고 | 1기, 보스 웨이브(`waveType=2`) |
| (-1) 지상 | `batch_land_factory.json`: 포탑·전차·함선 55종 | 맵 타일 배치점(`land_bath_trig*`) |

- 공중 일반기(`base_small` 계열, `EnemyPlaneWhite`, `base_dish`)는 프리팹에 `EmittingSystem`이 없고 `m_Crashable=1`이다 [관찰]. `danmakuRes`도 전부 null이다. **잡몹 편대는 쏘지 않고 몸으로 부딪힌다.** 탄막은 지상 포대와 헬기 이상이 담당한다.
- `unit_ai.json` `walkType`: 0은 경로를 지나 퇴장, 2는 경로 끝에서 머묾(헬기·보스), 1은 좌우 왕복으로 보인다(`airplane_05/06/07`) [관찰/추론].

### 3.2 웨이브 안의 배치 (메인 스테이지 50웨이브 기준) [관찰]

- 스테이지 1(`10001`)은 30웨이브이고 30번째가 `tankBOSS`다. 스테이지 2부터는 50웨이브다.
- 엘리트 `Sboss_*`는 **14번째(waveType 1), 28번째(0), 42번째(1)**, 보스는 **50번째(waveType 2)**에 고정되어 있다. 예: stage 5는 5014 `Sboss_helicopter_01`, 5028 `Sboss_helicopter_small_crazy`, 5042 `Sboss_helicopter_crazy_2`, 5050 `TankBOSS_Heavy`.
- `waveType` 1·3·4·5의 의미는 확인하지 못했다(경고·보상 웨이브로 추정).
- 적 레벨(`unitsLevel`)은 3~4웨이브마다 1씩 오른다(`x01 → x14`).

### 3.3 메인 스테이지 보스 순서 (`decoded-config/stage_config.json` + 웨이브 추적) [관찰]

| 스테이지 | 보스 | 스테이지 | 보스 |
|---|---|---|---|
| 1 | `tankBOSS` (전차, 3단계) | 7, 11 | `OceanBOSS` (전함, 5단계) |
| 2, 20 | `hyzhishengjiBOSS` (공격헬기, 3단계) | 8 | `Boss_Spider` (거미 전차, 3단계) |
| 3, 10, 17 | `helicopter_boss` (대형헬기, 5단계) | 9, 14, 16, 18 | `GeminiBoss` (쌍둥이기, 4단계) |
| 4, 15, 19 | `Boss_Airplane_Big` (폭격기, 7단계) | 12 | `SubmarineBoss` (잠수함, 4단계) |
| 5 | `TankBOSS_Heavy` (중전차, 5단계) | 13 | `FaceBoss` (얼굴 요새, 4단계) |
| 6 | `TrainBoss` (열차, 4단계) | 21~80 | 위 11종 반복 |

이벤트 모드 보스(`batch_factory`, `unitAI 4013~4017`): `DevilfishBoss`, `RobotBoss`, `UnicronBoss`(+`_TaiTan`), `BigSpiderBoss_N`, `DevastatorBoss`, `zsjBOSS`.

### 3.4 HP 배율 (`ent_prop*.json`, 같은 레벨에서 `base_small`(id 1201) 대비) [관찰]

| 대상 | prop id | 배율 |
|---|---|---|
| 일반 공중기 | 1201/1202 | 1× |
| 소형 헬기, 지상 포탑·전차 포탑 | 1301/1302 | 5× |
| 중간 헬기 총좌 | 1401 | 5× (2단계 몸체 1402는 0.01×) |
| 기타 | 1403 / 1404 / 1405 | 7× / 2× / 10× |
| **엘리트 Sboss, smallboss, CloudMaster** | 1501 | **30×** |
| 보스 부위 1개 | 21xxxx | 10×~110× |

보스 총 HP와 단계별 비중 (보스 레벨, 같은 레벨의 1201 대비):

| 보스 | 총 HP 배율 | 단계별 배율 | 단계별 비중(%) |
|---|---|---|---|
| tankBOSS (lv110) | 60× | 30 / 10 / 20 | 50 / 17 / 33 |
| hyzhishengjiBOSS (lv214) | 60× | 40 / 10 / 10 | 67 / 17 / 17 |
| helicopter_boss (lv314) | 170× | 30 / 30 / 50 / 50 / 10 | 18 / 18 / 29 / 29 / 6 |
| Boss_Airplane_Big (lv414) | 190× | 30 ×6 / 10 | 16 ×6 / 5 |
| TankBOSS_Heavy (lv514) | 160× | 40 / 50 / 50 / 10 / 10 | 25 / 31 / 31 / 6 / 6 |
| TrainBoss (lv614) | 140× | 30 / 50 / 50 / 10 | 21 / 36 / 36 / 7 |
| OceanBOSS (lv714) | 160× | 50 / 30 / 30 / 40 / 10 | 31 / 19 / 19 / 25 / 6 |
| Boss_Spider (lv814) | 120× | 45 / 60 / 15 | 38 / 50 / 12 |
| GeminiBoss (lv914) | 150× | 40 / 40 / 50 / 20 | 27 / 27 / 33 / 13 |
| SubmarineBoss (lv1214) | 160× | 50 / 50 / 50 / 10 | 31 / 31 / 31 / 6 |
| FaceBoss (lv1314) | 260× | 60 / 80 / 110 / 10 | 23 / 31 / 42 / 4 |

- **단계 전환은 HP% 기준이 아니다.** 단계의 모든 부위(`m_Entities`)를 부수면 다음 단계로 넘어간다(`m_Type=0`, `m_StepDuration=0`) [관찰: 모든 보스 단계에 해당. 해석은 추론]. 같은 단계 부위는 HP가 같고, 마지막 단계는 발사구가 없는 몸체(10×)다.
- 레벨 안 성장 [관찰]: stage 1은 lv101 150HP에서 lv114 9,630HP(64배)로, 적 공격력은 150에서 225(1.5배)로 오른다. stage 13은 11,270에서 723,534로 오른다. 플레이어의 현장 성장 속도에 맞춰 적 HP가 기하급수로 오른다.

---

## 4. 일반 적 패턴 카탈로그

`enemy_preset_catalog.json`의 특성 태그 분포 (적 프리셋 343개) [관찰/분류]: stream 144, aimed 98, 다중 큐 79, ring 60, 연발 볼리 53, fan 51, 레이저류 48, random 42, 예고 41, 각도 오프셋 37, homing 27, 빔(발사구 추적) 26, 평행탄 25, 나선 20, 바늘 열차 18, 곡선 12, 무한 11, 스윕 10.

### 4.1 공중 소형

| 유닛 | 프리셋 | 내용 [관찰] |
|---|---|---|
| `base_small` 계열, `EnemyPlaneWhite`, `base_dish` | 없음 | 미발사. 충돌만. 속도 2, 5~12기, 0.5s 간격 |
| `helicopter_small` | `helicopter_small` | 좌(`sl`)/우(`sr`) 미사일 1발씩. spd 1.8, **유도 300°/s**, 유도 시간 100s, 해제 반경 0.8. start 2s, 좌 → 5s → 우 → 3s (8s 주기) |
| `Unit_Monster_Bomb` | `Unit_Monster_Bomb` | 사망 후 2단계 `nomesh`(자폭 2s)에서 **5방향 기뢰**(72°, 반경 오프셋 0.05). spd 1.8로 수명의 1%(0.6s)만 움직인 뒤 정지. 크기 0→1, 수명 60s, 1회 |

### 4.2 지상 포대·전차·함선

| 유닛 | 패턴 유형 | 수치 [관찰] |
|---|---|---|
| `DanGuanPao_1/_2` | 조준 단발 | 1발, spd 1, 2s/3s 주기, 포신 추적 120°/s |
| `DanGuanPao` | 조준 3점사 | 큰 구체 3발, 0.18s 간격, spd 1.4, 4s |
| `tankNew`, `_blue` | 조준 단발 무한 | 큰 구체, `num=-1`, 3.2s마다, spd 1.15, 포탑 추적 60°/s, 이동 0.3 |
| `tankNew_keep02` / `_keep03` | 2연·3연 | 0.4s 차 2연(무한) / 0.4s 간격 3연 후 3.2s |
| `lianshepao` / `_02/_05/_07` | 고정 방향 연사 | 3/2/5/7발, 0.21s 간격, spd 1, 2.4~5s |
| `sandanpao_4_01` | X자 4방향 | 4갈래 90°, 오프셋 45°, spd 1, 4s |
| `sandanpao_4_02/03` | X자 5연 가속 | 4갈래 × 5연발, 0.15s, spd 1, 가속 0.2, 5s |
| `sandanpao_8_01` | 8방향 링 | 8갈래 45°, spd 1, 4s |
| `sandanpao_8_02` / `_8_03` | 8방향 겹 링 | 0.1s 간격으로 0°/+4°/+8° 3겹. `_03`은 각 3연(0.4s) |
| `sandanpao`, `Warship_Small_BlueBullet` | 16방향 겹 링 | 16갈래 22.5° ×3겹(+4°, +8°), 0.1s 간격, spd 1, 5.2s 주기 |
| `sanshepao` / `sanshepao_up` | **회전 3/5갈래 나선** | 3갈래 120°(5갈래 72°) × 10연, 0.28s 간격, 발마다 −12° → 약 −43°/s, 8s 주기 |
| `sanshepao_1` | 6방향 링 3연 | 6갈래 60° × 3연, 0.4s, spd 0.7, 4s |
| `shuang_guan_pao` | 평행 쌍탄 | 2발 평행(간격 0.75), spd 1.6, 4s, 추적 120°/s |
| `singleblack` | 고정 단발 | 1발, spd 0.8, 2.2s |
| `jiguangpao`, `_02` | **사인 곡선 쌍줄기** | 발사구 2개 × 45발, 0.05s(2.25s), spd 2.5, `speedPattern=2` sin 속도 24, 진폭 18/8, 4s |
| `gaoshepao` | 예고 후 고속 평행 | 2발 평행(0.3), spd 6, **1s 전 0.8s 예고**, 2.4s, 추적 200°/s |
| `gaoshepao_01` | 예고 후 조준 저격 | 1발 조준, spd 6, 같은 예고 |
| `Warship_Mid_1/3` | 예고 평행 | 2발 평행(0.5), spd 6, 예고 1s/0.8s, 4s |
| `turret01` | **예고 빔 4연** | 발사구 4개에서 start 1/1.5/2/2.5s, 예고 0.6s, 펼침 0.6s, 빔 0.8s, 4s 주기 |
| `Tank_Laser`, `Unit_Monster_Laser`, `Warship_Small_Laser` | 예고 추적 빔 | `bullet_general_laser`: start 1~2s, 예고 0.6s(0.8s 전), 펼침 0.6s, 빔 0.4s, 6s, 머리 추적 30°/s, dot 0.05s |
| `Unit_Monster_Supersonics` | 초고속 저격 | `bullet_enemy_superspeed` 2발 평행(0.22), spd 8, **피해 2.5×**, 예고 0.6s, 4s, 추적 80°/s |
| `Tank_Gatlin` | 근거리 개틀링 | 2열 평행(0.25) × 5연, 0.03s, spd 3+무작위 0~1, 수명 0.4, 6s |
| `Tank_RocketS1` | 고속 연사 | 6발, 0.15s, spd 6, 5s |
| `Spider_Bean` | 2연 연사 | 5발 0.08s ×2(1.5s 차), spd 2, 5.5s |
| `Spider_Laser` | 바늘 열차 | 6발, 0.16s, spd 2, 한 줄 연결, 6s |
| `Spider_Missle` | 꼬불 유도 미사일 | 2발 평행 무한, 2s마다, spd 3, 유도 50°/s, 0.5s간 sin 흔들림(20/6) |
| `Warship_Small_Missile` | 평행 유도 | 2발 평행(0.75), spd 3, 유도 300°/s, sin 흔들림, 2s |
| `Motorboat` | 유도 단발 | 1발, spd 2, 유도 300°/s, 4s |
| `Warship_Mid_2` | 연사 + 물결 | 12발 0.08s spd 1, 3s / 8s 후 50발 0.02s 물줄기(spd 1.5, 수명 2.5s) |
| `Warship_Mid_4_01`, `Warship_Mid_5` | 무작위 흩뿌림 | 12발 0.1s spd 4 ±6° / 18발 0.05s spd 1.5 ±0.2° |
| `TripleTurret` | 조준 좁은 부채 | 10갈래 2°(18°) 긴 탄, spd 3, 3s |
| `artillery` | 단발 연속 | 40발, 0.08s, spd 1, 수명 0.2s, 1회 |

---

## 5. 중간 보스 패턴

### 5.1 헬기 계열 (unitType 3, HP 5×, 2단계) [관찰]

1단계는 총좌(1401)이고, 부서지면 2단계 몸체(1402, HP 0.01×, 무장 없음)만 남는다. `helicopter_02_1`은 예외다(아래). 이동 속도는 1, `unit_ai 2006`(`helicopter_1_medium` 경로 끝에서 머묾).

| 유닛 | 프리셋 | 수치 |
|---|---|---|
| `helicopter` | 3갈래 큰 구체 | 3갈래 16°, spd 1, start 2s, 3s 주기 |
| `helicopter_01` | 조준 연사 | 12발 0.07s spd 1.6, 5.6s, 피해 0.15 |
| `helicopter_02_1` | 조준 바늘 + 사망 링 | 1단계: 7발 0.13s spd 2 조준 5.2s. 2단계 `nomesh`(자폭 3s): **12방향 링 ×2**(발사구 1·2, 0.3s 차), spd 0.01 → 가속 3, 1회 |
| `helicopter_03` | 쌍 개틀링 | 총 2정 × 13발 0.07s spd 5, ±2°, 4s |
| `helicopter_04` | 쌍 로켓 흩뿌림 | 2발사구 × 6발 0.3s spd 3, 위치 ±0.3, 각도 ±8°, 조준, 6s |
| `syzsj` | 조준 바 레이저 | 막대탄 5발 0.14s spd 3.2, 한 줄, 3s |
| `changyifeiji` | 3갈래 구체 | 3갈래 11°, spd 1.2, 6s (2기 4s 간격, 지나감) |

### 5.2 엘리트 `Sboss_*` (HP 30×, 웨이브 14/28/42) [관찰]

모두 1단계 1부위이고 경로 `helicopter_04_a`, `unit_ai 3003`을 쓴다. **일반 헬기와 같은 패턴을 템포만 올린 것**이다.

| 엘리트 | 기반 | 패턴 | 템포 변화 |
|---|---|---|---|
| `Sboss_helicopter_difficult` | `helicopter` | 3갈래 16° 구체 spd 1 | 3s(+start 2) → **1.5s** |
| `Sboss_helicopter_crazy` | `helicopter` | 3갈래 ×3연(0.25s, 마지막 17°) | 3연발 + **2.1s 주기** |
| `Sboss_helicopter_01` | `helicopter_01` | 12발 0.07s spd 1.6 조준 | 5.6s → **1.6s**, 피해 0.15 → 0.5 |
| `Sboss_helicopter_small_difficult` | `helicopter_small` | 좌·우 유도 미사일 | 8s → **4.4s** |
| `Sboss_helicopter_small_crazy` | `helicopter_small` | 같음 | → **2.8s** |
| `Sboss_helicopter_small_difficult_1` | `helicopter_small` | 큰 미사일 `us_04` | → **2.0s** |
| `Sboss_helicopter_crazy_2` | 신규 | 2갈래 16° 구체를 +24° 쪽과 −26°(334°) 쪽으로 각 4연(0.5s), spd 0.8, 5s + 조준 큰 바늘 2발(0.5s) spd 1.5, 3s | V자 양옆 견제 + 조준 |
| `Sboss_helicopter_difficult_1` | 신규 | 같은 V자 쌍을 무한(1.8s마다) + 조준 2발(1.2s) | 무한 지속형 |

### 5.3 smallboss·기타 (HP 30×) [관찰]

| 유닛 | 패턴 |
|---|---|
| `smallboss1` | 15갈래 16°(224°) 부채, spd 2, 각도 무작위 ±14°, 지연 0.05~0.1, 5s + 평행 유도 미사일 2발(0.85, 30°/s) start 2.5s, 5s |
| `smallboss2` | 8갈래 2°(14°) 좁은 다발 ×3(0.3s 차) 5s마다(무한) + 큰 바늘 2발 평행(0.8) 1.8s마다 |
| `smallboss3` | 평행 유도 미사일 2열 ×4(0.2s) spd 3, 30°/s (start 2s, 5s) + 10갈래 12° 부채(1볼리), spd 1, 3s |
| `smallboss4` | 3갈래 10° ×3연(0.4s) spd 2, 3s + start 6s 조준 평행 고속 2발 ×(0.14s) spd 6, 5s |
| `smallboss5` | 6갈래 4° 부채 spd 2 → 4s 뒤 15발 무작위 ±16° spd 2 (3s/4s 교대) |
| `CloudMaster` | 전기구 3갈래 11° 조준, spd 4, 6s (애니메이션 트리거 `manualShot`), 이동 2.5, 충돌형 |

---

## 6. 스테이지 보스 단계별 패턴 (메인 11종)

`start`는 단계 시작 후 첫 발사 지연, `주기`는 프리셋 반복 간격이다. 별도 표기가 없으면 [관찰]이다.

### 6.1 `tankBOSS` (stage 1, 지상 루프, 3단계)
- **1단계** (부위 3개, 50%)
  - 주포 `TankBoss_step1_1`: 큰 탄 1발 spd 3, start 2s, 4s 주기, 추적 20°/s
  - 측포 2문 `TankBoss_step1_0`: 8발 0.08s spd 1, start 1.2s, 3s 주기, 추적 120°/s
- **2단계** (17%): 3연장 포탑 `TankBoss_step2_0` ×3포구. 포구당 20발(간격 0) spd 1과 시각 효과 큐를 함께 쏜다. start 2s, 4s 주기. 같은 방향 20발이 겹쳐 나가는 굵은 탄줄로 보인다 [추론].
- **3단계** (33%): 몸체. 발사 없음.
- 호위: 단계 밖 부위로 `helicopter_small` 2기가 붙어 있다(유도 미사일).

### 6.2 `hyzhishengjiBOSS` (stage 2·20, 공중, 3단계)
- **1단계** (67%)
  - 양 측면 기관포 `_twoside`: 조준 22발 0.04s spd 1.2(0.88s), 6s, 추적 120°/s
  - 머리 2문 `_head`: **긴 바늘(h0.8) 14발 한 줄 열차** 0.06s spd 2.5, start 4s, 5s
- **2단계** (17%): 상단 `_top`. 18갈래 22.5° 링(360° 넘어 일부 겹침) ×3겹(+3°, +6°, 0.05s 간격), spd 2.5, 5.1s 주기
- **3단계** (17%): 몸체가 머리 바늘 열차를 계속 쏜다.

### 6.3 `helicopter_boss` / 프리셋 `motorboss_*` (stage 3·10·17, 5단계, 경로 `helicopter_boss_4`)
- **1단계** (18%)
  - 3연장 2기: 10갈래 2°(18°) 조준 긴 탄 spd 3, 3s
  - 전방포: 3갈래 5° 큰 구체 ×5연 0.05s, spd 2, 위치 ±0.2, 6s
- **2단계** (18%, 진입 애니 `motorboss_step2`)
  - 포드 2기: 16방향 링 ×3겹(+2.5°, +5°) **spd 0.5**(느림), 2.2s
  - 측면 기관포: 조준 6발 1s 간격 spd 1.2, 6s
- **3단계** (29%, 좌선회) / **4단계** (29%, 우선회, 같은 구성)
  - 포 3문: 13갈래 9.5°(114°) 부채 1볼리 spd 1, start 4s/7s, 9s
  - 쌍포: 조준 큰 구체 3발 0.15s spd 2, 발사구 1→2 순서, 9s
- **5단계** (6%): 몸체. 발사 없음.

### 6.4 `Boss_Airplane_Big` (stage 4·15·19, 7단계)
- **1단계** (16%)
  - 머리 양쪽 각 2발사구: 12발 0.052s spd 2.3, 3.5s
  - 상부: 3갈래 13° 긴 탄 spd 3, start 3s, 4s
- **2단계** (16%, 왼날개)
  - 엔진 2기 × 3발사구: start를 0.5/1.5/2.5/3.5/4.5/5.5s로 엇갈려 각자 16방향 링 ×3겹(+3°, +6°) spd 2를 쏘고 9s 쉰다 → **약 1s마다 링 묶음**
  - 날개 포탑: 조준 5발 0.15s spd 2, 3s, 추적 80°/s
- **3단계** (16%, 오른날개): 엔진 2기 × 4발사구. 각자 16방향 링 7연(0.1s, 오프셋 없음) spd 2, start 0.5~7.5s, 9s
- **4~6단계** (각 16%, 꼬리 3세트)
  - 중앙: 16방향 링 ×3겹(+4°, +8°) spd 2, 2.2s
  - 양옆: 조준 단발 spd 2, start 3s, 4s
- **7단계** (5%): 머리 연사 하나만 남는다.

### 6.5 `TankBOSS_Heavy` (stage 5, 지상, 5단계)
- **1단계** (25%)
  - 상부 2기 × 4발사구(start 2.0/2.3/2.6/2.9s): **긴 바늘(h0.70) 30발 열차** 0.1s spd 3(3s), 6s → 4줄이 0.3s씩 어긋난 평행 열차
  - 측포 2문: 12발 0.08s spd 2, 6s, 추적 60°/s
- **2단계** (31%)
  - 전방 2문: 조준 큰 구체 3발(1s 간격) spd 2, 3s
  - 후방 2문: 조준 바늘 1발 **spd 6**, 5s
  - 중앙: **추적 빔** `tankboss_laser`. 추적 10°/s, 예고 1.8s(2.2s 전), 빔 2s, start 2.5s, 6s, dot 0.05s
- **3단계** (31%)
  - 주포 `step3_main`: 7갈래 51.43°(360/7) × 26볼리 0.2s(5.2s) spd 1, start 2s. 포탑이 **±25°를 3.5s 주기로 왕복**(Legacy `TankBOSS_Big_step3_Rotate`)한다 → 흔들리는 7갈래 풍차
  - 전방: 긴 탄 단발 spd 2, 6s
  - 로켓 2기: 3갈래 13° 긴 탄 spd 3, start 4s, 4s
- **4단계** (6%): 최후 폭발. `nomesh` 자폭 2s 동안 12방향 링 spd 5를 1회 쏜다(발사구 `1`).
- **5단계** (6%): 몸체.

### 6.6 `TrainBoss` (stage 6, 지상 열차, 4단계)
- **1단계** (21%)
  - 단관포 2문(추적 80°/s): 조준 큰 구체 15발 0.05s spd 3(0.75s), 4.5s
  - 회전 포탑 `TrainBoss_2`: **6갈래 60° × 10볼리 0.2s, 발마다 −10°(≈ −50°/s 나선)**, spd 1, start 2s, 6s
- **2단계** (36%)
  - 전차 4대(추적 50°/s): 조준 막대탄 4발 0.1s spd 3.2(한 줄), start 0/1.5/3/4.5s 엇갈림, 6s → 1.5s마다 한 대
  - 연사포(추적 10°/s): 3갈래 10° spd 1, 수명 3, 0.8s마다(느린 연속 부채)
- **3단계** (36%)
  - 포탑 2문: 6갈래 5° 좁은 부채 ×2볼리 0.2s spd 0.8, 4s
  - 기관포 2문: 조준 바늘 spd 6, start 2.5/5s, 5s
  - 로켓 1기 × 2발사구: 유도 미사일 spd 1.5, 120°/s, 유도 3s, 2s마다
- **4단계** (7%): 열차 몸체.

### 6.7 `OceanBOSS` (stage 7·11, 지상 전함, 5단계)
- **1단계** (31%)
  - 포 2문(추적 20°/s): 30발 0.05s spd 1(1.5s), start 1s, 3.4s
  - 포 2문(추적 120°/s): 긴 탄 12발 0.08s spd 2.5, start 4s, 6s
  - 로켓: 3발 평행(0.062) 조준 spd 6, start 2s, 4s
- **2단계** (19%)
  - 포 2문: 조준 큰 구체 20발 0.1s spd 1.2, start 2s, 4s
  - 로켓 1기 × 6관: 각 2발 0.15s spd 6, start 0/0.2/…/1.0s 물결, 3s
- **3단계** (19%)
  - 회전대 `Rotationanim` 6발사구: 각 70발 0.02s(1.4s) spd 1.5, 수명 3s, start 2s, 3.2s. 회전대가 **±27°를 3.5s 주기로 왕복**(Legacy `OceanBOSS_step3Rotation`)한다 → 6줄기 부채 스윕
  - 대공포 2문 `gaoshepao`: 평행 2발 spd 6, 예고 0.8s, 2.4s
- **4단계** (25%)
  - 8발사구: 각 4발 0.4s spd 4, 지연 무작위 0~0.8s, 6.5s → 산발 비
  - 로켓 3기: 조준 평행 2발 spd 6, start 4.3/4.8/5.1s, 6.5s
- **5단계** (6%): 구축함 몸체 로켓 1기.

### 6.8 `Boss_Spider` (stage 8, 지상 거미, 3단계)
- **1단계** (38%)
  - 등포 2발사구(추적 60°/s): 큰 구체 20발 0.06s spd 1.5, start 3s, 4s
  - 좌·우 레이저 포드: 유도 미사일 4발 0.2s spd 3, **300°/s**, 해제 반경 0.2, start 0/2s, 4s
- **2단계** (50%)
  - 좌·우 집탄기: **30방향 링(12°) spd 3**을 start 3s와 3.6s에 2연, 4s
  - 전방포 4발사구(추적 15°/s): 짧은 사거리 고속 줄기 32발 0.09s spd 6, 수명 0.65s(사거리 약 3.9u), 6s
  - 상부 소포(추적 3°/s): 예고 0.8s 평행 고속 2발(spd 6) 2단, start 3s, 6s
- **3단계** (12%): 몸체.

### 6.9 `GeminiBoss` (stage 9·14·16·18, 공중, 4단계)
- **1단계 A기** (27%)
  - 머리: **바늘 80발 0.008s(0.64s) spd 6, 감속 −3, 수명 2s, 사인 ±15° 스윕, 각도 ±4°·속도 ±0.2 무작위**, 4s → 감속하는 샷건 커튼
  - 내포(추적 60°/s): 조준 8발 0.1s spd 5(+0~2), ±1.5°, start 3s, 4s
  - 측포 2문: 조준 20발 0.05s spd 1.5, start 1.5s, 4s
- **2단계 B기** (27%)
  - 머리: 6갈래 8° 부채 ×4볼리 0.4s spd 2.4, 수명 3, start 2s, 4s
  - 내포: 유도 미사일 5발 0.5s spd 3, 180°/s, ±5°, start 4s, 4s
  - 측포 2문: 조준 긴 바늘 8발 0.07s spd 4(한 줄), start 1s, 4s
- **3단계** (33%)
  - 포탑 4문: **채찍 호(弧)**. 15발 0.02s(0.3s) spd 3, 발마다 ±3° → 0.3s에 45°를 쓸어 긋는다. start 0/1/2/3s 엇갈림, 7s
  - 눈알: 추적 빔. 추적 20°/s, 예고 0.7s, 펼침 0.9s, 빔 0.8s, start 2.5s, 2s 주기
- **4단계** (13%): 레이저 4문. start 1/2/3/4s, 각 예고 2s 후 빔 4s, 5s 주기 → **4줄 빔이 1초씩 순차 점등**
- 단계 밖 부위: 조준 12발 0.05s spd 2, 3s

### 6.10 `SubmarineBoss` (stage 12, 지상, 4단계)
- **1단계·2단계** (각 31%, 같은 구성을 두 번)
  - 포탑: 16방향 3겹 링(+4°, +8°) spd 1, start 0s와 1s 두 세트, 5.2s
  - 로켓 2기: 평행 2발 spd 6, 예고 0.7s, start 4.3s, 6.5s
  - 미사일 사일로(`manualShot`, 애니 이벤트 발사): 6발 평행(0.82) **뒤쪽(180°)**으로 발사, spd 6 + 0~3 무작위, 가속 0.5, 최대 15, 0.2s 간격
- **3단계** (31%)
  - 레이저 머리(추적 30°/s): 빔. 예고 1.8s, 펼침 2.3s, 빔 2s, start 2.5s, 4s
  - 로켓 2기: 유도 미사일 평행 2발 ×(0.5s) spd 4, 180°/s, start 4s, 3.5s
  - 포 2문(추적 20°/s): 30발 0.05s spd 1, start 1s, 3.4s
- **4단계** (6%): 최종 몸체.

### 6.11 `FaceBoss` (stage 13, 공중 요새, 4단계, 총 HP 260×)
- **1단계** (23%). 방패 부위는 발사 없음(HP만 있음).
  - 입: **긴 빔 5s**. 예고 0.7s, 펼침 0.9s, start 2.5s, 7s 주기
  - 눈 2개(추적 30°/s): 짧은 빔 0.4s, 예고 0.6s, start 1s, 6s
  - 아래 2문: 3갈래 10° 긴 탄 ×2볼리 0.2s spd 2, 4s
- **2단계** (31%)
  - 입: 바늘 6발 0.2s spd 6(+0~1), ±4° 무작위, 6s
  - 상단 2문: 미사일 6발 평행(0.82) 뒤쪽 발사, 속도 무작위 0~4, 위치 ±1, 1회 → 위에서 떨어지는 커튼
  - 눈 2개: **초고속 저격** spd 8, 피해 2.5×, 예고 0.6s, start 0.8s, 6s
  - 아래 2문: 유도탄 3발 0.6s spd 2, 120°/s, 4s
- **3단계** (42%)
  - 입: 초승달 3갈래 20° spd 2, 수명 4s, 크기 0→3배, 8s
  - 눈: 채찍 호 8발 0.08s spd 2, ±4°/발, 4s
  - 포탑 6문: 16방향 링 spd 2, start 0/3/6/9/12/15s, 각 10s → 약 1.7s마다 링이 하나씩
  - 레이저 부위 5발사구: 긴 바늘 30발 열차 0.1s spd 3(3s), start 0~4s를 1s씩 엇갈림, 10s
- **4단계** (4%): 빈 코어.

### 6.12 이벤트 모드 보스 (참고 요약) [관찰]

| 보스 | 단계 수 | 특징 패턴 |
|---|---|---|
| `DevilfishBoss` | 9 (1~4단계 반복 + 폭탄) | 조준 예고 레이저 6문, 조준 나선 줄기(8발 0.02s, −8°/발), 사인 스윕 줄기(±20°), 20방향 3겹 링, 60방향 링 2연(0.8s) |
| `RobotBoss` | 10 | 12방향 링 2연(1s), 5갈래 10° 부채 +320° 오프셋, 고속 사인 스윕(±10°, 속도 400) 바늘 100발 |
| `UnicronBoss`(+`_TaiTan`) | 3 (6) | 22발 0.015s ±3°/발 호, 유도+가속 100 2갈래 120°, **정지 후 발사체가 되는 탄**(`createEmitterUnit`, 속도 곡선 1→0), 6갈래 35° ×40볼리 사인 스윕 |
| `BigSpiderBoss_N` | 10 | 6갈래 7° ×8볼리 사인 스윕, 20방향 링 0.5s 무한 4s간 발마다 −60° 회전, 추적 빔 |
| `DevastatorBoss` | 1 (+시간표 52s 루프) | **유일한 시간표 제어**: 발사구 0을 상시, 1→2→3을 17s씩 교대(`controlType=1`, `duration=52`). 레이저 5연 예고 → 3s 추적 빔, 20방향 링 무한 4s, 조준 2갈래 5° 바늘, 12갈래 1.5~2° 감속탄(4.5 → 2.5) |
| `zsjBOSS` | 1 | 조준 12발 0.05s spd 2, 큰 구체 3발 0.16s |

---

## 7. 확인하지 못한 것 (한계)

1. **큐 실행 의미**: `afterDelay`가 시작 기준·병렬이라는 해석은 사례(2.2절)에서 나온 추론이다. 루프가 진행 중인 항목을 기다리는지는 모른다. 확인하려면 `EmittingSystem`/`EmittingUpdater` 네이티브 코드(`libil2cpp.so`)를 디컴파일해야 하는데, IL2CPP 덤프 도구가 설치되어 있지 않아 하지 않았다.
2. **`lifeWay=0`의 수명 값** (`life=1` 또는 0.1~6): 단위를 모른다. 화면 밖 소멸로 가정했다.
3. **각도 기준**: `m_angle=0`이 발사구의 정면이고 부채는 정면을 중심으로 대칭이라고 가정했다. `inheritAngle=0`은 발사구 회전을 무시하는 것으로 해석했다.
4. **회전 발사구**: Legacy 애니메이션은 2건(OceanBOSS 3단계, TankBOSS_Heavy 3단계)만 확인했다. Boss_Spider의 `xuanzhuan`(회전) 노드 등은 Animator(비-Legacy) 클립이라 곡선을 읽지 않았다. `motorboss` 선회는 기체 전체 연출로 보인다.
5. **화면 환산**: 원근 카메라라서 9u는 근사치다. 플레이어 판정 크기와 정확한 화면 경계는 확인하지 못했다.
6. **`waveType` 1/3/4/5**, `stageBulletWeaken [0.1, 0.4, 0.7]`(`game_base_config`)의 의미를 모른다. 후자는 탄 약화 계수일 가능성이 있다.
7. **`manualShot` 발사구**(잠수함 미사일, CloudMaster)의 발사 시점은 애니메이션 이벤트가 정한다. 해당 클립 이벤트(`type:1~6` JSON)의 의미는 해석하지 못했다.
8. `GhostFighter`(엘리트 웨이브 동반)는 프리팹에 발사구가 없다. 플레이어형 무장을 코드로 붙이는 것으로 보이며 확인하지 못했다.

---

## 8. Shootingstar 적용 제안

원칙:
- 수치는 원본 비율을 따른다. 그림·이름은 새로 만든다.
- 단위는 원본 u/s를 그대로 적고, 구현할 때 `px/s = spd × (뷰포트 세로 px / 9)`로 바꾼다.
- 탄 모양: **구슬**(소형 원), **큰구슬**(그림만 큼, 판정 작음), **바늘**(길쭉), **막대**, **미사일**, **빔**, **초승달**, **기뢰**.
- 아래 표의 값은 모두 원본의 어떤 프리셋에서 가져왔는지 `출처` 칸에 적었다. 원본과 다르게 바꾼 부분은 [조정]으로 표시했다.

### 8.0 공통 발사 명세 (구현용 데이터 구조 제안)

```dart
class EmitSpec {            // = 원본 m_emitParam 1개 (큐 항목)
  String root;              // 발사구 이름
  BulletShape shape;        // orb/bigOrb/needle/bar/missile/beam/crescent/mine
  int total;                // 총 탄 수 (-1 = 무한)
  int ways;                 // 한 볼리의 갈래 수
  double stepDeg;           // 갈래 사이 각도 (0이면 평행)
  double gapPos;            // 평행 간격
  double gapSec;            // 볼리 사이 간격
  double speed, accel, minSpeed, maxSpeed;
  double angleOffsetDeg;    // 오프셋 (겹 링)
  double shiftDegPerVolley; // 나선(0이 아니면 볼리마다 회전)
  double sweepRangeDeg, sweepSpeed; // 사인 스윕
  RandomRange? jitter;      // 속도/각도/위치/지연 무작위
  bool aimed;               // 플레이어 조준(볼리 시작 시점)
  double homingDegPerSec, homingTime, homingReleaseRadius;
  double sineSpeed, sineAmp;     // 곡선탄
  bool chain;               // 한 줄 연결(바늘 열차)
  bool followEmitter;       // 빔
  double warnLeadSec, warnShowSec; // 예고
  double releaseSec, lifeSec;
  double dmgCoef;           // 원본 m_atkAddition
  double afterDelay;        // 다음 항목 시작까지 (시작 기준)
}
class Pattern { double startDelay; bool loop; List<EmitSpec> queue; }
class Part { double hpMul; double trackDegPerSec; List<Pattern> emitters; }
class Phase { List<Part> parts; String? enterAnim; }  // 부위 전부 파괴 시 다음 단계
```

### 8.1 일반 적 패턴 13종

| # | 이름(제안) | 발사형 | 갈래/각도 | 볼리·간격 | 속도 | 주기·지연 | 탄/피해 | 출처 |
|---|---|---|---|---|---|---|---|---|
| N1 | 조준 단발 포대 | 조준 | 1 | 1 | 1.0 | 2.0s (포신 120°/s) | 구슬 / 1.0 | `DanGuanPao_1` |
| N2 | 조준 3점사 | 조준 | 1 | 3발, 0.18s | 1.4 | 4.0s | 큰구슬 / 0.5 | `DanGuanPao` |
| N3 | 직사 연사포 | 고정 | 1 | 3~7발, 0.21s | 1.0 | 2.4~5.0s | 구슬 / 1.0 | `lianshepao*` |
| N4 | X자 4방향 | 고정 링 | 4 / 90°, +45° | 1 (강화형 5볼리 0.15s, 가속 0.2) | 1.0 | 4~5s | 구슬 / 0.5 | `sandanpao_4_01/02` |
| N5 | 겹 링 포대 | 링 | 8 또는 16 / 45°·22.5° | 3겹, 0.1s, 오프셋 0/+4/+8° | 1.0 | 5.2s | 구슬 / 0.5 | `sandanpao`, `_8_02` |
| N6 | 회전 삼지창 | 나선 | 3 / 120° (강화 5 / 72°) | 10볼리, 0.28s, −12°/볼리 | 1.0 | 8s | 구슬 / 1.0 | `sanshepao`, `_up` |
| N7 | 6방향 맥동 | 링 | 6 / 60° | 3볼리, 0.4s | 0.7 | 4s | 구슬 / 1.0 | `sanshepao_1` |
| N8 | 사인파 쌍줄기 | 곡선 | 발사구 2 | 45발, 0.05s | 2.5 | 4s (sin 속도 24, 진폭 18/8) | 바늘 / 1.0 | `jiguangpao` |
| N9 | 예고 쌍저격 | 평행 | 2, 간격 0.3 | 1 | 6.0 | 2.4s, 1s 전 0.8s 예고, 포신 200°/s | 바늘 / 0.75 | `gaoshepao` |
| N10 | 예고 레이저 포탑 | 빔 | 1 | 예고 0.6s → 펼침 0.6s → 빔 0.4s | — | 6s, 추적 30°/s | 빔 / 0.2×틱 0.05s | `Tank_Laser`, `bullet_general_laser` |
| N11 | 유도 미사일 쌍 | 유도 | 좌·우 1발씩 | 좌 → 5s → 우 | 1.8 | 8s, 유도 300°/s, 해제 0.8 | 미사일 / 1.0 | `helicopter_small` |
| N12 | 근거리 개틀링 | 무작위 평행 | 2열, 간격 0.25 | 10발, 0.03s, +0~1 속도 | 3.0 | 6s, 수명 0.4s | 구슬 / 1.0 | `Tank_Gatlin` |
| N13 | 자폭 기뢰 | 기뢰 | 5 / 72° | 사망 시 1회 | 1.8 → 0.6s 뒤 정지 | 수명 60s [조정: 10~15s 권장] | 기뢰 / 1.0 | `Unit_Monster_Bomb` |

보충:
- **잡몹 편대는 쏘지 않는다** [관찰]. Shootingstar에서도 5~12기 편대(0.5s 간격, 속도 2)는 돌진·충돌형으로 두고, 탄은 포대와 헬기에 맡기는 편이 원본 구조에 가깝다.
- 지상 포대에는 "포신 추적 속도"(20~200°/s)를 꼭 넣는다. 원본은 조준탄 대신 **느리게 돌아가는 포신**으로 피할 여지를 만든다(예: 추적 20°/s + 고정탄).
- 1발 피해 계수는 원본처럼 링·산탄 0.5, 조준 연사 0.15~0.4, 저격 2.5로 차등을 둔다.

### 8.2 중간 보스 6세트 (HP 30×, 웨이브 14/28/42)

엘리트는 "일반 헬기 패턴 + 템포 상승"이 원본 방식이다. 각 세트에 "기본 / 강화(difficult) / 광폭(crazy)" 사다리를 함께 둔다.

| # | 세트 | 기본 (일반 헬기, HP 5×) | 강화 엘리트 | 광폭 엘리트 | 출처 |
|---|---|---|---|---|---|
| M1 | 3갈래 포격기 | 3갈래 16° 큰구슬 spd 1, start 2s, 3s | 주기 1.5s | 3연(0.25s, 마지막 17°), 2.1s | `helicopter` → `Sboss_helicopter_difficult` → `_crazy` |
| M2 | 조준 연사기 | 12발 0.07s spd 1.6 조준, 5.6s, 피해 0.15 | 주기 1.6s, 피해 0.5 | [조정] 주기 1.2s + 2발사구 | `helicopter_01` → `Sboss_helicopter_01` |
| M3 | 미사일 헬기 | 좌·우 유도(300°/s) spd 1.8, 8s | 4.4s | 2.8s (최상위: 큰 미사일, 2.0s) | `helicopter_small` → `Sboss_helicopter_small_*` |
| M4 | V자 견제기 | 2갈래 16°를 +24°/−26° 양쪽에 각 4연(0.5s) spd 0.8, 5s | + 조준 큰 바늘 2발(0.5s) spd 1.5, 3s | V자 무한(1.8s마다) + 조준 2발(1.2s), 4s | `Sboss_helicopter_crazy_2`, `_difficult_1` |
| M5 | 막대 레이저 포격기 | 막대 5발 0.14s spd 3.2 한 줄 조준, 3s | 쌍 개틀링 13발 0.07s spd 5 ±2°, 4s 추가 | [조정] 둘 다 주기 ×0.6 | `syzsj`, `helicopter_03` |
| M6 | 다중 무장 소보스 | 15갈래 16° 부채 ±14° 무작위 spd 2, 5s + 평행 유도 2발(30°/s), start 2.5s, 5s | 3갈래 10° ×3(0.4s) spd 2, 3s + start 6s 조준 고속 평행 2발 spd 6, 5s | 사망 시 12방향 링 ×2(0.3s 차, 0.01 → 가속 3) | `smallboss1`, `smallboss4`, `helicopter_02_1` 2단계 |

참고 패턴:
- `smallboss2`: 8갈래 2° 다발 ×3을 5s마다, 평행 큰 바늘을 1.8s마다
- `smallboss3`: 평행 유도 2열 ×4, 10갈래 12° 부채
- `CloudMaster`: 전기구 3갈래 11° 조준 spd 4, 6s, 충돌형, 속도 2.5

### 8.3 스테이지 보스 11세트 (부위 파괴 단계제)

컷 = 원본 단계별 HP 비중. 단계가 5~7개인 원본은 3~4페이즈로 묶었다(묶은 경우 `원본 단계` 칸에 표시). **페이즈 전환 조건은 HP%가 아니라 "그 페이즈 부위 전부 파괴"**로 구현하기를 권한다. HP%로 구현하려면 컷 비율을 그대로 쓴다.

**B1 지상 전차 (tankBOSS, 총 60×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 | 50% | 주포: 큰 탄 1발 spd 3, start 2s, 4s, 추적 20°/s ／ 측포 2: 8발 0.08s spd 1, start 1.2s, 3s, 추적 120°/s |
| P2 | 2 | 17% | 3연장 포탑: 포구 3개 동시, 포구당 굵은 탄줄(20발 동시) spd 1, start 2s, 4s [조정: 포구당 5발 0.05s 연사 권장] |
| P3 | 3 | 33% | 몸체(무장 없음) + 호위 헬기 2(N11) |

**B2 공격 헬기 (hyzhishengjiBOSS, 60×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 | 67% | 측면 2: 조준 22발 0.04s spd 1.2, 6s ／ 머리 2: 긴 바늘 14발 열차 0.06s spd 2.5, start 4s, 5s |
| P2 | 2 | 17% | 상단: 18갈래 22.5° ×3겹(+3°, +6°, 0.05s) spd 2.5, 5.1s |
| P3 | 3 | 17% | 몸체가 바늘 열차를 계속 쏨 |

**B3 대형 헬기 (helicopter_boss, 170×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 | 18% | 포탑 2: 10갈래 2° 조준 긴 탄 spd 3, 3s ／ 전방: 3갈래 5° ×5연 0.05s spd 2, ±0.2, 6s |
| P2 | 2 | 18% | 포드 2: 16방향 3겹(+2.5°, +5°) **spd 0.5**, 2.2s ／ 측면: 조준 6발 1s 간격 spd 1.2, 6s |
| P3 | 3+4 | 29%+29% | 좌 → 우 선회하며 13갈래 9.5° 부채 spd 1(start 4s/7s, 9s) ×3문 + 조준 큰구슬 3발 0.15s spd 2 쌍포, 9s |
| P4 | 5 | 6% | 몸체 |

**B4 폭격기 (Boss_Airplane_Big, 190×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 | 16% | 머리 4발사구: 12발 0.052s spd 2.3, 3.5s ／ 상부: 3갈래 13° 긴 탄 spd 3, start 3s, 4s |
| P2 | 2+3 | 16%+16% | 엔진 발사구 6~8개가 start 0.5~7.5s로 엇갈려 각자 16방향 3겹 링(+3/+6°) 또는 7연 링 spd 2, 9s 주기 → 약 1s마다 링 ／ 날개포: 조준 5발 0.15s spd 2, 3s |
| P3 | 4~6 | 16% ×3 | 꼬리 3세트를 차례로: 16방향 3겹(+4/+8°) spd 2, 2.2s + 양옆 조준 단발 spd 2, 4s |
| P4 | 7 | 5% | 머리 연사만 남음 |

**B5 중전차 (TankBOSS_Heavy, 160×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 | 25% | 상부 2 × 4발사구: 긴 바늘 30발 열차 0.1s spd 3, start 2.0/2.3/2.6/2.9s, 6s ／ 측포 2: 12발 0.08s spd 2, 6s |
| P2 | 2 | 31% | 전방 2: 조준 큰구슬 3발(1s) spd 2, 3s ／ 후방 2: 조준 바늘 spd 6, 5s ／ 중앙: 추적 빔(10°/s, 예고 1.8s, 빔 2s, 6s) |
| P3 | 3 | 31% | 풍차: 7갈래 51.4° × 26볼리 0.2s spd 1, 포탑 ±25° / 3.5s 왕복 ／ 로켓 2: 3갈래 13° spd 3, 4s |
| P4 | 4+5 | 6%+6% | 최후 폭발 12방향 spd 5 1회 → 몸체 |

**B6 열차 (TrainBoss, 140×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 | 21% | 포 2(추적 80°/s): 조준 15발 0.05s spd 3, 4.5s ／ 회전포: 6갈래 60° × 10볼리 0.2s, −10°/볼리 나선 spd 1, 6s |
| P2 | 2 | 36% | 전차 4(추적 50°/s): 조준 막대 4발 0.1s spd 3.2, start 0/1.5/3/4.5s, 6s ／ 연사포: 3갈래 10° spd 1, 0.8s마다(추적 10°/s) |
| P3 | 3 | 36% | 포 2: 6갈래 5° ×2(0.2s) spd 0.8, 4s ／ 기관포 2: 조준 바늘 spd 6, 5s ／ 로켓: 유도 spd 1.5, 120°/s, 2s |
| P4 | 4 | 7% | 몸체 |

**B7 전함 (OceanBOSS, 160×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 | 31% | 포 2(추적 20°/s): 30발 0.05s spd 1, 3.4s ／ 포 2: 긴 탄 12발 0.08s spd 2.5, start 4s, 6s ／ 로켓: 평행 3발 조준 spd 6, 4s |
| P2 | 2+3 | 19%+19% | 포 2: 조준 큰구슬 20발 0.1s spd 1.2, 4s ／ 로켓 6관 물결(0.2s 엇갈림, 2발 spd 6), 3s ／ 이어서 **스윕 회전대**: 6줄기 × 70발 0.02s spd 1.5, ±27° / 3.5s 왕복, 3.2s + 대공 쌍저격(N9) |
| P3 | 4 | 25% | 8발사구 산발 비(4발 0.4s spd 4, 지연 0~0.8 무작위), 6.5s ／ 로켓 3: 조준 평행 2발 spd 6, start 4.3/4.8/5.1s |
| P4 | 5 | 6% | 코어: 로켓 1기 |

**B8 거미 전차 (Boss_Spider, 120×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 | 38% | 등포(추적 60°/s): 큰구슬 20발 0.06s spd 1.5, 4s ／ 좌·우 포드: 유도 4발 0.2s spd 3, 300°/s, start 0/2s, 4s |
| P2 | 2 | 50% | 좌·우: 30방향 링 spd 3 2연(0.6s 차), 4s ／ 전방 4줄기 근거리 화염형: 32발 0.09s spd 6, 수명 0.65s, 추적 15°/s, 6s ／ 소포: 예고 평행 쌍탄 spd 6 |
| P3 | 3 | 12% | 몸체 |

**B9 쌍둥이기 (GeminiBoss, 150×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 | 27% | 머리: 감속 샷건 커튼(바늘 80발 0.008s spd 6, 감속 −3, 수명 2s, ±15° 스윕, ±4° 무작위), 4s ／ 내포: 조준 8발 spd 5~7 ±1.5°, 4s ／ 측포 2: 조준 20발 0.05s spd 1.5, 4s |
| P2 | 2 | 27% | 머리: 6갈래 8° ×4(0.4s) spd 2.4, 4s ／ 내포: 유도 5발 0.5s, 180°/s ／ 측포 2: 조준 긴 바늘 열차 8발 0.07s spd 4 |
| P3 | 3 | 33% | 채찍 포탑 4: 15발 0.02s ±3°/발, spd 3, start 0/1/2/3s, 7s ／ 눈알 추적 빔(20°/s, 예고 0.7s, 빔 0.8s, 2s) |
| P4 | 4 | 13% | 순차 빔 4문: start 1/2/3/4s, 예고 2s → 빔 4s, 5s 주기 |

**B10 잠수함 (SubmarineBoss, 160×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 (원본 2단계는 같은 구성 반복) | 31% | 16방향 3겹 링 spd 1 ×2세트(1s 차), 5.2s ／ 예고 평행 쌍탄 spd 6, 6.5s ／ 사일로: 뒤로 쏜 미사일 6발 평행, 가속 0.5(최대 15) |
| P2 | 2 | 31% | P1과 같게 + [조정] 링 주기 4.0s |
| P3 | 3 | 31% | 추적 빔(30°/s, 예고 1.8s, 펼침 2.3s, 빔 2s, 4s) ／ 유도 평행 2발 ×(0.5s) 180°/s, 3.5s ／ 30발 0.05s spd 1(추적 20°/s), 3.4s |
| P4 | 4 | 6% | 코어 |

**B11 얼굴 요새 (FaceBoss, 260×)**

| 페이즈 | 원본 단계 | 비중 | 부위·패턴 |
|---|---|---|---|
| P1 | 1 | 23% | 입: 긴 빔 5s(예고 0.7s, 펼침 0.9s, 7s) ／ 눈 2: 짧은 빔 0.4s(추적 30°/s, 6s) ／ 아래 2: 3갈래 10° ×2 spd 2, 4s ／ 방패 부위(무장 없음) |
| P2 | 2 | 31% | 입: 바늘 6발 spd 6~7 ±4°, 6s ／ 상단 2: 뒤로 쏜 미사일 커튼 6발(위치 ±1, 속도 0~4), 1회 ／ 눈 2: 초고속 저격 spd 8, 피해 2.5×, 예고 0.6s, 6s ／ 아래: 유도 3발 0.6s, 120°/s |
| P3 | 3 | 42% | 입: 초승달 3갈래 20°(크기 0→3, 수명 4s) spd 2, 8s ／ 눈: 채찍 호 8발 ±4°/발 spd 2, 4s ／ 포탑 6: 16방향 링 spd 2, start 0~15s를 3s씩 엇갈림, 10s ／ 레이저 5: 긴 바늘 30발 열차 0.1s spd 3, 1s씩 엇갈림, 10s |
| P4 | 4 | 4% | 빈 코어 |

(이벤트 보스 참고: `DevastatorBoss`의 **시간표 교대**(상시 무장 + 17s마다 무장 교체, 52s 루프)는 "부위 파괴 없이 시간으로 바뀌는 보스"가 필요할 때 쓸 수 있는 원본 사례다.)

### 8.4 난이도 노트 (원본 수치)

1. **HP 배율** (같은 레벨 잡몹 대비): 소형 헬기·포대 5×, 중간 헬기 총좌 5×(몸체 0.01×), 특수 7×/10×, **엘리트 30×**. **보스 총합은 초반 60×, 중반 120~190×, 후반 260×.** 단계 하나는 10~110×이고 마지막 코어는 항상 10×(4~7%)다.
2. **배치**: 50웨이브 스테이지에서 엘리트는 14·28·42번째, 보스는 50번째(1스테이지만 30웨이브/30번째). 웨이브 14·42는 waveType 1(특수)이다.
3. **레벨 성장**: 스테이지 안에서 적 HP는 레벨 x01 → x14 사이에 약 64배, 공격력은 1.5배 오른다. 3~4웨이브마다 레벨이 하나씩 오른다. Shootingstar의 현장 성장 곡선과 맞추려면 "HP는 기하급수, 탄 피해는 완만"이라는 원본 구조를 따른다.
4. **엘리트 템포 사다리** (같은 패턴): 주기 ×0.5(강화), ×0.35 또는 3연발(광폭), 유도 미사일은 8s → 4.4s → 2.8s → 2.0s.
5. **탄 피해 계수**: 링·부채 0.5, 조준 연사 0.15~0.4, 빔 0.2/틱(0.05s), 단발 큰 탄 1.0, 고속 저격 2.5. 탄 수와 1발 피해는 반비례로 둔다.
6. **예고(텔레그래프)**: 빔은 예고 0.6~2.0s, 펼침 0.6~2.3s, 지속 0.4~5s. 고속 저격·평행 쌍탄(spd 6~8)도 반드시 0.6~0.8s 예고가 있다. 추적 빔의 포신 추적 속도는 10~30°/s로 느리다.
7. **속도 범위**: 큰구슬·링 0.5~2.5(대부분 1~2), 바늘·저격 3~8. 빠른 탄은 예고와 짝을 이루거나 근거리(수명 0.4~0.65s)로 제한한다.
8. **동시 패턴 수**: 보스 한 단계에는 보통 부위 3~5개가 각자 다른 주기(3~10s)와 start 지연(0~15s)으로 엇갈려 쏜다. 한 화면에 한 종류 탄만 몰리지 않게 하는 것이 원본 방식이다.
