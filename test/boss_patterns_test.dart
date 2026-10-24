import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine makeBoss({int stage = 0}) {
  final g = GameEngine(
    stageIndex: stage,
    shipIndex: 0,
    attackLevel: 0,
    hullLevel: 0,
    magnetLevel: 0,
    equipmentIndex: 0,
    seed: 1,
  );
  g.upgrades.clear();
  g.elapsed = g.nextBossAt;
  g.update(.01);
  return g;
}

void advance(GameEngine g, double seconds) {
  for (int i = 0; i < (seconds / .01).round(); i++) {
    g.update(.01);
  }
}

void main() {
  test('boss spawn never clamps onto a pilot at the arena corners', () {
    for (final at in [
      const Offset(32, 32),
      const Offset(1768, 32),
      const Offset(32, 2368),
      const Offset(1768, 2368),
    ]) {
      final g = GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 1,
      );
      g.position = at;
      g.upgrades.clear();
      g.elapsed = g.nextBossAt;
      final hp = g.hp;
      g.update(.01);
      expect((g.boss!.position - at).distance, greaterThanOrEqualTo(120));
      expect(g.hp, hp);
      expect(g.bossWarning, true);
    }
  });
  test('extreme burst must face all three telegraphed phases with fixed route health', () {
    final g = makeBoss();
    expect(g.boss!.maxHp, 1710);
    final phases = <int>{};
    for (int i = 0; i < 1200 && g.boss != null; i++) {
      phases.add(g.bossPhase);
      g.shots.add(Shot(g.boss!.position, Offset.zero, 1000000, 0));
      g.update(.01);
    }
    expect(g.bossesDefeated, 1);
    expect(phases, {0, 1, 2});
    expect(g.bossAttacks, 3);
    expect(g.combatTime, greaterThanOrEqualTo(9.6));
    expect(g.combatTime, lessThan(11));
    expect(g.damageByWeapon['gun'], closeTo(1710, .001));
  });
  test(
    'warning locks aim and pause/choices freeze cycle; charge follows warning',
    () {
      final g = makeBoss(stage: 2);
      final aim = g.bossAim, at = g.boss!.position, cycle = g.bossCycle;
      g.setPaused(true);
      g.update(.05);
      expect(g.bossCycle, cycle);
      g.setPaused(false);
      g.choices = [GameEngine.catalog.first];
      g.update(.05);
      expect(g.bossCycle, cycle);
      g.choices.clear();
      g.position += const Offset(150, 0);
      advance(g, .8);
      expect(g.bossAim, aim);
      expect(g.boss!.position, at);
      advance(g, .4);
      expect(g.bossCharging, true);
      expect(g.boss!.position.dx, closeTo(at.dx, .001));
      expect(g.boss!.position.dy, greaterThan(at.dy));
      advance(g, 2.1);
      expect(g.bossExposed, true);
      final stopped = g.boss!.position;
      advance(g, .3);
      expect(g.boss!.position, stopped);
    },
  );
  test('radial volley leaves the displayed safe wedge clear', () {
    final g = makeBoss();
    advance(g, 1.1);
    final shots = g.shots.where((s) => s.kind == 4);
    expect(shots, isNotEmpty);
    for (final s in shots) {
      final direction = s.velocity / s.velocity.distance;
      final dot =
          direction.dx * g.bossSafeDirection.dx +
          direction.dy * g.bossSafeDirection.dy;
      expect(dot, lessThan(.914)); // cos(.42)
    }
  });
  test('bomb supply cannot bypass closed hull sections', () {
    final g = makeBoss();
    g.boss!.hp = g.boss!.maxHp * .65 + .01;
    g.supplies.add(Supply(g.position, 2));
    g.update(.01);
    expect(g.boss!.hp, closeTo(g.boss!.maxHp * .65 + .01, .001));
    expect(g.bossPhase, 0);
  });
  test(
    'lightning retains crowd strikes but caps repeated target hits and range',
    () {
      for (final evo in [false, true]) {
        final g = makeBoss();
        g.enemies.clear();
        g.upgrades['lightning'] = 5;
        if (evo) g.evolved.add('lightning');
        final targets = List.generate(
          5,
          (i) => Foe(g.position + Offset(60 + i * 20, 0), 10000, 0, 8, 0),
        );
        final far = Foe(g.position + const Offset(500, 0), 10000, 0, 8, 0);
        g.enemies.addAll([...targets, far]);
        g.update(.01);
        for (final e in targets) {
          expect(
            10000 - e.hp,
            lessThanOrEqualTo(73 * g.damageFactor * (evo ? 3 : 2) + .00001),
          );
        }
        expect(far.hp, 10000);
        expect(
          g.damageByWeapon['lightning'],
          closeTo(73 * g.damageFactor * (evo ? 12 : 6), .001),
        );
      }
    },
  );
  test('evolved drone trades excess fire rate for one pierce', () {
    final g = makeBoss();
    g.upgrades['drone'] = 5;
    g.evolved.add('drone');
    g.boss!.position = g.position + const Offset(0, -100);
    g.update(.01);
    expect(g.shots.singleWhere((s) => s.weapon == 'drone').pierce, 1);
  });
}
