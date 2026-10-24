class SurvivalSkill {
  const SurvivalSkill(
    this.id,
    this.name,
    this.description, {
    this.passive = false,
    this.partner,
    this.evolution,
    this.fusionWith,
    this.recipeHint,
    this.fusionOnly = false,
  });
  final String id, name, description;
  final bool passive;
  final String? partner, evolution, fusionWith, recipeHint;
  final bool fusionOnly;
}

const survivalSkills = [
  SurvivalSkill(
    'gun',
    '펄스 블래스터',
    '기체 전방으로 수직 직선 연사',
    partner: 'attack',
    evolution: '초신성 관통 레이저',
  ),
  SurvivalSkill(
    'missile',
    '추적 로켓',
    '강한 적을 추적하는 범위 폭발',
    partner: 'area',
    evolution: '궤도 폭격',
  ),
  SurvivalSkill(
    'drone',
    '요격 드론',
    '주변 적 요격 · 진화 시 가속·1회 관통',
    fusionWith: 'droneB',
    recipeHint: '요격 드론 A 5단계 + 폭격 드론 B 5단계',
    evolution: '쌍성 요격대',
  ),
  SurvivalSkill(
    'side',
    '광자 수레바퀴',
    '모든 방향으로 퍼지는 광자탄',
    partner: 'speed',
    evolution: '광자 폭풍',
  ),
  SurvivalSkill(
    'mine',
    '중력 지뢰',
    '추격하는 군집을 폭발로 제거',
    partner: 'hull',
    evolution: '중력 붕괴',
  ),
  SurvivalSkill(
    'trail',
    '플라스마 장판',
    '기체 주변에 지속 피해 영역 생성',
    partner: 'gold',
    evolution: '항성 코로나',
  ),
  SurvivalSkill(
    'guardian',
    '궤도 수호자',
    '회전하는 위성이 적을 밀어내고 탄환 제거',
    partner: 'duration',
    evolution: '행성 방패',
  ),
  SurvivalSkill(
    'lightning',
    '이온 낙뢰',
    '주변 적 분산 타격 · 대상당 2회, 진화 3회',
    partner: 'cooldown',
    evolution: '천둥 성운',
  ),
  SurvivalSkill(
    'droneB',
    '폭격 드론 B',
    '넓은 각도의 폭격탄',
    fusionWith: 'drone',
    recipeHint: '드론 A·B 각각 5단계',
    evolution: '쌍성 요격대',
  ),
  SurvivalSkill(
    'ball',
    '반사 플라스마구',
    '전장 벽을 튕기는 구체',
    partner: 'speed',
    evolution: '양자 반사구',
  ),
  SurvivalSkill(
    'drill',
    '관통 드릴',
    '무작위 관통 투사체',
    partner: 'projectile',
    evolution: '휘파람 추적침',
  ),
  SurvivalSkill(
    'laser',
    '레이저 발사기',
    '주변을 훑는 선형 광선',
    partner: 'armor',
    evolution: '감속 광선망',
  ),
  SurvivalSkill(
    'forcefield',
    '에너지 역장',
    '상시 주변 피해',
    partner: 'regen',
    evolution: '압력 역장',
  ),
  SurvivalSkill(
    'brick',
    '중량 탄두',
    '중력이 작용하는 관통 탄두',
    partner: 'hull',
    evolution: '중량 위성진',
  ),
  SurvivalSkill(
    'boomerang',
    '귀환 광륜',
    '날아갔다 돌아오는 광륜',
    partner: 'magnet',
    evolution: '자기장 귀환진',
  ),
  SurvivalSkill(
    'durian',
    '가시 위성',
    '튀는 거대 구체 · 진화 시 가시 방출',
    partner: 'area',
    evolution: '파편 위성',
  ),
  SurvivalSkill(
    'pilot',
    '조종사 고유 모듈',
    '격납고에서 선택한 고유 능력을 강화',
    recipeHint: '고유 모듈 5단계',
    evolution: '고유 모듈 각성',
  ),
  SurvivalSkill(
    'infernoMine',
    '태양 기뢰',
    '화염 장판을 남기는 융합 기뢰',
    fusionOnly: true,
    recipeHint: '지뢰 5 + 플라스마 5',
    evolution: '태양 기뢰',
  ),
  SurvivalSkill(
    'thunderMine',
    '전격 기뢰',
    '낙뢰를 방출하는 융합 기뢰',
    fusionOnly: true,
    recipeHint: '지뢰 5 + 낙뢰 5',
    evolution: '전격 기뢰',
  ),
  SurvivalSkill(
    'medicDrone',
    '구급 요격대',
    '드론 공격과 주기 치유의 합성',
    fusionOnly: true,
    recipeHint: '쌍성 요격대 + 정비 고유 모듈 5',
    evolution: '구급 요격대',
  ),
  SurvivalSkill('attack', '고밀도 탄약', '단계마다 모든 피해 +10%', passive: true),
  SurvivalSkill('area', '고출력 연료', '단계마다 폭발·장판 범위 +12%', passive: true),
  SurvivalSkill('cooldown', '에너지 큐브', '단계마다 무기 재사용 시간 −7%', passive: true),
  SurvivalSkill('speed', '추진 부스터', '단계마다 이동 속도 +8%', passive: true),
  SurvivalSkill('hull', '장갑 증폭기', '단계마다 기본 선체의 20% 추가·회복', passive: true),
  SurvivalSkill('magnet', '회수 자기장', '단계마다 경험치 회수 반경 +28', passive: true),
  SurvivalSkill(
    'duration',
    '지속 전지',
    '단계마다 지뢰·장판·수호 방패 지속 시간 +20%',
    passive: true,
  ),
  SurvivalSkill('armor', '반응 장갑', '단계마다 받는 피해 -8%', passive: true),
  SurvivalSkill('regen', '회복 전지', '5초마다 단계당 선체 1% 회복', passive: true),
  SurvivalSkill('projectile', '탄속 추진기', '단계마다 투사체 속도 +10%', passive: true),
  SurvivalSkill('gold', '회수 채권', '출격 츄르 단계당 +8%', passive: true),
  SurvivalSkill('crit', '정밀 연산기', '단계마다 치명타 확률 +8%', passive: true),
  SurvivalSkill('xp', '전술 기록기', '단계마다 경험치 획득 +8%', passive: true),
];

/// v12 exaggerated level-up weapons (lib/game/paw_weapons.dart). Each one
/// evolves at level 5 when its partner passive is owned.
const pawSkills = [
  SurvivalSkill(
    'paw:orbit',
    '꾹꾹 냥펀치',
    '고양이 발이 주위를 돌며 적을 밀쳐 내고 탄을 막습니다',
    partner: 'hull',
    evolution: '냥펀치 폭풍',
  ),
  SurvivalSkill(
    'paw:yarn',
    '털실 폭탄',
    '느린 거대 털실이 적 무리 한가운데서 크게 터집니다',
    partner: 'attack',
    evolution: '털실 대폭발',
  ),
  SurvivalSkill(
    'paw:laser',
    '레이저 포인터',
    '가장 강한 적 하나를 끈질기게 지져 댑니다',
    partner: 'cooldown',
    evolution: '레드닷 집중',
  ),
  SurvivalSkill(
    'paw:crescent',
    '발톱 반달',
    '회전하는 반달 발톱이 부메랑처럼 날아갔다 돌아옵니다',
    partner: 'speed',
    evolution: '태풍 반달',
  ),
  SurvivalSkill(
    'paw:bounce',
    '통통 공',
    '커다란 공이 화면 가장자리를 튕기며 적을 뚫습니다',
    partner: 'magnet',
    evolution: '왕 통통 공',
  ),
  SurvivalSkill(
    'paw:zap',
    '수염 번개',
    '수염에서 번개가 튀어 적들 사이를 연쇄로 타고 넘습니다',
    partner: 'attack',
    evolution: '천둥 수염',
  ),
];

SurvivalSkill skillFor(String id) => id.startsWith('paw:')
    ? pawSkills.firstWhere((s) => s.id == id)
    : survivalSkills.firstWhere((s) => s.id == id);
