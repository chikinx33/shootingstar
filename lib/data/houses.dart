import 'package:flutter/material.dart';

/// v12 stages are houses in the cats' own small neighbourhood (user decision
/// 2026-10-24). The cats talk about saving the planet from the Vacuum Empire,
/// but what they really guard is the homes of the people who looked after
/// them. Clearing a house opens the next one like a tech tree.
class HouseSpec {
  const HouseSpec(this.place, this.owner, this.line, this.color);
  final String place, owner, line;
  final Color color;
}

const houseRoot = 'assets/art/houses_v12/';

const houses = [
  HouseSpec('민지네 집', '일곱 살 민지', '냥이야, 내 트램펄린 지켜 줘!', Color(0xFFFFC93C)),
  HouseSpec('할아버지 댁', '김 할아버지', '허허, 감나무만은 안 된다.', Color(0xFFB98A5B)),
  HouseSpec('수아 누나 옥탑', '대학생 수아 누나', '시험 기간이야… 조용히 부탁해.', Color(0xFF7FB6FF)),
  HouseSpec('쌍둥이네 집', '쌍둥이 준이·건이', '우리 장난감 자동차 지켜!', Color(0xFF5FD0FF)),
  HouseSpec('동네 빵집', '빵집 아저씨', '갓 구운 빵 냄새를 지켜 다오!', Color(0xFFFF9F59)),
  HouseSpec('꽃집 언니네', '꽃집 하나 언니', '온실 유리 조심해 줘!', Color(0xFF7DE08A)),
  HouseSpec('음악가 형네', '드러머 도윤 형', '내 드럼 세트는 소중하다고!', Color(0xFFFF6F7D)),
  HouseSpec('할머니 댁', '박 할머니', '연못 잉어들이 놀라겠구나.', Color(0xFFC79BFF)),
  HouseSpec('동네 파출소', '경찰관 아저씨', '순찰 협조 고맙다, 냥!', Color(0xFF6E8BFF)),
  HouseSpec('우리 집', '우리 집사', '오늘도 야근… 집은 네가 지켜 줘.', Color(0xFFFFB13B)),
];

/// Neighbourhood 2 (user request 2026-10-24): an autumn hill of shops and
/// homes — the cats' new neighbours.
const hillHouses = [
  HouseSpec('24시 편의점', '알바생 지호 형', '츄르 진열대만은 꼭 지켜 줘!', Color(0xFF7DE08A)),
  HouseSpec('동물병원', '수의사 윤 선생님', '오늘은 주사 없어, 진짜야.', Color(0xFF8FE3D0)),
  HouseSpec('태권도장', '태권도 관장님', '기합! 도장 지붕을 부탁한다!', Color(0xFF6E9BFF)),
  HouseSpec('세탁소', '세탁소 할아버지', '빨래가 다 젖으면 큰일이란다.', Color(0xFFB7C6FF)),
  HouseSpec('어린이집', '원장 선생님', '낮잠 시간이야, 쉿!', Color(0xFFFFD45C)),
  HouseSpec('캠핑카 언니네', '여행가 소라 언니', '내 캠핑카, 바퀴 하나도 못 줘!', Color(0xFFFFA25C)),
  HouseSpec('텃밭 아저씨네', '농부 아저씨', '토마토 다 익을 때까지만 버텨 줘.', Color(0xFFFF7A6B)),
  HouseSpec('동네 도서관', '사서 선생님', '도서관에선 정숙! 청소기는 더더욱!', Color(0xFFB98A5B)),
  HouseSpec('소방서', '소방관 누나', '불은 우리가 끌게, 청소기는 네가!', Color(0xFFFF5A4F)),
  HouseSpec('고양이 카페', '카페 사장님', '우리 카페 고양이들도 다 네 편이야!', Color(0xFFFFB13B)),
];

class Neighborhood {
  const Neighborhood(this.name, this.concept, this.houses);
  final String name, concept;
  final List<HouseSpec> houses;
}

/// Each campaign world is a neighbourhood of ten houses; worlds past the
/// drawn neighbourhoods revisit them in order (harder each time).
const neighborhoods = [
  Neighborhood('햇살 골목', '집사네 동네 · 고양이를 돌봐 준 이웃들의 집', houses),
  Neighborhood('노을 언덕', '단풍 든 언덕 동네 · 새 이웃들의 가게와 집', hillHouses),
];

int neighborhoodOf(int stageIndex) => (stageIndex ~/ 10) % neighborhoods.length;
Neighborhood neighborhoodForWorld(int world) =>
    neighborhoods[world % neighborhoods.length];

/// Index of the drawn house art: neighbourhood × 10 + house.
int houseArt(int stageIndex) =>
    neighborhoodOf(stageIndex) * 10 + stageIndex % 10;

HouseSpec houseOf(int stageIndex) =>
    neighborhoods[neighborhoodOf(stageIndex)].houses[stageIndex % 10];
String houseMap(int stageIndex) =>
    '${houseRoot}house_${houseArt(stageIndex)}.jpg';
String houseOwner(int stageIndex) =>
    '${houseRoot}owner_${houseArt(stageIndex)}.webp';
String streetMap(int stageIndex) => neighborhoodOf(stageIndex) == 0
    ? '${houseRoot}street.jpg'
    : '${houseRoot}street_${neighborhoodOf(stageIndex)}.jpg';

/// The boss archetypes that come for a house, in order (mirrors
/// `HouseBossKind` in lib/game/house_bosses.dart).
const houseBossStyles = [
  '거대 함선 · 보호막 발생기부터 부수기',
  '탄막 보스 · 빈틈으로 파고들기',
  '결투 보스 · 피하는 적을 앞질러 쏘기',
];
List<String> houseBosses(int stageIndex, int count) => [
  for (var wave = 0; wave < count; wave++)
    houseBossStyles[(stageIndex % 10 + wave) % 3],
];
