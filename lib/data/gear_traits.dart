import 'content_catalog.dart';

/// Existing spec IDs remain the sole identity for ownership, merges and perks.
const baseGearTraits = [
  '8회 사격마다 주포 관통 +1',
  '8회 사격마다 전방 유도 로켓 · 최대 3표적',
  '6초마다 공중 적 1기를 2초 표식 · 받는 피해 +20%',
  '4초마다 300 이내 경험치 4개를 회수 범위로 견인',
  '10초마다 2초 과출력 · 부품 피해 +10%',
  '주포 8회마다 에너지 +2 · 파일럿 대기 0.5초 단축',
  '최대 선체 10% 이상 피격 시 2% 차폐 · 12초 간격',
  '30초마다 최대 선체의 2% 회복',
  '12초마다 근접 적탄 1발 차단',
  '선체 35% 이하 피격 시 6% 차폐 · 30초 간격',
  '이동 중 12초마다 1초 가속 · 이동 속도 +12%',
  '기본 경험치 32 회수마다 에너지 +3 · 파일럿 대기 0.3초 단축',
];

String gearTraitDescription(int spec) =>
    spec < 12 ? baseGearTraits[spec] : '같은 세계 희귀 이상 선체·추진기 2개 장착 시 발동';

bool validGearSpecs(List<int> specs) =>
    specs.isEmpty ||
    specs.length == 6 &&
        List.generate(6, (i) => i).every(
          (slot) =>
              specs[slot] >= 0 &&
              specs[slot] < gearCatalog.length &&
              gearCatalog[specs[slot]].slot == slot,
        );

List<int> checkedGearSpecs(Iterable<int> raw) {
  final specs = List<int>.unmodifiable(raw);
  if (!validGearSpecs(specs))
    throw const FormatException('Invalid gear loadout');
  return specs;
}

/// Comparable contribution only: perks, set effects and roles stay explicit.
double gearBaseContribution(GearItem g) => g.definition.slot < 3
    ? g.rank * .06 +
          g.level * .02 +
          (g.spec == 2
              ? .02 * (g.rank + 1)
              : g.spec == 4
              ? .03 * (g.rank + 1)
              : 0)
    : g.rank * .08 +
          g.level * .025 +
          (g.spec == 6
              ? .04 * (g.rank + 1)
              : g.spec == 9
              ? .03 * (g.rank + 1)
              : 0);
