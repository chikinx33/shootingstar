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

  /// The reference phase for the boss's remaining health.
  int houseBossPhase(Foe b, BossPatternSet set) {
    final lost = 1 - (b.hp / b.maxHp).clamp(0.0, 1.0);
    var edge = 0.0;
    for (var i = 0; i < set.phases.length; i++) {
      edge += set.phases[i].share;
      if (lost < edge) return i;
    }
    return set.phases.length - 1;
  }

  void updateHouseBoss(double dt) {
    final b = boss;
    if (b == null || b.hp <= 0) return;
    // the entrance: glide down onto the stage before shooting
    if (b.position.dy < houseBossHome.dy - 6 && b.phase < 2.5) return;
    // v12.9.8 (user 2026-10-25): every house boss has its own reference
    // pattern set (B1-B11); its phases follow the reference health shares,
    // each phase several parts firing on their own cycles.
    final set = BossPatterns.forStage(stageIndex);
    final phase = houseBossPhase(b, set);
    runDanmaku(b, set.phases[phase].emits, dt, damage: 12 * threat, limit: 200);
  }
}
