part of 'engine.dart';

/// v12 "exaggerated" survivor weapons, picked from level-up cards on top of
/// the airframe's own guns (user feedback 2026-10-24: Survivor.io-style
/// hammers, slow giant shells, a laser that beats on one target, boomerang
/// crescents, an edge-bouncing ball). Everything is drawn as light — see
/// [GlowShots] — never as bullet pictures. Each one grows by enhance /
/// evolve / ultimate steps (weapon_growth.dart). The same effect list also
/// carries the weapon ultimates of the main gun and the mounted parts.
class PawFx {
  PawFx(this.kind, this.position, {this.velocity = Offset.zero});
  final String kind;
  Offset position, velocity;
  Offset origin = Offset.zero, start = Offset.zero;
  double age = 0, life = 1, radius = 10, damage = 0, spin = 0, clock = 0;
  String source = '';
  Foe? target;
  List<Offset> chain = const [];
  final Map<Foe, double> hitClock = {};
  bool returning = false;
}

extension PawWeapons on GameEngine {
  static const maxPawWeapons = 4;

  int pawLevel(String id) => upgrades[id] ?? 0;
  Iterable<String> get ownedPaws =>
      pawSkills.map((w) => w.id).where((id) => pawLevel(id) > 0);

  Rect get viewRect => camera & Size(420, viewportHeight);

  bool _pawCanHit(Foe e) =>
      e.hp > 0 &&
      !e.retired &&
      e.plane == AircraftTarget.air &&
      viewRect.deflate(4).contains(e.position);

  /// Damage scale of a paw weapon: the first enhance step, plus ultimates.
  double _pawPower(String id, {double first = 1.25}) =>
      damageFactor * gUp(id, 1, first) * (ult(id) ? 1.6 : 1);

  void _pawReady(
    String id,
    double step,
    double interval,
    void Function() fire,
  ) {
    final t = (_pawTimers[id] ?? .4) - step;
    if (t > 0) {
      _pawTimers[id] = t;
      return;
    }
    _pawTimers[id] = interval * cooldownFactor;
    fire();
  }

  bool _hasFx(String kind, [String source = '']) => pawFx.any(
    (f) => f.kind == kind && (source.isEmpty || f.source == source),
  );

  void updatePawWeapons(double step) {
    for (final id in ownedPaws) {
      switch (id) {
        case 'paw:orbit':
          _orbitPaws();
          if (ult(id)) {
            _pawReady('giantpaw', step, 6, _giantPaw);
          }
        case 'paw:yarn':
          _pawReady(id, step, 3.6 * (enh(id) >= 2 ? .75 : 1), _launchYarn);
          if (ult(id)) _pawReady('yarnstorm', step, 8, _yarnStorm);
        case 'paw:laser':
          if (ult(id)) {
            if (!_hasFx('satellite')) {
              pawFx.removeWhere((f) => f.kind == 'laser');
              pawFx.add(
                PawFx('satellite', viewRect.topCenter + const Offset(0, 60))
                  ..life = double.infinity,
              );
            }
          } else {
            _pawReady(id, step, 5.4 * (enh(id) >= 3 ? .7 : 1), _fireLaser);
          }
        case 'paw:crescent':
          if (ult(id)) {
            if (!_hasFx('typhoon')) {
              for (var i = 0; i < 3; i++) {
                pawFx.add(
                  PawFx('typhoon', viewRect.center)
                    ..spin = i * math.pi * 2 / 3
                    ..life = double.infinity
                    ..radius = 34 * areaFactor,
                );
              }
            }
          } else {
            _pawReady(id, step, 2.5, _throwCrescents);
          }
        case 'paw:bounce':
          if (ult(id)) {
            if (!_hasFx('pinball')) {
              pawFx.add(
                PawFx(
                    'pinball',
                    position + const Offset(0, -60),
                    velocity: const Offset(250, -260),
                  )
                  ..life = double.infinity
                  ..radius = 34 * areaFactor,
              );
            }
          } else {
            _pawReady(id, step, 4.6, _launchBall);
          }
        case 'paw:zap':
          _pawReady(id, step, 1.9 * (enh(id) >= 2 ? .7 : 1), _zap);
          if (ult(id)) {
            if (!_hasFx('cloud')) {
              pawFx.add(PawFx('cloud', position)..life = double.infinity);
            }
          }
      }
    }
    for (final fx in pawFx.toList()) {
      if (fx.age < 0) {
        fx.age += step;
        continue;
      }
      fx.age += step;
      fx.hitClock.updateAll((_, v) => v - step);
      switch (fx.kind) {
        case 'orbit':
          _moveOrbitPaw(fx, step);
        case 'giantpaw':
          _stepGiantPaw(fx);
        case 'yarn':
          _moveYarn(fx, step);
        case 'yarnstorm':
          _moveYarnStorm(fx, step);
        case 'net':
        case 'goo':
          _slowInside(fx);
        case 'laser':
          _burnLaser(fx, step);
        case 'satellite':
          _stepSatellite(fx, step);
        case 'crescent':
          _moveCrescent(fx, step);
        case 'typhoon':
          _moveTyphoon(fx, step);
        case 'ball':
          _moveBall(fx, step);
        case 'pinball':
          _movePinball(fx, step);
        case 'cloud':
          _stepCloud(fx, step);
        default:
          stepGrowthFx(fx, step);
      }
    }
    pawFx.removeWhere((fx) => fx.age >= fx.life);
  }

  void _touch(PawFx fx, double cooldown, {double push = 0, String? source}) {
    for (final e in enemies) {
      if (!_pawCanHit(e) || (fx.hitClock[e] ?? 0) > 0) continue;
      if ((e.position - fx.position).distance > fx.radius + e.radius) continue;
      fx.hitClock[e] = cooldown;
      _hit(
        e,
        fx.damage,
        source ?? (fx.source.isEmpty ? 'paw:${fx.kind}' : fx.source),
      );
      if (push > 0) _knock(e, fx.position, push);
    }
  }

  void _knock(Foe e, Offset from, double push) {
    if (e.kind == 3 || e.path != null || e.anchor != null) return;
    e.position += _unit(e.position - from) * push;
  }

  /// Area damage with a ring, shared by yarn, shells, paws and missiles.
  void growthBlast(Offset at, double damage, double radius, String source) {
    final r = radius * areaFactor;
    for (final e in enemies) {
      if (!_pawCanHit(e)) continue;
      if ((e.position - at).distance < r + e.radius) _hit(e, damage, source);
    }
    pawFx.add(
      PawFx('blast', at)
        ..returning = true
        ..radius = r
        ..life = .42,
    );
    _burst(at, 1, 10);
    onEvent?.call('explosion');
  }

  void _slowInside(PawFx fx) {
    for (final e in enemies) {
      if (e.kind == 3 || !_pawCanHit(e)) continue;
      if ((e.position - fx.position).distance < fx.radius + e.radius) {
        e.status = 2;
        e.statusTime = math.max(e.statusTime, .4);
      }
    }
  }

  // ── 꾹꾹 냥펀치 ──────────────────────────────────────────────────────
  void _orbitPaws() {
    const id = 'paw:orbit';
    final v = evo(id);
    final count = ult(id) || v >= 3
        ? 5
        : v >= 1
        ? 3
        : 2;
    final paws = pawFx.where((f) => f.kind == 'orbit').toList();
    if (paws.length == count) return;
    pawFx.removeWhere((f) => f.kind == 'orbit');
    for (var i = 0; i < count; i++) {
      pawFx.add(
        PawFx('orbit', position)
          ..spin = i / count * math.pi * 2
          ..life = double.infinity,
      );
    }
  }

  void _moveOrbitPaw(PawFx fx, double step) {
    const id = 'paw:orbit';
    fx.radius = 15 * gUp(id, 3, 1.3) * (ult(id) ? 1.3 : 1);
    fx.spin += step * 3.2 * gUp(id, 2, 1.3);
    // 꾹꾹: the paws knead outward in a wide punch, then come back
    final period = enh(id) >= 2 ? 1.8 : 2.4;
    final beat = (combatTime % period) / .7;
    final punch = beat < 1 ? math.sin(beat * math.pi) : 0.0;
    final reach = 66.0 * gUp(id, 3, 1.3) * areaFactor * (1 + punch * 1.9);
    fx.position =
        position + Offset(math.cos(fx.spin), math.sin(fx.spin)) * reach;
    fx.damage = 7 * _pawPower(id);
    _touch(fx, .45, push: gEvo(id, 2) ? 46 : 26);
    // the punch's apex sends out a small shockwave
    if (gEvo(id, 3)) {
      final apex = beat >= .5 && beat < 1;
      if (apex && !fx.returning) {
        growthBlast(fx.position, fx.damage * .8, 40, id);
      }
      fx.returning = apex;
    }
    // a paw swats bullets: evolved paws bat them back at the enemy
    for (final s in shots.toList()) {
      if (s.kind != 4 ||
          (s.position - fx.position).distance > fx.radius + s.radius + 2) {
        continue;
      }
      s.life = 0;
      if (gEvo(id, 2)) {
        _deferredShots.add(
          Shot(
            s.position,
            _unit(s.position - position) * 320,
            fx.damage,
            0,
            weapon: id,
            life: 1.2,
            radius: 4,
          ),
        );
      }
    }
  }

  void _giantPaw() {
    final target = _crowdCentre();
    final at = target?.position ?? position + const Offset(0, -240);
    pawFx.add(
      PawFx('giantpaw', at)
        ..life = .95
        ..radius = 130
        ..damage = 7 * _pawPower('paw:orbit') * 9,
    );
  }

  void _stepGiantPaw(PawFx fx) {
    if (fx.age >= .45 && !fx.returning) {
      fx.returning = true;
      growthBlast(fx.position, fx.damage, fx.radius, 'paw:orbit');
      for (final e in enemies) {
        if ((e.position - fx.position).distance < fx.radius * 1.3) {
          _knock(e, fx.position, 60);
        }
      }
    }
  }

  // ── 털실 폭탄 ────────────────────────────────────────────────────────
  Foe? _crowdCentre() {
    Foe? best;
    var score = -1;
    for (final e in enemies) {
      if (!_pawCanHit(e) || e.position.dy > position.dy + 40) continue;
      final n = enemies
          .where((o) => o.hp > 0 && (o.position - e.position).distance < 100)
          .length;
      if (n > score) {
        score = n;
        best = e;
      }
    }
    return best;
  }

  void _launchYarn() {
    const id = 'paw:yarn';
    final target = _crowdCentre();
    final aim = target?.position ?? position + const Offset(0, -260);
    for (var i = 0; i < (gEvo(id, 1) ? 2 : 1); i++) {
      final offset = Offset(i == 0 ? 0 : 70, i == 0 ? 0 : 30);
      pawFx.add(
        PawFx('yarn', position + const Offset(0, -30))
          ..origin = aim + offset
          ..velocity = _unit(aim + offset - position) * 150
          ..life = 4
          ..radius = 16
          ..damage = 26 * _pawPower(id, first: 1.3),
      );
    }
    onEvent?.call('missile');
  }

  void _moveYarn(PawFx fx, double step) {
    const id = 'paw:yarn';
    fx.position += fx.velocity * step;
    fx.spin += step * 5;
    final hit = enemies.any(
      (e) =>
          _pawCanHit(e) &&
          (e.position - fx.position).distance < e.radius + fx.radius,
    );
    if (hit ||
        (fx.position - fx.origin).distance < 12 ||
        fx.age > 3.2 ||
        !viewRect.contains(fx.position)) {
      final radius = 64 * gUp(id, 3, 1.35);
      growthBlast(fx.position, fx.damage, radius, id);
      if (gEvo(id, 2)) {
        pawFx.add(
          PawFx('net', fx.position)
            ..radius = radius * .8
            ..life = 2,
        );
      }
      if (gEvo(id, 3)) {
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + .6;
          growthBlast(
            fx.position + Offset(math.cos(a), math.sin(a)) * 80,
            fx.damage * .5,
            44,
            id,
          );
        }
      }
      fx.age = fx.life;
    }
  }

  void _yarnStorm() {
    final a = -math.pi / 2 + (random.nextDouble() - .5) * 1.4;
    pawFx.add(
      PawFx(
          'yarnstorm',
          position + const Offset(0, -60),
          velocity: Offset(math.cos(a), math.sin(a)) * 260,
        )
        ..life = 6
        ..radius = 30 * areaFactor
        ..damage = 26 * _pawPower('paw:yarn', first: 1.3),
    );
  }

  void _moveYarnStorm(PawFx fx, double step) {
    _bounceInView(fx, step);
    fx.spin += step * 6;
    fx.clock -= step;
    if (fx.clock <= 0) {
      fx.clock = .45;
      growthBlast(fx.position, fx.damage * .8, 70, 'paw:yarn');
      pawFx.add(
        PawFx('net', fx.position)
          ..radius = 52
          ..life = 1.6,
      );
    }
  }

  // ── 레이저 포인터 ────────────────────────────────────────────────────
  Foe? _strongest({Foe? except}) {
    final boss = this.boss;
    if (boss != null && boss != except && boss.hp > 0 && _pawCanHit(boss)) {
      return boss;
    }
    Foe? best;
    for (final e in enemies) {
      if (!_pawCanHit(e) || e == except) continue;
      if (best == null || e.hp > best.hp) best = e;
    }
    return best;
  }

  void _fireLaser() {
    const id = 'paw:laser';
    final first = _strongest();
    if (first == null) {
      _pawTimers[id] = .5;
      return;
    }
    pawFx.removeWhere((f) => f.kind == 'laser');
    final second = gEvo(id, 2) ? _strongest(except: first) : null;
    final targets = [first, if (second != null) second];
    for (final t in targets) {
      pawFx.add(
        PawFx('laser', position)
          ..target = t
          ..life = 1.5 * gUp(id, 2, 1.4)
          ..radius = 6
          ..damage = 34 * _pawPower(id, first: 1.3),
      );
    }
    onEvent?.call('laser');
  }

  void _burnLaser(PawFx fx, double step) {
    const id = 'paw:laser';
    fx.position = position + const Offset(0, -34);
    var target = fx.target;
    if (target == null || !_pawCanHit(target)) {
      // evolve 1: hop straight to the next target instead of stopping
      target = fx.target = gEvo(id, 1) ? _strongest() : null;
      if (target == null) {
        fx.age = fx.life;
        return;
      }
    }
    fx.origin = target.position;
    _hit(target, fx.damage * step, id);
    if (gEvo(id, 3)) {
      for (final e in enemies) {
        if (e != target &&
            _pawCanHit(e) &&
            (e.position - target.position).distance < 44 + e.radius) {
          _hit(e, fx.damage * .4 * step, id);
        }
      }
    }
  }

  void _stepSatellite(PawFx fx, double step) {
    const id = 'paw:laser';
    final target = _strongest();
    final home = Offset(
      (target?.position.dx ?? position.dx).clamp(
        viewRect.left + 40,
        viewRect.right - 40,
      ),
      viewRect.top + 60,
    );
    final d = home - fx.position;
    fx.position += _unit(d) * math.min(d.distance, 160 * step);
    fx.target = target;
    if (target == null) return;
    fx.origin = target.position;
    final dps = 34 * _pawPower(id, first: 1.3) * 2.5;
    _hit(target, dps * step, id);
    // the beam burns everything along its path too
    final seg = target.position - fx.position;
    final len = seg.distance;
    if (len < 1) return;
    final dir = seg / len;
    for (final e in enemies) {
      if (e == target || !_pawCanHit(e)) continue;
      final rel = e.position - fx.position;
      final along = rel.dx * dir.dx + rel.dy * dir.dy;
      if (along < 0 || along > len) continue;
      final off = (rel - dir * along).distance;
      if (off < 18 + e.radius) _hit(e, dps * .5 * step, id);
    }
  }

  // ── 발톱 반달 ────────────────────────────────────────────────────────
  void _throwCrescents() {
    const id = 'paw:crescent';
    final count = gEvo(id, 1) ? 2 : 1;
    for (var i = 0; i < count; i++) {
      final spread = count == 1 ? 0.0 : (i == 0 ? -.45 : .45);
      final dir = Offset(math.sin(spread), -math.cos(spread));
      pawFx.add(
        PawFx('crescent', position, velocity: dir * 440 * gUp(id, 2, 1.3))
          ..life = 3
          ..radius = 19 * gUp(id, 3, 1.35) * areaFactor
          ..damage = 12 * _pawPower(id),
      );
    }
  }

  void _moveCrescent(PawFx fx, double step) {
    const id = 'paw:crescent';
    fx.spin += step * 14;
    if (fx.clock > 0) {
      // a split-off shard flies out and fades
      fx.position += fx.velocity * step;
      _touch(fx, 99, source: id);
      return;
    }
    if (!fx.returning) {
      fx.position += fx.velocity * step;
      fx.velocity *= math.pow(.18, step).toDouble();
      if (fx.velocity.distance < 60) {
        fx.returning = true;
        fx.hitClock.clear();
        if (gEvo(id, 2)) fx.damage *= 2;
      }
    } else {
      final home = position - fx.position;
      fx.position += _unit(home) * math.min(home.distance, 470 * step);
      if (home.distance < 20) fx.age = fx.life;
    }
    final before = enemies.where((e) => e.hp > 0).toSet();
    _touch(fx, .3, source: id);
    if (gEvo(id, 3)) {
      for (final e in before) {
        if (e.hp > 0) continue;
        for (final side in [-1.0, 1.0]) {
          pawFx.add(
            PawFx('crescent', e.position, velocity: Offset(side * 300, -200))
              ..life = .9
              ..clock = 1
              ..radius = fx.radius * .6
              ..damage = fx.damage * .5,
          );
        }
      }
    }
  }

  void _moveTyphoon(PawFx fx, double step) {
    const id = 'paw:crescent';
    fx.spin += step * 1.7;
    final c = viewRect.center + const Offset(0, -40);
    final r = 140 + math.sin(combatTime * .9 + fx.spin) * 40;
    fx.position = c + Offset(math.cos(fx.spin), math.sin(fx.spin)) * r;
    fx.damage = 12 * _pawPower(id) * 1.4;
    _touch(fx, .35, source: id);
    shots.removeWhere(
      (s) =>
          s.hostile &&
          s.kind != 23 &&
          (s.position - fx.position).distance < fx.radius + s.radius,
    );
  }

  // ── 통통 공 ──────────────────────────────────────────────────────────
  void _launchBall() {
    const id = 'paw:bounce';
    for (var i = 0; i < (gEvo(id, 1) ? 2 : 1); i++) {
      final a = -math.pi / 2 + (random.nextDouble() - .5) * 1.6;
      pawFx.add(
        PawFx(
            'ball',
            position + const Offset(0, -24),
            velocity: Offset(math.cos(a), math.sin(a)) * 330 * gUp(id, 3, 1.3),
          )
          ..life = 5.5 * gUp(id, 3, 1.3)
          ..radius = 17 * gUp(id, 2, 1.3) * areaFactor
          ..damage = 10 * _pawPower(id),
      );
    }
  }

  /// Moves [fx] and bounces it off the screen edges; true on a bounce.
  bool _bounceInView(PawFx fx, double step) {
    fx.position += fx.velocity * step;
    final r = viewRect.deflate(fx.radius);
    var v = fx.velocity;
    var bounced = false;
    if (fx.position.dx < r.left || fx.position.dx > r.right) {
      v = Offset(-v.dx, v.dy);
      fx.position = Offset(
        fx.position.dx.clamp(r.left, r.right),
        fx.position.dy,
      );
      bounced = true;
    }
    if (fx.position.dy < r.top || fx.position.dy > r.bottom) {
      v = Offset(v.dx, -v.dy);
      fx.position = Offset(
        fx.position.dx,
        fx.position.dy.clamp(r.top, r.bottom),
      );
      bounced = true;
    }
    fx.velocity = v;
    if (bounced) fx.hitClock.clear();
    return bounced;
  }

  void _moveBall(PawFx fx, double step) {
    const id = 'paw:bounce';
    fx.spin += step * 6;
    if (_bounceInView(fx, step) && !fx.returning) {
      if (gEvo(id, 2) && fx.clock < 6) {
        fx.clock++;
        fx.radius *= 1.1;
        fx.damage *= 1.1;
      }
      if (gEvo(id, 3)) {
        pawFx.add(
          PawFx(
              'ball',
              fx.position,
              velocity: Offset(-fx.velocity.dy, fx.velocity.dx) * .8,
            )
            ..returning = true
            ..life = 1.6
            ..radius = fx.radius * .5
            ..damage = fx.damage * .5,
        );
      }
    }
    _touch(fx, .35, source: id);
  }

  void _movePinball(PawFx fx, double step) {
    const id = 'paw:bounce';
    fx.spin += step * 7;
    _bounceInView(fx, step);
    fx.damage = 10 * _pawPower(id) * 2;
    for (final e in enemies) {
      if (!_pawCanHit(e) || (fx.hitClock[e] ?? 0) > 0) continue;
      if ((e.position - fx.position).distance > fx.radius + e.radius) continue;
      fx.hitClock[e] = .3;
      _hit(e, fx.damage, id);
      _knock(e, fx.position, 50);
      // bumper: the struck enemy slams into its neighbours
      for (final o in enemies) {
        if (o != e &&
            _pawCanHit(o) &&
            (o.position - e.position).distance < 70 + o.radius) {
          _hit(o, fx.damage * .5, id);
        }
      }
      pawFx.add(
        PawFx('blast', e.position)
          ..returning = true
          ..radius = 60
          ..life = .3,
      );
    }
  }

  // ── 수염 번개 ────────────────────────────────────────────────────────
  void _zap() {
    const id = 'paw:zap';
    var fired = _zapFrom(position + const Offset(0, -20), {});
    if (gEvo(id, 3))
      fired = _zapFrom(position + const Offset(0, -20), {}) || fired;
    if (!fired) _pawTimers[id] = .3;
  }

  bool _zapFrom(Offset from, Set<Foe> hit, {int? linkCount}) {
    const id = 'paw:zap';
    final links = linkCount ?? 2 + (gEvo(id, 1) ? 2 : 0);
    var at = from;
    final points = <Offset>[from];
    for (var i = 0; i <= links; i++) {
      Foe? next;
      var best = i == 0 ? 330.0 : 160.0 * gUp(id, 3, 1.4);
      for (final e in enemies) {
        if (!_pawCanHit(e) || hit.contains(e)) continue;
        final d = (e.position - at).distance;
        if (d < best) {
          best = d;
          next = e;
        }
      }
      if (next == null) break;
      hit.add(next);
      points.add(next.position);
      _hit(next, 14 * _pawPower(id) * (i == 0 ? 1.3 : 1), id);
      if (gEvo(id, 2) && next.kind != 3) {
        next.status = 2;
        next.statusTime = math.max(next.statusTime, 1.2);
      }
      at = next.position;
    }
    if (points.length < 2) return false;
    pawFx.add(
      PawFx('zap', from)
        ..chain = points
        ..life = .22
        ..spin = random.nextDouble() * 1000,
    );
    onEvent?.call('lightning');
    return true;
  }

  void _stepCloud(PawFx fx, double step) {
    final home = position + const Offset(0, -96);
    fx.position = Offset.lerp(fx.position, home, math.min(1, step * 4))!;
    fx.clock -= step;
    if (fx.clock > 0) return;
    fx.clock = 2;
    final targets = enemies.where(_pawCanHit).toList()..shuffle(random);
    for (final e in targets.take(5)) {
      // a bolt drops from the sky onto the enemy, then chains on
      final sky = Offset(e.position.dx, viewRect.top);
      pawFx.add(
        PawFx('zap', sky)
          ..chain = [sky, e.position]
          ..life = .3
          ..spin = random.nextDouble() * 1000,
      );
      _hit(e, 14 * _pawPower('paw:zap') * 2, 'paw:zap');
      _zapFrom(e.position, {e}, linkCount: 3);
    }
  }
}
