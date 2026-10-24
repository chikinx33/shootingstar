# 전투 스킬 벤치마크 범위 · 2026-10-16

사용자가 지정한 범위는 일반 전투 스킬·보조·진화·합성뿐 아니라 캐릭터 고유 스킬과 장착 주무기까지다. 이를 우주 슈팅의 기존 코드와 자산에 연결했다. 게임 화면은 Shootingstar의 이름·실루엣·색을 사용하며 아래 원작 명칭은 대응 자료다.

공개 설명으로 확인 가능한 발동 방식·방향·역할·합성 관계를 참고했다. 원작 실행 파일·계정·서버 수치에 접근하지 않았으므로 현재 모든 등급·각성·전용 테크 효과의 1:1 재현이나 원작과 같은 DPS를 주장하지 않는다. 특히 최신 Elaine/SP 및 일부 협업 캐릭터는 공개 자료가 제한돼 별도 해석을 적용했다. 행의 대응 캐릭터 이름이 해당 캐릭터의 전체 각성 패시브까지 동일함을 뜻하지 않는다.

## 일반 액티브 14계열과 진화

| 참고 계열 | Shootingstar ID | 동작과 진화/합성 |
|---|---|---|
| RPG | missile | 추적 폭발 → 다중 목표 유지 폭격, 범위 보조 |
| Type-A Drone | drone | 조준 사격, 희귀 테크부터 추적 |
| Type-B Drone | droneB | 각도를 나누는 폭격탄 |
| Destroyer | drone EVO | A/B 각각 5단계 합체, 슬롯 하나 반환 |
| Guardian | guardian | 회전 위성·밀치기·탄환 제거 → 넓은 방패, 지속 보조 |
| Forcefield | forcefield | 상시 주변 피해 → 감속 역장, 회복 보조 |
| Lightning Emitter | lightning | 즉시 분산 타격 → 타격 수 증가, 쿨다운 보조 |
| Molotov | trail | 지속 장판 → 넓은 코로나, 재화 보조 |
| Soccer Ball | ball | 튕기는 구체 → 빠른 양자구, 이동 보조 |
| Drill Shot | drill | 관통 드릴 → 추적침, 탄속 보조 |
| Laser Launcher | laser | 선형 레이저 → 회전 감속망, 장갑 보조 |
| Brick | brick | 중력 탄두 → 원형 중량탄, 선체 보조 |
| Boomerang | boomerang | 왕복·회수 → 궤도 광륜, 자석 보조 |
| Durian | durian | 거대 반사 위성 → 가시 방출, 범위 보조 |
| Modular Mine | mine | 기뢰; 5단계 화염/낙뢰와 태양/전격 기뢰 합성 |
| Divine Destroyer | medicDrone | 진화 드론과 정비 고유 모듈 합성, 치유·공격을 한 슬롯으로 통합 |

기뢰 합성은 기뢰와 해당 원소 무기를 소모하고 한 슬롯을 반환한다. 소모한 원소는 다시 선택할 수 있다. 원작 계열 외에 기존 광자 수레바퀴와 중력 기뢰의 보조 진화는 프로젝트 고유 옵션으로 유지했다. 공격 모듈은 최대 5단계와 진화를 사용한다.

기존 낙뢰 단일 대상 반복 제한(일반 2/진화 3), 보스의 방어/코어 개방과 격벽은 유지한다. 원작의 무제한 단일 대상 합산 피해를 그대로 적용해 보스를 즉사시키지 않도록 한 프로젝트 밸런스 차이다.

## 보조

공격·범위·쿨다운·이동·선체·자석·지속·경험치·장갑·회복·탄속·재화의 12기능을 제공한다. 정밀 연산(치명타)은 추가 선택이고 King 대응 고유 모듈에도 치명타·각성 시 치명타 피해 효과가 있다. HP, 이동, 쿨다운, 피해 감소, XP, 재화의 실제 배율은 Shootingstar의 조합·출격 길이를 기준으로 조정한 수치다. 재화 보조는 최종 출격 크레딧에 실제 반영한다.

## 장착 주무기 9계열 + 기존 펄스

| 참고 계열 | 장착 ID | 동작 |
|---|---|---|
| 기존 펄스 | pulse | 전방 직선 → 삼중탄·관통 레이저 |
| Kunai / Spirit Shuriken | kunai | 가까운 적 유도 → 다중 연속 유도 |
| Katana / Demon Blade | katana | 전후 파동 → 적중 시 제한 회복 |
| Baseball Bat / Lucille | bat | 넓은 타격·밀치기 → 원형 타격 |
| Shotgun / Gatling | shotgun | 산탄 → 좁은 고속 탄막 |
| Revolver / Reaper | revolver | 6발 탄창·재장전 → 관통 |
| Lightchaser / Eternal Light | lightchaser | 검기·주기 후방 공격 → 검진 |
| Void Power / Gloom Nova | void | 흡인장 → 소멸 폭발·차폐 |
| Sword of Disorder / Domination | disorder | 처치 영혼 중첩·피격 시 방출 |
| Twin Lance / Starforged Havoc | lance | 빛 고리·어둠 찌르기 → 균열·추적탄 |

사용자의 별도 주포 성장 지시가 우선이므로 주무기는 레벨업 6슬롯을 사용하지 않는다. R/P/N 현장 축으로 성장·진화하며 원작의 주무기별 보조 진화나 Twin Lance의 2액티브 슬롯 소모 방식은 이 구조로 대체했다. 장비 등급의 모든 Astral/Chaos 강화 효과는 이 장착 선택기에 복제한 범위가 아니다.

## 캐릭터 대응 고유 모듈 27종

| 참고 캐릭터 | ID | 구현한 행동 |
|---|---|---|
| Common | common | 선천 피해 보너스, 슬롯 비소모 |
| Tsukuyomi | tsuki | 원형 참격·각성 검기 |
| Catnips | cat | 치유 드론·의료 요격 합성 |
| Worm | worm | 취약 표식·각성 표식 타격 |
| King | king | 치명타 확률·각성 치명타 피해 |
| Wesson | wesson | EMP와 감속장 |
| Yelena | yelena | 빠른 연속 사격 |
| Master Yang | yang | 태양 타격 / 회복·차폐 자세 전환 |
| Metallia | metallia | 독·냉기·전기 원소 순환 |
| Joey | joey | 전방 약점 공격·노출 표식 |
| Taloxa | taloxa | 동기화 축적·버튼 증폭·기갑 전환·수평 빔 |
| Venato | venato | 피격 시 피해 버프·혈투 중 HP를 차폐로 전환·주변 타격 |
| Elaine | elaine | 낮은 선체에서 차폐·반격 강화, 공개 정보 기반 해석 |
| Nezha / Vulcan / Loki | nezha / vulcan / loki | 화륜·지속 화염 / 용광로 폭발 / 분신 사격, 개별 수치는 해석 |
| SpongeBob / Squidward | sponge / squid | 부채 타격 / 음파 고리 |
| Patrick / Sandy / Plankton | patrick / sandy / plankton | 돌진 충격 / 근접 연타 / 보조 기계 |
| Leonardo / Raphael | leo / raph | 전후 쌍검 / 좁은 관통·취약 |
| Michelangelo / Donatello | mikey / don | 회전 연타 / 긴 창·밀치기 |
| Splinter / April | splinter / april | 펫·드론 지원과 회복 / 표식 지원 |

기본 모듈은 5단계와 각성을 사용한다. 수동 자세·변신·혈투 버튼은 실제 전투 입력이며 선택/정지 중 사용과 쿨다운 진행을 막는다. 양·원소·동기화·혈투 상태는 HUD에 표시한다. 스킨, 소유 조건, 현금 상품, 전체 캐릭터 각성 트리와 시너지 팀 전체를 복제한 구현은 아니다.

## 자료와 증거

- [Apple 공식 전술 소개](https://apps.apple.com/nz/iphone/story/id1641743438): 공격·방어 역할, A/B 드론 합성, 진화, 자석·폭탄 사용을 확인.
- [공식 앱 업데이트 기록](https://apps.apple.com/ee/app/survivor-io/id1528941310): 신규 캐릭터와 버전별 콘텐츠 존재 확인. 이름만으로 내부 효과 수치를 확정하지 않음.
- [커뮤니티 스킬 자료](https://survivorio.fandom.com/wiki/Skills), [기뢰](https://survivorio.fandom.com/wiki/Modular_Mine), [Twin Lance](https://survivorio.fandom.com/wiki/Twin_Lance_Starforged_Havoc): 검색 색인과 공개 설명의 분류·합성 관계 참고. 전체 원문 접근이 제한된 페이지는 미확인 세부 수치를 추정해 확정하지 않음.
- [캐릭터 능력 분류](https://whatifgaming.com/survivor-io-hero-tier-list/), [Taloxa 가이드](https://mturbogamer.com/2026/08/survivor-io-taloxa-guide/), [Venato 가이드](https://mturbogamer.com/2026/08/survivor-io-venato-guide/): 고유 능력의 큰 작동 구조 참고. 서드파티 자료의 랭킹·홍보·계정 구매 안내는 구현 근거로 사용하지 않음.

자동 검사: 모든 주무기와 일반 무기의 실제 타격·개체 상한, 27개 모듈 실행·정지 시계, 드론/기뢰 합성 및 슬롯 반환, 전체 주무기의 추가 발사 효과. 웹 화면과 실행 로그는 `tools/qa/evidence/campaign-v5/`에 보관한다. 런타임 예외가 없다는 검사가 캐릭터별 DPS 균형이나 미확인 원작 효과의 동일성을 증명하지는 않는다.
