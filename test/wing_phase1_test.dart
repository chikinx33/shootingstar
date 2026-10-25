import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine arena({String weapon = 'pulse'}) =>
    GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        armament: weapon,
        seed: 57,
      )
      ..hp = 100000
      ..maxHp = 100000;

void nextLevel(GameEngine g) {
  // v12.4.1: a level-up only opens when a gem reaches the cat.
  g.xp = g.xpNeeded;
  g.crystals.add(g.position);
  g.update(.001);
}

List<Shot> volley(GameEngine g) {
  g.update(.001);
  return g.shots.where((s) => s.kind == 0).toList();
}

void main() {
  test('formation destinations stay reachable at the world boundaries', () {
    for (final at in [const Offset(32, 32), const Offset(1768, 2368)]) {
      final g = arena()
        ..position = at
        ..xpNeeded = 1e9;
      g.upgrades.clear();
      for (int i = 0; i < 162; i++) {
        g.update(.05);
        g.enemies.removeWhere((e) => e.formationPattern == null);
      }
      final group = g.enemies.where((e) => e.formationPattern != null).toList();
      expect(group, isNotEmpty);
      for (final e in group) {
        expect(
          e.formationDestination!.dx,
          inInclusiveRange(16, GameEngine.worldWidth - 16),
        );
        expect(
          e.formationDestination!.dy,
          inInclusiveRange(16, GameEngine.worldHeight - 16),
        );
      }
    }
  });
  test('all three weapons offer exclusive branches through real level-up, without slots', () {
    for (final weapon in ['pulse', 'revolver', 'shotgun']) {
      final g = arena(weapon: weapon);
      nextLevel(g);
      final pair = g.choices.where((c) => c.specialization).toList();
      expect(pair.length, 2);
      final upgrades = Map.of(g.upgrades), passives = Map.of(g.passives);
      g.chooseUpgrade(pair.first.id);
      expect(g.mainBranchSpec!.id, pair.first.id);
      expect(g.upgrades, upgrades);
      expect(g.passives, passives);
      g.chooseUpgrade(pair.last.id); // stale/unoffered input cannot replace it
      expect(g.mainBranchSpec!.id, pair.first.id);
      nextLevel(g);
      expect(g.choices.any((c) => c.specialization), false);
      expect(arena(weapon: weapon).mainBranch, isNull); // run-only state
    }
    final other = arena(weapon: 'kunai');
    nextLevel(other);
    // Phase5 extends the same exclusive offer contract to the remaining weapons.
    expect(other.choices.where((c) => c.specialization).length, 2);
  });

  test(
    'branches remain selectable at six plus six and rerolls respect exclusions',
    () {
      final g = arena();
      g.upgrades.addAll({
        'missile': 1,
        'drone': 1,
        'side': 1,
        'mine': 1,
        'trail': 1,
        'guardian': 1,
      });
      g.passives.addAll({
        'attack': 1,
        'area': 1,
        'speed': 1,
        'hull': 1,
        'magnet': 1,
        'duration': 1,
      });
      nextLevel(g);
      final offered = g.choices.map((c) => c.id).toSet();
      expect(g.rerollChoices(), true);
      expect(g.choices.any((c) => offered.contains(c.id)), false);
      g.choices = [mainBranches.first.choice];
      g.chooseUpgrade(mainBranches.first.id);
      expect(g.weaponCount, 6);
      expect(g.passives.length, 6);
    },
  );

  test(
    'R/P/N independent evolution is retained for every branch and no branch',
    () {
      for (final branch in mainBranches.take(6)) {
        final g = arena(weapon: branch.armament)..mainBranch = branch.branch;
        for (final kind in [4, 4, 4, 5, 5, 5, 6, 6]) {
          g.supplies.add(Supply(g.position, kind));
          g.update(.001);
        }
        expect([g.mainRate, g.mainPower, g.mainCount], [3, 3, 2]);
        expect(g.evolved, contains('gun'));
        expect(g.mainBranch, branch.branch);
        expect(volley(arena(weapon: branch.armament)), isNotEmpty);
      }
    },
  );

  test('pulse focus pierces while spread trades per-bullet damage for angle and count', () {
    final base = volley(arena());
    final focus = volley(arena()..mainBranch = MainBranch.pulseFocus);
    final spread = volley(arena()..mainBranch = MainBranch.pulseSpread);
    expect(focus.length, base.length);
    expect(focus.first.pierce, base.first.pierce + 2);
    expect(focus.first.damage, closeTo(base.first.damage * .9, .0001));
    expect(spread.length, base.length + 2);
    expect(spread.first.velocity.dx, lessThan(0));
    expect(spread.last.velocity.dx, greaterThan(0));
    expect(spread.every((s) => s.velocity.dy < 0), true);
    expect(spread.first.damage, closeTo(base.first.damage * .72, .0001));
  });

  test('rail penetrates distinct targets and charge applies once after a slower reload', () {
    final base = volley(arena(weapon: 'revolver')).first;
    final over = arena(weapon: 'revolver')..mainBranch = MainBranch.railPierce;
    final a = Foe(over.position + const Offset(0, -100), 10000, 0, 12, 0);
    final b = Foe(over.position + const Offset(0, -155), 10000, 0, 12, 0);
    over.enemies
      ..clear()
      ..addAll([a, b]);
    final bullet = volley(over).first;
    expect(bullet.pierce, 5);
    expect(bullet.damage, closeTo(base.damage * .8, .0001));
    for (int i = 0; i < 18; i++) over.update(.02);
    expect(a.hp, lessThan(a.maxHp));
    expect(b.hp, lessThan(b.maxHp));
    final g = arena(weapon: 'revolver')
      ..mainBranch = MainBranch.railCharge
      ..revolverAmmo = 1;
    expect(volley(g).first.damage, base.damage);
    g.shots.clear();
    for (int i = 0; i < 34; i++) g.update(.05);
    expect(g.shots.where((s) => s.kind == 0), isEmpty); // 1.7s < reload 1.8s
    g.setPaused(true);
    for (int i = 0; i < 40; i++) g.update(.05);
    g.setPaused(false);
    for (int i = 0; i < 4; i++) g.update(.05);
    expect(
      g.shots.firstWhere((s) => s.kind == 0).damage,
      closeTo(base.damage * 2, .0001),
    );
    g.shots.clear();
    for (int i = 0; i < 12; i++) g.update(.05);
    expect(g.shots.firstWhere((s) => s.kind == 0).damage, base.damage);
  });

  test('compressed shells reward actual distance; shards do not hit parent or recurse', () {
    double hitAt(double distance) {
      final g = arena(weapon: 'shotgun');
      g.upgrades.clear();
      final target = Foe(g.position + Offset(0, -distance), 1000, 0, 12, 0);
      g.enemies.add(target);
      g.shots.add(
        Shot(target.position, Offset.zero, 100, 0, weapon: 'gun')
          ..closeRange = true
          ..distanceTravelled = distance,
      );
      g.update(.001);
      return target.maxHp - target.hp;
    }

    expect(hitAt(100), closeTo(150, .001));
    expect(hitAt(200), closeTo(55, .001));
    final g = arena(weapon: 'shotgun')..mainBranch = MainBranch.shellSplit;
    final shells = volley(g);
    expect(shells.every((s) => s.splitOnHit), true);
    final target = Foe(g.position + const Offset(0, -80), 10000, 0, 20, 0);
    g.enemies
      ..clear()
      ..add(target);
    g.shots
      ..clear()
      ..add(
        Shot(target.position, const Offset(0, -420), 100, 0, weapon: 'gun')
          ..splitOnHit = true,
      );
    g.update(.001);
    final shards = g.shots.where((s) => s.hitTargets.contains(target)).toList();
    expect(shards.length, 2);
    expect(shards.every((s) => !s.splitOnHit && s.life <= .45), true);
    final hp = target.hp;
    g.update(.001);
    expect(target.hp, hp);
  });

  test(
    'N pickups add firepower to all six branches before and after evolution',
    () {
      for (final spec in mainBranches.take(6)) {
        for (final evolved in [false, true]) {
          final a = arena(weapon: spec.armament)..mainBranch = spec.branch;
          final b = arena(weapon: spec.armament)..mainBranch = spec.branch;
          if (evolved) {
            a.evolved.add('gun');
            b.evolved.add('gun');
          }
          b.supplies.add(Supply(b.position, 6));
          expect(
            volley(b).length,
            greaterThan(volley(a).length),
            reason: spec.name,
          );
        }
      }
    },
  );

  test('column and fan enter, telegraph, fire within budget, and retire without rewards', () {
    final g = arena()
      ..viewportHeight = 720
      ..xpNeeded = 1e9;
    g.upgrades.clear();
    final patterns = <FlightFormation>{};
    final retired = <int>{};
    var sawTell = false, sawFire = false;
    for (int i = 0; i < 740; i++) {
      g.update(.05);
      for (final e in g.enemies.where((e) => e.formationPattern != null)) {
        e.hp = 100000;
        if (e.formationPattern == FlightFormation.column ||
            e.formationPattern == FlightFormation.fan)
          patterns.add(e.formationPattern!);
        if (e.phase < 1.25) expect(e.tell, 0);
        if (e.tell > 0) sawTell = true;
        if (e.phase > 3.8) expect(e.tell, 0);
        expect(e.position.dx.isFinite && e.position.dy.isFinite, true);
        if (e.phase > 3.5 &&
            (e.formationPattern == FlightFormation.column ||
                e.formationPattern == FlightFormation.fan))
          retired.add(e.formationId);
      }
      sawFire |= g.shots.any((s) => s.hostile);
      expect(
        g.shots.where((s) => s.hostile).length,
        lessThanOrEqualTo(g.hostileShotLimit),
      );
      g.enemies.removeWhere((e) => e.formationPattern == null);
    }
    expect(patterns, {FlightFormation.column, FlightFormation.fan});
    expect(retired.length, 2);
    expect(g.enemies.where((e) => retired.contains(e.formationId)), isEmpty);
    expect(sawTell && sawFire, true);
    expect(g.kills, 0);
    expect(g.crystals, isEmpty);
  });

  test('formation phase freezes on pause and level choices; capacity and boss transition hold', () {
    final g = arena()..xpNeeded = 1e9;
    for (int i = 0; i < 162; i++) {
      g.update(.05);
      g.enemies.removeWhere((e) => e.formationPattern == null);
    }
    final e = g.enemies.firstWhere((e) => e.formationPattern != null);
    final phase = e.phase, at = e.position;
    g.setPaused(true);
    g.update(.05);
    g.setPaused(false);
    g.choices = [mainBranches.first.choice];
    g.update(.05);
    expect(e.phase, phase);
    expect(e.position, at);
    g.choices.clear();
    g.elapsed = g.nextBossAt - .01;
    g.update(.05);
    expect(g.boss, isNotNull);
    expect(g.enemies.any((e) => e.formationPattern != null), false);
    final full = arena()..elapsed = 8;
    full.upgrades.clear();
    full.enemies.addAll(
      List.generate(
        full.enemyLimit,
        (i) => Foe(
          full.position + Offset((i % 10) * 20.0, -200),
          100000,
          0,
          10,
          0,
        ),
      ),
    );
    for (int i = 0; i < 162; i++) full.update(.05);
    expect(full.enemies.length, lessThanOrEqualTo(full.enemyLimit));
  });
}
