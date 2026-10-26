part of 'engine.dart';

/// Permanent equipment effects are frozen at sortie creation, never read live
/// from the lobby. Transient counters/timers are checkpointed with the battle.
extension GearCombat on GameEngine {
  List<int> get gearSpecs => aircraft?.gearSpecs ?? const [];
  bool _gear(int slot, int spec) =>
      gearSpecs.length == 6 && gearSpecs[slot] == spec;
  double get gearThrustFactor =>
      _gear(5, 10) && (_moduleTimers['gear-thrust-active'] ?? 0) > 0 ? 1.12 : 1;
  double _gearHitFactor(String source) =>
      _gear(2, 4) &&
          (_moduleTimers['gear-overdrive-active'] ?? 0) > 0 &&
          (source.startsWith('module-') || source == 'gear-seeker')
      ? 1.10
      : 1;
  void _gearShield(double fraction) {
    moduleShield = math.min(maxHp * .22, moduleShield + maxHp * fraction);
    visuals.emit(CombatCueKind.shield, position, source: 'gear', radius: 44);
  }

  void _gearCharge(double energy, double pilotSeconds) {
    if (hasCommonUltimate && ultimateRemaining == 0)
      _ultimateCharge = math.min(100, _ultimateCharge + energy);
    pilotAbilityCooldown = math.max(0, pilotAbilityCooldown - pilotSeconds);
    visuals.emit(
      CombatCueKind.pickup,
      position,
      source: 'gear-charge',
      radius: 24,
    );
  }

  void _gearTick() {
    if (gearSpecs.isEmpty) return;
    if (_gear(1, 2) && _moduleReady('gear-mark', 6)) {
      final target = _moduleTarget(position, range: 400);
      if (target != null) {
        target.vulnerable = math.max(2, target.vulnerable);
        visuals.emit(
          CombatCueKind.area,
          target.position,
          source: 'gear-sensor',
          radius: 22,
        );
      }
    }
    if (_gear(1, 3) && _moduleReady('gear-scan', 4)) {
      var count = 0;
      final radius = math.min(300.0, collectionRadius + 110);
      final near =
          crystals
              .where(
                (p) =>
                    (p - position).distance > collectionRadius &&
                    (p - position).distance <= 300,
              )
              .toList()
            ..sort(
              (a, b) => (a - position).distanceSquared.compareTo(
                (b - position).distanceSquared,
              ),
            );
      for (final crystal in near) {
        if (count++ >= 4) break;
        final i = crystals.indexWhere((p) => identical(p, crystal));
        if (i < 0) continue;
        crystals[i] = ExperienceCrystal.at(
          position +
              _unit(crystal - position) *
                  math.min(collectionRadius * .9, radius),
          ExperienceCrystal.valueOf(crystal),
        );
      }
      if (near.isNotEmpty)
        visuals.emit(
          CombatCueKind.magnet,
          position,
          source: 'gear-scanner',
          radius: radius,
        );
    }
    if (_gear(2, 4) && _moduleReady('gear-overdrive', 10)) {
      _moduleTimers['gear-overdrive-active'] = 2;
      visuals.emit(
        CombatCueKind.synergy,
        position,
        source: 'gear-core',
        radius: 40,
      );
    }
    if (_gear(4, 8) && (_moduleTimers['gear-intercept'] ?? 0) <= 0) {
      final incoming = shots.where(
        (s) => s.interceptable && (s.position - position).distance <= 48,
      );
      if (incoming.isNotEmpty) {
        shots.remove(incoming.first);
        _moduleTimers['gear-intercept'] = 12;
        visuals.emit(
          CombatCueKind.shield,
          position,
          source: 'gear-belt',
          radius: 48,
        );
      }
    }
    if (_gear(5, 10) &&
        input.distance > .2 &&
        _moduleReady('gear-thrust', 12)) {
      _moduleTimers['gear-thrust-active'] = 1;
      visuals.emit(
        CombatCueKind.area,
        position,
        source: 'gear-thruster',
        radius: 25,
      );
    }
  }

  int _gearPrimaryPierce() {
    gearVolleys++;
    return _gear(0, 0) && gearVolleys % 8 == 0 ? 1 : 0;
  }

  void _gearPrimaryFired(double damage) {
    if (gearVolleys % 8 != 0) return;
    if (_gear(0, 1)) {
      final at = moduleMuzzle(AircraftMount.main);
      shots.add(
        Shot(
          at,
          const Offset(0, -260),
          damage * .35,
          28,
          weapon: 'gear-seeker',
          life: 1.6,
          radius: 4,
        ),
      );
      visuals.emit(CombatCueKind.muzzle, at, source: 'gear-seeker', radius: 10);
    }
    if (_gear(2, 5)) _gearCharge(2, .5);
  }

  void _gearTookDamage(double loss) {
    if (loss <= 0 || hp <= 0) return;
    if (_gear(3, 6) &&
        loss >= maxHp * .10 &&
        _moduleReady('gear-hull-guard', 12))
      _gearShield(.02);
    if (_gear(4, 9) && hp <= maxHp * .35 && _moduleReady('gear-emergency', 30))
      _gearShield(.06);
  }

  void _gearCollectedCrystal(double value) {
    if (!_gear(5, 11)) return;
    final before = gearSalvage ~/ 16;
    gearSalvage += (value / 2).round();
    final earned = gearSalvage ~/ 16 - before;
    if (earned > 0) _gearCharge(3 * earned.toDouble(), .3 * earned);
  }

  bool _gearShot(Shot shot, double dt) {
    if (shot.kind != 28) return false;
    final target = _moduleTarget(
      shot.position,
      axis: -math.pi / 2,
      halfArc: .65,
      range: 300,
    );
    if (target != null) {
      final yaw = math
          .atan2(
            target.position.dx - shot.position.dx,
            shot.position.dy - target.position.dy,
          )
          .clamp(-.55, .55);
      shot.velocity = Offset.lerp(
        shot.velocity,
        Offset(math.sin(yaw), -math.cos(yaw)) * 260,
        math.min(1, dt * 4),
      )!;
    }
    shot.position += shot.velocity * dt;
    if (enemies.any(
          (e) =>
              e.hp > 0 &&
              e.plane == AircraftTarget.air &&
              (e.position - shot.position).distance < e.radius + 4,
        ) ||
        shot.age >= 1.3) {
      final targets =
          enemies
              .where(
                (e) =>
                    e.hp > 0 &&
                    e.plane == AircraftTarget.air &&
                    (e.position - shot.position).distance < 28 + e.radius,
              )
              .toList()
            ..sort(
              (a, b) => (a.position - shot.position).distanceSquared.compareTo(
                (b.position - shot.position).distanceSquared,
              ),
            );
      for (final foe in targets.take(3)) {
        _hit(foe, shot.damage, 'gear-seeker');
      }
      visuals.emit(
        CombatCueKind.explosion,
        shot.position,
        source: 'gear-seeker',
        radius: 28,
      );
      shot.life = 0;
    }
    return true;
  }
}
