part of 'engine.dart';

/// v12 weapon growth for the airframe's own guns: the main gun of each cat
/// and the parts on W1~W4 (docs/WEAPON_EVOLUTION_DESIGN.md). Numbers are
/// folded into the existing stats; evolutions and ultimates add behaviour.
extension GrowthArms on GameEngine {
  ModuleStats grownPartStats(String id, String partId, ModuleStats s) {
    var damage = s.damage, rate = s.fireRate, aoe = s.aoe, range = s.range;
    var speed = s.speed, count = s.count, pierce = s.pierce;
    var health = s.droneHealth, recovery = s.droneRecovery;
    switch (partId) {
      case 'gun_vulcan':
        damage *= gUp(id, 1, 1.25);
        rate *= gUp(id, 2, 1.35);
        range *= gUp(id, 3, 1.3);
        speed *= gUp(id, 3, 1.3);
        if (gEvo(id, 1)) count *= 2;
        if (gEvo(id, 2)) pierce += 1;
        if (ult(id)) {
          rate *= 1.5;
          damage *= 1.1;
        }
      case 'missile_hawk':
        damage *= gUp(id, 1, 1.3);
        rate *= gUp(id, 2, 1 / .75);
        aoe *= gUp(id, 3, 1.35);
        if (gEvo(id, 1)) count += 1;
      case 'drone_wasp':
        damage *= gUp(id, 1, 1.25);
        health *= gUp(id, 2, 1.4);
        if (enh(id) >= 2) recovery *= .7;
        rate *= gUp(id, 3, 1.3);
        count += gEvo(id, 2)
            ? 2
            : gEvo(id, 1)
            ? 1
            : 0;
        if (ult(id)) count = 0; // the mothership replaces the drones
      case 'mortar_cat':
        damage *= gUp(id, 1, 1.25);
        rate *= gUp(id, 2, 1 / .75);
        aoe *= gUp(id, 3, 1.3);
    }
    return ModuleStats(
      damage,
      rate,
      aoe,
      count,
      pierce,
      range,
      speed,
      s.supportPower,
      s.damage > 0 ? s.bossDamage * damage / s.damage : s.bossDamage,
      health,
      recovery,
    );
  }

  Foe? strongestIn(Offset at, double range) {
    Foe? best;
    for (final e in enemies) {
      if (e.hp <= 0 || e.retired || e.plane != AircraftTarget.air) continue;
      if ((e.position - at).distance > range) continue;
      if (best == null || e.hp > best.hp) best = e;
    }
    return best;
  }

  // ── 후방 자주포 ──────────────────────────────────────────────────────
  void fireMortar(MountProfile mount, ModuleStats stats) {
    final id = 'part:${mount.id}', source = 'part:${mount.id}:mortar_cat';
    final from = moduleWorldAnchor(mount.id, 0);
    if (ult(id)) {
      // 냥냥 융단 폭격: a row of six shells across the upper screen
      for (var i = 0; i < 6; i++) {
        _launchShell(
          from,
          Offset(viewRect.left + 45 + i * 66, viewRect.top + 150),
          stats.damage * 1.6,
          stats.aoe * 1.2,
          source,
          delay: i * .12,
        );
      }
      return;
    }
    final main = _crowdCentre()?.position ?? position + const Offset(0, -260);
    final targets = <Offset>[
      main,
      if (gEvo(id, 3)) main + const Offset(-70, 20),
      if (gEvo(id, 3)) main + const Offset(70, 20),
    ];
    for (final t in targets) {
      _launchShell(from, t, stats.damage, stats.aoe, source);
    }
    if (gEvo(id, 1)) {
      final second = enemies
          .where((e) => _pawCanHit(e) && (e.position - main).distance > 60)
          .fold<Foe?>(
            null,
            (b, e) =>
                b == null ||
                    (e.position - position).distance <
                        (b.position - position).distance
                ? e
                : b,
          );
      _launchShell(
        from,
        second?.position ?? main + const Offset(0, 50),
        stats.damage,
        stats.aoe,
        source,
        delay: .18,
      );
    }
    onEvent?.call('missile');
  }

  void _launchShell(
    Offset from,
    Offset to,
    double damage,
    double radius,
    String source, {
    double delay = 0,
  }) {
    pawFx.add(
      PawFx('shell', from)
        ..start = from
        ..origin = to
        ..life = .75
        ..age = -delay
        ..damage = damage
        ..radius = radius
        ..source = source,
    );
  }

  void _stepShell(PawFx fx) {
    final t = (fx.age / fx.life).clamp(0.0, 1.0);
    fx.position =
        Offset.lerp(fx.start, fx.origin, t)! -
        Offset(0, math.sin(t * math.pi) * 70);
    if (fx.age < fx.life - .001) return;
    growthBlast(fx.origin, fx.damage, fx.radius, fx.source);
    final id = fx.source.substring(0, fx.source.lastIndexOf(':'));
    if (gEvo(id, 2)) {
      pawFx.add(
        PawFx('goo', fx.origin)
          ..radius = fx.radius * .8 * areaFactor
          ..life = 1.6,
      );
    }
  }

  // ── 정찰 드론 궁극: 공수 정찰 모선 ──────────────────────────────────
  void ensureMothership(String mount, ModuleStats stats) {
    final source = 'part:$mount:drone_wasp';
    final unit = stats.damage;
    final ship = pawFx.where((f) => f.kind == 'mothership').firstOrNull;
    if (ship != null) {
      ship.damage = unit * 1.6;
      return;
    }
    pawFx.add(
      PawFx('mothership', position + const Offset(0, -140))
        ..life = double.infinity
        ..source = source
        ..damage = unit * 1.6
        ..clock = 1.5,
    );
  }

  void _stepMothership(PawFx fx, double step) {
    // cruise over the busiest part of the upper screen
    final crowd = _crowdCentre()?.position;
    final goal = Offset(
      (crowd?.dx ?? position.dx).clamp(viewRect.left + 50, viewRect.right - 50),
      viewRect.top + viewportHeight * .3,
    );
    final d = goal - fx.position;
    fx.position += _unit(d) * math.min(d.distance, 110 * step);
    fx.spin += step;
    fx.clock -= step;
    if (fx.clock > 0) return;
    fx.clock = 4;
    final near = enemies.where(_pawCanHit).toList()
      ..sort(
        (a, b) => (a.position - fx.position).distanceSquared.compareTo(
          (b.position - fx.position).distanceSquared,
        ),
      );
    if (near.isEmpty) {
      fx.clock = .5;
      return;
    }
    // drop ten little airborne scouts onto the nearest targets
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * math.pi * 2;
      pawFx.add(
        PawFx(
            'para',
            fx.position,
            velocity: Offset(math.cos(a), math.sin(a)) * 160,
          )
          ..target = near[i % math.min(near.length, 4)]
          ..life = 4
          ..damage = fx.damage
          ..source = fx.source
          ..age = -i * .05,
      );
    }
  }

  void _stepPara(PawFx fx, double step) {
    final ship = pawFx.where((f) => f.kind == 'mothership').firstOrNull;
    if (fx.returning || ship == null) {
      final home = (ship?.position ?? position) - fx.position;
      fx.position += _unit(home) * math.min(home.distance, 420 * step);
      if (home.distance < 12 || ship == null) fx.age = fx.life;
      return;
    }
    var target = fx.target;
    if (target == null || !_pawCanHit(target)) {
      target = fx.target = enemies
          .where(_pawCanHit)
          .fold<Foe?>(
            null,
            (b, e) =>
                b == null ||
                    (e.position - fx.position).distance <
                        (b.position - fx.position).distance
                ? e
                : b,
          );
      if (target == null) {
        fx.returning = true;
        return;
      }
    }
    final to = target.position - fx.position;
    fx.velocity = Offset.lerp(
      fx.velocity,
      _unit(to) * 420,
      math.min(1, step * 6),
    )!;
    fx.position += fx.velocity * step;
    if (to.distance < target.radius + 8) {
      _hit(target, fx.damage, fx.source);
      fx.clock++;
      if (fx.clock >= 2) fx.returning = true;
      fx.target = null;
    }
  }

  // ── 고등어 미사일 궁극: 참치 순항 미사일 ────────────────────────────
  void fireTuna(MountProfile mount, OwnedModulePart part, ModuleStats stats) {
    final at = moduleMuzzleAt(mount.id, 0, 0);
    final target = strongestIn(at, 900) ?? _crowdCentre();
    final shot = Shot(
      at,
      const Offset(0, -150),
      stats.damage * 5,
      1,
      weapon: 'part:${mount.id}:${part.partId}:tuna',
      target: target,
      life: 5,
      radius: 9,
    )..fuse = 130 * areaFactor;
    shots.add(shot);
    onEvent?.call('missile');
  }

  /// Splits a missile on impact: 4 small mackerels (evolve 3) or, from the
  /// tuna ultimate, 8 of them in every direction.
  void missileAftermath(Shot shot, Offset at) {
    final bits = shot.weapon.split(':');
    if (bits.length < 3 || bits[2] != 'missile_hawk') return;
    final tuna = shot.weapon.endsWith(':tuna');
    final mini = shot.weapon.endsWith(':mini');
    final n = tuna
        ? 8
        : !mini && gEvo('part:${bits[1]}', 3)
        ? 4
        : 0;
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      _deferredShots.add(
        Shot(
            at,
            Offset(math.cos(a), math.sin(a)) * 260,
            shot.damage * (tuna ? .45 : .35),
            1,
            weapon: 'part:${bits[1]}:missile_hawk:mini',
            life: 1.4,
            radius: 3,
          )
          ..fuse = math.max(18, shot.fuse * .4)
          ..closeRange = true,
      );
    }
  }

  // ── 주무기 ───────────────────────────────────────────────────────────
  double get mainRateGrowth => switch (armament) {
    'pulse' => gUp('gun', 2, 1.3) * (ult('gun') ? 2.2 : 1),
    'shotgun' => gUp('gun', 2, 1 / .75),
    'revolver' => ult('gun') ? 1 / 1.7 : 1,
    _ => 1,
  };

  /// Returns true when an ultimate replaced the ordinary volley.
  bool mainUltimateVolley(Offset at, double perShot) {
    if (!ult('gun')) return false;
    switch (armament) {
      case 'revolver':
        // 구름 레일건: the whole screen column above the cat, at once
        pawFx.add(
          PawFx('rail', at)
            ..life = .32
            ..radius = 20,
        );
        for (final e in enemies) {
          if (!_pawCanHit(e) || e.position.dy > at.dy) continue;
          if ((e.position.dx - at.dx).abs() < 20 + e.radius) {
            _hit(e, perShot * 4.5, 'module-main');
            e.vulnerable = math.max(e.vulnerable, 2);
          }
        }
        onEvent?.call('laser');
        return true;
      case 'shotgun':
        // 밤하늘 발톱 폭풍: three giant claw waves
        for (final a in [-.35, 0.0, .35]) {
          pawFx.add(
            PawFx('claw', at, velocity: Offset(math.sin(a), -math.cos(a)) * 520)
              ..life = .7
              ..radius = 32 * areaFactor
              ..spin = a
              ..damage = perShot * 2.6
              ..source = 'module-main',
          );
        }
        return true;
      default:
        // 태양 냥냥 개틀링: shots keep flying, heat builds a sun beam
        mainHeat += .03;
        if (mainHeat >= 1 && !_hasFx('sunbeam')) {
          mainHeat = 0;
          pawFx.add(
            PawFx('sunbeam', at)
              ..life = 2
              ..radius = 26
              ..damage = perShot * 9
              ..source = 'module-main',
          );
        }
        return false;
    }
  }

  void _stepSunbeam(PawFx fx, double step) {
    fx.position = position + const Offset(0, -30);
    for (final e in enemies) {
      if (!_pawCanHit(e) || e.position.dy > fx.position.dy) continue;
      if ((e.position.dx - fx.position.dx).abs() < fx.radius + e.radius) {
        _hit(e, fx.damage * step, 'module-main');
      }
    }
    shots.removeWhere(
      (s) =>
          s.kind == 4 &&
          s.position.dy < fx.position.dy &&
          (s.position.dx - fx.position.dx).abs() < fx.radius,
    );
  }

  void _stepClaw(PawFx fx, double step) {
    fx.position += fx.velocity * step;
    fx.radius += step * 30;
    _touch(fx, 99);
    shots.removeWhere(
      (s) =>
          (s.kind == 4 || s.kind == 19) &&
          (s.position - fx.position).distance < fx.radius + s.radius,
    );
  }

  /// Main-gun evolutions that act on a hit.
  void growthMainHit(Shot s, Foe e) {
    if (s.weapon != 'module-main' || !unifiedModules) return;
    switch (armament) {
      case 'revolver':
        // evolve 2: shatter into three fragments
        if (gEvo('gun', 2) && !s.closeRange) {
          for (final a in [-.5, 0.0, .5]) {
            _deferredShots.add(
              Shot(
                  e.position,
                  Offset(math.sin(a), -math.cos(a)) * 380,
                  s.damage * .35,
                  6,
                  weapon: 'module-main',
                  life: .5,
                  radius: 3,
                )
                ..closeRange = true
                ..hitTargets.add(e),
            );
          }
        }
      case 'shotgun':
        // evolve 2: ricochet once toward another enemy
        if (gEvo('gun', 2) && !s.closeRange) {
          Foe? next;
          var best = 220.0;
          for (final o in enemies) {
            if (o == e || !_pawCanHit(o) || s.hitTargets.contains(o)) continue;
            final d = (o.position - e.position).distance;
            if (d < best) {
              best = d;
              next = o;
            }
          }
          if (next != null) {
            s.velocity =
                _unit(next.position - e.position) * s.velocity.distance;
            s.closeRange = true;
            s.pierce += 1;
          }
        }
        // evolve 3: point-blank knockback and a short stun
        if (gEvo('gun', 3) &&
            e.kind != 3 &&
            (e.position - position).distance < 170) {
          _knock(e, position, 26);
          e.status = 2;
          e.statusTime = math.max(e.statusTime, .5);
        }
    }
  }

  void stepGrowthFx(PawFx fx, double step) {
    switch (fx.kind) {
      case 'shell':
        _stepShell(fx);
      case 'mothership':
        _stepMothership(fx, step);
      case 'para':
        _stepPara(fx, step);
      case 'sunbeam':
        _stepSunbeam(fx, step);
      case 'claw':
        _stepClaw(fx, step);
    }
  }
}
