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
  test('the three cat guns get no 주포 특화 choice through real level-up', () {
    for (final weapon in ['pulse', 'revolver', 'shotgun']) {
      final g = arena(weapon: weapon);
      for (var i = 0; i < 3; i++) {
        nextLevel(g);
        expect(g.choices.any((c) => c.specialization), false, reason: weapon);
        g.choices.clear();
      }
    }
  });

  test('rerolls respect exclusions at six plus six', () {
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
    expect(g.weaponCount, 6);
    expect(g.passives.length, 6);
  });

  test('R/P/N independent evolution is retained for every cat gun', () {
    for (final weapon in ['pulse', 'revolver', 'shotgun']) {
      final g = arena(weapon: weapon);
      for (final kind in [4, 4, 4, 5, 5, 5, 6, 6]) {
        g.supplies.add(Supply(g.position, kind));
        g.update(.001);
      }
      expect([g.mainRate, g.mainPower, g.mainCount], [3, 3, 2]);
      expect(g.evolved, contains('gun'));
      expect(volley(arena(weapon: weapon)), isNotEmpty);
    }
  });

  test('close-range shells reward actual distance', () {
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
  });

  test(
    'N pickups add firepower to all three cat guns before and after evolution',
    () {
      for (final weapon in ['pulse', 'revolver', 'shotgun']) {
        for (final evolved in [false, true]) {
          final a = arena(weapon: weapon);
          final b = arena(weapon: weapon);
          if (evolved) {
            a.evolved.add('gun');
            b.evolved.add('gun');
          }
          b.supplies.add(Supply(b.position, 6));
          expect(
            volley(b).length,
            greaterThan(volley(a).length),
            reason: weapon,
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
    g.choices = [GameEngine.catalog.first];
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
