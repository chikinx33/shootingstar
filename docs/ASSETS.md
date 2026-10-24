# 에셋 원본과 출처

## 생성 이미지

아래 PNG 6개는 기본 `image_gen` 도구로 이 실행 작업에서 직접 생성했습니다. 기존 게임의 이름·캐릭터·로고·이미지를 입력하지 않았습니다. 도구가 반환한 원본 PNG 바이트를 그대로 프로젝트에 저장했으며, 게임은 아래 파일을 직접 참조합니다.

| 파일 | 용도 | 확인 |
|---|---|---|
| `assets/art/shootingstar_title_art.png` | 타이틀·출격 화면 배경 | 1024×1536 원본을 직접 열어 시각 확인 |
| `assets/art/shootingstar_interceptor.png` | 오로라: 격납고·전투 | 1122×1402, RGBA, 위쪽 방향 |
| `assets/art/shootingstar_scout.png` | 벡터: 격납고·전투 | 1050×1498, RGBA, 가늘고 긴 고속 기체 |
| `assets/art/shootingstar_bastion.png` | 모노리스: 격납고·전투 | 1254×1254, RGBA, 넓은 금빛 중장갑 기체 |
| `assets/art/shootingstar_enemy_hunter.png` | 일반·고속·정예 적 | 1254×1254, RGBA, 붉은 적 드론 |
| `assets/art/shootingstar_boss_fortress.png` | 전 항로 보스 | 1254×1254, RGBA, 보라색 집게 날개와 금빛 코어 |

기체 3종은 각기 다른 생성 원본을 사용합니다. `ShipSpec.asset`이 격납고와 실제 전투의 동일 기체 파일을 연결합니다. 모든 스프라이트는 위쪽이 앞이며, 렌더러에서 원래 종횡비와 알파를 유지한 채 이동 방향으로 회전합니다. 디코딩 크기는 플레이어 192px, 적 128px, 보스 320px로 제한하지만 원본 PNG는 수정하지 않습니다. 정예는 크기와 보라색 테두리로 추가 구분합니다. 탄환·호위 드론·폭발·경고 구역은 자체 Canvas 도형입니다.

스프라이트 5개의 실제 디코딩, 투명한 모서리, 표시 가능한 본체 픽셀, 고유 기체 경로를 `test/assets_test.dart`에서 검증합니다. 부모 대화에서 생성한 별도 Library 이미지 6종은 공식 전송 도우미의 Windows `os.setxattr` 미지원으로 확보하지 못해 사용하지 않았습니다. 이번 6개는 별도로 직접 생성한 로컬 프로젝트 원본이며, 전송 도우미를 변형하거나 비공식 경로로 우회하지 않았습니다.

### 타이틀 생성 프롬프트

> Use case: stylized-concept. Create original premium indie sci-fi flight survival game title artwork, vertical 2:3 portrait. A sleek ivory and dark navy exploration interceptor with luminous cyan thrusters flies upward into a vast ink-blue starfield. Small hostile amber drones circle far away. Lower third a curved broken orbital ring and subtle nebula. Strong restrained cinematic graphic composition, detailed painterly 3D spacecraft, not photoreal, sophisticated dark navy/cyan/amber palette. Main spacecraft in lower half facing toward upper edge, top 45 percent dark negative space for separately rendered title. No text, no letters, no logos, no watermark. Intended game named Shootingstar, completely original not any existing franchise.

### 기체 생성 프롬프트

> Use case: stylized-concept. Asset type: transparent 2D game spacecraft sprite. A single original sleek ivory and dark navy sci-fi interceptor, bright small cyan cockpit and two cyan engine glows. Strict orthographic TOP DOWN view, nose pointing directly UP at 12 o'clock. Symmetrical swept wings, clear bold silhouette, isolated centered with generous transparent padding, ship occupies 80% of canvas height. Premium hand-painted 3D game illustration with crisp silhouette that reads at 48 pixels. No perspective angle, no scenery, no ground shadow, no background, no lettering, no logos, no grid. Genuinely transparent PNG background, preserve alpha. Completely original design.

## 추가 스프라이트 생성 프롬프트

기본 도구를 사용했고 네 요청 모두 `transparent_background: true`였습니다. 동일한 원문은 [asset-prompts.json](asset-prompts.json)에도 보관했습니다.

### `assets/art/shootingstar_bastion.png`

> Use case: stylized-concept. Asset type: transparent 2D space shooter sprite. Create one completely original spacecraft, strict orthographic TOP DOWN view, nose toward 12 o'clock (UP), bilaterally symmetric, isolated centered with transparent padding on all sides. Crisp premium hand-painted 3D game illustration with simplified large shapes, readable when rendered at 48 pixels. Genuinely transparent PNG background. No perspective, no scenery, no ground shadow, no text, no letters, no logos, no grid, no watermark. Subject: a heavy armored player spacecraft, ivory-white layered armor over a dark navy chassis, warm gold lights and two cyan engine exhausts pointing DOWN. Very broad compact hull, squared shoulder armor, two thick outer nacelles, short central forward nose. Massive protective silhouette, clearly unlike a slender fighter. Same design family as a sleek ivory/navy/cyan exploration interceptor. The entire craft and subtle engine glow must fit inside the canvas. Ship occupies 78% width and 74% height of square canvas.

### `assets/art/shootingstar_scout.png`

> Use case: stylized-concept. Asset type: transparent 2D space shooter sprite. Create one completely original spacecraft, strict orthographic TOP DOWN view, nose toward 12 o'clock (UP), bilaterally symmetric, isolated centered with transparent padding on all sides. Crisp premium hand-painted 3D game illustration with simplified large shapes, readable when rendered at 48 pixels. Genuinely transparent PNG background. No perspective, no scenery, no ground shadow, no text, no letters, no logos, no grid, no watermark. Subject: a high-speed player reconnaissance spacecraft, ivory-white and dark navy, emerald cockpit and cyan engine light. Very slender elongated arrowhead silhouette, long sharp nose, two small backward-swept wings, twin narrow engines pointing DOWN. Agile lightweight profile, clearly unlike a broad armored vessel. Same design family as a sleek ivory/navy/cyan exploration interceptor. Craft occupies 80% height, 56% width of square canvas, all parts inside frame.

### `assets/art/shootingstar_enemy_hunter.png`

> Use case: stylized-concept. Asset type: transparent 2D space shooter sprite. Create one completely original spacecraft, strict orthographic TOP DOWN view, nose toward 12 o'clock (UP), bilaterally symmetric, isolated centered with transparent padding on all sides. Crisp premium hand-painted 3D game illustration with simplified large shapes, readable when rendered at 48 pixels. Genuinely transparent PNG background. No perspective, no scenery, no ground shadow, no text, no letters, no logos, no grid, no watermark. Subject: an enemy autonomous hunter drone, angular scarlet-red armor over graphite metal, glowing amber targeting core. Compact triangular silhouette, two aggressive forward prongs, tiny red engine exhausts pointing DOWN. Threatening but clean readable shape, no cockpit for humans. Visually distinct from friendly ivory/cyan vessels. One single craft only, occupying 76% of square canvas, all parts inside frame.

### `assets/art/shootingstar_boss_fortress.png`

> Use case: stylized-concept. Asset type: transparent 2D space shooter sprite. Create one completely original spacecraft, strict orthographic TOP DOWN view, nose toward 12 o'clock (UP), bilaterally symmetric, isolated centered with transparent padding on all sides. Crisp premium hand-painted 3D game illustration with simplified large shapes, readable when rendered at 48 pixels. Genuinely transparent PNG background. No perspective, no scenery, no ground shadow, no text, no letters, no logos, no grid, no watermark. Subject: an imposing enemy orbital fortress boss, wide purple and graphite armor, two enormous curved claw-like forward wings around a brilliant gold circular reactor core, heavy side engines and short deep-violet exhausts pointing DOWN. Broad menacing silhouette, three clearly separated armor masses, intricate but readable with dominant gold center. One single craft only, occupying 78% width and 76% height of square canvas. All wings and effects fit inside frame.

## 효과음 및 아이콘

- `assets/audio/*.wav`: `tools/generate_audio.py`로 직접 합성한 7개 짧은 효과음. 외부 음원·샘플 없음. 발사, 피격, 성장, 승리, 패배, 클릭, 보스 알림.
- `web/icons/star.svg`, `android/.../drawable/ic_shootingstar.xml`: 직접 작성한 기체/별 모양 앱 아이콘.
- Material Icons: Flutter가 제공하는 아이콘. 앱 설정의 오픈소스 라이선스 화면 참조.

## 글꼴

`assets/fonts/NotoSansKR.ttf`: Google Fonts Noto Sans KR variable font. SIL Open Font License 1.1, 원문 `assets/fonts/OFL.txt`. 한글을 오프라인으로 표시하기 위해 포함했습니다.

공식 원본: https://github.com/google/fonts/tree/main/ofl/notosanskr

## 기술 참고

- https://docs.flutter.dev/resources/games-toolkit
- https://docs.flutter.dev/platform-integration/web/initialization
- https://pub.dev/packages/shared_preferences
- https://pub.dev/packages/audioplayers

실제 사용 버전은 `pubspec.lock`에 고정되어 있습니다.
