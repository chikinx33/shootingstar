part of 'engine.dart';

/// A telegraph: a thin warning line before a snipe or a beam.
class DangerLine {
  DangerLine(this.origin, this.angle, this.total, {this.beam = false})
    : time = total;
  Offset origin;
  double angle, time;
  final double total;
  final bool beam;
}

class _EmitRun {
  _EmitRun(this.e, this.sign) : clock = e.start;
  final Emit e;

  /// 1, or -1 for the mirrored muzzle.
  final double sign;
  double clock, gap = 0, warn = 0, spin = 0;
  int left = 0, fired = 0;
  double angle = math.pi / 2;
  bool tracking = false;
  DangerLine? line;
}

class _DanmakuRun {
  _DanmakuRun(this.set)
    : runs = [
        for (final e in set) ...[_EmitRun(e, 1), if (e.mirror) _EmitRun(e, -1)],
      ];
  final List<Emit> set;
  final List<_EmitRun> runs;
}

/// v12.9.8 data-driven enemy fire (lib/game/danmaku_patterns.dart): every
/// ordinary shooter, mid-boss and stage boss runs its reference emitters.
extension Danmaku on GameEngine {
  /// Pixels per reference unit (the reference screen is ~9 units tall).
  double get danmakuUnit => viewportHeight / 9;

  /// Runs [set] for [f] this frame. A different set (a new boss phase)
  /// restarts its emitters. [tempo] scales cycles and gaps (rage < 1).
  void runDanmaku(
    Foe f,
    List<Emit> set,
    double dt, {
    double tempo = 1,
    required double damage,
    required int limit,
  }) {
    var run = _danmakuRuns[f];
    if (run == null || !identical(run.set, set)) {
      run = _danmakuRuns[f] = _DanmakuRun(set);
    }
    for (final r in run.runs) {
      _stepEmit(f, r, dt, tempo, damage, limit);
    }
  }

  void _stepEmit(
    Foe f,
    _EmitRun r,
    double dt,
    double tempo,
    double damage,
    int limit,
  ) {
    final e = r.e;
    final origin = f.position + Offset(e.at.dx * r.sign, e.at.dy);
    final toCat = math.atan2(position.dy - origin.dy, position.dx - origin.dx);
    if (e.aimed && e.track > 0) {
      // a turret barrel: it swings toward the cat at its own speed
      if (!r.tracking) {
        r.angle = toCat;
        r.tracking = true;
      }
      final diff = math.atan2(
        math.sin(toCat - r.angle),
        math.cos(toCat - r.angle),
      );
      final turn = e.track * math.pi / 180 * dt;
      r.angle += diff.clamp(-turn, turn);
    }
    r.clock -= dt;
    if (r.clock <= 0 && r.left == 0 && r.warn <= 0) {
      r.clock = math.max(.05, r.clock + e.period * tempo);
      if (!e.aimed) {
        r.angle = math.pi / 2;
      } else if (e.track <= 0) {
        r.angle = toCat;
      }
      if (e.warn > 0) {
        r.warn = e.warn;
        r.line = DangerLine(
          origin,
          _volleyAngle(r, 0),
          e.warn,
          beam: e.look == BulletLook.beam,
        );
        dangerLines.add(r.line!);
      } else {
        r.left = e.volleys;
        r.gap = 0;
      }
    }
    if (r.warn > 0) {
      r.warn -= dt;
      r.line
        ?..origin = origin
        ..angle = _volleyAngle(r, 0);
      if (r.warn <= 0) {
        r.line = null;
        if (e.look == BulletLook.beam) {
          _fireBeam(origin, _volleyAngle(r, 0), e, damage);
        } else {
          r.left = e.volleys;
          r.gap = 0;
        }
      }
    }
    var guard = 0;
    while (r.left > 0 && guard++ < 8) {
      r.gap -= guard == 1 ? dt : 0;
      if (r.gap > 0) break;
      _fireVolley(origin, r, damage, limit);
      r.fired++;
      r.left--;
      r.spin += e.shift * r.sign * math.pi / 180;
      r.gap += math.max(.004, e.volleyGap * tempo);
    }
  }

  double _volleyAngle(_EmitRun r, int index) {
    final e = r.e;
    var a = r.angle + e.offset * r.sign * math.pi / 180 + r.spin;
    if (e.sweep > 0) {
      a +=
          e.sweep *
          math.pi /
          180 *
          math.sin(combatTime * 2 * math.pi / e.sweepPeriod);
    }
    return a;
  }

  void _fireVolley(Offset origin, _EmitRun r, double damage, int limit) {
    final e = r.e;
    final base = _volleyAngle(r, r.fired);
    final ring = e.step * e.ways >= 359;
    final unit = danmakuUnit;
    for (var i = 0; i < e.ways; i++) {
      if (shots.where((s) => s.hostile).length >= limit) return;
      var a = ring
          ? base + e.step * i * math.pi / 180
          : base + e.step * (i - (e.ways - 1) / 2) * math.pi / 180;
      var at = origin;
      if (e.step == 0 && e.gap > 0 && e.ways > 1) {
        final side = Offset(-math.sin(a), math.cos(a));
        at += side * (i - (e.ways - 1) / 2) * e.gap * unit;
      }
      if (e.jitter > 0) {
        a += e.jitter * math.pi / 180 * (random.nextDouble() * 2 - 1);
      }
      final speed =
          e.speed * unit * (1 + e.speedJitter * (random.nextDouble() * 2 - 1));
      final hit = damage * e.dmg;
      final dir = _direction(a);
      if (e.look == BulletLook.missile) {
        shots.add(
          Shot(
            at,
            dir * 180,
            hit,
            20,
            weapon: 'enemy-missile',
            life: 3.2,
            radius: 5,
          ),
        );
        continue;
      }
      final (weapon, radius) = switch (e.look) {
        BulletLook.needle => ('enemy-needle', 3.5),
        BulletLook.bigOrb => ('enemy-big', 5.0),
        BulletLook.bar => ('enemy-bullet', hostileBulletRadius),
        _ => ('enemy-orb', hostileBulletRadius),
      };
      shots.add(
        Shot(
          at,
          dir * speed,
          hit,
          4,
          weapon: weapon,
          life: e.life,
          radius: radius,
        )..accel = e.accel * unit,
      );
    }
    if (r.fired == 0) onEvent?.call('enemy-fire');
  }

  void _fireBeam(Offset origin, double angle, Emit e, double damage) {
    shots.add(
      Shot(
        origin,
        _direction(angle) * 900,
        damage * e.dmg * 2,
        23,
        weapon: 'enemy-laser',
        life: e.beam,
        radius: 8,
      ),
    );
    onEvent?.call('enemy-fire');
  }

  /// Telegraph clocks; patterns of units that are gone stop.
  void updateDanmaku(double dt) {
    for (final l in dangerLines) {
      l.time -= dt;
    }
    dangerLines.removeWhere((l) => l.time <= 0);
    if (_danmakuRuns.isNotEmpty) {
      _danmakuRuns.removeWhere(
        (f, _) => f.hp <= 0 || f.retired || !enemies.contains(f),
      );
    }
  }
}
