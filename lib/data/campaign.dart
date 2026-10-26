import 'package:flutter/material.dart';

import 'houses.dart';

enum EnemyRole {
  scout,
  weaver,
  bulwark,
  spitter,
  lancer,
  orbiter,
  miner,
  splitter,
  sniper,
  carrier,
  kamikaze,
}

class WorldSpec {
  const WorldSpec(
    this.name,
    this.code,
    this.concept,
    this.color,
    this.roles,
    this.hazard,
  );
  final String name, code, concept;
  final Color color;
  final List<EnemyRole> roles;
  final int hazard; // 0 none, 1 lanes, 2 rings, 3 moving cross
}

const worlds = [
  WorldSpec(
    '동네 하늘',
    'HOME SKY',
    '집사네 동네 상공 · 청소기 정찰대와 편대 침투',
    Color(0xFF60E7EF),
    [EnemyRole.scout, EnemyRole.weaver, EnemyRole.spitter],
    0,
  ),
  WorldSpec(
    '노을 구름',
    'SUNSET SEA',
    '노을 구름 위 · 빗자루 돌격과 조준 포격',
    Color(0xFFFF8D77),
    [EnemyRole.lancer, EnemyRole.spitter, EnemyRole.sniper],
    1,
  ),
  WorldSpec('성층권', 'STRATOSPHERE', '지구의 지붕 · 궤도 포위와 장갑 함대', Color(0xFFB9A1FF), [
    EnemyRole.orbiter,
    EnemyRole.bulwark,
    EnemyRole.carrier,
  ], 2),
  WorldSpec('달 궤도', 'MOON ORBIT', '회색 달 · 깃털 편대와 저격', Color(0xFF99DFFF), [
    EnemyRole.weaver,
    EnemyRole.sniper,
    EnemyRole.splitter,
  ], 1),
  WorldSpec(
    '소행성 정원',
    'ASTEROID GARDEN',
    '이끼 소행성 · 먼지 뭉치 분열과 번식',
    Color(0xFF9EEA78),
    [EnemyRole.splitter, EnemyRole.carrier, EnemyRole.scout],
    2,
  ),
  WorldSpec(
    '화성 사막',
    'MARS DESERT',
    '붉은 협곡 · 캐리어 전차와 오이 기뢰',
    Color(0xFFE6B373),
    [EnemyRole.bulwark, EnemyRole.miner, EnemyRole.spitter],
    3,
  ),
  WorldSpec('목성 폭풍', 'JUPITER STORM', '폭풍 띠 · 고속 돌격과 화망', Color(0xFFFFB04B), [
    EnemyRole.lancer,
    EnemyRole.orbiter,
    EnemyRole.spitter,
  ], 1),
  WorldSpec('토성 고리', 'SATURN RINGS', '얼음 고리 · 은폐 저격과 포위', Color(0xFF6A9CFF), [
    EnemyRole.sniper,
    EnemyRole.orbiter,
    EnemyRole.miner,
  ], 2),
  WorldSpec(
    '해왕성 심연',
    'NEPTUNE DEEP',
    '푸른 심연 · 깃털 굴절과 분열 탄막',
    Color(0xFFF29CEB),
    [EnemyRole.weaver, EnemyRole.splitter, EnemyRole.miner],
    3,
  ),
  WorldSpec(
    '은하 봉인문',
    'MILKY WAY GATE',
    '흡입대왕의 봉인 · 모든 함대의 최종 시험',
    Color(0xFFFF6F9C),
    [EnemyRole.carrier, EnemyRole.bulwark, EnemyRole.sniper, EnemyRole.lancer],
    3,
  ),
];

/// Vacuum Empire fleet commanders, one per world (docs/CONCEPT_GUARDIAN_CATS.md).
const bossNames = [
  '분무 대위 스프리츠',
  '열풍 소령 드라이언',
  '오이 함장 큐컴버',
  '거품 제독 버블스',
  '캐리어 장군 케이지',
  '발톱깎이 장군 클리퍼',
  '시트러스 박사 레몬',
  '넥카라 경 콘',
  '굉음 대장 스피커',
  '대왕의 오른팔 룸바르 원수',
];

/// What each commander says when it arrives.
const bossTaunts = [
  '칙칙! 이 동네 고양이들은 전부 흠뻑 젖게 해 주마!',
  '후오오옹! 뜨거운 바람 맛을 보여 주지!',
  '깜짝 놀랐지? 오이는 어디에나 있다!',
  '보글보글~ 목욕 시간이다, 고양이들!',
  '철컥! 너희를 전부 이동장에 가둬 주마!',
  '딸깍딸깍! 그 발톱, 짧게 다듬어 주지!',
  '시큼한 레몬 가스를 견딜 수 있을까?',
  '이 넥카라를 쓰면 아무것도 못 핥는다!',
  '쿵! 쿵! 가장 큰 소리가 이긴다!',
  '흐으으읍… 대왕님의 봉인은 오늘 열린다!',
];

const sectorNames = [
  '접근 항로',
  '외곽 순찰',
  '측면 돌파',
  '포격 회랑',
  '전초 요새',
  '기뢰 해협',
  '추격 항로',
  '장갑 방벽',
  '혼성 함대',
  '함대 사령관',
];

class StageSpec {
  const StageSpec(this.index);
  final int index;
  int get worldIndex => index ~/ 10;
  int get sector => index % 10;
  WorldSpec get world => worlds[worldIndex];
  // v12: every stage is a neighbour's house (lib/data/houses.dart).
  HouseSpec get house => houseOf(index);
  String get name => house.place;
  String get subtitle => '${worldIndex + 1}-${sector + 1} / ${world.name}';
  String get description => '“${house.line}”\n$bossCount회 보스 결전';
  String get difficulty => sector == 9
      ? '세계 결전'
      : sector == 4
      ? '정예 시험'
      : '위험도 ${index + 1}';
  Color get color => world.color;
  int get duration => sector == 9 ? 240 : 180;
  int get bossCount => sector == 9
      ? 3
      : sector == 4
      ? 2
      : 1;
  double threat(int cycle) => (1 + index * .035) * (1 + cycle * .18);
}

final stages = List<StageSpec>.unmodifiable(List.generate(100, StageSpec.new));
