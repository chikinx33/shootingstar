import 'content.dart';
import 'content_catalog.dart';
import 'profile.dart';
import 'aircraft_assembly.dart';

/// A configuration remembers item identities, never a copy of their power.
class HangarPreset {
  HangarPreset({
    required String name,
    this.aircraft,
    required this.ship,
    required this.pilot,
    required this.armament,
    required this.equipment,
    required List<int> gearIds,
    required List<int> techIds,
    required this.pet,
    required List<int> assistPets,
  }) : name = cleanName(name),
       gearIds = List.unmodifiable(gearIds),
       techIds = List.unmodifiable(techIds),
       assistPets = List.unmodifiable(assistPets);

  final String name;
  final AircraftAssembly? aircraft;
  final int ship, pilot, armament, equipment, pet;
  final List<int> gearIds, techIds, assistPets;

  static String cleanName(String value) {
    final plain = value
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return plain.isEmpty ? '출격 구성' : String.fromCharCodes(plain.runes.take(24));
  }

  static HangarPreset capture(Profile p, String name) => HangarPreset(
    name: name,
    aircraft: p.aircraftAssembly,
    ship: p.selectedShip,
    pilot: p.selectedPilot,
    armament: p.selectedArmament,
    equipment: p.equipment,
    gearIds: p.equippedGear,
    techIds: p.equippedTech.toList()..sort(),
    pet: p.activePet,
    assistPets: p.assistingPets.toList()..sort(),
  );

  HangarPreset renamed(String value) => HangarPreset(
    name: value,
    aircraft: aircraft,
    ship: ship,
    pilot: pilot,
    armament: armament,
    equipment: equipment,
    gearIds: gearIds,
    techIds: techIds,
    pet: pet,
    assistPets: assistPets,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (aircraft != null) 'aircraft': aircraft!.toJson(),
    'ship': ship,
    'pilot': pilot,
    'armament': armament,
    'equipment': equipment,
    'gearIds': gearIds.toList(),
    'techIds': techIds.toList(),
    'pet': pet,
    'assistPets': assistPets.toList(),
  };

  static HangarPreset? restore(dynamic raw) {
    if (raw is! Map ||
        raw['name'] is! String ||
        (raw['name'] as String).length > 512) {
      return null;
    }
    for (final key in ['ship', 'pilot', 'armament', 'equipment', 'pet']) {
      if (raw[key] is! int) return null;
    }
    for (final key in ['gearIds', 'techIds', 'assistPets']) {
      final value = raw[key];
      if (value is! List || value.length > 6 || value.any((x) => x is! int)) {
        return null;
      }
    }
    final aircraft = raw['aircraft'] == null
        ? null
        : _restoreAircraft(raw['aircraft'], raw['ship']);
    if (raw['aircraft'] != null && aircraft == null) return null;
    final value = HangarPreset(
      name: raw['name'],
      aircraft: aircraft,
      ship: raw['ship'],
      pilot: raw['pilot'],
      armament: raw['armament'],
      equipment: raw['equipment'],
      pet: raw['pet'],
      gearIds: List<int>.from(raw['gearIds']),
      techIds: List<int>.from(raw['techIds']),
      assistPets: List<int>.from(raw['assistPets']),
    );
    return value._shapeIssue() == null ? value : null;
  }

  static AircraftAssembly? _restoreAircraft(dynamic raw, int hull) {
    try {
      return AircraftAssembly.decode(raw, hull: hull);
    } catch (_) {
      return null;
    }
  }

  String? _shapeIssue() {
    if (aircraft != null && aircraft!.hull != ship)
      return '저장된 기체 조립 정보가 올바르지 않습니다.';
    if (ship < 0 ||
        ship >= ships.length ||
        pilot < 0 ||
        pilot >= pilots.length ||
        armament < 0 ||
        armament >= armaments.length ||
        equipment < 0 ||
        equipment >= equipmentOptions.length) {
      return '저장된 기체 또는 무장 정보가 올바르지 않습니다.';
    }
    if (gearIds.length != 6 ||
        gearIds.any((id) => id <= 0) ||
        gearIds.toSet().length != 6) {
      return '장비 여섯 부위의 정보가 올바르지 않습니다.';
    }
    if (techIds.length > 6 ||
        techIds.toSet().length != techIds.length ||
        techIds.any((id) => id < 0 || id >= techNames.length) ||
        techIds.where((id) => id < 4).length > 3 ||
        techIds.where((id) => id >= 4).length > 3) {
      return '테크는 공격·방어 각각 3개까지 장착할 수 있습니다.';
    }
    if (pet < -1 ||
        pet >= petNames.length ||
        assistPets.length > 2 ||
        assistPets.toSet().length != assistPets.length ||
        assistPets.any((id) => id < 0 || id >= petNames.length || id == pet)) {
      return '출격 펫과 보조 펫 배치가 올바르지 않습니다.';
    }
    return null;
  }

  /// Check every dependency before changing even one current selection.
  String? issue(Profile p) {
    final shape = _shapeIssue();
    if (shape != null) return shape;
    if (!p.unlockedShips.contains(ship)) {
      return '${ships[ship].name} 기체를 먼저 해금하세요.';
    }
    if (aircraft?.modules != null) {
      for (final part in aircraft!.modules!.parts.values) {
        if (p.shipModules.owned[part.instanceId]?.partId != part.partId)
          return '저장된 파츠를 보유하고 있지 않습니다.';
      }
      for (final id in techIds) {
        if (p.techRank(id) < 0) return '${techNames[id]} 테크를 보유하고 있지 않습니다.';
      }
      return null;
    }
    return '이전 조립 구성입니다. 모듈 구성으로 다시 저장하세요.';
  }

  bool apply(Profile p) {
    if (issue(p) != null) return false;
    if (!p.setAircraftAssembly(aircraft!)) return false;
    p.selectedPilot = pilot;
    p.equippedTech = techIds.toSet();
    p.contentChanged();
    return true;
  }
}
