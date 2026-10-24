part of 'engine.dart';

extension EnemyBehaviors on GameEngine {
  Foe _createEnemy(Offset at, content.EnemyRole role, {int generation = 0}) {
    final heavy =
        role == content.EnemyRole.bulwark || role == content.EnemyRole.carrier;
    final fast =
        role == content.EnemyRole.weaver || role == content.EnemyRole.lancer;
    final foe = Foe(
      at,
      (heavy
              ? 45 + wave * 3.0
              : fast
              ? 10 + wave * 1.0
              : 12 + wave * 1.2) *
          threat,
      (heavy
              ? 52.0
              : fast
              ? 95.0
              : 68.0) *
          (1 + math.min(.35, stageIndex * .002 + campaignLoop * .015)),
      heavy
          ? 19
          : role == content.EnemyRole.splitter
          ? 15
          : 11,
      heavy
          ? 2
          : fast
          ? 1
          : 0,
      role: role,
    );
    if (screenMode) {
      // House stages (user 2026-10-24): bigger, sturdier formation planes
      // that read clearly on a phone and take a real volley to bring down.
      // the painter draws them larger still (v12.4.2) without growing the
      // hitbox, so contact and bullets stay as fair as before
      foe.radius *= heavy ? 1.25 : 1.3;
      foe.hp *= 1.4;
    }
    foe.hp *= dailyEntry?.healthMultiplier ?? 1;
    foe.maxHp = foe.hp;
    foe.speed *= dailyEntry?.enemySpeedMultiplier ?? 1;
    foe.generation = generation;
    foe.orbitSign = random.nextBool() ? 1 : -1;
    foe.heading = math.atan2(position.dy - at.dy, position.dx - at.dx);
    foe.attackClock = 2.5 + random.nextDouble() * 2;
    return foe;
  }

  bool _spawnKamikazeFormation() {
    final count = math.min(6, 4 + worldIndex ~/ 4);
    return _spawnNewFlightFormation(FlightFormation.assault, count);
  }

  /// Enemy shots look much larger in the house stages (the painter scales
  /// them up); the hitbox grows only a little so dodging stays fair.
  double get hostileBulletRadius => screenMode ? 4.5 : 4;

  bool _enemyCanFire(Foe e) {
    final view = Rect.fromLTWH(
      camera.dx + 12,
      camera.dy + 12,
      396,
      math.max(1, viewportHeight - 24),
    );
    final distance = (e.position - position).distance;
    return view.contains(e.position) && distance >= 85 && distance <= 460;
  }

  double engagementRange(Foe e) {
    final outward = _unit(e.position - position);
    double range = content.enemyDoctrines[e.role]!.range;
    // Fit the patrol ring inside the portrait combat area, below the HUD.
    if (outward.dx.abs() > .01) range = math.min(range, 174 / outward.dx.abs());
    if (outward.dy.abs() > .01) {
      final vertical = viewportHeight / 2 - (outward.dy < 0 ? 180 : 40);
      range = math.min(range, math.max(130, vertical) / outward.dy.abs());
    }
    return math.max(130, range);
  }

  void _moveEnemy(Foe e, double dt, Offset toward) {
    if (e.formationPattern != null) {
      _moveFlightFormation(e, dt);
      return;
    }
    final distance = (e.position - position).distance;
    final slow = e.statusTime > 0 && e.status == 2 ? .55 : 1.0;
    if (e.role == content.EnemyRole.kamikaze) {
      e.flight = content.EnemyFlight.attackRun;
      e.velocity = e.aim * 185 * slow * (dailyEntry?.enemySpeedMultiplier ?? 1);
      e.position += e.velocity * dt;
      if (e.phase > 12 || (e.phase > 4 && distance > 850)) e.retired = true;
      return;
    }
    final doctrine = content.enemyDoctrines[e.role]!;
    final desired = engagementRange(e);
    e.attackClock -= dt;
    final canFire = _enemyCanFire(e);
    if (!canFire) {
      e.tell = 0;
      e.attackClock = math.max(e.attackClock, doctrine.windup + .2);
    } else if (e.attackClock <= doctrine.windup && e.attackClock > 0) {
      if (e.tell <= 0) {
        // Aim is frozen at windup start; no last-frame tracking of dodges.
        e.aim = toward;
        e.targetPoint = e.position + toward * distance.clamp(90.0, 360.0);
        if (doctrine.weapon == content.EnemyArmament.laser) {
          onEvent?.call('enemy-charge');
        }
      }
      e.tell = e.attackClock;
    } else if (e.attackClock <= 0) {
      final fired = _enemyFire(e);
      if (fired) onEvent?.call('enemy-fire');
      e.tell = 0;
      e.attackClock = fired
          ? math.max(
              doctrine.windup + .2,
              (doctrine.cooldown + random.nextDouble() * .9) *
                  (dailyEntry?.projectileIntervalMultiplier ?? 1),
            )
          : 1.6;
      if (fired &&
          e.role == content.EnemyRole.carrier &&
          enemies.length < enemyLimit - 2 &&
          enemies.where((v) => v.generation == 1 && v.hp > 0).length < 8) {
        for (int i = 0; i < 2; i++) {
          enemies.add(
            _createEnemy(
              e.position + Offset(i * 30.0 - 15, 20),
              content.EnemyRole.scout,
              generation: 1,
            ),
          );
        }
      }
    }
    final tangent = Offset(-toward.dy, toward.dx) * e.orbitSign;
    final radial = ((distance - desired) / 55).clamp(-1.6, 1.0);
    final strafe = e.role == content.EnemyRole.weaver
        ? .7 + math.sin(e.phase * 1.7) * .15
        : e.role == content.EnemyRole.orbiter
        ? .85
        : .4;
    var steering = (toward * radial + tangent * strafe) * e.speed * slow;
    e.flight = distance < desired - 35
        ? content.EnemyFlight.evade
        : distance > desired + 35
        ? content.EnemyFlight.approach
        : content.EnemyFlight.patrol;
    if (e.tell > 0) {
      e.flight = content.EnemyFlight.windup;
      steering *= doctrine.weapon == content.EnemyArmament.laser ? 0 : .3;
    }
    if (distance < 75) {
      // Emergency separation also wins over the firing brace.
      steering = -toward * e.speed * slow * 1.8;
      e.velocity = steering;
    } else {
      e.velocity = Offset.lerp(e.velocity, steering, math.min(1, dt * 6))!;
    }
    e.position += e.velocity * dt;
    if (e.velocity.distance > 3) {
      final angle = math.atan2(e.velocity.dy, e.velocity.dx);
      final turn = math.atan2(
        math.sin(angle - e.heading),
        math.cos(angle - e.heading),
      );
      e.heading += turn.clamp(-3.2 * dt, 3.2 * dt);
    }
  }

  int get hostileShotLimit =>
      (44 + worldIndex * 4 + stage.sector).clamp(44, 90);

  bool _enemyFire(Foe e) {
    if (!_enemyCanFire(e) ||
        shots.where((s) => s.hostile).length >= hostileShotLimit) {
      return false;
    }
    final weapon = content.enemyDoctrines[e.role]!.weapon;
    final aim = e.aim.distance > .1 ? e.aim : _unit(position - e.position);
    final angle = math.atan2(aim.dy, aim.dx);
    switch (weapon) {
      case content.EnemyArmament.bullet:
        final count = e.role == content.EnemyRole.splitter
            ? 3
            : e.role == content.EnemyRole.weaver
            ? 2
            : 1;
        for (
          int i = 0;
          i < count && shots.where((s) => s.hostile).length < hostileShotLimit;
          i++
        ) {
          shots.add(
            Shot(
              e.position,
              _direction(angle + (i - (count - 1) / 2) * .18) * 135,
              6,
              4,
              weapon: 'enemy-bullet',
              life: 4,
              radius: hostileBulletRadius,
            ),
          );
        }
      case content.EnemyArmament.guidedBolt:
        if (shots.where((s) => s.kind == 19).length >= 6) return false;
        shots.add(
          Shot(
            e.position,
            aim * 140,
            8,
            19,
            weapon: 'enemy-guided',
            life: 3.5,
            radius: hostileBulletRadius,
          ),
        );
      case content.EnemyArmament.missile:
        if (shots.where((s) => s.kind == 20).length >= 5) return false;
        shots.add(
          Shot(
            e.position,
            aim * 180,
            10,
            20,
            weapon: 'enemy-missile',
            life: 3.2,
            radius: 5,
          ),
        );
      case content.EnemyArmament.highExplosive:
      case content.EnemyArmament.grenade:
        if (shots.where((s) => s.kind == 21 || s.kind == 22).length >= 6) {
          return false;
        }
        final grenade = weapon == content.EnemyArmament.grenade;
        final delta = (e.targetPoint ?? position) - e.position;
        final range = delta.distance.clamp(90.0, 360.0);
        final destination = e.position + _unit(delta) * range;
        final fuse = grenade ? 1.25 : range / 145;
        shots.add(
          Shot(
            e.position,
            (destination - e.position) / fuse,
            grenade ? 10 : 12,
            grenade ? 22 : 21,
            weapon: grenade ? 'enemy-grenade' : 'enemy-shell',
            anchor: destination,
            life: fuse,
            radius: grenade ? 38 : 46,
          )..fuse = fuse,
        );
      case content.EnemyArmament.laser:
        if (shots.where((s) => s.kind == 23).length >= 2) return false;
        shots.add(
          Shot(
            e.position,
            aim * 460,
            12,
            23,
            weapon: 'enemy-laser',
            life: .38,
            radius: 7,
          ),
        );
      case content.EnemyArmament.mine:
        if (shots.where((s) => s.kind == 17).length >= 10) return false;
        shots.add(
          Shot(
            e.position,
            // house stages: the mine drifts down with the scrolling street
            screenMode ? const Offset(0, 36) : Offset.zero,
            9,
            17,
            weapon: 'enemy-mine',
            life: 5,
            radius: 28,
          ),
        );
      case content.EnemyArmament.ram:
        return false;
    }
    return true;
  }

  void _enemyDeath(Foe e) {
    if (armament == 'revolver' &&
        evolved.contains('gun') &&
        e.lastSource == 'gun') {
      revolverAmmo = (revolverAmmo + 1).clamp(0, 6);
      _gun = math.min(_gun, .12 * mainInterval);
    }
    if (e.kind != 3 &&
        e.role == content.EnemyRole.splitter &&
        e.generation == 0 &&
        enemies.length < enemyLimit - 2) {
      for (int i = 0; i < 2; i++) {
        final child = _createEnemy(
          e.position + Offset(i * 20.0 - 10, 0),
          content.EnemyRole.scout,
          generation: 1,
        );
        child.hp = child.maxHp = math.max(1, e.maxHp * .3);
        enemies.add(child);
      }
    }
  }
}
