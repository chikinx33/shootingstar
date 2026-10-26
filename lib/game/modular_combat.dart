part of 'engine.dart';

const moduleSkillGroups = <AircraftMount, List<String>>{
  AircraftMount.main: ['gun'],
  AircraftMount.auxiliary: [
    'drone',
    'drill',
    'laser',
    'lightning',
    'forcefield',
    'medicDrone',
  ],
  AircraftMount.wings: ['missile', 'side', 'ball', 'droneB', 'durian'],
  AircraftMount.rear: ['mine', 'boomerang', 'infernoMine', 'thunderMine'],
  AircraftMount.ground: ['trail', 'brick'],
  AircraftMount.armor: ['guardian'],
};
AircraftMount? moduleSkillMount(String id) {
  for (final entry in moduleSkillGroups.entries) {
    if (entry.value.contains(id)) return entry.key;
  }
  return id == 'pilot' ? AircraftMount.auxiliary : null;
}

String moduleMountLabel(AircraftMount mount) => switch (mount) {
  AircraftMount.main => '주포',
  AircraftMount.auxiliary => '보조',
  AircraftMount.wings => '날개',
  AircraftMount.rear => '후방',
  AircraftMount.ground => '지상',
  AircraftMount.armor => '장갑',
  _ => '지원',
};

extension ModularCombat on GameEngine {
  bool get modular => aircraft != null;
  bool _mounted(AircraftMount mount) =>
      aircraft?.parts.containsKey(mount) == true;
  double get moduleArmorReduction => unifiedModules
      ? math.min(.18, .06 * moduleLoadout!.supportPower('armor'))
      : !_mounted(AircraftMount.armor)
      ? 0
      : (aircraft!.parts[AircraftMount.armor] == 'reinforce' ? .10 : .06) +
            math.min(.08, (upgrades['guardian'] ?? 0) * .016);
  bool moduleSkillAvailable(String id) {
    final mount = moduleSkillMount(id);
    if (mount == null) return true;
    if (!_mounted(mount)) return false;
    return mount != AircraftMount.auxiliary ||
        aircraft!.parts[mount] != 'auxShield' ||
        id == 'forcefield';
  }

  double _modulePower(AircraftMount mount) {
    final group = moduleSkillGroups[mount] ?? const <String>[];
    var total = 0, evo = 0;
    for (final id in group) {
      total += upgrades[id] ?? 0;
      if (evolved.contains(id)) evo++;
    }
    return 1 + total * .20 + evo * .45;
  }

  double _moduleTech(AircraftMount mount) {
    final group = moduleSkillGroups[mount] ?? const <String>[];
    var total = 0.0, count = 0;
    for (final id in group) {
      if (techRanks.containsKey(id)) {
        total += techDamage(id) - 1;
        count++;
      }
    }
    return 1 + (count == 0 ? 0 : total / count);
  }

  bool modularSourceCanHit(String source, Foe target) {
    if (unifiedModules) return partSourceHits(source, target);
    if (aircraft == null) return true;
    if (source == 'module-ground' || source == 'bomb')
      return target.plane == AircraftTarget.ground;
    if (target.plane == AircraftTarget.ground) return false;
    if (source.startsWith('module-') ||
        source == 'gear-seeker' ||
        source == 'common-ultimate' ||
        source == 'status')
      return true;
    return aircraft!.parts[AircraftMount.auxiliary] == 'turret';
  }

  Offset moduleAnchor(AircraftMount mount, {bool right = false}) =>
      position + AircraftGeometry.offset(shipIndex, mount, right: right);
  Foe? _moduleTarget(
    Offset origin, {
    AircraftTarget plane = AircraftTarget.air,
    double? axis,
    double halfArc = math.pi,
    double range = 520,
  }) {
    Foe? found;
    var distance = range;
    for (final foe in enemies) {
      if (foe.hp <= 0 || foe.retired || foe.plane != plane) continue;
      final delta = foe.position - origin;
      final d = delta.distance;
      if (d > distance) continue;
      if (axis != null &&
          math
                  .atan2(
                    math.sin(math.atan2(delta.dy, delta.dx) - axis),
                    math.cos(math.atan2(delta.dy, delta.dx) - axis),
                  )
                  .abs() >
              halfArc)
        continue;
      found = foe;
      distance = d;
    }
    return found;
  }

  double moduleAngle(AircraftMount mount, {bool right = false}) {
    if (mount == AircraftMount.main) return 0;
    if (mount == AircraftMount.rear) return math.pi;
    final axis = right ? 0.0 : math.pi;
    final origin = moduleAnchor(mount, right: right);
    final target = _moduleTarget(
      origin,
      axis: mount == AircraftMount.wings ? axis : null,
      halfArc: mount == AircraftMount.wings ? .85 : math.pi,
    );
    return target == null
        ? (mount == AircraftMount.wings
              ? (right ? math.pi / 2 : -math.pi / 2)
              : 0)
        : math.atan2(
                target.position.dy - origin.dy,
                target.position.dx - origin.dx,
              ) +
              math.pi / 2;
  }

  Offset moduleMuzzle(
    AircraftMount mount, {
    bool right = false,
    double? angle,
  }) {
    if (unifiedModules && mount == AircraftMount.main) {
      // The cat's own nose cannon: the top of its base pod.
      final nose = ShipSpriteArt.mountPoint(shipIndex, 'base', muzzle: true);
      return position +
          (nose ?? Offset(0, (.065 - .5) * AircraftGeometry.combatBodySize));
    }
    final at = moduleAnchor(mount, right: right);
    final yaw = angle ?? moduleAngle(mount, right: right);
    final reach = switch (mount) {
      AircraftMount.main =>
        gearSpecs.length == 6
            ? AircraftGeometry.mainMuzzleReach(gearSpecs[0])
            : AircraftGeometry.moduleMuzzleReach(mount),
      _ => AircraftGeometry.moduleMuzzleReach(mount),
    };
    return at + Offset(math.sin(yaw), -math.cos(yaw)) * reach;
  }

  bool _moduleReady(String key, double seconds) {
    if ((_moduleTimers[key] ?? 0) > 0) return false;
    _moduleTimers[key] = seconds;
    return true;
  }

  void _moduleBullet(
    AircraftMount mount,
    Offset origin,
    Offset velocity,
    double damage, {
    int kind = 6,
    int pierce = 0,
    double radius = 3,
    double life = 2,
    bool right = false,
  }) {
    final strength = mount == AircraftMount.main
        ? (armament == 'revolver' || armament == 'shotgun' ? 6.0 : 4.5)
        : 3.5;
    visuals.kick(
      '${mount.name}${right ? '-right' : ''}',
      -_unit(velocity) * strength,
    );
    shots.add(
      Shot(
        origin,
        velocity,
        damage,
        kind,
        weapon: 'module-${mount.name}',
        pierce: pierce,
        radius: radius,
        life: life,
      ),
    );
    visuals.emit(
      CombatCueKind.muzzle,
      origin,
      from: origin + _unit(velocity) * (unifiedModules ? -7 : 10),
      source: 'module-${mount.name}',
      radius: mount == AircraftMount.main ? 13 : 10,
      throttle: 'module-${mount.name}${right ? '-right' : ''}',
      interval: .08,
    );
  }

  void _modularWeapons(double dt) {
    if (unifiedModules) {
      _shipModuleWeapons(dt);
      return;
    }
    _moduleTimers.updateAll((key, value) => value - dt);
    _extraTimers.updateAll((key, value) => value - dt);
    _gearTick();
    if (_mounted(AircraftMount.main) &&
        _moduleReady('main', _moduleMainInterval))
      _fireModularMain();
    if (_mounted(AircraftMount.auxiliary) &&
        aircraft!.parts[AircraftMount.auxiliary] == 'turret' &&
        _moduleReady('aux', .95 * cooldownFactor)) {
      final target = _moduleTarget(moduleAnchor(AircraftMount.auxiliary));
      if (target != null) {
        final at = moduleMuzzle(AircraftMount.auxiliary);
        _moduleBullet(
          AircraftMount.auxiliary,
          at,
          _unit(target.position - at) * 360 * skillSpeed,
          6 *
              damageFactor *
              _modulePower(AircraftMount.auxiliary) *
              _moduleTech(AircraftMount.auxiliary),
          pierce:
              evolved.any(
                (id) => (moduleSkillGroups[AircraftMount.auxiliary] ?? [])
                    .contains(id),
              )
              ? 1
              : 0,
        );
      }
    }
    if (_mounted(AircraftMount.wings) &&
        _moduleReady('wings', 1.4 * cooldownFactor)) {
      for (final right in [false, true]) {
        final angle = moduleAngle(AircraftMount.wings, right: right);
        final origin = moduleAnchor(AircraftMount.wings, right: right);
        final target = _moduleTarget(
          origin,
          axis: right ? 0 : math.pi,
          halfArc: .85,
        );
        if (target == null) continue;
        final at = moduleMuzzle(
          AircraftMount.wings,
          right: right,
          angle: angle,
        );
        _moduleBullet(
          AircraftMount.wings,
          at,
          Offset(math.sin(angle), -math.cos(angle)) * 330 * skillSpeed,
          5 *
              damageFactor *
              _modulePower(AircraftMount.wings) *
              _moduleTech(AircraftMount.wings),
          radius: 3 + (evolved.contains('side') ? 2 : 0),
          pierce: evolved.contains('missile') ? 1 : 0,
          right: right,
        );
      }
    }
    if (_mounted(AircraftMount.rear) &&
        _moduleReady('rear', 1.1 * cooldownFactor)) {
      if (_moduleTarget(
            moduleAnchor(AircraftMount.rear),
            axis: math.pi / 2,
            halfArc: .7,
          ) !=
          null) {
        final at = moduleMuzzle(AircraftMount.rear);
        for (final x in [-3.0, 3.0])
          _moduleBullet(
            AircraftMount.rear,
            at + Offset(x, 0),
            const Offset(0, 320) * skillSpeed,
            4 *
                damageFactor *
                _modulePower(AircraftMount.rear) *
                _moduleTech(AircraftMount.rear),
          );
      }
    }
    if (_mounted(AircraftMount.ground) &&
        _moduleReady('ground', 2.0 * cooldownFactor)) {
      final target = _moduleTarget(
        moduleAnchor(AircraftMount.ground),
        plane: AircraftTarget.ground,
        range: 440,
      );
      if (target != null) {
        visuals.kick('ground', const Offset(0, 3));
        shots.add(
          Shot(
            moduleAnchor(AircraftMount.ground),
            Offset.zero,
            30 *
                damageFactor *
                _modulePower(AircraftMount.ground) *
                _moduleTech(AircraftMount.ground),
            26,
            weapon: 'module-ground',
            anchor: target.position,
            life: .7,
            radius: 60 * areaFactor,
          ),
        );
      }
    }
    _modularSupport();
    if ((passives['regen'] ?? 0) > 0 && _moduleReady('regen', 5))
      hp = math.min(maxHp, hp + maxHp * .01 * passives['regen']!);
    final before = shots.length;
    _pilotWeapon(dt);
    for (var i = before; i < shots.length; i++) {
      final shot = shots[i];
      if (!shot.hostile) shot.position = moduleMuzzle(AircraftMount.auxiliary);
    }
    if (!bossIncoming && boss == null) {
      moduleGroundClock -= dt;
      if (moduleGroundClock <= 0) {
        moduleGroundClock = 12;
        _spawnGroundUnit();
      }
    }
  }

  double get _moduleMainInterval =>
      (math.max(.12, .36 - (upgrades['gun'] ?? 1) * .025) *
          cooldownFactor *
          mainInterval *
          (armament == 'shotgun'
              ? 1.5
              : armament == 'revolver'
              ? 1.4
              : 1)) /
      (unifiedModules ? mainRateGrowth : 1);

  /// The three cat main guns (v12.17: the legacy families and the old
  /// '주포 특화' branches are gone): 치즈 pulse, 구름 revolver, 까미 shotgun.
  void _fireModularMain() {
    final at = moduleMuzzle(AircraftMount.main), gun = upgrades['gun'] ?? 1;
    var count = mainProjectiles + (armament == 'shotgun' ? 4 : 0);
    var multiplier = armament == 'shotgun'
        ? .48
        : armament == 'revolver'
        ? 2.5
        : 1.0;
    var radius = mainWidth;
    var pierce = (techSpecial('gun') ? 1 : 0) + _gearPrimaryPierce();
    final spacing = armament == 'shotgun' ? .09 : .025;
    var life = 2.0;
    if (evolved.contains('gun')) {
      pierce++;
      multiplier *= 1.2;
    }
    if (frontBreakRemaining > 0) pierce++;
    final counter = shieldCounterPending;
    if (counter) multiplier *= 1.5;
    // v12 growth (growth_arms.dart): enhance / evolve the cat's main gun
    if (unifiedModules) {
      multiplier *= switch (armament) {
        'revolver' => gUp('gun', 1, 1.3),
        _ => gUp('gun', 1, 1.25),
      };
      if (armament == 'pulse') {
        radius *= gUp('gun', 3, 1.25);
        count += (gEvo('gun', 1) ? 1 : 0) + (gEvo('gun', 3) ? 1 : 0);
        pierce += (gEvo('gun', 2) ? 1 : 0) + (gEvo('gun', 3) ? 1 : 0);
      } else if (armament == 'revolver') {
        life *= gUp('gun', 2, 1.3);
        if (gEvo('gun', 1)) pierce += 2;
        if (gEvo('gun', 3)) pierce += 99;
      } else if (armament == 'shotgun') {
        life *= gUp('gun', 3, 1.3);
        if (gEvo('gun', 1)) count += 2;
      }
      final perShot =
          (13 + gun * 4) *
          damageFactor *
          mainDamage *
          techDamage('gun') *
          multiplier;
      if (mainUltimateVolley(at, perShot)) {
        _event('shoot');
        return;
      }
    }
    final growthSpeed = !unifiedModules
        ? 1.0
        : armament == 'pulse'
        ? gUp('gun', 3, 1.25)
        : armament == 'revolver'
        ? gUp('gun', 2, 1.4)
        : 1.0;
    final n = count.clamp(1, 12);
    for (var i = 0; i < n; i++) {
      final angle = (i - (n - 1) / 2) * spacing;
      final speed = armament == 'revolver' ? 520.0 : 420.0;
      _moduleBullet(
        AircraftMount.main,
        at + Offset((i - (n - 1) / 2) * 3, 0),
        Offset(math.sin(angle), -math.cos(angle)) *
            speed *
            skillSpeed *
            growthSpeed,
        (13 + gun * 4) *
            damageFactor *
            mainDamage *
            techDamage('gun') *
            multiplier *
            (precisionLinkActive ? 1.08 : 1),
        kind: 6,
        radius: radius,
        pierce: pierce,
        life: life * mainReachFactor,
      );
    }
    // v12.16 구름's shadow clones fire the same volley beside the cat
    for (final clone in clonePositions) {
      for (var i = 0; i < n; i++) {
        final angle = (i - (n - 1) / 2) * spacing;
        _moduleBullet(
          AircraftMount.main,
          at - position + clone + Offset((i - (n - 1) / 2) * 3, 0),
          Offset(math.sin(angle), -math.cos(angle)) * 420 * skillSpeed,
          (13 + gun * 4) * damageFactor * mainDamage * multiplier * .7,
          kind: 6,
          radius: radius,
          pierce: pierce,
          life: life * mainReachFactor,
        );
      }
    }
    _gearPrimaryFired(
      (13 + gun * 4) * damageFactor * mainDamage * techDamage('gun'),
    );
    if (counter) {
      _shieldCounterArmed = false;
      _shieldCounterAttacks++;
    }
    if (armament == 'revolver' && --revolverAmmo <= 0) {
      revolverAmmo = 6;
      _moduleTimers['main'] = 1.4 * cooldownFactor;
    }
    if (cycleLinkActive && ++_mainLinkVolleys % 8 == 0) {
      moduleShield = math.max(
        moduleShield,
        math.min(maxHp * .15, moduleShield + maxHp * .03),
      );
    }
    _event('shoot');
  }

  void _modularHit(Shot shot, Foe target, double before) {
    growthMainHit(shot, target);
    if (target.plane != AircraftTarget.air || before <= target.hp) return;
    if (shot.weapon == 'module-auxiliary' &&
        (upgrades['laser'] ?? 0) > 0 &&
        target.kind != 3) {
      target.status = 2;
      target.statusTime = .8;
    }
    if (shot.weapon != 'module-main' || target.kind == 3) return;
    if (synergyReady('front-break') &&
        target.status == 2 &&
        target.statusTime > 0 &&
        combatTime >= _frontBreakReadyAt) {
      target.frontBreakHits = combatTime - target.frontBreakLastHit <= 1.1
          ? target.frontBreakHits + 1
          : 1;
      target.frontBreakLastHit = combatTime;
      if (target.frontBreakHits >= 3) {
        target.frontBreakHits = 0;
        _frontBreakReadyAt = combatTime + 3;
        _frontBreakUntil = combatTime + 1.25;
        _synergyFeedback('front-break', '정면 돌파 · 주포 관통 +1');
      }
    }
    if (synergyReady('explosive-spread') &&
        target.hp <= 0 &&
        combatTime >= _explosiveSpreadReadyAt) {
      for (final foe in enemies) {
        if (foe != target &&
            foe.hp > 0 &&
            foe.plane == AircraftTarget.air &&
            foe.position.dy < position.dy &&
            (foe.position - target.position).distance < 40 * areaFactor)
          _hit(foe, shot.damage * .45, 'module-main');
      }
      _explosiveSpreadReadyAt = combatTime + 1.5;
      visuals.emit(
        CombatCueKind.explosion,
        target.position,
        source: 'module-main',
        radius: 40 * areaFactor,
      );
      _synergyFeedback('explosive-spread', '폭발 확산 · 전방 폭발');
    }
  }

  void _modularSupport() {
    moduleShield = math.min(moduleShield, maxHp * .22);
    if (_mounted(AircraftMount.armor) &&
        (upgrades['guardian'] ?? 0) > 0 &&
        (_moduleTimers['guardian'] ?? 0) <= 0) {
      final incoming = shots.where(
        (s) => s.interceptable && (s.position - position).distance < 45,
      );
      if (incoming.isNotEmpty) {
        shots.remove(incoming.first);
        _moduleTimers['guardian'] = 2;
        _onGuardianBlock();
      }
    }
    final hasShield = aircraft!.parts[AircraftMount.auxiliary] == 'auxShield';
    if (hasShield && _moduleReady('auxShield', 2))
      moduleShield = math.max(
        moduleShield,
        math.min(
          maxHp * .18,
          moduleShield + maxHp * .025 * _modulePower(AircraftMount.auxiliary),
        ),
      );
    for (final mount in supportMounts) {
      final id = aircraft!.parts[mount];
      if (id == null) continue;
      final level = (supportLevels[id] ?? 1).clamp(1, 30);
      final power = (1 + level * .035) * (1 + petAwakePower.clamp(0, .18));
      final interval = (1 - petAwakeCooldown.clamp(0, .12));
      if (!_moduleReady(
        'support-$id',
        (id == 'repair'
                ? 12.0
                : id == 'capacitor'
                ? 6.0
                : 4.0) *
            interval,
      ))
        continue;
      if (id == 'repair') {
        hp = math.min(maxHp, hp + maxHp * .018 * power);
        visuals.emit(
          CombatCueKind.heal,
          moduleAnchor(mount),
          source: 'support',
          radius: 25,
        );
      }
      if (id == 'capacitor') {
        // v12.16: no charge while the ultimate is still playing out
        if (ultimateRemaining == 0) {
          _ultimateCharge = math.min(100, _ultimateCharge + 3 * power);
        }
        pilotAbilityCooldown = math.max(0, pilotAbilityCooldown - 1.2 * power);
        visuals.emit(
          CombatCueKind.pickup,
          moduleAnchor(mount),
          source: 'support-charge',
          radius: 20,
        );
      }
      if (id == 'ward') {
        moduleShield = math.min(
          maxHp * .22,
          moduleShield + maxHp * .025 * power,
        );
        visuals.emit(
          CombatCueKind.shield,
          moduleAnchor(mount),
          source: 'support',
          radius: 25,
        );
      }
    }
  }

  bool _stepModularShot(Shot shot, double dt) {
    if (_stepPartShot(shot, dt)) return true;
    if (_gearShot(shot, dt)) return true;
    if (shot.kind != 26) return false;
    if (shot.age >= .45 && shot.life > 0) {
      final center = shot.anchor ?? shot.position;
      for (final foe in enemies) {
        if (foe.plane == AircraftTarget.ground &&
            foe.hp > 0 &&
            (foe.position - center).distance < shot.radius + foe.radius)
          _hit(foe, shot.damage, 'module-ground');
      }
      visuals.emit(
        CombatCueKind.explosion,
        center,
        source: 'module-ground',
        radius: shot.radius,
      );
      shot.life = 0;
    }
    return true;
  }

  void _spawnGroundUnit() {
    if (enemies.length >= waveEnemyBudget ||
        enemies.where((e) => e.plane == AircraftTarget.ground).length >= 5)
      return;
    final index = moduleGroundSerial++ % 3;
    final at =
        (position + Offset((moduleGroundSerial.isEven ? 1 : -1) * 120, -180));
    enemies.add(
      Foe(
        Offset(
          at.dx.clamp(60, GameEngine.worldWidth - 60).toDouble(),
          at.dy.clamp(60, GameEngine.worldHeight - 60).toDouble(),
        ),
        (24 + worldIndex * 9 + stage.sector * 2) * math.sqrt(threat),
        index == 2 ? 0 : 12,
        17,
        1,
        plane: AircraftTarget.ground,
        groundKind: index,
      )..attackClock = 2.5,
    );
  }

  void _moveGroundEnemy(Foe foe, double dt, Offset toward) {
    if ((foe.position - position).distance > 750) {
      foe.retired = true;
      return;
    }
    foe.position += toward * foe.speed * dt;
    foe.heading = math.atan2(toward.dy, toward.dx);
    foe.attackClock -= dt;
    if (foe.attackClock < .8 && foe.tell == 0) {
      foe.tell = .8;
      foe.aim = toward;
      visuals.emit(
        CombatCueKind.area,
        foe.position,
        source: 'ground-warning',
        radius: 35,
      );
    }
    if (foe.tell > 0) foe.tell = math.max(.001, foe.tell - dt);
    if (foe.attackClock <= 0) {
      shots.add(
        Shot(
          foe.position,
          foe.aim * 105,
          8,
          4,
          weapon: 'ground-shell',
          life: 4,
          radius: 5,
        ),
      );
      foe.attackClock = 4.5;
      foe.tell = 0;
    }
  }
}
