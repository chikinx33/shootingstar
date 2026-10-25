part of 'engine.dart';

/// v12 house bosses (user feedback 2026-10-24: "every boss feels the same").
/// Three archetypes rotate through the houses, each a different way to play:
///  * fortress — a giant ship: break its shield generators and turrets
///    before the core can really be hurt.
///  * barrage — a bullet-pattern boss: spirals and flower rings to weave
///    through.
///  * duelist — a smart boss that reads your shots, sidesteps, and fires
///    fast aimed bursts back.
enum HouseBossKind { fortress, barrage, duelist }

extension HouseBosses on GameEngine {
  HouseBossKind get houseBossKind => HouseBossKind
      .values[(stage.sector + (_bossWave > 1 ? _bossWave - 1 : 0)) % 3];

  double get houseBossSpin => _hbSpin;

  Iterable<Foe> get bossParts =>
      enemies.where((e) => e.anchor != null && e.hp > 0 && !e.retired);
  bool get houseBossShielded =>
      boss != null && bossParts.any((p) => p.partKind == 2);

  String get houseBossCue => switch (houseBossKind) {
    HouseBossKind.fortress =>
      houseBossShielded ? '보호막 발생기를 먼저 부수세요' : '보호막 해제 · 코어 집중 공격',
    HouseBossKind.barrage => '탄막의 빈틈을 따라 움직이세요',
    HouseBossKind.duelist => '피하는 보스 · 앞질러 쏘세요',
  };

  /// Damage scale on the boss core in house stages.
  double houseBossDamage(Foe target) =>
      houseBossKind == HouseBossKind.fortress && houseBossShielded ? .08 : 1;

  Offset get houseBossHome => screenOrigin + Offset(210, viewportHeight * .22);

  void spawnHouseBoss(Foe b) {
    b.position = screenOrigin + const Offset(210, -90);
    // the duelist dodges single guns but not a whole build: it needs more hull
    // later houses field much tougher bosses (weapons now grow a lot)
    b.hp = b.maxHp =
        b.maxHp *
        // v12.9.7 (user 2026-10-25: bosses died too easily): about 2x
        (houseBossKind == HouseBossKind.duelist ? 6.0 : 4.4) *
        (1 + stage.sector * .12);
    _hbFire = 1.6;
    _hbSpin = 0;
    _hbDodge = 0;
    if (houseBossKind != HouseBossKind.fortress) {
      b.radius = 40;
      return;
    }
    b.radius = 66;
    // two spray turrets on the wings, two shield generators by the core
    for (final (kind, mount, hp) in [
      (1, const Offset(-92, 26), 170.0),
      (1, const Offset(92, 26), 170.0),
      (2, const Offset(-46, -44), 240.0),
      (2, const Offset(46, -44), 240.0),
    ]) {
      enemies.add(
        Foe(
            b.position + mount,
            hp * threat * (challenge ? 1.4 : 1),
            0,
            kind == 1 ? 20 : 22,
            2,
            role: kind == 1
                ? content.EnemyRole.spitter
                : content.EnemyRole.bulwark,
          )
          ..anchor = b
          ..mount = mount
          ..partKind = kind
          ..attackClock = 1.4 + mount.dx.abs() / 200,
      );
    }
  }

  /// Parts ride on the hull and fire on their own clocks.
  void followAnchor(Foe e, double dt) {
    final b = e.anchor!;
    if (b.hp <= 0 || b.retired) {
      e.retired = true;
      return;
    }
    e.position = b.position + e.mount;
    if (e.partKind != 1) return;
    e.attackClock -= dt;
    if (e.attackClock <= .45 && e.attackClock > 0) {
      e.tell = e.attackClock;
      e.aim = _unit(position - e.position);
    } else if (e.attackClock <= 0) {
      e.tell = 0;
      // a short spray fan from the nozzle
      final a = math.atan2(e.aim.dy, e.aim.dx);
      final n = bossPhase >= 1 ? 5 : 3;
      for (var i = 0; i < n; i++) {
        _bossBullet(e.position, a + (i - (n - 1) / 2) * .2, 150);
      }
      e.attackClock = bossPhase >= 2 ? 1.2 : 1.7;
    }
  }

  void moveHouseBoss(Foe b, double dt) {
    final home = houseBossHome;
    switch (houseBossKind) {
      case HouseBossKind.fortress:
        // a slow, heavy sway across the top of the screen
        final goal = home + Offset(math.sin(b.phase * .35) * 70, 0);
        final d = goal - b.position;
        b.position += _unit(d) * math.min(d.distance, 60 * dt);
      case HouseBossKind.barrage:
        final goal =
            home +
            Offset(math.sin(b.phase * .5) * 110, math.sin(b.phase * .9) * 26);
        final d = goal - b.position;
        b.position += _unit(d) * math.min(d.distance, 90 * dt);
      case HouseBossKind.duelist:
        _hbDodge = math.max(0, _hbDodge - dt);
        // read the cat's shots: sidestep a bullet about to hit
        if (_hbDodge <= 0) {
          for (final s in shots) {
            if (s.hostile) continue;
            final rel = s.position - b.position;
            if (rel.dy > 0 &&
                rel.dy < 190 &&
                rel.dx.abs() < b.radius + 10 &&
                s.velocity.dy < 0) {
              final side = rel.dx > 0 ? -1.0 : 1.0;
              final room = screenRect.deflate(b.radius + 10);
              final dir =
                  (b.position.dx + side * 90).clamp(room.left, room.right) ==
                      b.position.dx + side * 90
                  ? side
                  : -side;
              b.velocity = Offset(dir * 520, 0);
              _hbDodge = bossPhase >= 1 ? .55 : .85;
              break;
            }
          }
        }
        // otherwise shadow the cat's lane with a lag
        final goal = Offset(
          (position.dx + math.sin(b.phase * 1.3) * 60).clamp(
            screenRect.left + 60,
            screenRect.right - 60,
          ),
          home.dy + math.sin(b.phase * .8) * 30,
        );
        final d = goal - b.position;
        b.position +=
            b.velocity * dt + _unit(d) * math.min(d.distance, 110 * dt);
        b.velocity *= math.pow(.02, dt).toDouble();
    }
  }

  void _bossBullet(Offset at, double angle, double speed, {int kind = 4}) {
    shots.add(
      Shot(
        at,
        _direction(angle) * speed,
        13.5 * threat,
        kind,
        weapon: 'boss-volley',
        life: 6,
        radius: 5,
      ),
    );
  }

  void updateHouseBoss(double dt) {
    final b = boss;
    if (b == null || b.hp <= 0) return;
    // the entrance: glide down onto the stage before shooting
    if (b.position.dy < houseBossHome.dy - 6 && b.phase < 2.5) return;
    _hbFire -= dt;
    _hbAim -= dt;
    final phase = bossPhase;
    final aim = math.atan2(
      position.dy - b.position.dy,
      position.dx - b.position.dx,
    );
    // every boss keeps a quick aimed shot going: standing still is never safe
    if (_hbAim <= 0 && houseBossKind != HouseBossKind.duelist) {
      final n = houseBossKind == HouseBossKind.barrage ? 5 : 3;
      for (var i = 0; i < n; i++) {
        _bossBullet(b.position, aim + (i - (n - 1) / 2) * .12, 185);
      }
      _hbAim = phase >= 2 ? 1.3 : 1.8;
    }
    switch (houseBossKind) {
      case HouseBossKind.fortress:
        if (_hbFire > 0) break;
        if (houseBossShielded) {
          // the core lobs slow aimed triples while the shield holds
          for (var i = -1; i <= 1; i++) {
            _bossBullet(b.position + const Offset(0, 40), aim + i * .22, 120);
          }
          _hbFire = 2.6;
        } else {
          // shield down: the core panics into wide rings
          final n = 14 + phase * 4;
          final off = _hbSpin += .17;
          for (var i = 0; i < n; i++) {
            _bossBullet(b.position, off + i * math.pi * 2 / n, 115);
          }
          _hbFire = phase >= 2 ? 1.5 : 2.1;
        }
      case HouseBossKind.barrage:
        // breathe: 3.6 s of pattern, 1.1 s of rest to slip through
        final cycle = b.phase % 4.7;
        if (cycle > 3.6 || _hbFire > 0) break;
        _hbSpin += .26;
        final arms = 2 + phase;
        for (var i = 0; i < arms; i++) {
          _bossBullet(b.position, _hbSpin + i * math.pi * 2 / arms, 125);
          if (phase >= 2) {
            _bossBullet(b.position, -_hbSpin + i * math.pi * 2 / arms, 105);
          }
        }
        if (phase >= 1 && (b.phase % 1.6) < dt) {
          // a flower ring on the beat
          for (var i = 0; i < 18; i++) {
            _bossBullet(b.position, i * math.pi / 9 + _hbSpin * .5, 90);
          }
        }
        _hbFire = .13;
      case HouseBossKind.duelist:
        if (_hbFire > 0) break;
        // quick aimed bursts, leading the cat's movement
        final lead = position + input * 70;
        final a = math.atan2(lead.dy - b.position.dy, lead.dx - b.position.dx);
        final burst = 3 + phase;
        for (var i = 0; i < burst; i++) {
          _bossBullet(
            b.position + Offset(0, b.radius * .6),
            a + (i - (burst - 1) / 2) * .07,
            205 + i * 12,
          );
        }
        _hbFire = phase >= 2 ? .9 : 1.25;
    }
  }
}
