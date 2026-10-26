part of 'engine.dart';

/// One deployed chick card: its kind and how far the player raised it.
class ChickLoadout {
  const ChickLoadout(
    this.kind, {
    this.level = 1,
    this.rank = 0,
    this.awakePower = 0,
    this.awakeCooldown = 0,
  });
  final int kind, level, rank;
  final double awakePower, awakeCooldown;
}

/// The nine chick kinds (user 2026-10-27).
abstract final class ChickKind {
  static const fire = 0, medic = 1, shield = 2, lightning = 3, ice = 4;
  static const bomb = 5, sniper = 6, star = 7, mirror = 8;
  static const count = 9;
}

enum ChickState { waiting, tail, falling }

class Chick {
  Chick(this.spec, this.position);
  final ChickLoadout spec;
  Offset position;
  ChickState state = ChickState.waiting;

  /// Waiting chicks keep their spot on screen (offset from the camera).
  Offset anchor = Offset.zero;

  /// 0..1 rescue gauge (kept while the craft is away).
  double rescue = 0;
  bool inReach = false, rescuedBefore = false;
  double hp = 1, maxHp = 1, skillClock = 0, hurtClock = 0;

  /// Fall-off animation: elapsed seconds, outward drift and spin.
  double fall = 0, spin = 0;
  Offset fallVelocity = Offset.zero;
  int get kind => spec.kind;
}

/// Frost left by the ice chick and eggs dropped by the bomb chick.
class ChickMark {
  ChickMark(this.at, this.life);
  final Offset at;
  double life;
}

/// v12.17 chick tail squad (user 2026-10-27). The run starts with no chicks:
/// every deployed card appears in turn, hanging from a cloud parachute and
/// waving an SOS flag. Flying near one (reach 110) draws a tether line and
/// fills a donut gauge in 1.5 s — leaving pauses the gauge and drops the
/// line. Rescued chicks join the end of a snake trail: each follows the
/// exact path the one ahead flew, so circling makes a ring. Their bodies
/// block enemy bullets; at zero HP a chick spins off with a cheep and a puff
/// of feathers, opens its parachute nearby and waits to be rescued again
/// (back at half HP). Each kind also has its own skill.
class ChickSquad {
  ChickSquad(this.roster);
  final List<ChickLoadout> roster;
  final List<Chick> chicks = [];

  /// Tail order (rescued chicks, front first).
  final List<Chick> tail = [];

  /// The craft's recent path, newest first (spaced about 3 px).
  final List<Offset> trail = [];
  final List<ChickMark> frost = [], eggs = [];

  /// Reflected and sniper shots fired this run (statistics/tests).
  int blocked = 0, reflected = 0;
  int released = 0;
  double clock = 0;

  /// Seconds before the first chick appears, then between chicks.
  static const firstAt = 10.0, every = 25.0;
  static const reach = 110.0, rescueSeconds = 1.5, spacing = 30.0;
  static const body = 13.0;

  /// XP bonus while a star chick flies in the tail.
  double get xpFactor => tail.any((c) => c.kind == ChickKind.star)
      ? 1.15 +
            .01 *
                tail
                    .where((c) => c.kind == ChickKind.star)
                    .map((c) => c.spec.rank)
                    .fold(0, math.max)
      : 1;
}

extension ChickSquadCombat on GameEngine {
  double _chickPower(Chick c) =>
      (1 + c.spec.level * .08 + c.spec.rank * .2) *
      (1 + c.spec.awakePower.clamp(0, .18));
  double _chickInterval(Chick c) => 1 - c.spec.awakeCooldown.clamp(0, .12);

  /// HP in bullets: five, more with level and rank; the shield chick has
  /// twice as much.
  double _chickMaxHp(ChickLoadout spec) =>
      (5 + spec.level * .25 + spec.rank) *
      (spec.kind == ChickKind.shield ? 2 : 1);

  void _updateChicks(double dt) {
    final s = squad;
    if (s.roster.isEmpty) return;
    s.clock += dt;
    _recordTrail();
    // a deployed card appears to be rescued
    while (s.released < s.roster.length &&
        s.clock >= ChickSquad.firstAt + s.released * ChickSquad.every) {
      final spec = s.roster[s.released++];
      final c = Chick(spec, position)
        ..maxHp = _chickMaxHp(spec)
        ..anchor = Offset(
          70 + random.nextDouble() * 280,
          viewportHeight * (.28 + random.nextDouble() * .3),
        );
      c.hp = c.maxHp;
      c.position = camera + c.anchor;
      s.chicks.add(c);
    }
    for (final c in s.chicks) {
      switch (c.state) {
        case ChickState.waiting:
          _waitForRescue(c, dt);
        case ChickState.falling:
          _fallOff(c, dt);
        case ChickState.tail:
          c.hurtClock = math.max(0, c.hurtClock - dt);
      }
    }
    _placeTail();
    for (final c in List.of(s.tail)) {
      _chickBlocks(c);
      if (c.state == ChickState.tail) _chickSkill(c, dt);
    }
    _chickMarks(dt);
  }

  /// Tests and developer battles: every deployed card joins the tail at once
  /// (at [at], default the craft), skipping the rescue.
  void seatChicks({Offset? at}) {
    final s = squad;
    while (s.released < s.roster.length) {
      final spec = s.roster[s.released++];
      final c = Chick(spec, at ?? position)
        ..maxHp = _chickMaxHp(spec)
        ..state = ChickState.tail
        ..rescuedBefore = true;
      c.hp = c.maxHp;
      s.chicks.add(c);
      s.tail.add(c);
    }
    s.clock = math.max(
      s.clock,
      ChickSquad.firstAt + s.roster.length * ChickSquad.every,
    );
  }

  void _recordTrail() {
    final t = squad.trail;
    if (t.isEmpty || (t.first - position).distance >= 3) {
      t.insert(0, position);
      final need = (squad.tail.length + 2) * ChickSquad.spacing / 3 + 20;
      while (t.length > math.max(40, need)) {
        t.removeLast();
      }
    }
  }

  /// Tail chick i sits (i+1) spacings back along the recorded path.
  void _placeTail() {
    final t = squad.trail;
    for (var i = 0; i < squad.tail.length; i++) {
      final want = (i + 1) * ChickSquad.spacing;
      var walked = 0.0;
      var at = t.isEmpty ? position : t.last;
      var prev = position;
      for (final p in t) {
        final step = (p - prev).distance;
        if (walked + step >= want && step > 0) {
          at = Offset.lerp(prev, p, (want - walked) / step)!;
          break;
        }
        walked += step;
        prev = p;
        at = p;
      }
      final c = squad.tail[i];
      c.position = Offset.lerp(c.position, at, .6)!;
    }
  }

  void _waitForRescue(Chick c, double dt) {
    // house stages: it hangs at its spot on screen (the camera only pans)
    if (screenMode) c.position = camera + c.anchor;
    c.inReach = (c.position - position).distance <= ChickSquad.reach;
    if (!c.inReach) return;
    c.rescue = math.min(1, c.rescue + dt / ChickSquad.rescueSeconds);
    if (c.rescue < 1) return;
    c
      ..state = ChickState.tail
      ..rescue = 0
      ..inReach = false
      ..hp = c.rescuedBefore ? c.maxHp * .5 : c.maxHp
      ..skillClock = .5;
    squad.tail.add(c);
    visuals.emit(CombatCueKind.heal, c.position, source: 'chick', radius: 34);
    pickupNotice = '${boss_catalog.petNames[c.kind].split(' · ').first} 구출!';
    noticeTime = 1.6;
    onEvent?.call('pet');
  }

  void _fallOff(Chick c, double dt) {
    c.fall += dt;
    c.spin += dt * 14;
    c.position += c.fallVelocity * dt;
    c.fallVelocity *= math.pow(.18, dt).toDouble();
    if (c.fall < 1.1) return;
    // parachute open: wait nearby on screen for the next rescue
    final local = c.position - camera;
    c
      ..state = ChickState.waiting
      ..fall = 0
      ..spin = 0
      ..rescue = 0
      ..rescuedBefore = true
      ..anchor = Offset(
        local.dx.clamp(50.0, 370.0),
        local.dy.clamp(viewportHeight * .2, viewportHeight * .75),
      );
  }

  void _chickHurt(Chick c, double amount) {
    c.hp -= amount;
    if (c.hp > 0) return;
    c.hp = 0;
    final i = squad.tail.indexOf(c);
    squad.tail.remove(c);
    final from = i <= 0 ? position : squad.tail[i - 1].position;
    var out = c.position - from;
    out = out.distance < 1 ? const Offset(1, 0) : out / out.distance;
    final side = Offset(-out.dy, out.dx) * (random.nextBool() ? 1 : -1);
    c
      ..state = ChickState.falling
      ..fall = 0
      ..fallVelocity = (out + side) * 220;
    visuals.emit(CombatCueKind.impact, c.position, source: 'chick', radius: 26);
    onEvent?.call('hit');
    if (c.kind == ChickKind.bomb) _chickBlast(c.position, c, 1.5);
  }

  /// Bodies block enemy bullets; enemies that ram a chick also hurt it.
  void _chickBlocks(Chick c) {
    if (c.state != ChickState.tail) return;
    final radius = ChickSquad.body * (c.kind == ChickKind.shield ? 1.4 : 1);
    for (var i = shots.length - 1; i >= 0; i--) {
      final s = shots[i];
      if (!s.hostile || !s.interceptable) continue;
      if ((s.position - c.position).distance > radius + s.radius) continue;
      shots.removeAt(i);
      squad.blocked++;
      if (c.kind == ChickKind.mirror) {
        // the mirror chick sends the bullet back at the nearest enemy
        final target = _nearest();
        final dir = target == null
            ? const Offset(0, -1)
            : _unit(target.position - c.position);
        shots.add(
          Shot(
            c.position,
            dir * 420,
            10 * _chickPower(c) * damageFactor,
            6,
            weapon: 'chick-mirror',
            radius: 5,
          ),
        );
        squad.reflected++;
        _chickHurt(c, .5);
      } else {
        _chickHurt(c, 1);
      }
      if (c.state != ChickState.tail) return;
    }
    if (c.hurtClock > 0) return;
    for (final e in enemies) {
      if (e.hp <= 0 || e.retired) continue;
      if ((e.position - c.position).distance < e.radius + radius) {
        c.hurtClock = .8;
        _chickHurt(c, 1);
        return;
      }
    }
  }

  void _chickSkill(Chick c, double dt) {
    c.skillClock -= dt;
    final power = _chickPower(c), every = _chickInterval(c);
    switch (c.kind) {
      case ChickKind.fire:
        if (c.skillClock > 0) return;
        c.skillClock = .9 * every;
        final target = _nearest();
        if (target == null) return;
        for (var i = 0; i < (c.spec.level >= 5 ? 2 : 1); i++) {
          shots.add(
            Shot(
              c.position + Offset(i * 8.0, 0),
              _unit(target.position - c.position) * 330,
              12 * power * damageFactor,
              6,
              weapon: 'pet',
            ),
          );
        }
        onEvent?.call('pet');
      case ChickKind.medic:
        if (c.skillClock > 0) return;
        c.skillClock = 10 * every;
        hp = math.min(maxHp, hp + maxHp * .04 * power);
        for (final o in squad.tail) {
          o.hp = math.min(o.maxHp, o.hp + 1);
        }
        visuals.emit(CombatCueKind.heal, position, source: 'chick', radius: 40);
        onEvent?.call('pet');
      case ChickKind.shield:
        if (c.skillClock > 0) return;
        c.skillClock = 3 * every;
        final before = shots.length;
        shots.removeWhere(
          (s) =>
              s.hostile &&
              s.interceptable &&
              (s.position - c.position).distance < 85 * power,
        );
        if (shots.length < before) {
          visuals.emit(
            CombatCueKind.shield,
            c.position,
            source: 'chick',
            radius: 60,
          );
        }
      case ChickKind.lightning:
        // a crackling line to the chick (or craft) ahead and the one behind
        if (c.skillClock > 0) return;
        c.skillClock = .3;
        for (final (from, to) in chickLinks(c)) {
          for (final e in enemies) {
            if (e.hp <= 0 || e.retired) continue;
            if (_segmentDistance(e.position, from, to) < e.radius + 8) {
              _hit(e, 8 * power * damageFactor, 'chick-zap');
            }
          }
        }
      case ChickKind.ice:
        if (c.skillClock > 0) return;
        c.skillClock = .15;
        squad.frost.add(ChickMark(c.position, 3));
        if (squad.frost.length > 48) squad.frost.removeAt(0);
      case ChickKind.bomb:
        if (c.skillClock > 0) return;
        c.skillClock = 6 * every;
        squad.eggs.add(ChickMark(c.position, .6));
      case ChickKind.sniper:
        if (c.skillClock > 0) return;
        c.skillClock = 4 * every;
        Foe? target;
        for (final e in enemies) {
          if (e.hp <= 0 || e.retired) continue;
          if (target == null || e.hp > target.hp) target = e;
        }
        if (target == null) return;
        shots.add(
          Shot(
            c.position,
            _unit(target.position - c.position) * 760,
            60 * power * damageFactor,
            6,
            weapon: 'chick-snipe',
            pierce: 6,
            radius: 4,
            life: 1.6,
          ),
        );
        onEvent?.call('pet');
      default:
      // the star chick's XP bonus is passive (ChickSquad.xpFactor)
    }
  }

  /// The lightning chick's links: to the one ahead and the one behind.
  List<(Offset, Offset)> chickLinks(Chick c) {
    final i = squad.tail.indexOf(c);
    if (i < 0) return const [];
    return [
      (i == 0 ? position : squad.tail[i - 1].position, c.position),
      if (i + 1 < squad.tail.length) (c.position, squad.tail[i + 1].position),
    ];
  }

  static double _segmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a, len = ab.distanceSquared;
    if (len == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  void _chickMarks(double dt) {
    final s = squad;
    for (final f in s.frost) {
      f.life -= dt;
    }
    s.frost.removeWhere((f) => f.life <= 0);
    if (s.frost.isNotEmpty) {
      for (final e in enemies) {
        if (e.hp <= 0 || e.retired) continue;
        if (s.frost.any((f) => (f.at - e.position).distance < e.radius + 22)) {
          e.status = 2;
          e.statusTime = math.max(e.statusTime, .6);
        }
      }
      for (final b in shots) {
        if (!b.hostile || b.velocity.distance < 60) continue;
        if (s.frost.any((f) => (f.at - b.position).distance < 24)) {
          b.velocity *= math.pow(.2, dt).toDouble();
        }
      }
    }
    for (final egg in List.of(s.eggs)) {
      egg.life -= dt;
      if (egg.life > 0) continue;
      s.eggs.remove(egg);
      final bomber = s.tail.firstWhere(
        (c) => c.kind == ChickKind.bomb,
        orElse: () => s.chicks.firstWhere((c) => c.kind == ChickKind.bomb),
      );
      _chickBlast(egg.at, bomber, 1);
    }
  }

  void _chickBlast(Offset at, Chick c, double scale) {
    final power = _chickPower(c);
    for (final e in enemies) {
      if (e.hp <= 0 || e.retired) continue;
      if ((e.position - at).distance < 70 * scale + e.radius) {
        _hit(e, 40 * power * scale * damageFactor, 'chick-egg');
      }
    }
    visuals.emit(
      CombatCueKind.explosion,
      at,
      source: 'chick',
      radius: 70 * scale,
    );
  }
}
