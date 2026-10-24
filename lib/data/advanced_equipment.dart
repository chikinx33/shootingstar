import 'content_catalog.dart';

/// Own deterministic adaptation of the reference's refinement/fusion panels.
/// No original recipe, cost or probability table was recovered from the XAPK.
class EquipmentGrowth {
  const EquipmentGrowth({
    this.refinement = 0,
    this.mode = 0,
    this.ascension = 0,
    this.spentCredits = 0,
    this.spentPlans = 0,
    this.materials = const [],
  });
  final int refinement, mode, ascension, spentCredits, spentPlans;
  final List<GearItem> materials;
  Map<String, dynamic> toJson(int id) => {
    'id': id,
    'refinement': refinement,
    'mode': mode,
    'ascension': ascension,
    'spentCredits': spentCredits,
    'spentPlans': spentPlans,
    'materials': materials.map((g) => g.toJson()).toList(),
  };
}

class AdvancedBonuses {
  const AdvancedBonuses(this.damage, this.hull, this.pickup);
  final double damage, hull, pickup;
}

/// The caller commits the returned wallet/inventory changes synchronously and
/// saves once. A null result never changes either the ledger or an input item.
class AdvancedChange {
  const AdvancedChange({
    required this.creditsCost,
    required this.plansCost,
    this.consumedIds = const [],
    this.returnedItems = const [],
  });
  final int creditsCost, plansCost;
  final List<int> consumedIds;
  final List<GearItem> returnedItems;
}

class AdvancedEquipment {
  final Map<int, EquipmentGrowth> _entries = {};
  final Map<int, int> _slots = {};
  static const modeNames = ['출력', '방호', '회수'];
  static const modeEffects = [
    '단계마다 화력 +0.5%',
    '단계마다 선체 +0.75%',
    '단계마다 회수 반경 +1%',
  ];
  static const maxRefinement = 3, maxAscension = 2;

  EquipmentGrowth? entry(int id) {
    final state = _entries[id];
    if (state == null) return null;
    return EquipmentGrowth(
      refinement: state.refinement,
      mode: state.mode,
      ascension: state.ascension,
      spentCredits: state.spentCredits,
      spentPlans: state.spentPlans,
      materials: List.unmodifiable(
        state.materials.map((g) => GearItem.restore(g.toJson())!),
      ),
    );
  }

  bool isProtected(int id) => _entries.containsKey(id);
  int get highestReservedId => _entries.entries.fold(0, (highest, e) {
    var value = e.key > highest ? e.key : highest;
    for (final material in e.value.materials) {
      if (material.id > value) value = material.id;
    }
    return value;
  });
  void pruneTo(Set<int> inventoryIds) {
    _entries.removeWhere((id, _) => !inventoryIds.contains(id));
    _slots.removeWhere((id, _) => !inventoryIds.contains(id));
  }

  int refineCredits(int id) => 150 + (entry(id)?.refinement ?? 0) * 100;
  int refinePlans(int id) => 3 + (entry(id)?.refinement ?? 0) * 2;
  int ascendCredits(int id) => (entry(id)?.ascension ?? 0) == 0 ? 600 : 1000;
  int ascendPlans(int id) => (entry(id)?.ascension ?? 0) == 0 ? 10 : 16;

  bool canRefine(GearItem g) =>
      g.rank >= 1 && (entry(g.id)?.refinement ?? 0) < maxRefinement;
  bool canAscend(GearItem g) =>
      g.rank >= 2 &&
      entry(g.id)?.refinement == maxRefinement &&
      (entry(g.id)?.ascension ?? 0) < maxAscension;

  AdvancedChange? refine({
    required GearItem target,
    required int credits,
    required int plans,
    required int mode,
  }) {
    if (!canRefine(target) || mode < 0 || mode >= modeNames.length) return null;
    final c = refineCredits(target.id), p = refinePlans(target.id);
    if (credits < c || plans < p) return null;
    final old = entry(target.id) ?? const EquipmentGrowth();
    _slots[target.id] = target.definition.slot;
    _entries[target.id] = EquipmentGrowth(
      refinement: old.refinement + 1,
      mode: mode,
      ascension: old.ascension,
      spentCredits: old.spentCredits + c,
      spentPlans: old.spentPlans + p,
      materials: old.materials,
    );
    return AdvancedChange(creditsCost: c, plansCost: p);
  }

  bool chooseMode(int id, int mode) {
    final old = entry(id);
    if (old == null ||
        mode < 0 ||
        mode >= modeNames.length ||
        mode == old.mode) {
      return false;
    }
    _entries[id] = EquipmentGrowth(
      refinement: old.refinement,
      mode: mode,
      ascension: old.ascension,
      spentCredits: old.spentCredits,
      spentPlans: old.spentPlans,
      materials: old.materials,
    );
    return true;
  }

  List<GearItem> candidates({
    required GearItem target,
    required List<GearItem> inventory,
    required Iterable<int> equipped,
    Iterable<int> protectedIds = const [],
  }) {
    final protected = {...equipped, ...protectedIds};
    return inventory
        .where(
          (g) =>
              g.id != target.id &&
              g.definition.slot == target.definition.slot &&
              g.rank >= 1 &&
              g.level == 0 &&
              g.spentCredits == 0 &&
              g.spentPlans == 0 &&
              !g.locked &&
              !protected.contains(g.id) &&
              !isProtected(g.id),
        )
        .toList();
  }

  AdvancedChange? ascend({
    required GearItem target,
    required List<GearItem> inventory,
    required Iterable<int> equipped,
    Iterable<int> protectedIds = const [],
    required List<int> materialIds,
    required int credits,
    required int plans,
  }) {
    if (!canAscend(target) ||
        materialIds.length != 2 ||
        materialIds.toSet().length != 2 ||
        !inventory.any((g) => identical(g, target))) {
      return null;
    }
    final c = ascendCredits(target.id), p = ascendPlans(target.id);
    if (credits < c || plans < p) return null;
    final safe = candidates(
      target: target,
      inventory: inventory,
      equipped: equipped,
      protectedIds: protectedIds,
    );
    final selected = <GearItem>[];
    for (final id in materialIds) {
      final found = safe.where((g) => g.id == id);
      if (found.length != 1) return null;
      selected.add(GearItem.restore(found.single.toJson())!);
    }
    final old = entry(target.id)!;
    _entries[target.id] = EquipmentGrowth(
      refinement: old.refinement,
      mode: old.mode,
      ascension: old.ascension + 1,
      spentCredits: old.spentCredits + c,
      spentPlans: old.spentPlans + p,
      materials: List.unmodifiable([...old.materials, ...selected]),
    );
    return AdvancedChange(
      creditsCost: c,
      plansCost: p,
      consumedIds: List.unmodifiable(materialIds),
    );
  }

  AdvancedChange? reset({
    required int targetId,
    required List<GearItem> inventory,
  }) {
    final old = entry(targetId);
    if (old == null ||
        !inventory.any((g) => g.id == targetId) ||
        inventory.length + old.materials.length > 240 ||
        old.materials.any((m) => inventory.any((g) => g.id == m.id))) {
      return null;
    }
    final returned = old.materials
        .map((m) => GearItem.restore(m.toJson())!)
        .toList();
    _entries.remove(targetId);
    _slots.remove(targetId);
    return AdvancedChange(
      creditsCost: -old.spentCredits,
      plansCost: -old.spentPlans,
      returnedItems: List.unmodifiable(returned),
    );
  }

  AdvancedBonuses bonuses(Iterable<GearItem> equipped) {
    return _bonuses(equipped.map((g) => (g.id, g.definition.slot)));
  }

  double damageBonus(Iterable<int> equippedIds) =>
      _bonusesById(equippedIds).damage;
  double hullBonus(Iterable<int> equippedIds) => _bonusesById(equippedIds).hull;
  double pickupBonus(Iterable<int> equippedIds) =>
      _bonusesById(equippedIds).pickup;
  AdvancedBonuses _bonusesById(Iterable<int> equippedIds) => _bonuses(
    equippedIds.where(_slots.containsKey).map((id) => (id, _slots[id]!)),
  );
  AdvancedBonuses _bonuses(Iterable<(int, int)> equipped) {
    double damage = 0, hull = 0, pickup = 0;
    final seen = <int>{};
    for (final (id, slot) in equipped) {
      if (!seen.add(id)) continue;
      final state = entry(id);
      if (state == null) continue;
      switch (state.mode) {
        case 0:
          damage += state.refinement * .005;
        case 1:
          hull += state.refinement * .0075;
        case 2:
          pickup += state.refinement * .01;
      }
      if (slot < 3) {
        damage += state.ascension * .015;
      } else {
        hull += state.ascension * .02;
      }
    }
    return AdvancedBonuses(
      damage.clamp(0, .18),
      hull.clamp(0, .255),
      pickup.clamp(0, .18),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'entries': _entries.entries.map((e) => e.value.toJson(e.key)).toList(),
  };

  static AdvancedEquipment restore(
    dynamic raw, {
    required List<GearItem> inventory,
  }) {
    final result = AdvancedEquipment();
    if (raw is! Map || raw['entries'] is! List) return result;
    final byId = {for (final g in inventory) g.id: g};
    final consumed = <int>{};
    for (final row in (raw['entries'] as List).take(240)) {
      if (row is! Map || row['id'] is! int) continue;
      final id = row['id'] as int, target = byId[id];
      if (target == null || result._entries.containsKey(id)) continue;
      final refinement = boundedInt(row['refinement'], 0, maxRefinement);
      if (refinement == 0 || target.rank < 1) continue;
      var ascension = boundedInt(row['ascension'], 0, maxAscension);
      if (target.rank < 2 || refinement < maxRefinement) ascension = 0;
      final materials = <GearItem>[];
      var validMaterials = row['materials'] is List;
      if (validMaterials) {
        for (final saved in (row['materials'] as List).take(4)) {
          final material = GearItem.restore(saved);
          if (material == null ||
              material.id == id ||
              byId.containsKey(material.id) ||
              consumed.contains(material.id) ||
              materials.any((g) => g.id == material.id) ||
              material.definition.slot != target.definition.slot ||
              material.rank < 1 ||
              material.level != 0 ||
              material.locked ||
              material.spentCredits != 0 ||
              material.spentPlans != 0) {
            validMaterials = false;
            break;
          }
          materials.add(material);
        }
      }
      if (!validMaterials || materials.length != ascension * 2) {
        // Preserve safe refinement but never fabricate materials/refunds for a
        // damaged fusion record.
        ascension = 0;
        materials.clear();
      }
      consumed.addAll(materials.map((g) => g.id));
      final refinementCredits =
          refinement * 150 + 50 * refinement * (refinement - 1);
      final refinementPlans = refinement * 3 + refinement * (refinement - 1);
      final ceilingCredits =
          refinementCredits +
          (ascension > 0 ? 600 : 0) +
          (ascension > 1 ? 1000 : 0);
      final ceilingPlans =
          refinementPlans + (ascension > 0 ? 10 : 0) + (ascension > 1 ? 16 : 0);
      result._entries[id] = EquipmentGrowth(
        refinement: refinement,
        mode: boundedInt(row['mode'], 0, 2),
        ascension: ascension,
        spentCredits: boundedInt(row['spentCredits'], 0, ceilingCredits),
        spentPlans: boundedInt(row['spentPlans'], 0, ceilingPlans),
        materials: List.unmodifiable(materials),
      );
      result._slots[id] = target.definition.slot;
    }
    return result;
  }
}
