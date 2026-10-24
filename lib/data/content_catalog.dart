class GearSpec {
  const GearSpec(
    this.name,
    this.slot,
    this.perk, {
    this.weapon = 'gun',
    this.bossWorld = -1,
  });
  final String name, perk, weapon;
  final int slot;
  final int bossWorld;
}

const gearCatalog = [
  GearSpec('펄스 블래스터', 0, '주포 모드에 전방 관통 사격을 결합'),
  GearSpec('유성 추적기', 0, '주포 모드에 전방 유도 로켓을 결합', weapon: 'missile'),
  GearSpec('매의 눈 센서', 1, '등급마다 화력 추가 +2%'),
  GearSpec('수집 스캐너', 1, '등급마다 회수 반경 +10%'),
  GearSpec('항성 출력 코어', 2, '등급마다 화력 추가 +3%'),
  GearSpec('순환 에너지 코어', 2, '등급마다 쿨다운 −2%'),
  GearSpec('티타늄 선체', 3, '등급마다 선체 추가 +4%'),
  GearSpec('재생 선체', 3, '30초마다 최대 선체의 2% 회복'),
  GearSpec('방벽 벨트', 4, '등급마다 받는 피해 −2%'),
  GearSpec('생명 유지 벨트', 4, '등급마다 선체 추가 +3%'),
  GearSpec('고속 추진기', 5, '등급마다 이동 속도 +3%'),
  GearSpec('회수 추진기', 5, '등급마다 회수 반경 +8%'),
  GearSpec('잔광 수문장 선체', 3, '잔광 2피스 · 선체80% 이상 주무기 피해 +8%', bossWorld: 0),
  GearSpec('잔광 수문장 추진기', 5, '잔광 2피스 · 선체80% 이상 주무기 피해 +8%', bossWorld: 0),
  GearSpec('성운 수문장 선체', 3, '성운 2피스 · 코어 개방 중 보스 피해 +10%', bossWorld: 1),
  GearSpec('성운 수문장 추진기', 5, '성운 2피스 · 코어 개방 중 보스 피해 +10%', bossWorld: 1),
  GearSpec('왕관 수문장 선체', 3, '왕관 2피스 · 편대 대상 주무기 피해 +10%', bossWorld: 2),
  GearSpec('왕관 수문장 추진기', 5, '왕관 2피스 · 편대 대상 주무기 피해 +10%', bossWorld: 2),
  GearSpec('빙결 수문장 선체', 3, '빙결 2피스 · 감속 중인 적 피해 +10%', bossWorld: 3),
  GearSpec('빙결 수문장 추진기', 5, '빙결 2피스 · 감속 중인 적 피해 +10%', bossWorld: 3),
  GearSpec('균사 수문장 선체', 3, '균사 2피스 · 선체50% 미만이면10초마다 최대 선체1% 회복', bossWorld: 4),
  GearSpec(
    '균사 수문장 추진기',
    5,
    '균사 2피스 · 선체50% 미만이면10초마다 최대 선체1% 회복',
    bossWorld: 4,
  ),
  GearSpec('철묘 수문장 선체', 3, '철묘 2피스 · 선체50% 미만 피해 감소 +6%p', bossWorld: 5),
  GearSpec('철묘 수문장 추진기', 5, '철묘 2피스 · 선체50% 미만 피해 감소 +6%p', bossWorld: 5),
  GearSpec('태양 수문장 선체', 3, '태양 2피스 · 선체80% 이상 이동 속도 +8%', bossWorld: 6),
  GearSpec('태양 수문장 추진기', 5, '태양 2피스 · 선체80% 이상 이동 속도 +8%', bossWorld: 6),
  GearSpec('심해 수문장 선체', 3, '심해 2피스 · 보스 교전 중 피해 감소 +5%p', bossWorld: 7),
  GearSpec('심해 수문장 추진기', 5, '심해 2피스 · 보스 교전 중 피해 감소 +5%p', bossWorld: 7),
  GearSpec('수정 수문장 선체', 3, '수정 2피스 · 치명타 확률 +4%p · 기존 상한 유지', bossWorld: 8),
  GearSpec('수정 수문장 추진기', 5, '수정 2피스 · 치명타 확률 +4%p · 기존 상한 유지', bossWorld: 8),
  GearSpec(
    '특이점 수문장 선체',
    3,
    '특이점 2피스 · 보스에 주무기 +6% / 일반 적에 보조 무기 +6%',
    bossWorld: 9,
  ),
  GearSpec(
    '특이점 수문장 추진기',
    5,
    '특이점 2피스 · 보스에 주무기 +6% / 일반 적에 보조 무기 +6%',
    bossWorld: 9,
  ),
];
const qualityNames = ['일반', '우수', '희귀', '엘리트', '에픽', '전설'];
const slotNames = ['주무장', '센서', '코어', '선체', '벨트', '추진기'];
const techWeapons = [
  'gun',
  'missile',
  'drone',
  'side',
  'mine',
  'trail',
  'guardian',
  'lightning',
];
const techNames = [
  '관통 증폭기',
  '폭발 유도 칩',
  '자동 추적 AI',
  '분광 렌즈',
  '중력 응축기',
  '플라스마 전지',
  '궤도 확장기',
  '연쇄 축전기',
];
const techPerks = [
  '주포 본탄 관통 +1 / 근접 사거리·범위 +15% / 공허 지속 +0.4초. 우수 매의 눈 센서: 정밀 연계, 우수 순환 에너지 코어: 순환 방호',
  '로켓 폭발 반경 +60%',
  '드론 탄환 적 추적',
  '광자탄 2발 추가',
  '지뢰 폭발 반경 +50%',
  '장판 지속 시간 +50%',
  '수호자 범위 +20%',
  '낙뢰 타격 2회 추가',
];

/// Chick companions: hatched from star eggs the cats sat on.
const petNames = ['삐약 · 불꽃 병아리', '코코 · 간호 병아리', '뚜껑 · 냄비뚜껑 병아리'];
const petDescriptions = [
  '공격 · 가까운 적에게 불씨를 쏩니다 (Lv.5부터 2발)',
  '회복 · 12초마다 선체를 회복합니다',
  '방어 · 3초마다 주변 적탄을 냄비뚜껑으로 막습니다',
];

int boundedInt(dynamic value, int fallback, int max) =>
    value is num && value.isFinite ? value.toInt().clamp(0, max) : fallback;

class GearItem {
  GearItem(
    this.id,
    this.spec, {
    this.rank = 0,
    this.level = 0,
    this.locked = false,
    this.spentCredits = 0,
    this.spentPlans = 0,
  });
  final int id, spec;
  int rank, level, spentCredits, spentPlans;
  bool locked;
  GearSpec get definition => gearCatalog[spec];
  Map<String, dynamic> toJson() => {
    'id': id,
    'spec': spec,
    'rank': rank,
    'level': level,
    'locked': locked,
    'spentCredits': spentCredits,
    'spentPlans': spentPlans,
  };
  static GearItem? restore(dynamic value) {
    if (value is! Map ||
        value['id'] is! int ||
        value['id'] <= 0 ||
        value['spec'] is! int ||
        value['spec'] < 0 ||
        value['spec'] >= gearCatalog.length) {
      return null;
    }
    return GearItem(
      value['id'],
      value['spec'],
      rank: boundedInt(value['rank'], 0, 5),
      level: boundedInt(value['level'], 0, 70),
      locked: value['locked'] == true,
      spentCredits: boundedInt(value['spentCredits'], 0, 1000000),
      spentPlans: boundedInt(value['spentPlans'], 0, 10000),
    );
  }
}

class RewardMail {
  RewardMail(
    this.id,
    this.title, {
    this.credits = 0,
    this.plans = 0,
    this.food = 0,
    this.gearKeys = 0,
    this.techKeys = 0,
    this.eggs = 0,
    this.claimed = false,
  });
  final String id, title;
  final int credits, plans, food, gearKeys, techKeys, eggs;
  bool claimed;
  String get summary => [
    if (credits > 0) '$credits 츄르',
    if (plans > 0) '별가루 $plans',
    if (food > 0) '먹이 $food',
    if (gearKeys > 0) '장비 보급권 $gearKeys',
    if (techKeys > 0) '테크 보급권 $techKeys',
    if (eggs > 0) '펫 구조권 $eggs',
  ].join(' · ');
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'credits': credits,
    'plans': plans,
    'food': food,
    'gearKeys': gearKeys,
    'techKeys': techKeys,
    'eggs': eggs,
    'claimed': claimed,
  };
  static RewardMail? restore(dynamic v) {
    if (v is! Map ||
        v['id'] is! String ||
        v['title'] is! String ||
        (v['id'] as String).length > 160) {
      return null;
    }
    return RewardMail(
      v['id'],
      v['title'],
      credits: boundedInt(v['credits'], 0, 999999),
      plans: boundedInt(v['plans'], 0, 9999),
      food: boundedInt(v['food'], 0, 99999),
      gearKeys: boundedInt(v['gearKeys'], 0, 100),
      techKeys: boundedInt(v['techKeys'], 0, 100),
      eggs: boundedInt(v['eggs'], 0, 100),
      claimed: v['claimed'] == true,
    );
  }
}
