part of 'engine.dart';

extension ShipModuleCombat on GameEngine {
  ModuleSnapshot? get moduleLoadout => aircraft?.modules;
  bool get unifiedModules => moduleLoadout != null;
  SurvivalSkill combatSkill(String id) {
    if (unifiedModules && id.startsWith('part:')) {
      final mount = id.substring(5), part = moduleLoadout!.parts[mount];
      if (part != null && part.definition.weapon) {
        return SurvivalSkill(
          id,
          '$mount · ${part.definition.name}',
          '이번 전투 · 장착 파츠 피해 +20%',
        );
      }
    }
    return skillFor(id);
  }

  double moduleVisualAngle(String mountId) {
    final part = moduleLoadout?.parts[mountId];
    if (part == null) return 0;
    if (part.definition.category != PartCategory.gun) return 0;
    final mount = mountProfile(mountId);
    final target = _partTarget(
      moduleWorldAnchor(mountId, 0),
      part.definition,
      mount,
    );
    if (target == null) return 0;
    final delta = target.position - moduleWorldAnchor(mountId, 0);
    return math.atan2(delta.dy, delta.dx) + math.pi / 2;
  }

  /// Weapon bay → authored sprite layer (v11 cat airframes).
  static String? _bayLayer(String id, int side) => switch (id) {
    'W1' => side == 0 ? 'gun_l' : 'gun_r',
    'W2' => side == 0 ? 'missile_l' : 'missile_r',
    'W3' => 'rear_gun',
    _ => null,
  };

  Offset moduleWorldAnchor(String id, int side) {
    final layer = _bayLayer(id, side);
    final authored = layer == null
        ? null
        : ShipSpriteArt.mountPoint(shipIndex, layer);
    if (authored != null) return position + authored;
    return position +
        (ModuleGeometry.anchors(id)[side] - const Offset(.5, .5)) *
            AircraftGeometry.combatBodySize;
  }

  Offset modulePartVisualOffset(String id, int side) =>
      visuals.followOffset(id) +
      visuals.recoil(ModuleGeometry.recoilKey(id, side));
  Offset moduleMuzzleAt(String id, int side, double angle) {
    // Fixed bays fire from the front edge of their drawn sprite.
    final layer = _bayLayer(id, side);
    final tip = layer == null
        ? null
        : ShipSpriteArt.mountPoint(shipIndex, layer, muzzle: true);
    if (tip != null) return position + tip;
    return _moduleMuzzleGeometry(id, side, angle);
  }

  Offset _moduleMuzzleGeometry(String id, int side, double angle) =>
      ModuleGeometry.muzzle(
        moduleWorldAnchor(id, side),
        AircraftGeometry.combatBodySize * ModuleGeometry.partScale(id),
        moduleLoadout!.parts[id]!.definition.category,
        ModuleGeometry.angle(id, side),
      );
  Offset partShotVisualPosition(Shot s, {bool reduced = false}) =>
      s.position +
      (reduced
          ? Offset.zero
          : (s.anchor ?? Offset.zero) * math.exp(-math.max(0, s.age) / .045));
  bool partSourceHits(String source, Foe foe) {
    if (foe.plane == AircraftTarget.air) return true;
    if (!source.startsWith('part:')) return false;
    final bits = source.split(':');
    return bits.length >= 3 &&
        (mountProfile(bits[1]).canHitGround || modulePart(bits[2]).homing);
  }

  Foe? _partTarget(
    Offset at,
    ModulePart part,
    MountProfile mount, {
    double? axis,
    double halfArc = math.pi,
    Set<Foe> exclude = const {},
  }) {
    Foe? selected;
    var range = resolvePartStats(
      OwnedModulePart('target', part.id, 1),
      mount,
    ).range;
    for (final e in enemies) {
      if (e.hp <= 0 ||
          exclude.contains(e) ||
          e.retired ||
          (!mount.canHitGround &&
              !part.homing &&
              e.plane == AircraftTarget.ground))
        continue;
      final delta = e.position - at, d = delta.distance;
      if (d > range) continue;
      if (axis != null &&
          math
                  .atan2(
                    math.sin(math.atan2(delta.dy, delta.dx) - axis),
                    math.cos(math.atan2(delta.dy, delta.dx) - axis),
                  )
                  .abs() >
              halfArc)
        continue;
      range = d;
      selected = e;
    }
    return selected;
  }

  ModuleStats partStats(String mount) {
    final part = moduleLoadout!.parts[mount]!;
    final base = resolvePartStats(
      part,
      mountProfile(mount),
      damageBonus:
          damageFactor / (1 + (moduleLoadout!.airframeLevel - 1) * .04) -
          1 +
          (upgrades['part:$mount'] ?? 0) * .20,
      rateBonus: 1 / cooldownFactor - 1,
      aoeBonus: areaFactor - 1,
    );
    return grownPartStats('part:$mount', part.partId, base);
  }

  void _shipModuleWeapons(double dt) {
    _moduleTimers.updateAll(
      (key, value) => key.startsWith('drone-hp:') ? value : value - dt,
    );
    if (_moduleReady('main', _moduleMainInterval)) _fireModularMain();
    for (final mount in moduleProfiles.where((m) => m.weapon)) {
      final part = moduleLoadout!.parts[mount.id];
      // v12.16: a shed part fires only once it has merged back
      if (part == null || !partAttached(mount.id)) continue;
      final stats = partStats(mount.id), definition = part.definition;
      final growthId = 'part:${mount.id}';
      // v12 growth: the vulcan's ultimate turns into free-aiming turrets
      final behavior = definition.id == 'gun_vulcan' && ult(growthId)
          ? 'turret'
          : definition.behaviors[mount.kind]!;
      if (definition.category == PartCategory.drone) {
        if (ult(growthId)) {
          ensureMothership(mount.id, stats);
        } else {
          _moduleDroneWeapon(mount, part, stats, dt);
        }
        continue;
      }
      if (definition.id == 'mortar_cat') {
        if (ult(growthId)
            ? _moduleReady('carpet:${mount.id}', 3)
            : _moduleReady(
                'part:${mount.id}',
                1 / math.max(.1, stats.fireRate),
              ))
          fireMortar(mount, stats);
        continue;
      }
      if (definition.homing && ult(growthId)) {
        if (_moduleReady('tuna:${mount.id}', 3.2 * cooldownFactor))
          fireTuna(mount, part, stats);
        continue;
      }
      if (!_moduleReady('part:${mount.id}', 1 / math.max(.1, stats.fireRate)))
        continue;
      final origins = ModuleGeometry.anchors(mount.id);
      final assignedTargets = <Foe>{};
      for (var i = 0; i < stats.count; i++) {
        final side = i % origins.length;
        final at = moduleWorldAnchor(mount.id, side);
        double angle;
        Foe? target;
        switch (behavior) {
          case 'turret':
            target = _partTarget(at, definition, mount);
            if (target == null) continue;
            angle =
                math.atan2(
                  target.position.dy - at.dy,
                  target.position.dx - at.dx,
                ) +
                math.pi / 2;
          case 'rear_fan':
          case 'rear_homing':
            angle =
                math.pi +
                (stats.count <= 1
                    ? 0
                    : (i / (stats.count - 1) - .5) * math.pi / 3);
            if (definition.homing)
              target = _partTarget(
                at,
                definition,
                mount,
                axis: math.pi / 2,
                halfArc: math.pi / 2,
              );
          case 'twin_outward':
          case 'alternating_homing':
            angle = side == 0 ? -math.pi / 12 : math.pi / 12;
            if (definition.homing)
              target = _partTarget(
                at,
                definition,
                mount,
                axis: -math.pi / 2,
                halfArc: math.pi / 2,
                exclude: assignedTargets,
              );
            if (target == null && definition.homing)
              target = _partTarget(
                at,
                definition,
                mount,
                axis: -math.pi / 2,
                halfArc: math.pi / 2,
              );
            if (target != null) assignedTargets.add(target);
          case 'vertical_salvo':
            angle = 0;
            target = _partTarget(at, definition, mount);
          default:
            angle = (i - (stats.count - 1) / 2) * .055;
            if (definition.homing)
              target = _partTarget(
                at,
                definition,
                mount,
                axis: -math.pi / 2,
                halfArc: math.pi / 2,
              );
        }
        // missile evolve 2: lock on to the toughest enemy in range
        if (definition.homing && gEvo(growthId, 2))
          target = strongestIn(at, stats.range) ?? target;
        _emitPartShot(
          mount,
          part,
          stats,
          at,
          angle,
          target,
          delay: behavior == 'alternating_homing' ? i * .10 : 0,
          side: side,
        );
      }
    }
    _shipSupport();
    if ((passives['regen'] ?? 0) > 0 && _moduleReady('regen', 5))
      hp = math.min(maxHp, hp + maxHp * .01 * passives['regen']!);
    _pilotWeapon(dt);
  }

  void _emitPartShot(
    MountProfile mount,
    OwnedModulePart part,
    ModuleStats stats,
    Offset at,
    double angle,
    Foe? target, {
    double delay = 0,
    int side = 0,
    int? drone,
  }) {
    final direction = Offset(math.sin(angle), -math.cos(angle));
    final origin = drone == null
        ? moduleMuzzleAt(mount.id, side, angle)
        : ModuleGeometry.muzzle(
            at,
            ModuleGeometry.droneExtent,
            PartCategory.drone,
            angle,
          );
    final shot = Shot(
      origin,
      direction * stats.speed,
      stats.damage,
      part.definition.homing ? 1 : 0,
      weapon: 'part:${mount.id}:${part.partId}',
      target: target,
      pierce: stats.pierce,
      life: stats.range / stats.speed + delay,
      radius: 3,
    );
    shot.age = -delay;
    shot.fuse = stats.aoe;
    shots.add(shot);
    if (delay == 0) {
      shot.anchor = drone == null
          ? modulePartVisualOffset(mount.id, side)
          : droneVisualOffset(mount.id, drone);
      _partLaunchCue(shot, mount.id, side, angle, drone: drone);
    }
  }

  void _partLaunchCue(
    Shot shot,
    String mount,
    int side,
    double angle, {
    int? drone,
  }) {
    final key = drone == null
        ? ModuleGeometry.recoilKey(mount, side)
        : 'drone-$mount-$drone';
    final kickAngle = drone != null ? angle : ModuleGeometry.angle(mount, side);
    visuals.kick(
      key,
      -ModuleGeometry.direction(kickAngle) *
          (shot.kind == 1
              ? 4
              : drone == null
              ? 2.5
              : 1.5),
    );
    final at = partShotVisualPosition(shot);
    visuals.emit(
      CombatCueKind.muzzle,
      at,
      from: at - ModuleGeometry.direction(kickAngle) * 7,
      source: shot.weapon,
      radius: shot.kind == 1 ? 11 : 7,
      throttle: '$key-fire',
      interval: .08,
    );
    _event('shoot');
  }

  bool _stepPartShot(Shot shot, double dt) {
    if (!unifiedModules || !shot.weapon.startsWith('part:')) return false;
    if (shot.age < 0) return true;
    final bits = shot.weapon.split(':'),
        mount = mountProfile(bits[1]),
        definition = modulePart(bits[2]);
    final behavior = definition.behaviors[mount.kind];
    if (shot.age - dt < 0) {
      // the paired bays (wing guns, wing missiles) launch from their side
      final paired = mount.id == 'W1' || mount.id == 'W2';
      final side = paired && shot.velocity.dx >= 0 ? 1 : 0;
      final angle = math.atan2(shot.velocity.dx, -shot.velocity.dy);
      shot.position = moduleMuzzleAt(mount.id, side, angle);
      shot.anchor = modulePartVisualOffset(mount.id, side);
      _partLaunchCue(shot, mount.id, side, angle);
      dt = shot.age;
    }
    if (behavior == 'vertical_salvo' && !shot.closeRange && shot.age >= .38) {
      final targets =
          enemies
              .where(
                (e) =>
                    e.hp > 0 &&
                    !e.retired &&
                    (e.position - position).distance <
                        partStats(mount.id).range,
              )
              .toList()
            ..sort(
              (a, b) => (a.position - position).distanceSquared.compareTo(
                (b.position - position).distanceSquared,
              ),
            );
      for (final e in targets.take(3)) {
        final drop =
            Shot(
                e.position + const Offset(0, -180),
                const Offset(0, 460),
                shot.damage / math.min(3, math.max(1, targets.length)),
                1,
                weapon: shot.weapon,
                target: e,
                life: 1.2,
                radius: 3,
              )
              ..fuse = shot.fuse
              ..closeRange = true;
        _deferredShots.add(drop);
      }
      shot.life = 0;
      return true;
    }
    if (definition.homing &&
        (behavior != 'vertical_salvo' || shot.closeRange)) {
      if (shot.target == null ||
          shot.target!.hp <= 0 ||
          !enemies.contains(shot.target)) {
        shot.target = _partTarget(
          shot.position,
          definition,
          mount,
          axis: shot.closeRange
              ? null
              : behavior == 'rear_homing'
              ? math.pi / 2
              : behavior == 'turret'
              ? null
              : -math.pi / 2,
          halfArc: shot.closeRange || behavior == 'turret'
              ? math.pi
              : math.pi / 2,
          exclude: shot.hitTargets,
        );
      }
      if (shot.target != null)
        shot.velocity = Offset.lerp(
          shot.velocity,
          _unit(shot.target!.position - shot.position) *
              (shot.closeRange ? 460 : definition.speed),
          math.min(1, dt * (shot.closeRange ? 10 : 5)),
        )!;
    }
    final growthId = 'part:${mount.id}';
    if (definition.id == 'gun_vulcan') {
      // evolve 3: rounds bend gently toward enemies ahead
      if (gEvo(growthId, 3) || ult(growthId)) {
        final ahead = _partTarget(
          shot.position,
          definition,
          mount,
          axis: math.atan2(shot.velocity.dy, shot.velocity.dx),
          halfArc: .6,
        );
        if (ahead != null)
          shot.velocity = Offset.lerp(
            shot.velocity,
            _unit(ahead.position - shot.position) * shot.velocity.distance,
            math.min(1, dt * 2.5),
          )!;
      }
      // ultimate: the turrets sometimes shoot enemy bullets out of the air
      if (ult(growthId))
        for (final h in shots)
          if (h.kind == 4 &&
              h.life > 0 &&
              (h.position - shot.position).distance < h.radius + 6) {
            if (random.nextDouble() < .35) h.life = 0;
            shot.life = 0;
            break;
          }
    }
    shot.position += shot.velocity * dt;
    shot.distanceTravelled += shot.velocity.distance * dt;
    if (behavior == 'vertical_salvo' && !shot.closeRange) return true;
    for (final e in enemies) {
      if (e.hp <= 0 ||
          e.retired ||
          shot.hitTargets.contains(e) ||
          !partSourceHits(shot.weapon, e))
        continue;
      if ((e.position - shot.position).distance >= e.radius + shot.radius)
        continue;
      if (definition.homing) {
        _partBlast(shot, shot.position, shot.damage);
        shot.hitTargets.add(e);
        shot.target = null;
        if (shot.pierce-- <= 0) {
          shot.life = 0;
          break;
        }
        continue;
      }
      _hit(e, shot.damage, shot.weapon);
      shot.hitTargets.add(e);
      visuals.emit(
        CombatCueKind.impact,
        shot.position,
        source: shot.weapon,
        radius: 8,
      );
      if (shot.pierce-- <= 0) {
        shot.life = 0;
        break;
      }
    }
    return true;
  }

  void _partBlast(Shot shot, Offset at, double damage) {
    for (final e in enemies)
      if (e.hp > 0 &&
          !e.retired &&
          !shot.hitTargets.contains(e) &&
          partSourceHits(shot.weapon, e) &&
          (e.position - at).distance < math.max(10, shot.fuse) + e.radius) {
        _hit(e, damage, shot.weapon);
        shot.hitTargets.add(e);
      }
    visuals.emit(
      CombatCueKind.explosion,
      at,
      source: shot.weapon,
      radius: math.max(12, shot.fuse),
    );
    missileAftermath(shot, at);
    _event('explode');
  }

  /// Where the drones fly; evolve 3 lets each one roam after enemies.
  List<Offset> droneFormation(String mountId, OwnedModulePart part, int count) {
    final base = _baseDroneFormation(mountId, part, count);
    if (!gEvo('part:$mountId', 3)) return base;
    return [
      for (var i = 0; i < base.length; i++) droneRoam['$mountId:$i'] ?? base[i],
    ];
  }

  void _roamDrones(String mountId, OwnedModulePart part, int count, double dt) {
    if (!gEvo('part:$mountId', 3)) return;
    final base = _baseDroneFormation(mountId, part, count);
    for (var i = 0; i < base.length; i++) {
      Foe? near;
      var best = 260.0;
      for (final e in enemies) {
        if (e.hp <= 0 || e.retired || e.plane != AircraftTarget.air) continue;
        final d = (e.position - base[i]).distance;
        if (d < best) {
          best = d;
          near = e;
        }
      }
      final goal = near == null
          ? base[i]
          : near.position + Offset((i.isEven ? -1 : 1) * 40, 70);
      final key = '$mountId:$i';
      droneRoam[key] = Offset.lerp(
        droneRoam[key] ?? base[i],
        goal,
        math.min(1, dt * 2.6),
      )!;
    }
  }

  List<Offset> _baseDroneFormation(
    String mountId,
    OwnedModulePart part,
    int count,
  ) {
    final behavior = part.definition.behaviors[mountProfile(mountId).kind];
    return [
      for (var i = 0; i < count; i++)
        position +
            switch (behavior) {
              'formation_side' => Offset(i.isEven ? -48 : 48, (i ~/ 2) * 20.0),
              'lead' => Offset((i - (count - 1) / 2) * 22, -65),
              'trail' => Offset((i - (count - 1) / 2) * 23, 58 + (i % 2) * 10),
              _ => Offset(
                math.cos(combatTime * 1.5 + i * math.pi * 2 / count) * 52,
                math.sin(combatTime * 1.5 + i * math.pi * 2 / count) * 52,
              ),
            },
    ];
  }

  double droneHealth(String mount, int index) =>
      _moduleTimers['drone-hp:$mount:$index'] ?? partStats(mount).droneHealth;
  Offset droneVisualOffset(String mount, int index) =>
      visuals.followOffset(mount) + visuals.recoil('drone-$mount-$index');
  Foe? droneTarget(String mount, OwnedModulePart part, int index, Offset at) {
    final behavior = part.definition.behaviors[mountProfile(mount).kind];
    final axis = switch (behavior) {
      'lead' => -math.pi / 2,
      'trail' => math.pi / 2,
      'formation_side' => index.isEven ? math.pi : 0.0,
      _ => null,
    };
    return _partTarget(
      at,
      part.definition,
      mountProfile(mount),
      axis: axis,
      halfArc: math.pi * .48,
    );
  }

  double droneVisualAngle(
    String mount,
    OwnedModulePart part,
    int index,
    Offset at,
  ) {
    final target = droneTarget(mount, part, index, at);
    if (target != null)
      return math.atan2(target.position.dx - at.dx, at.dy - target.position.dy);
    return switch (part.definition.behaviors[mountProfile(mount).kind]) {
      'trail' => math.pi,
      'formation_side' => index.isEven ? -math.pi / 2 : math.pi / 2,
      _ => 0,
    };
  }

  void _moduleDroneWeapon(
    MountProfile mount,
    OwnedModulePart part,
    ModuleStats stats,
    double dt,
  ) {
    _roamDrones(mount.id, part, stats.count, dt);
    final positions = droneFormation(mount.id, part, stats.count);
    for (var i = 0; i < positions.length; i++) {
      final key = '${mount.id}:$i',
          hpKey = 'drone-hp:$key',
          revive = 'drone-revive:$key';
      var health = _moduleTimers[hpKey] ?? stats.droneHealth;
      if (health <= 0) {
        if ((_moduleTimers[revive] ?? 0) > 0) continue;
        health = stats.droneHealth;
      }
      if (_moduleReady('drone-touch:$key', .6))
        for (final e in enemies)
          if (e.hp > 0 && (e.position - positions[i]).distance < e.radius + 9) {
            health -= 8;
            break;
          }
      // v12 growth: in house stages drones shoot bullets down only from
      // evolve 2 (the old free-roam arena keeps its always-on interception)
      if (!screenMode || gEvo('part:${mount.id}', 2))
        for (final shot in shots)
          if (shot.interceptable &&
              shot.life > 0 &&
              (shot.position - positions[i]).distance < shot.radius + 10) {
            health -= shot.damage;
            shot.life = 0;
          }
      _moduleTimers[hpKey] = math.max(0, health);
      if (health <= 0) {
        _moduleTimers[revive] = stats.droneRecovery;
        continue;
      }
      final target = droneTarget(mount.id, part, i, positions[i]);
      if (target == null ||
          !_moduleReady('drone-fire:$key', 1 / math.max(.1, stats.fireRate)))
        continue;
      final delta = target.position - positions[i];
      _emitPartShot(
        mount,
        part,
        stats,
        positions[i],
        math.atan2(delta.dy, delta.dx) + math.pi / 2,
        target,
        drone: i,
      );
    }
  }

  void _shipSupport() {
    if (!partAttached('S1')) return;
    final snap = moduleLoadout!;
    final shield = snap.supportLevel('shield');
    if (shield > 0 && _moduleReady('support-shield', 2))
      moduleShield = math.min(
        maxHp * .22,
        moduleShield + ship.health * .025 * snap.supportPower('shield'),
      );
    final repair = snap.supportLevel('repair');
    if (repair > 0 && _moduleReady('support-repair', 12))
      hp = math.min(
        maxHp,
        hp + ship.health * .018 * snap.supportPower('repair'),
      );
    if (snap.hasSupport('sensor') && _moduleReady('support-sensor', 6)) {
      final e = _partTarget(
        position,
        modulePart('gun_vulcan'),
        mountProfile('W1'),
      );
      if (e != null) e.vulnerable = 2 * snap.supportPower('sensor');
    }
  }

  void _offerModuleChoices({Set<String> exclude = const {}}) {
    // v12: weapon cards are enhance / evolve / ultimate steps
    // (weapon_growth.dart); passives stay as they were.
    // weapons still shed in flight cannot grow yet (v12.16)
    final growth = [
      for (final c in growthChoices())
        if (!c.id.startsWith('part:') || partAttached(c.id.substring(5))) c,
    ];
    final pool = <UpgradeChoice>[...growth];
    // v12.17: no movement-speed skill; the magnet skill only once the
    // wings (the gem intake) are on the craft
    for (final id in ['attack', 'cooldown', 'hull', 'magnet']) {
      if ((passives[id] ?? 0) >= 5) continue;
      if (id == 'magnet' && !partAttached('wings')) continue;
      final skill = survivalSkills.firstWhere((s) => s.id == id);
      pool.add(UpgradeChoice(id, skill.name, skill.description, id));
    }
    if (pool.isEmpty)
      pool.add(
        const UpgradeChoice('repair', '응급 수리', '최대 체력의 30% 회복', 'repair'),
      );
    pool.shuffle(random);
    final fresh = pool.where((c) => !exclude.contains(c.id)).toList();
    // three different names: one weapon never fills two cards of a draft
    final picks = <UpgradeChoice>[];
    for (final c in fresh.isNotEmpty ? fresh : pool) {
      if (picks.length == 3) break;
      if (picks.every((p) => p.title != c.title)) picks.add(c);
    }
    // a finished weapon's ultimate always shows up
    for (final ultimate in growth.where((c) => c.growth == 'ult')) {
      if (picks.contains(ultimate)) continue;
      picks[picks.length - 1] = ultimate;
      break;
    }
    // at least one weapon card in every draw
    if (!picks.any((c) => c.growth.isNotEmpty)) {
      final weapons = growth
          .where(
            (c) =>
                !exclude.contains(c.id) &&
                picks.skip(1).every((p) => p.title != c.title),
          )
          .toList();
      if (weapons.isNotEmpty)
        picks[0] = weapons[random.nextInt(weapons.length)];
    }
    // a random shed part always comes back as one of the cards
    final merge = rollMergeChoice();
    if (merge != null && !exclude.contains(merge.id) && picks.isNotEmpty) {
      picks[0] = merge;
    }
    choices = picks;
    input = Offset.zero;
  }
}
