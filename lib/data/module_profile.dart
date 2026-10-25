part of 'profile.dart';

extension ModuleProfile on Profile {
  ModuleFleet get shipModules {
    final fleet = _moduleFleet ??= _migrateModules();
    _convertModuleRewards(fleet);
    fleet.seed(selectedShip);
    fleet.grantMortar();
    fleet.grantSupport();
    final drones = fleet.retireDrones();
    if (drones.isNotEmpty) {
      // refunded like a salvage
      var churu = 0, dust = 0;
      for (final d in drones) {
        churu += 20 + d.level * 5;
        dust += 1 + d.level ~/ 3;
      }
      credits = (credits + churu).clamp(0, 9999999);
      blueprints = (blueprints + dust).clamp(0, 999999);
      addUpdateNotice(
        '와스프 드론 ${drones.length}개는 기체에 붙는 장치가 아니어서 정리했습니다. 츄르 $churu · 별가루 $dust',
      );
    }
    return fleet;
  }

  ModuleSnapshot get moduleLoadout => shipModules.snapshot(selectedShip);

  /// Sprite swaps on the cat airframe: equipped gear, the rear mortar and
  /// the support device's own core in the middle.
  Map<String, String> get shipLayerAssets {
    final parts = moduleLoadout.parts;
    return {
      ...catGear.layerAssets,
      if (parts['W3']?.partId == 'mortar_cat') 'rear_gun': mortarMountAsset,
      if (parts['S1'] case final support?)
        'shield': supportOrbAsset(support.partId),
    };
  }

  void _convertModuleRewards(ModuleFleet fleet) {
    for (final gear in inventory) {
      if (!fleet.convertedGear.add(gear.id)) continue;
      if (gear.spec >= 12)
        continue; // Archived world sets are explicitly on hold.
      fleet.add(
        legacyModulePartIds[gear.spec],
        level: (1 + gear.level + gear.rank * 2).clamp(1, 40),
        id: 'legacy-gear-${gear.id}',
      );
    }
    for (var pet = 0; pet < 3; pet++) {
      final id = 'legacy-support-$pet';
      if (petLevels[pet] > 0 && !fleet.owned.containsKey(id))
        fleet.add(
          const ['capacitor', 'repair', 'shield'][pet],
          level: petLevels[pet].clamp(1, 40),
          id: id,
        );
    }
  }

  ModuleFleet _migrateModules() {
    final fleet = ModuleFleet();
    _convertModuleRewards(fleet);
    fleet.legacyArchive.addAll({
      'aircraft': _assembly.toJson(),
      'heldWorldSetIds': inventory
          .where((g) => g.spec >= 12)
          .map((g) => g.id)
          .toList(),
      'armamentCollection': armamentCollection.toJson(),
    });
    for (final hull in unlockedShips) {
      fleet.seed(hull);
      fleet.airframeLevels[hull] = (1 + attackLevel + hullLevel).clamp(1, 40);
    }
    final active = fleet.loadouts[selectedShip]!;
    for (final pair in const [
      (AircraftMount.wings, 'W1'),
      (AircraftMount.ground, 'W2'),
      (AircraftMount.rear, 'W3'),
    ]) {
      final old = _assembly.parts[pair.$1];
      if (old == null || old == 'auxShield') {
        active.remove(pair.$2);
        continue;
      }
      final kind = old == 'bomb' ? 'missile_hawk' : 'gun_vulcan';
      active[pair.$2] = fleet.add(kind).instanceId;
    }
    final desired = <String>[
      for (final id in _assembly.parts.values)
        if ([
          'repair',
          'capacitor',
          'ward',
          'auxShield',
          'armor',
          'reinforce',
        ].contains(id))
          id == 'ward' || id == 'auxShield'
              ? 'shield'
              : id == 'reinforce'
              ? 'armor'
              : id,
      'sensor',
      'magnet',
    ];
    final used = <String>{};
    var index = 1;
    for (final kind in desired) {
      if (index > 1) break;
      if (!used.add(kind)) continue;
      final candidates = fleet.owned.values
          .where((p) => p.partId == kind)
          .toList();
      final part = candidates.isEmpty ? fleet.add(kind) : candidates.first;
      active['S${index++}'] = part.instanceId;
    }
    return fleet;
  }

  bool equipModule(String mount, String? instance) {
    final done = shipModules.equip(selectedShip, mount, instance);
    if (done) _changed();
    return done;
  }

  int moduleUpgradeCredits(int level) => 60 + level * 15;
  int moduleUpgradePlans(int level) => 1 + level ~/ 5;
  bool openModuleSupply({bool support = false}) {
    final fleet = shipModules;
    if (fleet.owned.length >= 240 || (support ? petEggs : gearKeys) <= 0)
      return false;
    final key = support ? 'supportSupplyCount' : 'weaponSupplyCount';
    final raw = fleet.legacyArchive[key];
    final count = raw is int && raw >= 0 ? raw : 0;
    // v12.11: only devices that fit a slot (no drones)
    final catalog = moduleParts
        .where(
          (p) =>
              p.weapon != support &&
              moduleProfiles.any((m) => mountAccepts(m.id, p)),
        )
        .toList();
    if (support) {
      petEggs--;
    } else {
      gearKeys--;
    }
    final part = fleet.add(catalog[count % catalog.length].id);
    fleet.legacyArchive[key] = count + 1;
    lastLoot = part.definition.name;
    _changed();
    return true;
  }

  bool upgradeModule(String instance) {
    final fleet = shipModules, part = fleet.owned[instance];
    if (part == null ||
        part.level >= 40 ||
        credits < moduleUpgradeCredits(part.level) ||
        blueprints < moduleUpgradePlans(part.level))
      return false;
    credits -= moduleUpgradeCredits(part.level);
    blueprints -= moduleUpgradePlans(part.level);
    fleet.owned[instance] = part.leveled();
    _changed();
    return true;
  }

  bool canSalvageModule(String id) {
    final f = shipModules;
    if (id.startsWith('legacy-support-') ||
        !f.owned.containsKey(id) ||
        f.loadouts.values.any((l) => l.values.contains(id)))
      return false;
    final oldId = id.startsWith('legacy-gear-')
        ? int.tryParse(id.substring(12))
        : null;
    if (oldId != null &&
        (equippedGear.contains(oldId) ||
            protectedGearIds.contains(oldId) ||
            item(oldId)?.locked == true))
      return false;
    return true;
  }

  bool salvageModule(String id) {
    if (!canSalvageModule(id)) return false;
    final part = shipModules.owned.remove(id)!;
    final oldId = id.startsWith('legacy-gear-')
        ? int.tryParse(id.substring(12))
        : null;
    if (oldId != null) inventory.removeWhere((g) => g.id == oldId);
    credits = (credits + 20 + part.level * 5).clamp(0, 9999999);
    blueprints = (blueprints + 1 + part.level ~/ 3).clamp(0, 999999);
    _changed();
    return true;
  }

  bool upgradeAirframe() {
    final fleet = shipModules, level = fleet.airframeLevels[selectedShip] ?? 1;
    if (level >= 40 ||
        credits < moduleUpgradeCredits(level) ||
        blueprints < moduleUpgradePlans(level))
      return false;
    credits -= moduleUpgradeCredits(level);
    blueprints -= moduleUpgradePlans(level);
    fleet.airframeLevels[selectedShip] = level + 1;
    _changed();
    return true;
  }
}
