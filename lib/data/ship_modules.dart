import 'dart:ui';
import 'dart:math' as math;

// Canonical system: one mount, one owned instance. Legacy inventory is archival.
enum ModuleKind { wing, belly, tail, top, support }

enum PartCategory { gun, missile, drone, support }

class MountProfile {
  const MountProfile(
    this.id,
    this.name,
    this.kind,
    this.direction,
    this.behavior,
    this.damageMul,
    this.fireRateMul,
    this.aoeMul,
    this.countMul,
    this.countAdd,
    this.pierceAdd,
    this.canHitGround,
    this.rangeMul, {
    this.droneFireRateMul = 1,
  });
  final String id, name, direction, behavior;
  final ModuleKind kind;
  final double damageMul, fireRateMul, aoeMul, countMul, rangeMul;
  final double droneFireRateMul;
  final int countAdd, pierceAdd;
  final bool canHitGround;
  bool get weapon => kind != ModuleKind.support;
  String roleFor(PartCategory category) => switch ((kind, category)) {
    (ModuleKind.wing, PartCategory.gun) => '전방 군집 확산 · 중앙 단일 표적에 불리',
    (ModuleKind.wing, PartCategory.missile) => '전방 추적 연사 · 측후방 사각',
    (ModuleKind.wing, PartCategory.drone) => '좌우 엄호·요격 · 정면 사각',
    (ModuleKind.belly, PartCategory.gun) => '직선 관통·보스 정밀 · 조준 필요',
    (ModuleKind.belly, PartCategory.missile) => '지상·밀집 범위 폭발 · 긴 재장전',
    (ModuleKind.belly, PartCategory.drone) => '전방 요격 방패 · 뒤쪽 사각',
    (ModuleKind.tail, PartCategory.gun) => '후방 확산 · 정면 사각',
    (ModuleKind.tail, PartCategory.missile) => '뒤쫓는 군집 추적 · 정면 사각',
    (ModuleKind.tail, PartCategory.drone) => '후방 호위·탄환 차단 · 정면 사각',
    (ModuleKind.top, PartCategory.gun) => '360° 자동 조준 · 짧은 사거리',
    (ModuleKind.top, PartCategory.missile) => '주변 다중 낙하 · 피해 분산',
    (ModuleKind.top, PartCategory.drone) => '360° 회전 방공 · 짧은 사거리',
    _ => '위치 효과 없음',
  };
}

const moduleProfiles = <MountProfile>[
  MountProfile(
    'W1',
    '날개끝',
    ModuleKind.wing,
    '전방 ±15°',
    'twin_outward',
    .7,
    1.2,
    .8,
    2,
    0,
    0,
    false,
    1,
  ),
  MountProfile(
    'W2',
    '동체 하부',
    ModuleKind.belly,
    '전방 직선',
    'single_heavy',
    1.4,
    .7,
    1.3,
    1,
    0,
    1,
    true,
    1,
  ),
  MountProfile(
    'W3',
    '후미',
    ModuleKind.tail,
    '후방 60°',
    'rear_fan',
    .6,
    1,
    1,
    1,
    2,
    0,
    false,
    1,
  ),
  MountProfile(
    'W4',
    '상부',
    ModuleKind.top,
    '360° 자동 조준',
    'turret',
    .6,
    1,
    .9,
    1,
    0,
    0,
    false,
    .8,
    droneFireRateMul: 1.4,
  ),
  MountProfile(
    'S1',
    '보조 1',
    ModuleKind.support,
    '위치 효과 없음',
    'support',
    1,
    1,
    1,
    1,
    0,
    0,
    false,
    1,
  ),
  MountProfile(
    'S2',
    '보조 2',
    ModuleKind.support,
    '위치 효과 없음',
    'support',
    1,
    1,
    1,
    1,
    0,
    0,
    false,
    1,
  ),
  MountProfile(
    'S3',
    '보조 3',
    ModuleKind.support,
    '위치 효과 없음',
    'support',
    1,
    1,
    1,
    1,
    0,
    0,
    false,
    1,
  ),
];
MountProfile mountProfile(String id) =>
    moduleProfiles.firstWhere((m) => m.id == id);

class ModulePart {
  const ModulePart(
    this.id,
    this.name,
    this.category,
    this.damage,
    this.rate,
    this.aoe,
    this.speed,
    this.effect,
    this.behaviors, {
    this.bossDamageMultiplier = 1,
    this.droneBaseHealth = 0,
    this.droneRecovery = 4,
  });
  final String id, name, effect;
  final PartCategory category;
  final double damage, rate, aoe, speed;
  final double bossDamageMultiplier, droneBaseHealth, droneRecovery;
  final Map<ModuleKind, String> behaviors;
  bool get weapon => category != PartCategory.support;
  bool get homing => category == PartCategory.missile;
  String get projectile => category == PartCategory.missile
      ? 'rocket'
      : weapon
      ? 'bullet'
      : 'none';
  String get element =>
      category == PartCategory.missile ? 'explosive' : 'kinetic';
}

const moduleParts = <ModulePart>[
  ModulePart(
    'gun_vulcan',
    '발칸 건',
    PartCategory.gun,
    11,
    2.2,
    0,
    340,
    '정밀 운동탄 · 보스 피해 +50% · 비유도',
    {
      ModuleKind.wing: 'twin_outward',
      ModuleKind.belly: 'single_heavy',
      ModuleKind.tail: 'rear_fan',
      ModuleKind.top: 'turret',
    },
    bossDamageMultiplier: 1.5,
  ),
  ModulePart(
    'missile_hawk',
    '호크 미사일',
    PartCategory.missile,
    22,
    .65,
    38,
    215,
    '유도 폭발탄 · 지상 타격 · 보스 피해 70%',
    {
      ModuleKind.wing: 'alternating_homing',
      ModuleKind.belly: 'heavy_homing',
      ModuleKind.tail: 'rear_homing',
      ModuleKind.top: 'vertical_salvo',
    },
    bossDamageMultiplier: .7,
  ),
  ModulePart(
    'drone_wasp',
    '와스프 드론',
    PartCategory.drone,
    9,
    1.6,
    0,
    300,
    '운동탄 · 탄환 요격 · 기본 체력 42 · 재정비 4초',
    {
      ModuleKind.wing: 'formation_side',
      ModuleKind.belly: 'lead',
      ModuleKind.tail: 'trail',
      ModuleKind.top: 'orbit',
    },
    droneBaseHealth: 42,
  ),
  // v12 rear self-propelled gun: lobs shells over the cat onto the crowd
  ModulePart(
    'mortar_cat',
    '후방 자주포',
    PartCategory.gun,
    26,
    .55,
    48,
    260,
    '포물선 포탄 · 앞쪽 적 무리에 착탄 폭발',
    {
      ModuleKind.wing: 'mortar',
      ModuleKind.belly: 'mortar',
      ModuleKind.tail: 'mortar',
      ModuleKind.top: 'mortar',
    },
  ),
  ModulePart(
    'shield',
    '보호막 발생기',
    PartCategory.support,
    0,
    0,
    0,
    0,
    '2초마다 기본 선체의 2.5% 충전 · 피격 후 6초 대기 · 상한 22%',
    {},
  ),
  ModulePart(
    'repair',
    '수리 포드',
    PartCategory.support,
    0,
    0,
    0,
    0,
    '12초마다 기본 선체의 1.8% 회복',
    {},
  ),
  ModulePart(
    'armor',
    '보강 장갑',
    PartCategory.support,
    0,
    0,
    0,
    0,
    '받는 피해 6% 감소',
    {},
  ),
  ModulePart(
    'sensor',
    '표식 센서',
    PartCategory.support,
    0,
    0,
    0,
    0,
    '6초마다 공중 적 표식 · 2초간 받는 피해 +20%',
    {},
  ),
  ModulePart(
    'capacitor',
    '축전 포드',
    PartCategory.support,
    0,
    0,
    0,
    0,
    '궁극기 에너지 충전 속도 +15%',
    {},
  ),
  ModulePart(
    'magnet',
    '자석 모듈',
    PartCategory.support,
    0,
    0,
    0,
    0,
    '경험치 회수 반경 +20%',
    {},
  ),
  ModulePart(
    'thruster',
    '보조 추진기',
    PartCategory.support,
    0,
    0,
    0,
    0,
    '이동 속도 +8% · 이동 중 주기적 가속',
    {},
  ),
];

/// v12: the rear self-propelled gun's own sprite on the cat airframes'
/// 'rear_gun' layer (stored upside down because that layer turns 180°).
const mortarMountAsset = 'assets/art/icons_v12/mortar_mount.webp';

ModulePart modulePart(String id) => moduleParts.firstWhere((p) => p.id == id);

class OwnedModulePart {
  const OwnedModulePart(this.instanceId, this.partId, this.level);
  final String instanceId, partId;
  final int level;
  ModulePart get definition => modulePart(partId);
  OwnedModulePart leveled() => OwnedModulePart(instanceId, partId, level + 1);
  Map<String, dynamic> toJson() => {
    'id': instanceId,
    'part': partId,
    'level': level,
  };
  factory OwnedModulePart.restore(dynamic raw) {
    if (raw is! Map ||
        raw['id'] is! String ||
        (raw['id'] as String).isEmpty ||
        (raw['id'] as String).length > 80 ||
        raw['level'] is! int ||
        raw['level'] < 1 ||
        raw['level'] > 40 ||
        !moduleParts.any((p) => p.id == raw['part'])) {
      throw const FormatException('Invalid module instance');
    }
    return OwnedModulePart(raw['id'], raw['part'], raw['level']);
  }
}

class ModuleStats {
  const ModuleStats(
    this.damage,
    this.fireRate,
    this.aoe,
    this.count,
    this.pierce,
    this.range,
    this.speed,
    this.supportPower,
    this.bossDamage,
    this.droneHealth,
    this.droneRecovery,
  );
  final double damage, fireRate, aoe, range, speed, supportPower;
  final double bossDamage, droneHealth, droneRecovery;
  final int count, pierce;
}

ModuleStats resolvePartStats(
  OwnedModulePart part,
  MountProfile mount, {
  double damageBonus = 0,
  double rateBonus = 0,
  double aoeBonus = 0,
  int extraCount = 0,
}) {
  final p = part.definition;
  final scale = 1 + (part.level - 1) * .08;
  final baseCount = 1 + (part.level >= 5 ? 1 : 0);
  final damage = p.damage * scale * mount.damageMul * (1 + damageBonus);
  return ModuleStats(
    damage,
    p.rate *
        (1 + (part.level - 1) * .015) *
        mount.fireRateMul *
        (p.category == PartCategory.drone ? mount.droneFireRateMul : 1) *
        (1 + rateBonus),
    p.aoe * (1 + (part.level - 1) * .02) * mount.aoeMul * (1 + aoeBonus),
    (baseCount * mount.countMul).round() + mount.countAdd + extraCount,
    mount.pierceAdd + (part.level >= 10 ? 1 : 0),
    520 * mount.rangeMul,
    p.speed,
    1 + (part.level - 1) * .04,
    damage * p.bossDamageMultiplier,
    p.droneBaseHealth * (1 + (part.level - 1) * .05),
    p.droneRecovery,
  );
}

class ModuleSnapshot {
  ModuleSnapshot(
    this.hull,
    this.airframeLevel,
    Map<String, OwnedModulePart> parts,
  ) : parts = Map.unmodifiable(parts) {
    if (hull < 0 || hull > 2 || airframeLevel < 1 || airframeLevel > 40)
      throw const FormatException('Invalid airframe');
    final ids = <String>{}, supports = <String>{};
    for (final e in this.parts.entries) {
      if (!moduleProfiles.any((m) => m.id == e.key) ||
          !ids.add(e.value.instanceId) ||
          mountProfile(e.key).weapon != e.value.definition.weapon ||
          (!e.value.definition.weapon && !supports.add(e.value.partId)))
        throw const FormatException('Invalid loadout');
    }
  }
  final int hull, airframeLevel;
  final Map<String, OwnedModulePart> parts;
  String get signature => const ['pulse', 'revolver', 'shotgun'][hull];
  String get signatureName => const ['냥냥 연사포', '정밀 냥냥포', '꾹꾹 산탄포'][hull];
  String get ultimateName => const ['별똥별 광선', '냥냥 미사일 폭풍', '꾹꾹이 충격파'][hull];
  Iterable<OwnedModulePart> get supports =>
      parts.values.where((p) => !p.definition.weapon);
  bool hasSupport(String id) => supports.any((p) => p.partId == id);
  int supportLevel(String id) =>
      supports.where((p) => p.partId == id).firstOrNull?.level ?? 0;
  double supportPower(String id) {
    final part = supports.where((p) => p.partId == id).firstOrNull;
    return part == null
        ? 0
        : resolvePartStats(part, mountProfile('S1')).supportPower;
  }

  double get hitRadius => const [12.0, 10.0, 14.0][hull];
  ModuleSnapshot withHull(int hull) =>
      ModuleSnapshot(hull, airframeLevel, parts);
  Map<String, dynamic> toJson() => {
    'hull': hull,
    'level': airframeLevel,
    'parts': parts.map((k, v) => MapEntry(k, v.toJson())),
  };
  factory ModuleSnapshot.restore(dynamic raw) {
    if (raw is! Map || raw['parts'] is! Map || (raw['parts'] as Map).length > 7)
      throw const FormatException('Invalid module snapshot');
    return ModuleSnapshot(
      raw['hull'] as int,
      raw['level'] as int,
      (raw['parts'] as Map).map(
        (k, v) => MapEntry(k as String, OwnedModulePart.restore(v)),
      ),
    );
  }
}

class ModuleFleet {
  final Map<String, OwnedModulePart> owned = {};
  final Map<int, Map<String, String>> loadouts = {};
  final Map<int, int> airframeLevels = {};
  final Set<int> convertedGear = {};
  final Map<String, dynamic> legacyArchive = {};
  int serial = 1;

  /// v12: every fleet receives one rear self-propelled gun, and a rear bay
  /// still holding the old backward Vulcan switches to it (the Vulcan stays
  /// owned). Runs once per fleet.
  bool mortarGranted = false;
  void grantMortar() {
    if (mortarGranted) return;
    mortarGranted = true;
    final mortar =
        owned.values.where((p) => p.partId == 'mortar_cat').firstOrNull ??
        add('mortar_cat');
    if (loadouts.values.any((l) => l.containsValue(mortar.instanceId))) return;
    for (final loadout in loadouts.values) {
      if (owned[loadout['W3']]?.partId == 'gun_vulcan') {
        loadout['W3'] = mortar.instanceId;
        break;
      }
    }
  }

  OwnedModulePart add(String definition, {int level = 1, String? id}) {
    final item = OwnedModulePart(
      id ?? 'p${serial++}',
      definition,
      level.clamp(1, 40),
    );
    owned[item.instanceId] = item;
    return item;
  }

  void seed(int hull) {
    if (loadouts.containsKey(hull)) return;
    loadouts[hull] = {
      'W1': add('gun_vulcan').instanceId,
      'W2': add('missile_hawk').instanceId,
      'W3': add('mortar_cat').instanceId,
      'W4': add('drone_wasp').instanceId,
    };
    airframeLevels.putIfAbsent(hull, () => 1);
  }

  ModuleSnapshot preview(int hull) =>
      loadouts.containsKey(hull) ? snapshot(hull) : ModuleSnapshot(hull, 1, {});
  ModuleSnapshot snapshot(int hull) {
    seed(hull);
    return ModuleSnapshot(hull, airframeLevels[hull] ?? 1, {
      for (final e in loadouts[hull]!.entries)
        if (owned[e.value] != null) e.key: owned[e.value]!,
    });
  }

  bool equip(int hull, String mount, String? instance) {
    seed(hull);
    if (!moduleProfiles.any((m) => m.id == mount)) return false;
    final next = Map<String, String>.of(loadouts[hull]!);
    if (instance == null) {
      next.remove(mount);
    } else {
      final item = owned[instance];
      if (item == null || item.definition.weapon != mountProfile(mount).weapon)
        return false;
      // Same instance moves; independent copies may occupy other weapon mounts.
      next.removeWhere((k, v) => v == instance);
      if (!item.definition.weapon &&
          next.values.any((id) => owned[id]?.partId == item.partId))
        return false;
      next[mount] = instance;
    }
    loadouts[hull] = next;
    return true;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'serial': serial,
    'owned': owned.values.map((p) => p.toJson()).toList(),
    'loadouts': loadouts.map((k, v) => MapEntry('$k', v)),
    'airframeLevels': airframeLevels.map((k, v) => MapEntry('$k', v)),
    'convertedGear': convertedGear.toList()..sort(),
    'legacyArchive': legacyArchive,
    'mortarGranted': mortarGranted,
  };
  factory ModuleFleet.restore(dynamic raw) {
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['owned'] is! List ||
        (raw['owned'] as List).length > 4096)
      throw const FormatException('Invalid fleet');
    final f = ModuleFleet();
    for (final value in raw['owned']) {
      final p = OwnedModulePart.restore(value);
      if (f.owned.containsKey(p.instanceId))
        throw const FormatException('Duplicate part');
      f.owned[p.instanceId] = p;
    }
    f.serial = (raw['serial'] is int ? raw['serial'] as int : 1).clamp(
      1,
      9999999,
    );
    while (f.owned.containsKey('p${f.serial}')) {
      f.serial++;
    }
    if (raw['airframeLevels'] is Map)
      for (final e in (raw['airframeLevels'] as Map).entries) {
        final h = int.tryParse('${e.key}');
        if (h != null && h >= 0 && h < 3 && e.value is int)
          f.airframeLevels[h] = (e.value as int).clamp(1, 40);
      }
    if (raw['loadouts'] is Map)
      for (final e in (raw['loadouts'] as Map).entries) {
        final h = int.tryParse('${e.key}');
        if (h == null || h < 0 || h > 2 || e.value is! Map)
          throw const FormatException('Invalid hull loadout');
        final parts = <String, OwnedModulePart>{};
        for (final entry in (e.value as Map).entries) {
          final p = f.owned[entry.value];
          if (p == null) throw const FormatException('Missing part');
          parts[entry.key as String] = p;
        }
        ModuleSnapshot(h, f.airframeLevels[h] ?? 1, parts);
        f.loadouts[h] = parts.map((k, v) => MapEntry(k, v.instanceId));
      }
    if (raw['convertedGear'] is List)
      f.convertedGear.addAll((raw['convertedGear'] as List).whereType<int>());
    if (raw['legacyArchive'] is Map)
      f.legacyArchive.addAll(Map<String, dynamic>.from(raw['legacyArchive']));
    f.mortarGranted = raw['mortarGranted'] == true;
    f.grantMortar();
    return f;
  }
  ModuleFleet();
}

// Canonical top-view socket geometry. Support slots have no airframe position.
abstract final class ModuleGeometry {
  static double partScale(String id) => id == 'W1'
      ? .15
      : id == 'W3'
      ? .16
      : .18;
  static const droneExtent = 17.0;
  static Offset direction(double angle) =>
      Offset(math.sin(angle), -math.cos(angle));
  // Same local tip as the rectangular gun barrel / rocket nose in paintPart.
  static double tip(PartCategory category) =>
      category == PartCategory.drone ? .62 : .70;
  static Offset muzzle(
    Offset center,
    double extent,
    PartCategory category,
    double angle,
  ) => center + direction(angle) * extent * tip(category);
  static String recoilKey(String id, int side) =>
      id == 'W1' ? 'module-W1-$side' : 'module-$id';
  static List<Offset> anchors(String id) => switch (id) {
    'W1' => const [Offset(.10, .49), Offset(.90, .49)],
    'W2' => const [Offset(.50, .64)],
    'W3' => const [Offset(.50, .88)],
    'W4' => const [Offset(.50, .40)],
    _ => const [],
  };
  static Size size(String id) => switch (id) {
    'W1' => const Size(.17, .17),
    'W2' => const Size(.28, .15),
    'W3' => const Size(.18, .18),
    _ => const Size(.22, .22),
  };
  static Rect socketRect(String id, Offset at) => Rect.fromCenter(
    center: at,
    width: size(id).width,
    height: size(id).height,
  );
  static double angle(String id, int index) => switch (id) {
    'W1' => index == 0 ? -math.pi / 12 : math.pi / 12,
    'W3' => math.pi,
    _ => 0,
  };
}

const legacyModulePartIds = [
  'gun_vulcan',
  'missile_hawk',
  'sensor',
  'magnet',
  'capacitor',
  'capacitor',
  'armor',
  'repair',
  'shield',
  'shield',
  'thruster',
  'magnet',
];
