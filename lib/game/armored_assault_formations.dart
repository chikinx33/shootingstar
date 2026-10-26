part of 'engine.dart';

extension ArmoredAssaultFormations on GameEngine {
  bool formationShieldActive(Foe e) =>
      e.formationPattern == FlightFormation.bulwark &&
      e.formationOrder > 0 &&
      e.hp > 0 &&
      !e.retired &&
      e.phase >= 1.25 &&
      e.phase < 5.4 &&
      (e.phase < 2.65 || (e.phase >= 3.45 && e.phase < 4.6));

  bool _formationFront(Foe e) {
    final direction = _unit(position - e.position);
    return direction.dx * e.formationFacing.dx +
            direction.dy * e.formationFacing.dy >=
        .5;
  }

  bool formationCovered(Foe e) =>
      e.formationPattern == FlightFormation.bulwark &&
      e.formationOrder == 0 &&
      e.hp > 0 &&
      !e.retired &&
      enemies.any(
        (guard) =>
            guard.formationId == e.formationId &&
            formationShieldActive(guard) &&
            (guard.position - e.position).distance <= 110 &&
            _formationFront(guard),
      );

  double formationDamageFactor(Foe e, String source) {
    // Auxiliary fire, explosions, status and the ultimate bypass the main-gun
    // barrier. This is a bounded front guard, never an invulnerability gate.
    if (!const {'gun', 'primary'}.contains(source)) {
      return 1;
    }
    if (formationShieldActive(e) && _formationFront(e)) return .45;
    if (formationCovered(e)) return .7;
    return 1;
  }

  bool formationContactActive(Foe e) {
    if (e.formationPattern == FlightFormation.assault) {
      return !e.retired && e.phase >= 2.25 && e.phase < 6.5;
    }
    if (e.formationPattern == FlightFormation.bulwark) {
      return !e.retired && e.phase >= 1.25;
    }
    return true;
  }

  bool _spawnNewFlightFormation(FlightFormation pattern, int count) {
    if (pattern != FlightFormation.bulwark &&
        pattern != FlightFormation.assault) {
      return false;
    }
    if (!formationWindowOpen ||
        enemies.length + count > enemyLimit ||
        enemies.any(
          (e) => e.formationPattern != null && e.hp > 0 && !e.retired,
        )) {
      return false;
    }
    final assault = pattern == FlightFormation.assault;
    final side = position.dy < 220 ? 1.0 : -1.0;
    final centerX = position.dx.clamp(145.0, GameEngine.worldWidth - 145);
    final reach = (viewportHeight / 2 - 50).clamp(130.0, 165.0);
    final rallyY = (position.dy + side * reach).clamp(
      130.0,
      GameEngine.worldHeight - 130,
    );
    final id = _formationSerial++;
    for (int i = 0; i < count; i++) {
      final leader = !assault && i == 0;
      final lane = i.isEven ? -1.0 : 1.0;
      final destination = assault
          ? Offset(centerX + lane * 70, rallyY + side * (i ~/ 2) * 32)
          : leader
          ? Offset(centerX, rallyY + side * 32)
          : Offset(centerX + (i == 1 ? -52 : 52), rallyY);
      final origin = Offset(
        destination.dx,
        side < 0
            ? camera.dy - 48 - (assault ? i ~/ 2 : i) * 25
            : camera.dy + viewportHeight + 48 + (assault ? i ~/ 2 : i) * 25,
      );
      final e =
          _createEnemy(
              origin,
              assault
                  ? content.EnemyRole.kamikaze
                  : leader
                  ? content.EnemyRole.bulwark
                  : content.EnemyRole.scout,
            )
            ..formationPattern = pattern
            ..formationOrigin = origin
            ..formationDestination = destination
            ..formationId = id
            ..formationOrder = i
            ..formationFacing = _unit(position - destination)
            ..attackClock = leader ? 2.1 : .85 + i * .15;
      if (assault) {
        // Parallel lanes leave a 94-unit hull-safe center corridor. The route
        // is frozen at spawn and never steers toward the player's next dodge.
        e.targetPoint = Offset(destination.dx, position.dy - side * 280);
        e.aim = _unit(e.targetPoint! - destination);
        e.formationFacing = e.aim;
      }
      enemies.add(e);
    }
    _formationRestUntil = combatTime + (assault ? 9 : 11.3);
    waveNoticeTime = 2.5;
    return true;
  }

  void _moveNewFlightFormation(Foe e, double dt) {
    // Keep the existing battle banner visible through the full warning/guard
    // cycle, so an opening is not announced only after its text has vanished.
    waveNoticeTime = math.max(waveNoticeTime, .3);
    final assault = e.formationPattern == FlightFormation.assault;
    final slow = e.statusTime > 0 && e.status == 2 ? .55 : 1.0;
    if (e.phase < 1.25) {
      e.flight = content.EnemyFlight.approach;
      e.tell = 0;
      e.position = Offset.lerp(
        e.formationOrigin!,
        e.formationDestination!,
        e.phase / 1.25,
      )!;
      e.heading = math.atan2(e.formationFacing.dy, e.formationFacing.dx);
      return;
    }
    if (assault) {
      if (e.phase < 2.25) {
        e.flight = content.EnemyFlight.windup;
        e.velocity = Offset.zero;
        e.tell = 2.25 - e.phase;
      } else {
        e.flight = content.EnemyFlight.attackRun;
        e.tell = 0;
        e.velocity =
            e.aim * 220 * slow * (dailyEntry?.enemySpeedMultiplier ?? 1);
        e.position += e.velocity * dt;
        final remaining = e.targetPoint! - e.position;
        if (e.phase >= 6.5 ||
            remaining.dx * e.aim.dx + remaining.dy * e.aim.dy <= 0) {
          e.retired = true;
        }
      }
      e.heading = math.atan2(e.aim.dy, e.aim.dx);
      return;
    }
    if (e.phase >= 5.4) {
      e.tell = 0;
      e.flight = content.EnemyFlight.evade;
      final direction = e.formationOrder == 1
          ? -1.0
          : e.formationOrder == 2
          ? 1.0
          : e.orbitSign;
      e.velocity = Offset(direction * 120, -100) * slow;
      e.position += e.velocity * dt;
      e.heading = math.atan2(e.velocity.dy, e.velocity.dx);
      if (e.phase >= 8.8) e.retired = true;
      return;
    }
    e.flight = content.EnemyFlight.patrol;
    e.velocity = Offset.zero;
    e.heading = math.atan2(e.formationFacing.dy, e.formationFacing.dx);
    e.attackClock -= dt;
    final windup = content.enemyDoctrines[e.role]!.windup;
    if (!_enemyCanFire(e)) {
      e.tell = 0;
      e.attackClock = math.max(e.attackClock, windup + .15);
    } else if (e.attackClock > 0 && e.attackClock <= windup) {
      if (e.tell <= 0) {
        e.aim = _unit(position - e.position);
        e.targetPoint =
            e.position +
            e.aim * (position - e.position).distance.clamp(90.0, 360.0);
      }
      e.tell = e.attackClock;
      e.flight = content.EnemyFlight.windup;
    } else if (e.attackClock <= 0) {
      _enemyFire(e);
      e.tell = 0;
      e.attackClock = 3.2;
    }
  }
}
