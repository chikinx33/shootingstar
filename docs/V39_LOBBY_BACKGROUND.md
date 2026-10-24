# v10.0.39 메인 로비 배경 흐름

요청: 메인 로비의 배경이 천천히 흐르도록 한다.

## 구현

`RefitBackdrop`이 전용 Ticker/ValueNotifier를 소유한다. 장면 시간은 실제1초당0.35초로 증가해 기존 그림이 아래로 초당4.2논리px 이동한다. 배경만 RepaintBoundary 안에서 다시 그리며, 기체와 조작은 같은 자리에 유지한다. 원본 이미지/음향·저장·전투 수치와 전투 배경 속도는 바꾸지 않았다.

출격 탭에서만 동작한다. 다른 경로/옵션으로 덮이면 `ModalRoute.isCurrentOf`, 세로 회전 안내 등의 TickerMode, 앱 lifecycle, `Profile.reducedEffects`와 OS `disableAnimations`에 따라 멈춘다. 재개 시 이전 경과 시계를 버리고 한 프레임 최대50ms만 반영해 장면이 크게 점프하지 않는다. 제거 시 Ticker/observer/notifier를 정리한다.

로비의 대칭 타일 반복은2장 높이를 주기로 사용한다.1장 주기에서 방향이 갑자기 뒤집히는 경계를 제거하며, 전투의 기존 계산은 유지한다.

추가 검사에서360×640 기본 글자의 기체 설명이9px 넘치는 기존 로비 문제를 확인했다. `FixedLobby`의 기체 그림을 Flexible로 감싸 설명/무기 버튼을 배치한 뒤 남은 공간으로 제한했다. 글자/버튼 크기나 고정 화면 스크롤 규칙은 바꾸지 않았다.

## 검사

- 새 동작4개: 일정 프레임에서 느린 속도/기체 조작의 빌드 횟수·위치/클릭, 경로와 앱 비활성 정지·재개, 탭/효과 축소/OS 축소/TickerMode, 두 타일 경계의 픽셀 연속성.
- 정적 UI fixture는 효과 축소를 명시해 무한 장식 애니메이션을 pumpAndSettle로 기다리지 않는다. 관련9파일73개 중 초기72개 통과, portrait360에서 위9px 넘침1건을 발견했다. 이를 숨기지 않고 수정했다. 최초 보고서 `.local/quick-web/20261020-132711-372420/report.json`, 정확한 원인 `.local/lobby-v39/portrait-failure.log`.
- 수정 후 portrait/4폭×글자1.0·1.3 로비 규격 등26개 통과. `.local/quick-web/20261020-132847-221506/report.json`.
- 정식 진입점의390×844 실제 웹 화면:2초 뒤 배경 PNG 영역은 달라지고 버튼 내부 그림과 조작 좌표는 동일했다. 옵션 창으로 덮인 상태와 효과 축소 후 배경 픽셀은 고정되고, 효과를 되살리면 다시 이동했다. 브라우저 예외/넘침0건. `tools/qa/evidence/lobby-v39/report.json`과 `lobby-before.png`, `lobby-after-2s.png`.
- 위 픽셀 검사의 마지막 SDK API 정리 전 코드는 TickerMode.of였으며 최종 코드는 동일한 enabled 값을 제공하는 TickerMode.valuesOf를 사용한다. 최종 새 동작4개와 정식 출격 검사는 별도 보고서에 기록한다. 실제 앱 백그라운드는 widget lifecycle 검사이며 Android 기기 검증을 수행한 것은 아니다.

## 최종 결과

- 최종 `dart analyze lib` 종료0, 기존 info19건이며 신규 deprecated API 알림은 해소했다. 최종 배경 동작4개 통과.
- 정식320px 로비→옵션의 컴파일된 버전 확인→첫 출격 안내→출격→일시정지 통과. 하단 버전 부재·고정 내비게이션 유지. `tools/qa/evidence/quick-web/10.0.39-55/smoke.json`.
- `.local/quick-web/20261020-133030-973976/report.json`: 정식 O2 웹 빌드/스모크/업로드/활성 API 확인 전체77.63초. Worker `ff9b5061-e425-455f-ab35-357cbd07b73e` 트래픽100%, API `10.0.39`/D1 정상. 과금/광고는 실제 ID 미입력으로 false 유지.
- 공개 정적 화면은 기존 Cloudflare Access 차단 근거를 재사용했다. 공개 UI 직접 확인이나 Android 기기 성능 검증으로 간주하지 않는다. 기존 로컬8797 서버는 유지했고 사용자 진행 저장소는 수정하지 않았다. APK 빌드 없음.
