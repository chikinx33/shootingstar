import 'dart:math' as math;

/// v11 airframe equipment: the cat's "RPG armour". Five body slots whose
/// sprites replace the matching layers of the ship (see ShipSpriteArt), each
/// with a set, a rarity and a level. Weapons stay in the module bays.
enum CatGearSlot { nose, armor, wings, engines, shield }

const catGearSlotNames = {
  CatGearSlot.nose: '기수',
  CatGearSlot.armor: '동체 장갑',
  CatGearSlot.wings: '날개',
  CatGearSlot.engines: '추진기',
  CatGearSlot.shield: '보호막 장치',
};

/// Ship layout layers that show each slot (pairs mirror their left piece).
const catGearLayers = {
  CatGearSlot.nose: ['nose'],
  CatGearSlot.armor: ['armor'],
  CatGearSlot.wings: ['wing_l'],
  CatGearSlot.engines: ['engine_l'],
  CatGearSlot.shield: ['shield'],
};

/// File name of each slot's sprite inside a set folder.
const catGearFiles = {
  CatGearSlot.nose: 'nose.webp',
  CatGearSlot.armor: 'armor.webp',
  CatGearSlot.wings: 'wing_left.webp',
  CatGearSlot.engines: 'engine_left.webp',
  CatGearSlot.shield: 'shield.webp',
};

class CatGearSet {
  const CatGearSet(this.id, this.name, this.three, this.five);
  final String id;
  final String name;

  /// Set effect text at 3 and 5 equipped pieces.
  final String three, five;
  String asset(CatGearSlot slot) =>
      'assets/art/ship_parts/$id/${catGearFiles[slot]}';
}

const catGearSets = [
  CatGearSet('sunshine', '선샤인', '화력 +4%', '화력 +10%'),
  CatGearSet('night', '나이트 가드', '최대 선체 +6%', '최대 선체 +14% · 피해 감소 +4%'),
  CatGearSet('bloom', '벚꽃 블룸', '회수 범위 +8%', '회수 범위 +18% · 이동 속도 +6%'),
];

CatGearSet catGearSet(String id) =>
    catGearSets.firstWhere((s) => s.id == id, orElse: () => catGearSets.first);

const catGearRarityNames = ['일반', '고급', '희귀', '영웅', '전설'];
const catGearRarityColors = [
  0xFF9AA6B2,
  0xFF5BD06A,
  0xFF4AA8FF,
  0xFFB46BFF,
  0xFFFFB238,
];

class CatGearItem {
  CatGearItem({
    required this.id,
    required this.set,
    required this.slot,
    required this.rarity,
    this.level = 1,
    this.locked = false,
  });

  final int id;
  final String set;
  final CatGearSlot slot;
  final int rarity;
  int level;
  bool locked;

  int get maxLevel => 10 + rarity * 10;
  bool get maxed => level >= maxLevel;
  String get name => '${catGearSet(set).name} ${catGearSlotNames[slot]}';

  /// Slot stat as a fraction (0.12 = 12%).
  double get value {
    final r = rarity + 1;
    return switch (slot) {
      CatGearSlot.nose => .03 * r + .006 * level,
      CatGearSlot.armor => .04 * r + .008 * level,
      CatGearSlot.wings => .05 * r + .008 * level,
      CatGearSlot.engines => .02 * r + .003 * level,
      CatGearSlot.shield => .012 * r + .0022 * level,
    };
  }

  String get statLabel => switch (slot) {
    CatGearSlot.nose => '화력',
    CatGearSlot.armor => '최대 선체',
    CatGearSlot.wings => '회수 범위',
    CatGearSlot.engines => '이동 속도',
    CatGearSlot.shield => '피해 감소',
  };

  String get statText => '$statLabel +${(value * 100).toStringAsFixed(1)}%';

  /// Churu to raise one level; star dust every fifth level.
  int get upgradeChuru => 40 + 18 * level * (rarity + 1);
  int get upgradeStardust => level % 5 == 4 ? 2 + rarity * 2 : 0;

  /// What dismantling gives back: churu spent plus star dust by rarity.
  int get dismantleChuru {
    var spent = 0;
    for (var l = 1; l < level; l++) {
      spent += 40 + 18 * l * (rarity + 1);
    }
    return 20 + rarity * 30 + spent ~/ 2;
  }

  int get dismantleStardust => const [1, 2, 4, 8, 16][rarity];

  Map<String, dynamic> toJson() => {
    'id': id,
    'set': set,
    'slot': slot.name,
    'rarity': rarity,
    'level': level,
    if (locked) 'locked': true,
  };

  static CatGearItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final slot = CatGearSlot.values
        .where((s) => s.name == raw['slot'])
        .firstOrNull;
    final id = raw['id'], set = raw['set'], rarity = raw['rarity'];
    if (slot == null || id is! int || set is! String || rarity is! int) {
      return null;
    }
    if (!catGearSets.any((s) => s.id == set)) return null;
    final r = rarity.clamp(0, 4);
    final item = CatGearItem(id: id, set: set, slot: slot, rarity: r);
    final level = raw['level'];
    item.level = level is int ? level.clamp(1, item.maxLevel) : 1;
    item.locked = raw['locked'] == true;
    return item;
  }
}

class CatGearBonuses {
  const CatGearBonuses({
    this.damage = 0,
    this.hull = 0,
    this.speed = 0,
    this.pickup = 0,
    this.reduction = 0,
  });
  final double damage, hull, speed, pickup, reduction;
}

/// Everything the account owns plus what is equipped.
class CatGearState {
  CatGearState(this.items, this.equipped, this.nextId);

  final List<CatGearItem> items;
  final Map<CatGearSlot, int> equipped;
  int nextId;

  static const capacity = 120;

  /// A new pilot starts in the full common Sunshine set.
  factory CatGearState.starter() {
    final state = CatGearState([], {}, 1);
    for (final slot in CatGearSlot.values) {
      final item = state.add('sunshine', slot, 0);
      state.equipped[slot] = item.id;
    }
    return state;
  }

  CatGearItem add(String set, CatGearSlot slot, int rarity) {
    final item = CatGearItem(
      id: nextId++,
      set: set,
      slot: slot,
      rarity: rarity.clamp(0, 4),
    );
    items.add(item);
    return item;
  }

  CatGearItem? item(int id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  CatGearItem? equippedIn(CatGearSlot slot) {
    final id = equipped[slot];
    return id == null ? null : item(id);
  }

  bool isEquipped(CatGearItem i) => equipped[i.slot] == i.id;

  /// Count of equipped pieces per set.
  Map<String, int> get setCounts {
    final out = <String, int>{};
    for (final slot in CatGearSlot.values) {
      final i = equippedIn(slot);
      if (i != null) out[i.set] = (out[i.set] ?? 0) + 1;
    }
    return out;
  }

  CatGearBonuses get bonuses {
    double damage = 0, hull = 0, speed = 0, pickup = 0, reduction = 0;
    for (final slot in CatGearSlot.values) {
      final i = equippedIn(slot);
      if (i == null) continue;
      switch (slot) {
        case CatGearSlot.nose:
          damage += i.value;
        case CatGearSlot.armor:
          hull += i.value;
        case CatGearSlot.wings:
          pickup += i.value;
        case CatGearSlot.engines:
          speed += i.value;
        case CatGearSlot.shield:
          reduction += i.value;
      }
    }
    final counts = setCounts;
    int n(String id) => counts[id] ?? 0;
    if (n('sunshine') >= 5) {
      damage += .10;
    } else if (n('sunshine') >= 3) {
      damage += .04;
    }
    if (n('night') >= 5) {
      hull += .14;
      reduction += .04;
    } else if (n('night') >= 3) {
      hull += .06;
    }
    if (n('bloom') >= 5) {
      pickup += .18;
      speed += .06;
    } else if (n('bloom') >= 3) {
      pickup += .08;
    }
    return CatGearBonuses(
      damage: damage,
      hull: hull,
      speed: math.min(speed, .4),
      pickup: pickup,
      reduction: math.min(reduction, .3),
    );
  }

  /// Layer id → sprite asset override for the equipped sets.
  Map<String, String> get layerAssets => {
    for (final slot in CatGearSlot.values)
      if (equippedIn(slot) case final item?)
        for (final layer in catGearLayers[slot]!)
          layer: catGearSet(item.set).asset(slot),
  };

  /// Gear power shown on the hangar: a single comparable number.
  int get power {
    var total = 0;
    for (final slot in CatGearSlot.values) {
      final i = equippedIn(slot);
      if (i != null) total += 20 + (i.rarity + 1) * 25 + i.level * 6;
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
    'items': [for (final i in items) i.toJson()],
    'equipped': {for (final e in equipped.entries) e.key.name: e.value},
    'nextId': nextId,
  };

  static CatGearState restore(Object? raw) {
    if (raw is! Map) return CatGearState.starter();
    final items = <CatGearItem>[
      for (final i in (raw['items'] as List? ?? const []))
        if (CatGearItem.fromJson(i) case final item?) item,
    ];
    final ids = items.map((i) => i.id).toSet();
    final equipped = <CatGearSlot, int>{};
    final map = raw['equipped'];
    if (map is Map) {
      for (final slot in CatGearSlot.values) {
        final id = map[slot.name];
        if (id is int && ids.contains(id)) {
          final item = items.firstWhere((i) => i.id == id);
          if (item.slot == slot) equipped[slot] = id;
        }
      }
    }
    final maxId = items.fold<int>(0, (m, i) => math.max(m, i.id));
    final next = raw['nextId'];
    final state = CatGearState(
      items,
      equipped,
      math.max(next is int ? next : 1, maxId + 1),
    );
    if (items.isEmpty) return CatGearState.starter();
    return state;
  }

  /// Rolls a gear drop for a won flight. Deeper worlds and finales give
  /// better rarities; a world finale guarantees rare or better.
  CatGearItem rollDrop(
    math.Random rng, {
    required int stage,
    bool finale = false,
  }) {
    final world = (stage ~/ 10).clamp(0, 9);
    final roll = rng.nextDouble();
    // chance of each rarity grows with depth
    final legendary = .004 + world * .004;
    final epic = .03 + world * .012;
    final rare = .12 + world * .02;
    final fine = .32;
    var rarity = roll < legendary
        ? 4
        : roll < legendary + epic
        ? 3
        : roll < legendary + epic + rare
        ? 2
        : roll < legendary + epic + rare + fine
        ? 1
        : 0;
    if (finale) rarity = math.max(rarity, 2);
    final set = catGearSets[rng.nextInt(catGearSets.length)].id;
    final slot = CatGearSlot.values[rng.nextInt(CatGearSlot.values.length)];
    return add(set, slot, rarity);
  }
}
