/// Original Shootingstar collection rules. The reference APK establishes that
/// collection draws, upgrades, resets, set activation and fragment exchanges
/// exist; its prices, rewards and runtime rules were not recovered.
class RelicSpec {
  const RelicSpec(this.name, this.detail, this.setId);
  final String name, detail;
  final int setId;
}

class RelicSetSpec {
  const RelicSetSpec(this.name, this.passive, this.bonus);
  final String name, passive, bonus;
}

const relicSets = [
  RelicSetSpec('항로 개척', '등급당 화력 +0.4%', '완성 세트 활성: 화력 +4%'),
  RelicSetSpec('구조 신호', '등급당 선체 +0.5%', '완성 세트 활성: 선체 +4.5%'),
  RelicSetSpec('심우주 탐사', '등급당 회수 반경 +0.6%', '완성 세트 활성: 회수 반경 +6%'),
  RelicSetSpec('정밀 동기', '세트 총 15등급에서 쿨다운 단축 +1%', '완성 세트 활성: 쿨다운 단축 +1%'),
];

const relicCatalog = [
  RelicSpec('초신성 프리즘', '별빛의 주파수를 모아 주포의 출력을 안정시킵니다.', 0),
  RelicSpec('중력 조준경', '흐려진 항로에서도 목표의 윤곽을 읽어 냅니다.', 0),
  RelicSpec('파장 증폭기', '소실된 신호를 되살리는 오래된 항법 장치입니다.', 0),
  RelicSpec('구조 비콘', '고립된 탐사선에 귀환 방향을 알려 줍니다.', 1),
  RelicSpec('방호 축전지', '비상 착륙을 버틴 탐사대의 예비 전원입니다.', 1),
  RelicSpec('비상 격벽', '충격을 여러 겹으로 나누는 소형 차폐판입니다.', 1),
  RelicSpec('관측 나침반', '미세한 잔광을 따라 숨은 자원을 찾습니다.', 2),
  RelicSpec('유성 채집기', '멀리 흩어진 파편의 궤도를 계산합니다.', 2),
  RelicSpec('좌표 기록판', '수많은 탐사선의 회수 항로가 남아 있습니다.', 2),
  RelicSpec('펄스 시계', '전장의 작은 틈을 정확히 세는 정밀 시계입니다.', 3),
  RelicSpec('순환 조율기', '멈춰 있던 장치들의 신호 주기를 맞춥니다.', 3),
  RelicSpec('위상 릴레이', '다음 사격 신호를 빠짐없이 전달합니다.', 3),
];

class CollectionBook {
  static const maxLevel = 5;
  static const maxActiveSets = 2;
  static const resourceCap = 1000000;
  static const serialCap = 1000000000;
  static const supplyShards = 3;
  static const craftCost = 3;
  static const upgradeCosts = [1, 2, 4, 6, 8];

  int keys = 0, serial = 0, dust = 0;
  final List<int> shards = List.filled(relicCatalog.length, 0);
  final List<int> levels = List.filled(relicCatalog.length, 0);
  final List<int> _spent = List.filled(relicCatalog.length, 0);
  final Set<int> activeSets = {};

  int get nextRelicId => serial % relicCatalog.length;
  int get discoveredCount => levels.where((level) => level > 0).length;
  Set<int> get completeSets => {
    for (var set = 0; set < relicSets.length; set++)
      if (isSetComplete(set)) set,
  };

  bool _valid(int id) => id >= 0 && id < relicCatalog.length;
  bool isSetComplete(int id) =>
      id >= 0 &&
      id < relicSets.length &&
      List.generate(3, (i) => id * 3 + i).every((i) => levels[i] > 0);

  int upgradeCost(int id) =>
      !_valid(id) || levels[id] >= maxLevel ? 0 : upgradeCosts[levels[id]];
  int resetRefund(int id) => _valid(id) && levels[id] > 1 ? _spent[id] : 0;
  bool canUpgrade(int id) =>
      _valid(id) && levels[id] < maxLevel && shards[id] >= upgradeCost(id);
  bool get canOpenSupply =>
      keys > 0 &&
      serial >= 0 &&
      serial < serialCap &&
      shards[nextRelicId] <= resourceCap - supplyShards;
  bool canCraft(int id) =>
      _valid(id) && dust >= craftCost && shards[id] < resourceCap;
  bool canToggleSet(int id) =>
      activeSets.contains(id) ||
      (isSetComplete(id) && activeSets.length < maxActiveSets);

  /// Keys are earned in play. Every twelve draws supplies every relic once.
  bool openSupply() {
    if (!canOpenSupply) return false;
    final id = nextRelicId;
    keys--;
    shards[id] += supplyShards;
    serial++;
    return true;
  }

  bool upgrade(int id) {
    if (!canUpgrade(id)) return false;
    final cost = upgradeCost(id);
    shards[id] -= cost;
    // Discovery is retained by reset, so its one fragment is never refunded.
    if (levels[id] > 0) _spent[id] += cost;
    levels[id]++;
    return true;
  }

  /// Retains discovery and refunds only fragments actually spent on upgrades.
  bool reset(int id) {
    if (!_valid(id) || levels[id] <= 1) return false;
    final refund = resetRefund(id);
    if (shards[id] > resourceCap - refund) return false;
    shards[id] += refund;
    levels[id] = 1;
    _spent[id] = 0;
    return true;
  }

  bool toggleSet(int id) {
    if (!canToggleSet(id)) return false;
    if (!activeSets.remove(id)) activeSets.add(id);
    return true;
  }

  bool recycle(int id, int amount) {
    if (!_valid(id) ||
        amount <= 0 ||
        shards[id] < amount ||
        dust > resourceCap - amount) {
      return false;
    }
    shards[id] -= amount;
    dust += amount;
    return true;
  }

  bool craft(int id) {
    if (!canCraft(id)) return false;
    dust -= craftCost;
    shards[id]++;
    return true;
  }

  int _total(int set) => levels.skip(set * 3).take(3).fold(0, (a, b) => a + b);
  bool _active(int set) => activeSets.contains(set) && isSetComplete(set);
  double get damageBonus =>
      (_total(0) * .004 + (_active(0) ? .04 : 0)).clamp(0.0, .10);
  double get hullBonus =>
      (_total(1) * .005 + (_active(1) ? .045 : 0)).clamp(0.0, .12);
  double get pickupBonus =>
      (_total(2) * .006 + (_active(2) ? .06 : 0)).clamp(0.0, .15);
  double get cooldownBonus =>
      (_total(3) / 15 * .01 + (_active(3) ? .01 : 0)).clamp(0.0, .02);

  Map<String, dynamic> toJson() => {
    'version': 1,
    'keys': keys,
    'serial': serial,
    'dust': dust,
    // Return snapshots rather than references to mutable resource ledgers.
    'shards': List<int>.of(shards),
    'levels': List<int>.of(levels),
    'spent': List<int>.of(_spent),
    'activeSets': activeSets.toList()..sort(),
  };

  static CollectionBook restore(dynamic raw) {
    final result = CollectionBook();
    if (raw is! Map) return result;
    int read(dynamic value, int max) => value is int ? value.clamp(0, max) : 0;
    dynamic at(dynamic list, int index) =>
        list is List && index < list.length ? list[index] : null;
    result.keys = read(raw['keys'], resourceCap);
    result.serial = read(raw['serial'], serialCap);
    result.dust = read(raw['dust'], resourceCap);
    for (var id = 0; id < relicCatalog.length; id++) {
      result.shards[id] = read(at(raw['shards'], id), resourceCap);
      result.levels[id] = read(at(raw['levels'], id), maxLevel);
      final maxSpent = upgradeCosts
          .skip(1)
          .take((result.levels[id] - 1).clamp(0, maxLevel - 1))
          .fold(0, (a, b) => a + b);
      result._spent[id] = read(at(raw['spent'], id), maxSpent);
    }
    final active = raw['activeSets'];
    if (active is List) {
      final valid =
          active.whereType<int>().where(result.isSetComplete).toSet().toList()
            ..sort();
      result.activeSets.addAll(valid.take(maxActiveSets));
    }
    return result;
  }
}
