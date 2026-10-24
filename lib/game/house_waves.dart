part of 'engine.dart';

/// v12 house stages: a classic vertical shooter screen.
///
/// The camera no longer follows the cat around a big arena. It is fixed on
/// one portrait screen while the house map scrolls underneath; the cat is
/// kept inside that screen. Enemies arrive as readable formation waves from
/// the top and fly scripted paths (V, snake, sweep, circle, rain, hover),
/// shoot while they cross, then leave — instead of an endless swarm closing
/// in from every side. At most [screenEnemyCap] are on screen at once.
class WavePath {
  const WavePath(this.at, this.duration, {this.delay = 0});

  /// Screen-relative position (x 0..420, y 0..viewport height) at time t.
  final Offset Function(double t) at;
  final double duration;
  final double delay;
}

enum WaveKind { vee, snake, sweep, circle, rain, hover, dive, rear }

/// Extra field beyond each side of the 420 view; the camera pans into it as
/// the cat nears an edge (classic vertical-shooter side scroll).
const sideReach = 56.0;
const _panHalf = 210 + sideReach - 26;

extension HouseWaves on GameEngine {
  bool get screenMode => unifiedModules && !legacyArena;
  static const screenEnemyCap = 32;

  /// Fixed screen origin in world space: the cat starts in the lower third.
  Offset get screenOrigin => Offset(690, 1200 - viewportHeight * .74);
  Rect get screenRect => screenOrigin & Size(420, viewportHeight);

  /// Street scroll in px (the neighbourhood moves down under the cat).
  double get mapScroll => elapsed * 34;

  /// The whole flyable field: the view plus [sideReach] on each side.
  Rect get fieldRect => Rect.fromLTRB(
    screenOrigin.dx - sideReach,
    screenOrigin.dy,
    screenOrigin.dx + 420 + sideReach,
    screenOrigin.dy + viewportHeight,
  );

  /// Horizontal camera pan, ±[sideReach] at the field edges.
  double get screenPan =>
      ((position.dx - (screenOrigin.dx + 210)) * sideReach / _panHalf).clamp(
        -sideReach,
        sideReach,
      );

  void keepOnScreen() {
    final r = fieldRect.deflate(26);
    position = Offset(
      position.dx.clamp(r.left, r.right),
      position.dy.clamp(r.top + 40, r.bottom),
    );
  }

  /// [point] kept inside the flyable field.
  Offset clampToField(Offset point) {
    final r = fieldRect.deflate(26);
    return Offset(
      point.dx.clamp(r.left, r.right),
      point.dy.clamp(r.top + 40, r.bottom),
    );
  }

  /// The field point that ends up under [view] (420-wide view units) once
  /// the camera has panned: the cat settles exactly under a following finger.
  Offset screenToField(Offset view) {
    const k = sideReach / _panHalf;
    final o = screenOrigin, centre = o.dx + 210;
    final r = fieldRect.deflate(26);
    return Offset(
      ((view.dx + o.dx - centre * k) / (1 - k)).clamp(r.left, r.right),
      (o.dy + view.dy).clamp(r.top + 40, r.bottom),
    );
  }

  /// 0..1 veil of passing clouds that hides the street/house swap before a
  /// boss (and back to the streets after one).
  double get cloudCover {
    if (!screenMode) return 0;
    double veil(double u) => u < .4
        ? _smooth(u / .4)
        : u < .7
        ? 1
        : _smooth((1 - u) / .3);
    if (_cloudOut > 0) return veil(1 - _cloudOut / 2.6);
    if (!bossIncoming) return 0;
    return veil(1 - ((nextBossAt - elapsed) / 3).clamp(0.0, 1.0));
  }

  void updateHouseMap(double dt) {
    if (!screenMode) return;
    // a restored checkpoint mid-boss fight is already on the boss map
    if (boss != null && _cloudOut <= 0) houseMapShown = true;
    if (_cloudOut > 0) {
      _cloudOut = math.max(0, _cloudOut - dt);
      if (_cloudOut < 1.3) houseMapShown = false;
      return;
    }
    if (bossIncoming && !houseMapShown && nextBossAt - elapsed <= 1.5) {
      // Under the full veil: the boss map takes over and the leftover
      // formation with its shots is swept away.
      houseMapShown = true;
      for (final e in enemies) {
        if (e.kind != 3) e.retired = true;
      }
      shots.removeWhere((s) => s.hostile);
      return;
    }
    if (houseMapShown &&
        boss == null &&
        !bossIncoming &&
        !resolvingBoss &&
        !_bossDefeated &&
        elapsed < duration &&
        _bossWave < requiredBosses) {
      _cloudOut = 2.6; // back to the streets for the next leg
    }
  }

  int get _waveAlive => enemies
      .where((e) => e.hp > 0 && !e.retired && e.waveId == _waveId)
      .length;

  void directWaves(double dt) {
    if (bossIncoming || elapsed >= duration) return;
    _waveGap -= dt;
    _waveTimer += dt;
    final alive = enemies.where((e) => e.hp > 0 && !e.retired).length;
    // Waves overlap a little so the screen stays busy (about 20-30 planes),
    // but every sixth wave is followed by a short breather.
    final ready =
        _waveGap <= 0 &&
        alive < screenEnemyCap - 8 &&
        (_waveAlive <= 3 || _waveTimer > 5.2);
    if (!ready) return;
    _waveId++;
    _waveTimer = 0;
    _waveGap = _waveId % 6 == 0 ? 3.2 : .7 + random.nextDouble() * .6;
    waveNoticeTime = 0;
    _spawnWave(_pickWave());
  }

  WaveKind _pickWave() {
    // A readable rotation with a dive or a heavy hover every few waves;
    // later houses lean on harder shapes.
    const opening = [WaveKind.vee, WaveKind.sweep, WaveKind.snake];
    if (_waveId <= opening.length) return opening[_waveId - 1];
    if (_waveId % 5 == 0) return WaveKind.hover;
    // some formations sneak in from behind the cat
    if (_waveId % 7 == 3) return WaveKind.rear;
    if (_waveId % 4 == 0) return WaveKind.dive;
    final pool = [
      WaveKind.vee,
      WaveKind.snake,
      WaveKind.sweep,
      WaveKind.rain,
      if (stage.sector >= 2) WaveKind.circle,
      if (_waveId > 8) WaveKind.rear,
    ];
    return pool[random.nextInt(pool.length)];
  }

  void _spawnWave(WaveKind kind) {
    final h = viewportHeight;
    final depth = stage.sector + worldIndex * 2;
    int n(int base) => (base + 2 + depth ~/ 3).clamp(base, base + 6);
    final paths = <(content.EnemyRole, WavePath)>[];
    switch (kind) {
      case WaveKind.vee:
        final count = n(5);
        final c = (count - 1) / 2;
        for (var i = 0; i < count; i++) {
          final off = i - c;
          final x = 210 + off * 46;
          final hold = h * .2 + off.abs() * 26;
          paths.add((
            i == c.round()
                ? content.EnemyRole.spitter
                : content.EnemyRole.scout,
            WavePath((t) {
              if (t < 1.8) {
                final k = _easeOut(t / 1.8);
                return Offset(x, -40 + (hold + 40) * k);
              }
              if (t < 6.5) {
                return Offset(x + math.sin((t - 1.8) * 1.4) * 14, hold);
              }
              final k = (t - 6.5) / 1.8;
              return Offset(x + off * 120 * k, hold - (hold + 60) * k);
            }, 8.3),
          ));
        }
      case WaveKind.snake:
        final count = n(6);
        final fromLeft = random.nextBool();
        for (var i = 0; i < count; i++) {
          paths.add((
            content.EnemyRole.weaver,
            WavePath(
              (t) {
                final u = t / 7.0;
                final x = fromLeft ? -40 + u * 500 : 460 - u * 500;
                final y =
                    h * .12 +
                    math.sin(u * math.pi * 2.2) * h * .09 +
                    u * h * .18;
                return Offset(x, y);
              },
              7.0,
              delay: i * .38,
            ),
          ));
        }
      case WaveKind.sweep:
        final count = n(5);
        for (var row = 0; row < 2; row++) {
          final fromLeft = row.isEven;
          for (var i = 0; i < (count / 2).ceil(); i++) {
            paths.add((
              row == 0 ? content.EnemyRole.lancer : content.EnemyRole.scout,
              WavePath(
                (t) {
                  final u = t / 5.5;
                  final x = fromLeft ? -40 + u * 500 : 460 - u * 500;
                  return Offset(x, h * (.14 + row * .1) + math.sin(t * 3) * 8);
                },
                5.5,
                delay: i * .45 + row * .9,
              ),
            ));
          }
        }
      case WaveKind.circle:
        final count = n(6);
        final centre = Offset(210, h * .3);
        for (var i = 0; i < count; i++) {
          final phase0 = i / count * math.pi * 2;
          paths.add((
            content.EnemyRole.orbiter,
            WavePath((t) {
              if (t < 1.5) {
                final k = _easeOut(t / 1.5);
                final end =
                    centre + Offset(math.cos(phase0), math.sin(phase0)) * 110;
                return Offset.lerp(Offset(210, -50), end, k)!;
              }
              if (t < 8) {
                final a = phase0 + (t - 1.5) * 1.1;
                return centre + Offset(math.cos(a), math.sin(a)) * 110;
              }
              final a = phase0 + 6.5 * 1.1;
              final from = centre + Offset(math.cos(a), math.sin(a)) * 110;
              return from + Offset(0, -(t - 8) * 260);
            }, 9.5),
          ));
        }
      case WaveKind.rain:
        final count = n(7);
        for (var i = 0; i < count; i++) {
          final x = 40 + random.nextDouble() * 340;
          paths.add((
            content.EnemyRole.scout,
            WavePath(
              (t) => Offset(x, -40 + t * 150),
              (h + 100) / 150,
              delay: i * .42,
            ),
          ));
        }
      case WaveKind.hover:
        // A mid-boss: one big elite gunship weaving a figure-eight with two
        // escorts. It cycles four bullet patterns (see [eliteAttack]).
        paths.add((
          content.EnemyRole.bulwark,
          WavePath((t) {
            if (t < 2.4) {
              return Offset(210, -70 + (h * .2 + 70) * _easeOut(t / 2.4));
            }
            if (t < 26) {
              final u = t - 2.4;
              return Offset(
                210 + math.sin(u * .55) * 120,
                h * .2 + math.sin(u * 1.1) * h * .05,
              );
            }
            return Offset(210, h * .2 - (t - 26) * 120);
          }, 28),
        ));
        for (final side in [-1.0, 1.0]) {
          paths.add((
            content.EnemyRole.miner,
            WavePath((t) {
              final x = 210 + side * 150;
              if (t < 2.4) {
                return Offset(x, -50 + (h * .3 + 50) * _easeOut(t / 2.4));
              }
              if (t < 14) {
                return Offset(x + math.sin((t - 2.4) * .8) * 30, h * .3);
              }
              return Offset(x, h * .3 - (t - 14) * 120);
            }, 17),
          ));
        }
      case WaveKind.rear:
        final count = n(3).clamp(3, 6);
        final fromLeft = random.nextBool();
        for (var i = 0; i < count; i++) {
          final x = fromLeft ? 46.0 + i * 26 : 374.0 - i * 26;
          final top = h * (.32 + i * .02);
          paths.add((
            content.EnemyRole.lancer,
            WavePath(
              (t) {
                if (t < 2.4) {
                  return Offset(x, h + 40 - (h + 40 - top) * _easeOut(t / 2.4));
                }
                final k = (t - 2.4) / 2.6;
                return Offset(x + (210 - x) * .7 * k, top - (top + 70) * k * k);
              },
              5.0,
              delay: i * .32,
            ),
          ));
        }
        pickupNotice = '후방 접근!';
        noticeTime = 1.6;
        onEvent?.call('warning');
      case WaveKind.dive:
        final count = math.min(6, 3 + depth ~/ 4);
        for (var i = 0; i < count; i++) {
          final at = screenOrigin + Offset(70.0 + i * (280 / count), -40);
          final foe = _createEnemy(at, content.EnemyRole.kamikaze)
            ..hp *= 1 + depth * .12
            ..maxHp *= 1 + depth * .12
            ..waveId = _waveId
            ..aim = _unit(position - at)
            ..phase = -i * .35;
          enemies.add(foe);
        }
        onEvent?.call('warning');
        return;
    }
    final sturdy = 1 + depth * .12;
    for (final (role, path) in paths) {
      final foe = _createEnemy(screenOrigin + path.at(0), role)
        ..hp *= sturdy
        ..maxHp *= sturdy
        ..waveId = _waveId
        ..path = path
        ..pathTime = -path.delay
        ..attackClock =
            (kind == WaveKind.rear ? 2.6 : 1.2) + random.nextDouble() * 1.4;
      if (kind == WaveKind.hover && role == content.EnemyRole.bulwark) {
        foe
          ..elite = true
          ..radius = 30
          ..hp *= 4.5
          ..maxHp = foe.hp
          ..eliteTimer = 1.2;
        pickupNotice = '중간 보스 등장!';
        noticeTime = 1.8;
        onEvent?.call('warning');
      }
      enemies.add(foe);
    }
  }

  /// Field drops (user 2026-10-24): items are not random timers any more.
  /// The last plane of a fully destroyed formation drops one item; a
  /// mid-boss drops its own golden supply box.
  void houseDrop(Foe e, bool wiped) {
    if (e.elite) {
      supplies.add(Supply(e.position, 9));
      return;
    }
    if (!wiped || supplies.length >= 5) return;
    final options = <(int, double)>[
      if (planKey('gun') != null && !ult('gun')) (7, 3),
      if (missileGrowth.any((id) => !ult(id))) (8, 3),
      (0, hp < maxHp * .4 ? 4 : (hp < maxHp * .75 ? 2 : .5)),
      if (crystals.length > 6) (1, 1.5),
      (2, 1),
    ];
    var roll = random.nextDouble() * options.fold(0.0, (sum, o) => sum + o.$2);
    for (final (kind, weight) in options) {
      roll -= weight;
      if (roll <= 0) {
        supplies.add(Supply(e.position, kind));
        return;
      }
    }
  }

  /// Items and gems drift down with the street; the cat must fly to them.
  void driftHouseLoot(double dt) {
    final bottom = fieldRect.bottom + 30;
    for (final s in supplies) {
      // the boss chest waits where it fell; field items flow with the street
      if (s.kind != 3) s.position += Offset(0, 34 * dt);
    }
    supplies.removeWhere((s) => s.kind != 3 && s.position.dy > bottom);
    crystals.removeWhere((c) => c.dy > bottom);
  }

  /// Mid-boss attack cycle: aimed fans, double rings, a twin spiral and a
  /// falling curtain. Below half health it attacks faster.
  void eliteAttack(Foe e, double dt) {
    if (e.pathTime < 2.4 || !screenRect.deflate(8).contains(e.position)) {
      return;
    }
    final rage = e.hp < e.maxHp * .5;
    e.eliteSpin += dt;
    e.eliteTimer -= dt * (rage ? 1.4 : 1);
    if (e.eliteTimer > 0) return;
    final depth = stage.sector + worldIndex * 2;
    final speed = 140.0 + math.min(50, depth * 6);
    final toCat = math.atan2(
      position.dy - e.position.dy,
      position.dx - e.position.dx,
    );
    void fire(double angle, [double pace = 1]) {
      if (shots.where((s) => s.hostile).length >= hostileShotLimit) return;
      shots.add(
        Shot(
          e.position,
          _direction(angle) * speed * pace,
          7 * threat,
          4,
          weapon: 'enemy-bullet',
          life: 6,
          radius: hostileBulletRadius,
        ),
      );
    }

    void next(double pause) {
      e.elitePattern++;
      e.eliteVolley = 0;
      e.eliteTimer = pause;
    }

    switch (e.elitePattern % 4) {
      case 0:
        for (var i = -2; i <= 2; i++) {
          fire(toCat + i * .2);
        }
        e.eliteTimer = .32;
        if (++e.eliteVolley >= 3) next(1.1);
      case 1:
        final count = rage ? 18 : 14;
        for (var i = 0; i < count; i++) {
          fire(i / count * math.pi * 2 + e.eliteVolley * .22, .85);
        }
        e.eliteTimer = .5;
        if (++e.eliteVolley >= 2) next(1.2);
      case 2:
        for (final arm in [0.0, math.pi]) {
          fire(e.eliteSpin * 3.2 + arm, .9);
        }
        e.eliteTimer = .09;
        if (++e.eliteVolley >= 24) next(1.0);
      default:
        final shift = e.eliteVolley.isEven ? 0.0 : .07;
        for (var i = -3; i <= 3; i++) {
          fire(math.pi / 2 + i * .15 + shift, .8);
        }
        e.eliteTimer = .55;
        if (++e.eliteVolley >= 3) next(1.3);
    }
    if (e.eliteVolley <= 1) onEvent?.call('enemy-fire');
  }

  /// True when [e] was the last of its formation and nobody slipped away:
  /// a whole-wave wipe pays a bonus crystal and a cheer.
  bool waveWiped(Foe e) {
    if (e.waveId < 0 || _leakedWaves.contains(e.waveId)) return false;
    final rest = enemies.any(
      (o) => !identical(o, e) && o.waveId == e.waveId && o.hp > 0 && !o.retired,
    );
    if (rest) return false;
    _leakedWaves.add(e.waveId);
    pickupNotice = '편대 전멸!';
    noticeTime = 1.2;
    return true;
  }

  /// Moves a wave enemy along its script and lets it shoot while it crosses.
  void followPath(Foe e, double dt) {
    final path = e.path!;
    e.pathTime += dt * (e.statusTime > 0 && e.status == 2 ? .55 : 1);
    if (e.pathTime < 0) {
      e.position = screenOrigin + path.at(0);
      return;
    }
    if (e.pathTime >= path.duration) {
      e.retired = true;
      _leakedWaves.add(e.waveId);
      return;
    }
    final before = e.position;
    e.position = screenOrigin + path.at(e.pathTime);
    final v = e.position - before;
    if (v.distance > .2) {
      e.velocity = v / dt;
      e.heading = math.atan2(v.dy, v.dx);
    }
    if (e.elite) {
      eliteAttack(e, dt);
      return;
    }
    // shoot only while inside the screen, aimed at the cat
    final doctrine = content.enemyDoctrines[e.role]!;
    if (!screenRect.deflate(8).contains(e.position)) {
      e.tell = 0;
      return;
    }
    e.attackClock -= dt;
    if (e.attackClock <= doctrine.windup && e.attackClock > 0) {
      if (e.tell <= 0) {
        e.aim = _unit(position - e.position);
        e.targetPoint =
            e.position +
            e.aim * (position - e.position).distance.clamp(90, 360);
      }
      e.tell = e.attackClock;
    } else if (e.attackClock <= 0) {
      if (_enemyFire(e)) onEvent?.call('enemy-fire');
      e.tell = 0;
      // later houses shoot more often: standing still must not be safe
      final depth = stage.sector + worldIndex * 2;
      e.attackClock =
          doctrine.cooldown *
          (1.15 + random.nextDouble() * .8) *
          (1 - math.min(.4, depth * .035));
    }
  }
}

double _smooth(double t) {
  final u = t.clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

double _easeOut(double t) {
  final u = 1 - t.clamp(0.0, 1.0);
  return 1 - u * u;
}
