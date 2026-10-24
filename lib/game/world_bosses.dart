part of 'engine.dart';

// 0 safe-wedge volley, 1 locked fan, 2 charge, 3 twin lanes,
// 4 marked artillery, 5 open-ring mines. Existing world order stays intact.
const worldBossPatterns = [
  [0, 1, 2],
  [1, 4, 2],
  [0, 5, 3],
  [1, 3, 4],
  [4, 0, 5],
  [5, 4, 3],
  [2, 1, 4],
  [3, 0, 1],
  [1, 3, 0],
  [5, 3, 4],
];

extension WorldBosses on GameEngine {
  void _lockBossAttack() {
    final b = boss;
    if (b == null) return;
    bossOrigin = b.position;
    bossTarget = position;
    bossAim = _unit(position - b.position);
    onEvent?.call('warning');
  }

  // Radial exits alternate sides of the locked aim. Standing still is outside
  // the safe sector; its tell and actual bullet gap use this same direction.
  Offset get bossSafeDirection {
    final base = math.atan2(bossAim.dy, bossAim.dx);
    final side = (bossRound + bossPhase).isEven ? 1.0 : -1.0;
    for (final offset in [
      side * .95,
      -side * .95,
      side * 1.5,
      -side * 1.5,
      math.pi,
    ]) {
      final candidate = _direction(base + offset);
      final point = bossOrigin + candidate * 180;
      if (point.dx >= 34 &&
          point.dx <= GameEngine.worldWidth - 34 &&
          point.dy >= 34 &&
          point.dy <= GameEngine.worldHeight - 34)
        return candidate;
    }
    return _unit(
      const Offset(GameEngine.worldWidth / 2, GameEngine.worldHeight / 2) -
          bossOrigin,
    );
  }

  Offset get bossLaserSafeOrigin {
    final normal = Offset(-bossAim.dy, bossAim.dx);
    return bossOrigin + normal * (bossRound.isOdd ? -70.0 : 0.0);
  }

  List<(Offset, Offset)> get bossLaserLanes {
    final normal = Offset(-bossAim.dy, bossAim.dx);
    return [
      for (final offset in bossRound.isOdd ? [0.0, 140.0] : [-70.0, 70.0])
        (
          bossOrigin + normal * offset,
          bossOrigin + normal * offset + bossAim * 420,
        ),
    ];
  }

  List<Offset> get bossArtilleryTargets {
    final normal = Offset(-bossAim.dy, bossAim.dx);
    return [
      for (final side in [-1.0, 0.0, 1.0])
        _bossBoundedPoint(bossTarget + normal * side * 88),
    ];
  }

  Offset get bossMineExit {
    final candidate = bossTarget + bossAim * 160;
    return candidate.dx < 64 ||
            candidate.dx > GameEngine.worldWidth - 64 ||
            candidate.dy < 64 ||
            candidate.dy > GameEngine.worldHeight - 64
        ? _unit(
            const Offset(
                  GameEngine.worldWidth / 2,
                  GameEngine.worldHeight / 2,
                ) -
                bossTarget,
          )
        : bossAim;
  }

  List<Offset> get bossMineTargets {
    final exit = bossMineExit;
    final angle = math.atan2(exit.dy, exit.dx);
    // Leave the outward sector open. The target and gap freeze with the tell.
    final points = <Offset>[];
    for (var i = 1; i < 8; i++) {
      final at = _bossBoundedPoint(
        bossTarget + _direction(angle + i * math.pi / 4) * 115,
      );
      final delta = at - bossTarget;
      if (delta.distance < 70 ||
          (delta.dx * exit.dx + delta.dy * exit.dy) / delta.distance > .71 ||
          points.any((p) => (p - at).distance < 44)) {
        continue;
      }
      points.add(at);
    }
    return points;
  }

  Offset _bossBoundedPoint(Offset p) => Offset(
    p.dx.clamp(34.0, GameEngine.worldWidth - 34),
    p.dy.clamp(34.0, GameEngine.worldHeight - 34),
  );

  void _bossSignature(Foe b) {
    switch (bossPattern) {
      case 3:
        for (final (from, to) in bossLaserLanes) {
          shots.add(
            Shot(
              from,
              to - from,
              17,
              23,
              weapon: 'boss-laser',
              life: .55,
              radius: 10,
            ),
          );
        }
      case 4:
        for (final at in bossArtilleryTargets) {
          shots.add(
            Shot(
              bossOrigin,
              _unit(at - bossOrigin) * 360,
              17,
              21,
              weapon: 'boss-artillery',
              life: 1.15,
              radius: 30,
            )..anchor = at,
          );
        }
      case 5:
        for (final at in bossMineTargets) {
          shots.add(
            Shot(
              at,
              _unit(bossTarget - at) * 55,
              17,
              17,
              weapon: 'boss-mine',
              life: 2.2,
              radius: 22,
            )..age = 1,
          );
        }
      default:
        _bossVolley(b);
    }
  }

  void _bossReinforcements(Foe b) {
    if (bossPhase == 0 || (worldIndex != 4 && worldIndex != 9)) return;
    final adds = enemies
        .where((e) => e.kind != 3 && e.hp > 0 && !e.retired)
        .length;
    final normal = Offset(-bossAim.dy, bossAim.dx);
    for (var i = 0; i < math.min(2, 4 - adds); i++) {
      final at = _bossBoundedPoint(b.position + normal * (i == 0 ? -90 : 90));
      if ((at - position).distance < 90) continue;
      enemies.add(
        _createEnemy(
          at,
          worldIndex == 4
              ? content.EnemyRole.splitter
              : content.EnemyRole.weaver,
          generation: 1,
        ),
      );
    }
  }
}
