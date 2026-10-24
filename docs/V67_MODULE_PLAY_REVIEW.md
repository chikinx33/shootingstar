# v10.0.67 파츠 장착·실전 발사 일치 점검

기준은 사용자 제공 모듈 설계서다. 무기3종×위치4개를 같은 레벨/인스턴스로 옮겨 비교한다. APK는 빌드하지 않는다.

## 발견 및 수정

- 발사 섬광은 포구에서 위로30만큼 이동하고 무조건 위쪽을 향했다. 새 기체 주포/파츠 섬광은 실제 포구와 발사축에서 짧게 번쩍인다. 기존 다른 적탄/피격 연출은 유지한다.
- 무기 그림의 총열/미사일 끝과 발사 원점의5 고정값을 없앴다. 공통 ModuleGeometry의 파츠 크기/끝 좌표로 본체 소켓·포구·그림을 맞춘다. W3 확산탄과 강화된 W2 다발도 같은 실제 포구에서 갈라진다.
- 떠 있는 파츠의 이동 지연과 화면 탄의 출발을 맞추되, 조종·피격/공격 판정은 시각적 흔들림에 종속시키지 않는다. 발사 순간 시각 오프셋을 탄에 기록하고45ms 안에 자연스럽게 줄인다. 화면 밖으로 순간 이동하는 본체 반동은 추가하지 않는다.
- W1 미사일은 우측 탄을 미리 화면에 세워 놓지 않는다. 대기 중에는 숨기며, 실제 우측 발사 시점의 움직인 소켓에서 출발한다. 섬광/반동도 그때 발생한다. 좌우 반동은 독립적이다.
- W4 미사일 그림은 목표를 향해 회전하지 않고 수직 발사 방향을 유지한다. 상승한 모탄이 최근접3표적 위로 실제 낙하탄을 분리하고, 내려와 닿을 때 폭발한다. 낙하 위치에는 작은 아군 색 표식을 쓴다. 비행·표적·분리 상태는 기존 체크포인트 필드로 저장된다.
- 미사일도 하부 관통/레벨 관통 수치를 실제로 소비하며 추가 표적을 타격한다.
- 드론에 정사영 직사각형 포신을 표시한다. 좌우/전방/후방/공전 편대의 타깃 선택 함수를 렌더와 공격에서 공유하고, 기체와 별도로 회전해 자기 포구에서 발사한다. 드론별 반동은 모선의 빈 소켓을 흔들지 않는다.
- 새 파츠 탄환/미사일은 같은 단순한 메카닉 화풍으로 그리고, 미사일의 실제 비행 방향에 꼬리를 붙인다. 다른 무기/적탄의 그림은 교체하지 않는다.
- W2/W4 초기 탄이 기체 안쪽에서 가려지지 않도록 새 파츠 탄만 본체/드론 위에 그린다.

## 검증

- test/module_play_review_test.dart:12조합의 포구/섬광 일치, 이동 중 교대 발사, 드론 포신 조준, 상승→분리→낙하, 낙하 중 저장 후 결정적 복원. 별도 실브라우저용12개 독립 저장 생성.
- test/ship_modules_test.dart:기존 이관/독립 레벨/이동 장착/지상 타격/세이브/카드/보급/320px 구조 회귀. 상부 미사일 검사는 새 실제 낙하 시간을 기다려 타격을 확인한다.
- 정식 웹의 tools/qa/quick-smoke.cjs 선택 모드 QA_MODULE_PLAY_REVIEW=1:사용자 프로필과 분리한390×844 브라우저 컨텍스트에서 눈→슬롯→같은 보유 파츠→장착을 실제 클릭한다. 고정한 주변 표적이 있는 저장된 전투를 이어가서 실제 포인터 조종/발사/정지를 실행한다. 슬롯 이동/저장과 실제 피해를 검증하고 조합별 화면/재생 영상을 남긴다. 예측 수치만으로 실제 플레이 통과를 주장하지 않는다.
- 인앱 브라우저 제어는 이 세션에서 제공되지 않아 독립 브라우저 자동 플레이로 검증한다. 사람의 주관적 타격감 평가나 Android 실기기 검증과는 구분한다.
- 일반320px 로비·가이드·출격·정지/활성 배포·API 확인은 기존 quick-web 경로1회다. 정적 페이지의 Access 제한은 기존 근거를 재사용한다.

실제 실행 결과와 증거 경로는 작업 완료 시 아래에 기록한다.

배포 완료 기록: .local/quick-web/20261022-055534-852997/report.json. 동일 최종 웹 빌드 재사용,320px 기본 플레이 통과, Worker96d93b32-898f-4951-9c46-5776cefc2bfa 트래픽100%, health.ok=true/version10.0.67 확인. 실제 정적 페이지의 Access 제한은 이전 근거를 재사용했다. 로컬 플레이8797 유지.

## 최종 웹 플레이 결과 (2026-10-22)

관련 모델/위젯 검사17개 통과(기존12개 + 추가5개). 최종 정식 웹 빌드39.63초. 최종 빌드의 독립 브라우저12조합 모두 UI 장착/이동과 전투 저장 일치, 실제 피해 발생, 런타임 오류0개를 확인했다. 기존 기본320px 로비/출격/정지도 별도로 통과했다. Android APK는 빌드하지 않았다.

아래 피해량은 약3.6~3.8초의 고정 주변 표적 자동 플레이 기록이다. 진행 시간과 피격/관통/범위/사선 적중 차이가 있으므로 정규화한 DPS나 최종 밸런스 순위로 사용하지 않는다.

| 무기 | 위치 | 실제 전투 초 | 실제 피해 | 화면 | 영상 |
|---|---|---:|---:|---|---|
| 건 | W1 | 3.72 | 92.3 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/gun_vulcan-W1.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/gun_vulcan-W1.webm) |
| 건 | W2 | 3.71 | 114.8 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/gun_vulcan-W2.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/gun_vulcan-W2.webm) |
| 건 | W3 | 3.67 | 29.7 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/gun_vulcan-W3.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/gun_vulcan-W3.webm) |
| 건 | W4 | 3.69 | 39.6 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/gun_vulcan-W4.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/gun_vulcan-W4.webm) |
| 미사일 | W1 | 3.71 | 95.2 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/missile_hawk-W1.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/missile_hawk-W1.webm) |
| 미사일 | W2 | 3.74 | 126.9 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/missile_hawk-W2.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/missile_hawk-W2.webm) |
| 미사일 | W3 | 3.74 | 122.4 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/missile_hawk-W3.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/missile_hawk-W3.webm) |
| 미사일 | W4 | 3.67 | 36.3 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/missile_hawk-W4.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/missile_hawk-W4.webm) |
| 드론 | W1 | 3.73 | 50.5 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/drone_wasp-W1.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/drone_wasp-W1.webm) |
| 드론 | W2 | 3.69 | 57.7 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/drone_wasp-W2.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/drone_wasp-W2.webm) |
| 드론 | W3 | 3.69 | 55.6 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/drone_wasp-W3.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/drone_wasp-W3.webm) |
| 드론 | W4 | 3.71 | 18.5 | [화면](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/drone_wasp-W4.png) | [재생](F:/NKW/App/Shootingstar/tools/qa/evidence/module-play-v67/videos/drone_wasp-W4.webm) |

정본 실행 기록: tools/qa/evidence/module-play-v67/module-play-review.json. 각 영상은 실제 장착 UI부터 시작하며, 고정 표적 전투를 이어간 뒤 실제 포인터 입력으로 조종한다. 최초 검사의 일부 실패는 이어하기 버튼 이름과 팝업 진입/닫힘 애니메이션을 기다리지 않은 검사 문제였으며, 해당 대기를 교정했다. 새 파츠 탄 표시 순서 변경 후 최종12조합을 다시 확인했다.
