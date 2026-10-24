part of 'engine.dart';

/// Exact XP-bearing pickups in flight. No cosmetic cap can discard their value.
class AbsorbingCrystal {
  AbsorbingCrystal(this.origin, this.duration, this.bend, this.value)
    : position = origin;
  final Offset origin;
  final double duration, bend;
  double value;
  Offset position;
  double age = 0;
}

/// Presentation clock freezes gameplay and never samples combat RNG.
class BossResolution {
  BossResolution(this.foe, this.finalBoss, this.rotation);
  final Foe foe;
  final bool finalBoss;
  final double rotation;
  double time = 0;
  int bursts = 0;
  static const breakupAt = 1.9;
  static const clearAt = 2.55;
  static const departureAt = 3.65;
  static const endAt = 5.35;
  double get departure =>
      finalBoss ? ((time - departureAt) / 1.35).clamp(0, 1) : 0;
  String get message => time < clearAt
      ? '보스 격파'
      : finalBoss
      ? '항로 클리어'
      : '보스 격파 · 다음 교전 준비';
}

extension BattleResolution on GameEngine {
  void _attractCrystals() {
    final view = Rect.fromLTWH(
      camera.dx + 10,
      camera.dy + 10,
      400,
      math.max(20, viewportHeight - 20),
    );
    for (var i = crystals.length - 1; i >= 0; i--) {
      if ((crystals[i] - position).distance > 320) continue;
      final crystal = crystals[i];
      final value =
          ExperienceCrystal.valueOf(crystal) *
          (1 + (passives['xp'] ?? 0) * .08);
      // Only nearby ground pickups enter the stream. Off-screen stock remains.
      final from = Offset(
        crystal.dx.clamp(view.left, view.right),
        crystal.dy.clamp(view.top, view.bottom),
      );
      crystals.removeAt(i);
      if (absorbingCrystals.length >= GameEngine.crystalLimit) {
        // A second magnet may overlap the first stream. Share an existing mote
        // instead of dropping XP or growing beyond the restorable actor budget.
        absorbingCrystals[i % absorbingCrystals.length].value += value;
        continue;
      }
      absorbingCrystals.add(
        AbsorbingCrystal(
          from,
          .5 + (from - position).distance.clamp(0, 650) / 1100 + (i % 7) * .025,
          (i.isEven ? 1 : -1) * (20 + i % 5 * 7).toDouble(),
          value,
        ),
      );
    }
  }

  void _advanceAbsorption(double dt) {
    if (absorbingCrystals.isEmpty) {
      if (_absorptionSettle > 0) {
        _absorptionSettle = math.max(0, _absorptionSettle - dt);
        // the magnet's gems have just arrived: that is a gem moment
        if (_absorptionSettle == 0) _checkLevel();
      }
      return;
    }
    for (var i = absorbingCrystals.length - 1; i >= 0; i--) {
      final mote = absorbingCrystals[i];
      mote.age += dt;
      final p = (mote.age / mote.duration).clamp(0.0, 1.0);
      final ease = p * p;
      final delta = position - mote.origin;
      final normal = Offset(-delta.dy, delta.dx) / math.max(1, delta.distance);
      mote.position =
          Offset.lerp(mote.origin, position, ease)! +
          normal * math.sin(p * math.pi) * mote.bend;
      if (p >= 1) {
        xp += mote.value;
        absorbingCrystals.removeAt(i);
        visuals.emit(
          CombatCueKind.pickup,
          position,
          radius: 28,
          throttle: 'magnet-arrival',
          interval: .07,
        );
      }
    }
    if (absorbingCrystals.isEmpty) _absorptionSettle = .18;
  }

  void _beginBossResolution(Foe foe, bool finalBoss) {
    // The retired actor is presentation-only now. Keep its destruction in view
    // even when the killing shot reached beyond the short mobile viewport.
    foe.position = Offset(
      foe.position.dx.clamp(camera.dx + 78, camera.dx + 342),
      foe.position.dy.clamp(
        camera.dy + 84,
        camera.dy + math.max(85, viewportHeight * .4),
      ),
    );
    bossResolution = BossResolution(
      foe,
      finalBoss,
      math.atan2(position.dy - foe.position.dy, position.dx - foe.position.dx) +
          math.pi / 2,
    );
    input = Offset.zero;
    choices = [];
    shots.clear();
    laserLife = 0;
  }

  void _advanceBossResolution(double dt) {
    final scene = bossResolution!;
    _advanceAbsorption(dt);
    for (final spark in sparks) {
      spark.position += spark.velocity * dt;
      spark.life -= dt;
    }
    sparks.removeWhere((spark) => spark.life <= 0);
    final previous = scene.time;
    scene.time += dt;
    input = Offset.zero;
    final count = math.min(13, (scene.time / .145).floor());
    while (scene.bursts < count) {
      final n = scene.bursts++;
      final angle = n * 2.39996;
      final distance = scene.foe.radius * (.2 + (n % 4) * .23);
      visuals.emit(
        CombatCueKind.explosion,
        scene.foe.position + _direction(angle) * distance,
        radius: 22 + (n % 4) * 13.0,
      );
    }
    if (previous < BossResolution.breakupAt &&
        scene.time >= BossResolution.breakupAt) {
      visuals.emit(
        CombatCueKind.bossExplosion,
        scene.foe.position,
        radius: 155,
      );
    }
    if (previous < BossResolution.clearAt &&
        scene.time >= BossResolution.clearAt) {
      onEvent?.call('victory');
    }
    if (!scene.finalBoss && scene.time >= 3.4) {
      bossResolution = null;
      _hurt = math.max(_hurt, 1);
    } else if (scene.finalBoss && scene.time >= BossResolution.endAt) {
      _finishVictory();
    }
  }

  void _finishVictory() {
    // XP already carried by a collected magnet still counts in result growth;
    // there is no remaining combat in which to use another draft selection.
    while (xp >= xpNeeded && xpNeeded > 0) {
      xp -= xpNeeded;
      level++;
      xpNeeded = GameEngine.growthCost(level);
    }
    finished = true;
    victory = true;
    input = Offset.zero;
    // Result is now reachable only after the hero has left the viewport.
  }
}
