import 'package:flutter/foundation.dart';

import 'gear_traits.dart';
import 'ship_modules.dart';

enum AircraftMount {
  main,
  auxiliary,
  wings,
  rear,
  ground,
  armor,
  supportLeft,
  supportRight,
  supportRear,
}

enum AircraftTarget { air, ground }

enum ModuleRole {
  forward,
  omni,
  wing,
  rear,
  ground,
  armor,
  shield,
  repair,
  capacitor,
  ward,
}

@immutable
class AircraftPart {
  const AircraftPart(
    this.id,
    this.name,
    this.cell,
    this.mounts,
    this.role,
    this.targets,
    this.detail,
  );
  final String id, name, detail;
  final int cell;
  final Set<AircraftMount> mounts;
  final ModuleRole role;
  final Set<AircraftTarget> targets;
  bool get attacks => targets.isNotEmpty;
}

const supportMounts = {
  AircraftMount.supportLeft,
  AircraftMount.supportRight,
  AircraftMount.supportRear,
};
const aircraftParts = [
  AircraftPart(
    'cannon',
    '전방 주포',
    0,
    {AircraftMount.main},
    ModuleRole.forward,
    {AircraftTarget.air},
    '기수 방향으로만 발사',
  ),
  AircraftPart(
    'turret',
    '회전 포탑',
    1,
    {AircraftMount.auxiliary},
    ModuleRole.omni,
    {AircraftTarget.air},
    '본체 상부 · 전방위 대응',
  ),
  AircraftPart(
    'wing',
    '날개 포드',
    2,
    {AircraftMount.wings},
    ModuleRole.wing,
    {AircraftTarget.air},
    '좌우 날개에 한 쌍 장착',
  ),
  AircraftPart(
    'rear',
    '후방 방어포',
    3,
    {AircraftMount.rear},
    ModuleRole.rear,
    {AircraftTarget.air},
    '엔진 사이 · 후방만 공격',
  ),
  AircraftPart(
    'bomb',
    '지상 폭격창',
    4,
    {AircraftMount.ground},
    ModuleRole.ground,
    {AircraftTarget.ground},
    '복부 전용 · 지상 표적만 공격',
  ),
  AircraftPart(
    'armor',
    '측면 장갑',
    5,
    {AircraftMount.armor},
    ModuleRole.armor,
    {},
    '동체 양측에 장갑판 장착',
  ),
  AircraftPart(
    'auxShield',
    '차폐 발생기',
    6,
    {AircraftMount.auxiliary},
    ModuleRole.shield,
    {},
    '보조 슬롯 · 포탑과 교체 장착',
  ),
  AircraftPart(
    'reinforce',
    '보강 장갑',
    7,
    {AircraftMount.armor},
    ModuleRole.armor,
    {},
    '동체 양측에 보강판 장착',
  ),
  AircraftPart(
    'repair',
    '수리 포드',
    8,
    supportMounts,
    ModuleRole.repair,
    {},
    '비공격 지원 · 선체 회복',
  ),
  AircraftPart(
    'capacitor',
    '축전 포드',
    9,
    supportMounts,
    ModuleRole.capacitor,
    {},
    '비공격 지원 · 에너지 보급',
  ),
  AircraftPart(
    'ward',
    '차폐 포드',
    10,
    supportMounts,
    ModuleRole.ward,
    {},
    '비공격 지원 · 보호막 보충',
  ),
];
AircraftPart aircraftPart(String id) =>
    aircraftParts.firstWhere((part) => part.id == id);

/// Immutable loadout shared by profile, rendering and the combat snapshot.
@immutable
class AircraftAssembly {
  AircraftAssembly({
    this.hull = 0,
    this.modules,
    Map<AircraftMount, String> parts = const {},
    List<int> gearSpecs = const [],
  }) : gearSpecs = checkedGearSpecs(gearSpecs),
       parts = Map.unmodifiable(parts) {
    if (hull < 0 || hull > 2) throw ArgumentError.value(hull, 'hull');
    final supportIds = <String>{};
    for (final entry in this.parts.entries) {
      final part = aircraftPart(entry.value);
      if (!part.mounts.contains(entry.key))
        throw ArgumentError('Incompatible mount');
      if (supportMounts.contains(entry.key) && !supportIds.add(part.id)) {
        throw ArgumentError('Duplicate utility family');
      }
    }
  }
  factory AircraftAssembly.demo([int hull = 0]) => AircraftAssembly(
    hull: hull,
    parts: {
      AircraftMount.main: 'cannon',
      AircraftMount.auxiliary: 'turret',
      AircraftMount.wings: 'wing',
      AircraftMount.rear: 'rear',
      AircraftMount.ground: 'bomb',
      AircraftMount.armor: 'armor',
      AircraftMount.supportLeft: 'repair',
      AircraftMount.supportRight: 'capacitor',
      AircraftMount.supportRear: 'ward',
    },
  );
  static const petParts = ['capacitor', 'repair', 'ward'];
  static int petKind(String id) => petParts.indexOf(id);
  factory AircraftAssembly.initial(int hull, {Iterable<int> pets = const [0]}) {
    final basic = Map<AircraftMount, String>.of(
      AircraftAssembly.demo(hull).parts,
    )..removeWhere((mount, _) => supportMounts.contains(mount));
    var index = 0;
    for (final pet in pets.toSet()) {
      if (pet < 0 || pet > 2 || index >= 3) continue;
      basic[supportMounts.elementAt(index++)] = petParts[pet];
    }
    return AircraftAssembly(hull: hull, parts: basic);
  }
  Map<String, dynamic> toJson() => {
    'version': modules == null ? 1 : 2,
    if (modules != null) 'modules': modules!.toJson(),
    'parts': {for (final e in parts.entries) e.key.name: e.value},
  };
  factory AircraftAssembly.decode(dynamic raw, {int hull = 0}) {
    if (raw is Map && raw['version'] == 2) {
      final snapshot = ModuleSnapshot.restore(raw['modules']);
      if (snapshot.hull != hull)
        throw const FormatException('Mismatched airframe');
      return AircraftAssembly(hull: hull, modules: snapshot);
    }
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['parts'] is! Map ||
        (raw['parts'] as Map).length > 9) {
      throw const FormatException('Invalid aircraft assembly');
    }
    try {
      final entries = (raw['parts'] as Map).entries;
      return AircraftAssembly(
        hull: hull,
        parts: {
          for (final e in entries)
            AircraftMount.values.byName(e.key as String): e.value as String,
        },
      );
    } catch (_) {
      throw const FormatException('Invalid aircraft part');
    }
  }
  // Derived render metadata. Ownership remains in Profile inventory IDs.
  final ModuleSnapshot? modules;
  final List<int> gearSpecs;
  final int hull;
  final Map<AircraftMount, String> parts;
  AircraftAssembly withHull(int value) => AircraftAssembly(
    hull: value,
    parts: parts,
    gearSpecs: gearSpecs,
    modules: modules?.withHull(value),
  );
  AircraftAssembly withGear(List<int> values) => modules != null
      ? this
      : AircraftAssembly(hull: hull, parts: parts, gearSpecs: values);
  bool canEquip(AircraftMount mount, AircraftPart part) =>
      part.mounts.contains(mount) &&
      (!supportMounts.contains(mount) ||
          !parts.entries.any((e) => e.key != mount && e.value == part.id));
  AircraftAssembly equip(AircraftMount mount, String? id) {
    final next = Map<AircraftMount, String>.of(parts);
    if (id == null) {
      next.remove(mount);
    } else {
      next[mount] = id;
    }
    return AircraftAssembly(hull: hull, parts: next, gearSpecs: gearSpecs);
  }
}
