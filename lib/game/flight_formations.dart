part of 'engine.dart';

extension FlightFormations on GameEngine {
  String get formationCue {
    for (final e in enemies) {
      if (e.hp <= 0 || e.retired || e.formationPattern == null) continue;
      if (e.formationPattern == FlightFormation.bulwark) {
        final guards = enemies.where(
          (g) =>
              g.formationId == e.formationId &&
              g.formationOrder > 0 &&
              g.hp > 0 &&
              !g.retired,
        );
        return '방패·중장 편대 · ${e.phase < 1.25
            ? '진입 예고'
            : e.phase >= 5.4
            ? '이탈'
            : guards.isEmpty
            ? '호위 해제'
            : guards.any(formationShieldActive)
            ? '방패 가동'
            : '방패 재정비'}';
      }
      if (e.formationPattern == FlightFormation.assault) {
        return '돌입 편대 · ${e.phase < 1.25
            ? '진입 예고'
            : e.phase < 2.25
            ? '항로 고정'
            : '직선 돌진'}';
      }
      final name = e.formationPattern == FlightFormation.column
          ? '일렬 편대'
          : '펼침 편대';
      return '$name · ${e.phase < 1.25
          ? '진입 예고'
          : e.phase < 3.8
          ? '사격 준비'
          : '교차 이탈'}';
    }
    return '';
  }

  void _updateFlightFormations(double dt) {
    _flightFormationClock -= dt;
    if (_flightFormationClock > 0 ||
        !formationWindowOpen ||
        enemies.any(
          (e) => e.formationPattern != null && !e.retired && e.hp > 0,
        )) {
      return;
    }
    final patterns = routePlan.formations;
    final pattern = patterns[_flightFormationSerial % patterns.length];
    if (pattern == FlightFormation.bulwark) {
      if (_spawnNewFlightFormation(pattern, 3)) {
        _flightFormationSerial++;
        _flightFormationClock = routeFormationInterval;
      }
      return;
    }
    _spawnBasicFlightFormation(pattern);
  }

  void _spawnBasicFlightFormation(FlightFormation pattern) {
    final count = pattern == FlightFormation.column ? 4 : 5;
    if (enemies.length + count > enemyLimit) return;
    final centerX = (position.dx + (_flightFormationSerial.isEven ? -50 : 50))
        .clamp(140.0, GameEngine.worldWidth - 140)
        .toDouble();
    // Keep the full row inside the world even when the pilot hugs its edge.
    final y = math
        .max(camera.dy + 64, position.dy - 155)
        .clamp(150.0, GameEngine.worldHeight - 64)
        .toDouble();
    final id = _formationSerial++;
    for (int i = 0; i < count; i++) {
      final side = i - (count - 1) / 2;
      final destination = pattern == FlightFormation.column
          ? Offset(centerX, y - i * 34)
          : Offset(centerX + side * 48, y - side.abs() * 24);
      final origin = Offset(destination.dx, camera.dy - 48 - i * 25);
      final e = _createEnemy(origin, content.EnemyRole.scout)
        ..formationPattern = pattern
        ..formationOrigin = origin
        ..formationDestination = destination
        ..formationId = id
        ..formationOrder = i
        ..orbitSign = _flightFormationSerial.isEven ? 1 : -1
        ..attackClock = .9 + i * .12;
      enemies.add(e);
    }
    _flightFormationSerial++;
    _flightFormationClock = routeFormationInterval;
    _formationRestUntil = combatTime + 9.5;
    waveNoticeTime = 2;
  }

  void _moveFlightFormation(Foe e, double dt) {
    if (e.formationPattern == FlightFormation.bulwark ||
        e.formationPattern == FlightFormation.assault) {
      _moveNewFlightFormation(e, dt);
      return;
    }
    final slow = e.statusTime > 0 && e.status == 2 ? .55 : 1.0;
    if (e.phase < 1.25) {
      e.flight = content.EnemyFlight.approach;
      e.position = Offset.lerp(
        e.formationOrigin!,
        e.formationDestination!,
        e.phase / 1.25,
      )!;
      e.heading = math.pi / 2;
      return;
    }
    if (e.phase >= 3.8) {
      e.tell = 0;
      e.flight = content.EnemyFlight.evade;
      final side = e.formationPattern == FlightFormation.fan
          ? (e.formationOrder < 2 ? -1.0 : 1.0)
          : e.orbitSign;
      e.velocity = Offset(side * 130, -110) * slow;
      e.position += e.velocity * dt;
      e.heading = math.atan2(e.velocity.dy, e.velocity.dx);
      if (e.phase >= 7.2) e.retired = true;
      return;
    }
    e.flight = content.EnemyFlight.patrol;
    e.attackClock -= dt;
    final windup = content.enemyDoctrines[e.role]!.windup;
    if (!_enemyCanFire(e)) {
      e.tell = 0;
      e.attackClock = math.max(e.attackClock, windup + .15);
    } else if (e.attackClock <= windup && e.attackClock > 0) {
      if (e.tell <= 0) e.aim = _unit(position - e.position);
      e.tell = e.attackClock;
      e.flight = content.EnemyFlight.windup;
    } else if (e.attackClock <= 0) {
      _enemyFire(e);
      e.tell = 0;
      e.attackClock = 2.8;
    }
  }
}
