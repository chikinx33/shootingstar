class ArmamentSpec {
  const ArmamentSpec(this.id, this.name, this.detail);
  final String id, name, detail;
}

// v12.17: the three cat main guns only (save ids kept). Index = cat:
// 0 치즈 pulse, 1 구름 revolver, 2 까미 shotgun; growth in weapon_growth.dart.
const armaments = [
  ArmamentSpec('pulse', '냥냥 연사포', '빠른 직선탄 · 치즈'),
  ArmamentSpec('revolver', '정밀 냥냥포', '고위력탄 · 6발 후 재장전 · 구름'),
  ArmamentSpec('shotgun', '꾹꾹 산탄포', '전방 부채꼴 산탄 · 까미'),
];

/// v12.9.2 (user 2026-10-25): the cat is the pilot. Each guardian cat flies
/// with one fixed trait from the start; it takes no card slot and grows with
/// the cat's level (Lv.0-9 step 1 ... Lv.40+ step 5).
class CatTrait {
  const CatTrait(this.id, this.name, this.short, this.detail);

  /// Battle ability id in [pilots] (lib/game/pilot_abilities.dart).
  final String id;

  /// [short] fits the cat selection panel; [detail] is the full rule.
  final String name, short, detail;
}

const catTraits = [
  CatTrait(
    'common',
    '신참의 패기',
    '모든 피해 +3~15%',
    '모든 피해 +3% · 고양이 레벨 10마다 +3%p(최대 +15%)',
  ),
  CatTrait(
    'king',
    '고양이 눈',
    '치명타 확률 +5~25%',
    '치명타 확률 +5% · 고양이 레벨 10마다 +5%p(최대 25%)',
  ),
  CatTrait('elaine', '꼬리 방패', '차폐 충전·반격', '2초마다 차폐 충전과 반격 · 선체 50% 아래에서 강화'),
];

CatTrait catTraitFor(int ship) =>
    catTraits[ship.clamp(0, catTraits.length - 1)];

/// Trait step 1-5 from the cat's level.
int catTraitLevel(int catLevel) => (1 + catLevel ~/ 10).clamp(1, 5);

/// Battle ability library. The three cat traits are live; the other
/// thirteen are kept only as mechanics for future chick pets (developer
/// test menu). Abilities themed on outside works were removed in v12.9.2.
class PilotSpec {
  const PilotSpec(this.id, this.name, this.skill, this.detail);
  final String id, name, skill, detail;
}

const pilots = [
  PilotSpec('common', '신참의 패기', 'overclock', '모든 피해 선천 강화 · 슬롯을 사용하지 않음'),
  PilotSpec('king', '고양이 눈', 'instinct', '치명타 확률 · 고양이 레벨로 성장'),
  PilotSpec('elaine', '꼬리 방패', 'shield', '낮은 선체에서 차폐·반격 강화'),
  // chick pet candidates
  PilotSpec('tsuki', '원형 참격', 'moon', '주기적 원형 참격 · 각성 시 전방 검기'),
  PilotSpec('cat', '치유 드론', 'medic', '치유 드론 · 전투 드론과 의료 합성'),
  PilotSpec('worm', '취약 표식', 'bug', '주변 적 취약 표식 · 각성 시 표식 타격'),
  PilotSpec('wesson', 'EMP 감속', 'emp', 'EMP 수류탄 · 진화 시 감속장'),
  PilotSpec('yelena', '속사', 'pistol', '빠른 연속 사격 · 각성 시 발사 수 증가'),
  PilotSpec('yang', '자세 전환', 'palm', '태양 타격/보호 자세 전환 · 진화 시 취약'),
  PilotSpec('metallia', '원소 순환', 'song', '독·냉기·전기 자세 순환 · 원소 상태 부여'),
  PilotSpec('joey', '약점 돌파', 'weakpoint', '전방 약점 타격 · 진화 시 노출 피해 증폭'),
  PilotSpec('taloxa', '동기화 기갑', 'sync', '동기화 축적·체인 동기화·기갑 변신과 수평 빔'),
  PilotSpec('venato', '혈투', 'adrenaline', '피격 아드레날린·혈투 중 선체를 차폐로 전환'),
  PilotSpec('nezha', '화륜', 'firewheel', '회전 화륜과 신성 화염'),
  PilotSpec('vulcan', '용광로', 'forge', '지속 화염과 용광로 폭발'),
  PilotSpec('loki', '분신 사격', 'illusion', '분신 사격 · 각성 시 분신 증가'),
];
