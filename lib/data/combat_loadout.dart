class ArmamentSpec {
  const ArmamentSpec(this.id, this.name, this.reference, this.detail);
  final String id, name, reference, detail;
}

// Shared mechanical families; project names/assets remain original.
const armaments = [
  ArmamentSpec('pulse', '펄스 주포', 'Shootingstar', '전방 직선탄 · 진화 시 관통·피해 강화'),
  ArmamentSpec(
    'kunai',
    '유도 침',
    'Kunai / Spirit Shuriken',
    '전방 좁은 각도 유도탄 · 뒤로 돌지 않음',
  ),
  ArmamentSpec(
    'katana',
    '초승 파동검',
    'Katana / Demon Blade',
    '전방 중거리 파동 · 진화 시 관통·피해 강화',
  ),
  ArmamentSpec('bat', '중력 타격봉', 'Baseball Bat / Lucille', '짧고 넓은 전방 충격탄'),
  ArmamentSpec(
    'shotgun',
    '산탄 캐논',
    'Shotgun / Gatling',
    '전방 부채꼴 산탄 · 진화 시 관통·피해 강화',
  ),
  ArmamentSpec(
    'revolver',
    '중형 레일건',
    'Revolver / Reaper',
    '전방 고위력탄 · 6회 사격 후 재장전',
  ),
  ArmamentSpec(
    'lightchaser',
    '광자 참격기',
    'Lightchaser / Eternal Light',
    '전방 장거리 광자 파동',
  ),
  ArmamentSpec(
    'void',
    '공허 투사기',
    'Void Power / Gloom Nova',
    '전방 중력탄 · 공중 적만 범위 폭발',
  ),
  ArmamentSpec(
    'disorder',
    '영혼 추적검',
    'Sword of Disorder / Sword of Domination',
    '전방 영혼탄 · 처치 중첩으로 피해 강화',
  ),
  ArmamentSpec(
    'lance',
    '쌍극 성창',
    'Twin Lance / Starforged Havoc',
    '전방 쌍발 광탄 · 진화 시 관통·피해 강화',
  ),
];

class PilotSpec {
  const PilotSpec(this.id, this.name, this.reference, this.skill, this.detail);
  final String id, name, reference, skill, detail;
}

const pilots = [
  PilotSpec(
    'common',
    '항로 지휘관',
    'Common',
    'overclock',
    '모든 피해 선천 강화 · 슬롯을 사용하지 않음',
  ),
  PilotSpec('tsuki', '월영 검사', 'Tsukuyomi', 'moon', '주기적 원형 참격 · 각성 시 전방 검기'),
  PilotSpec('cat', '정비 드론 기사', 'Catnips', 'medic', '치유 드론 · 전투 드론과 의료 합성'),
  PilotSpec('worm', '신호 추적자', 'Worm', 'bug', '주변 적 취약 표식 · 각성 시 표식 타격'),
  PilotSpec('king', '정밀 사수', 'King', 'instinct', '치명타 확률 · 진화 시 치명타 피해 증폭'),
  PilotSpec('wesson', '전자전 기사', 'Wesson', 'emp', 'EMP 수류탄 · 진화 시 감속장'),
  PilotSpec('yelena', '속사 요원', 'Yelena', 'pistol', '빠른 연속 사격 · 각성 시 발사 수 증가'),
  PilotSpec(
    'yang',
    '쌍극 수호자',
    'Master Yang',
    'palm',
    '태양 타격/보호 자세 전환 · 진화 시 취약',
  ),
  PilotSpec(
    'metallia',
    '삼원소 지휘자',
    'Metallia',
    'song',
    '독·냉기·전기 자세 순환 · 원소 상태 부여',
  ),
  PilotSpec('joey', '약점 돌파자', 'Joey', 'weakpoint', '전방 약점 타격 · 진화 시 노출 피해 증폭'),
  PilotSpec('taloxa', '동기화 기갑사', 'Taloxa', 'sync', '동기화 축적·체인 동기화·기갑 변신과 수평 빔'),
  PilotSpec(
    'venato',
    '혈투 사냥꾼',
    'Venato',
    'adrenaline',
    '피격 아드레날린·혈투 중 선체를 차폐로 전환',
  ),
  PilotSpec('elaine', '차폐 전술가', 'Elaine', 'shield', '낮은 선체에서 차폐·반격 강화'),
  PilotSpec('nezha', '화륜 항해사', 'Nezha', 'firewheel', '회전 화륜과 신성 화염'),
  PilotSpec('vulcan', '용광로 기사', 'Vulcan', 'forge', '지속 화염과 용광로 폭발'),
  PilotSpec('loki', '환영 조종사', 'Loki', 'illusion', '분신 사격 · 각성 시 분신 증가'),
  PilotSpec('sponge', '해면 포격수', 'SpongeBob', 'spatula', '뒤집개형 부채 타격과 튕김'),
  PilotSpec(
    'squid',
    '음파 연주자',
    'Squidward',
    'clarinet',
    '주변 음파 고리 · 진화 시 연속 파동',
  ),
  PilotSpec('patrick', '유성 잠수사', 'Patrick', 'dive', '돌진 후 충격파 · 진화 시 넓은 충격파'),
  PilotSpec('sandy', '격투 항해사', 'Sandy', 'karate', '근거리 연타와 회전 타격'),
  PilotSpec('plankton', '기계 설계자', 'Plankton', 'mech', '보조 기계 소환과 유도탄'),
  PilotSpec('leo', '청광 쌍검사', 'Leonardo', 'dualblade', '전후방 쌍검과 회전 참격'),
  PilotSpec('raph', '적광 쌍차사', 'Raphael', 'sai', '짧은 고속 관통 · 취약 표식'),
  PilotSpec('mikey', '황광 회전사', 'Michelangelo', 'nunchaku', '회전 연타와 충격 고리'),
  PilotSpec('don', '자광 창기사', 'Donatello', 'bo', '긴 창 회전과 밀치기'),
  PilotSpec('splinter', '교관 항해사', 'Splinter', 'mentor', '펫·드론 보조 타격과 회복'),
  PilotSpec('april', '전장 관측자', 'April', 'reporter', '적 표식·펫 강화와 주기적 지원탄'),
];
