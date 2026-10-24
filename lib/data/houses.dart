import 'package:flutter/material.dart';

/// v12 stages are houses in the cats' own small neighbourhood (user decision
/// 2026-10-24). The cats talk about saving the planet from the Vacuum Empire,
/// but what they really guard is the homes of the people who looked after
/// them. Clearing a house opens the next one like a tech tree.
///
/// [line] is the guardian cat's own resolve about the people of that home
/// (user 2026-10-25): humans never talk to the cats or ask them for help;
/// the cats quietly look after their humans.
class HouseSpec {
  const HouseSpec(this.place, this.owner, this.line, this.color);
  final String place, owner, line;
  final Color color;
}

const houseRoot = 'assets/art/houses_v12/';

const houses = [
  HouseSpec('민지네 집', '일곱 살 민지', '민지가 아끼는 트램펄린, 내가 지켜 주겠다냥.', Color(0xFFFFC93C)),
  HouseSpec('할아버지 댁', '김 할아버지', '할아버지의 감나무, 감 한 알도 못 뺏긴다냥.', Color(0xFFB98A5B)),
  HouseSpec('수아 누나 옥탑', '대학생 수아 누나', '시험공부 하는 누나가 깨지 않게 조용히 끝내자냥.', Color(0xFF7FB6FF)),
  HouseSpec('쌍둥이네 집', '쌍둥이 준이·건이', '쌍둥이의 장난감 자동차, 바퀴 하나도 안 내준다냥.', Color(0xFF5FD0FF)),
  HouseSpec('동네 빵집', '빵집 아저씨', '아저씨가 구운 빵 냄새, 아침까지 지켜 낸다냥.', Color(0xFFFF9F59)),
  HouseSpec('꽃집 언니네', '꽃집 하나 언니', '언니의 온실 유리, 금 하나 안 가게 지킨다냥.', Color(0xFF7DE08A)),
  HouseSpec('음악가 형네', '드러머 도윤 형', '형이 아끼는 드럼 세트, 흠집 하나 안 낸다냥.', Color(0xFFFF6F7D)),
  HouseSpec('할머니 댁', '박 할머니', '할머니 연못의 잉어들이 놀라지 않게 막자냥.', Color(0xFFC79BFF)),
  HouseSpec('동네 파출소', '경찰관 아저씨', '아저씨가 골목을 돌 때, 하늘은 내가 지킨다냥.', Color(0xFF6E8BFF)),
  HouseSpec('우리 집', '우리 집사', '야근하는 우리 집사가 돌아올 집, 내가 지킨다냥.', Color(0xFFFFB13B)),
];

/// Neighbourhood 2 (user request 2026-10-24): an autumn hill of shops and
/// homes — the cats' new neighbours.
const hillHouses = [
  HouseSpec('24시 편의점', '알바생 지호 형', '지호 형의 츄르 진열대, 절대 못 뺏긴다냥.', Color(0xFF7DE08A)),
  HouseSpec('동물병원', '수의사 윤 선생님', '주사는 무섭지만 선생님 병원은 내가 지킨다냥.', Color(0xFF8FE3D0)),
  HouseSpec('태권도장', '태권도 관장님', '관장님의 도장 지붕, 기합 넣고 지킨다냥!', Color(0xFF6E9BFF)),
  HouseSpec('세탁소', '세탁소 할아버지', '할아버지가 맡은 빨래가 젖지 않게 막아 주자냥.', Color(0xFFB7C6FF)),
  HouseSpec('어린이집', '원장 선생님', '아이들 낮잠 시간이다냥. 쉿, 조용히 끝내자.', Color(0xFFFFD45C)),
  HouseSpec('캠핑카 언니네', '여행가 소라 언니', '언니의 캠핑카, 바퀴 하나도 못 내준다냥.', Color(0xFFFFA25C)),
  HouseSpec('텃밭 아저씨네', '농부 아저씨', '토마토가 다 익을 때까지 텃밭을 지킨다냥.', Color(0xFFFF7A6B)),
  HouseSpec('동네 도서관', '사서 선생님', '도서관은 정숙이다냥. 청소기는 더더욱 안 된다.', Color(0xFFB98A5B)),
  HouseSpec('소방서', '소방관 누나', '누나는 불을 끄고, 청소기는 내가 막는다냥.', Color(0xFFFF5A4F)),
  HouseSpec('고양이 카페', '카페 사장님', '사장님의 카페 친구들, 모두 내가 지킨다냥!', Color(0xFFFFB13B)),
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
