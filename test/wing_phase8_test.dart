import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine arena(int world, {Offset? at}) {
  final g =
      GameEngine(
          stageIndex: world * 10,
          shipIndex: 0,
          attackLevel: 0,
          hullLevel: 0,
          magnetLevel: 0,
          equipmentIndex: 0,
          seed: 73,
        )
        ..position = at ?? const Offset(900, 1680)
        ..hp = 100000
        ..maxHp = 100000
        ..xpNeeded = 1e9
        ..upgrades.clear();
  g.elapsed = g.nextBossAt;
  g.update(.01);
  return g;
}

void tick(GameEngine g, double seconds) {
  for (var i = 0; i < (seconds / .01).round(); i++) {
    g.update(.01);
  }
}

void phase(GameEngine g, int phase) {
  g.boss!.hp =
      g.boss!.maxHp *
      (phase == 0
          ? 1
          : phase == 1
          ? .65
          : .3);
  g.update(.01);
}

void main() {
  test('ten worlds have distinct three-stage contracts and emit all six attack families', () {
    final profiles = <String>{}, patterns = <int>{};
    for (var world = 0; world < 10; world++) {
      final g = arena(world);
      final order = <int>[];
      for (var p = 0; p < 3; p++) {
        phase(g, p);
        order.add(g.bossPattern);
        patterns.add(g.bossPattern);
        final life = g.boss!.maxHp, chapter = g.elapsed;
        final attackBefore = g.bossAttacks;
        tick(g, 1.05);
        expect(g.bossAttacks, attackBefore + 1);
        expect(
          g.bossCharging || g.shots.any((s) => s.hostile),
          true,
          reason: 'world $world phase $p',
        );
        tick(g, 1.3);
        expect(g.bossExposed, true);
        expect(g.boss!.maxHp, life);
        expect(g.elapsed, chapter);
        expect(g.shots.any((s) => s.weapon.startsWith('boss-')), false);
      }
      expect(order.toSet().length, 3);
      profiles.add(order.join(','));
    }
    expect(profiles.length, 10);
    expect(patterns, {0, 1, 2, 3, 4, 5});
  });
  test('later stages alternate familiar attacks after a full opening, first stage repeats', () {
    for (var world = 0; world < 10; world++) {
      final g = arena(world);
      final first = g.bossPattern;
      tick(g, 4.22);
      expect(g.bossPattern, first);
      phase(g, 1);
      final second = g.bossPattern;
      tick(g, 4.22);
      expect(g.bossPattern, isNot(second));
      tick(g, 4.22);
      expect(g.bossPattern, second);
      phase(g, 2);
      expect(g.bossRound, 0);
      expect(g.bossWarning, true);
    }
  });
  test('fixed lasers, artillery and mines do not retarget during the warning or pause', () {
    for (final world in [4, 5, 7]) {
      final g = arena(world);
      final target = g.bossTarget, origin = g.bossOrigin, aim = g.bossAim;
      final marks = g.bossArtilleryTargets,
          lanes = g.bossLaserLanes,
          mines = g.bossMineTargets;
      g.position += const Offset(100, 70);
      tick(g, .6);
      expect(g.bossTarget, target);
      expect(g.bossOrigin, origin);
      expect(g.bossAim, aim);
      expect(g.bossArtilleryTargets, marks);
      expect(g.bossLaserLanes, lanes);
      expect(g.bossMineTargets, mines);
      final time = g.bossCycle;
      g.setPaused(true);
      tick(g, .5);
      g.setPaused(false);
      g.choices = [const UpgradeChoice('x', 'x', 'x', 'x')];
      tick(g, .5);
      g.choices.clear();
      expect(g.bossCycle, time);
      expect(g.shots.any((s) => s.hostile), false);
    }
  });
  test('twin lanes damage only the warned lanes and leave the central corridor clear', () {
    final safe = arena(7);
    expect(safe.bossPattern, 3);
    final safeHp = safe.hp;
    tick(safe, 1.7);
    expect(safe.hp, safeHp);
    final hit = arena(7);
    final lane = hit.bossLaserLanes.first;
    hit.position = lane.$1 + hit.bossAim * 230;
    final hp = hit.hp;
    tick(hit, .9);
    expect(hit.hp, hp);
    tick(hit, .2);
    expect(hit.hp, lessThan(hp));
    expect(hit.shots.where((s) => s.kind == 23).length, 2);
    final damaged = hit.hp;
    tick(hit, .3);
    expect(hit.hp, damaged);
  });
  test(
    'marked artillery hits locked locations while moving out avoids damage',
    () {
      final hit = arena(4);
      expect(hit.bossPattern, 4);
      final hp = hit.hp;
      tick(hit, .9);
      expect(hit.hp, hp);
      tick(hit, 1.1);
      expect(hit.hp, lessThan(hp));
      final dodge = arena(4);
      final target = dodge.bossTarget;
      dodge.position += const Offset(0, 110);
      final start = dodge.hp;
      tick(dodge, 2.1);
      expect(dodge.bossTarget, target);
      expect(dodge.hp, start);
    },
  );
  test('mine ring is harmless during warning, armed after tell, and has reachable exits at all corners', () {
    final g = arena(5);
    expect(g.bossPattern, 5);
    final mine = g.bossMineTargets.first;
    g.position = mine;
    final hp = g.hp;
    tick(g, .9);
    expect(g.hp, hp);
    tick(g, .2);
    expect(g.hp, lessThan(hp));
    for (final at in [
      const Offset(32, 32),
      const Offset(1768, 32),
      const Offset(32, 2368),
      const Offset(1768, 2368),
      const Offset(900, 1680),
    ]) {
      final c = arena(5, at: at);
      final end = c.bossTarget + c.bossMineExit * 160;
      expect(end.dx, inInclusiveRange(32, 1768));
      expect(end.dy, inInclusiveRange(32, 2368));
      for (final point in c.bossMineTargets) {
        final v = point - c.bossTarget;
        final along = (v.dx * c.bossMineExit.dx + v.dy * c.bossMineExit.dy)
            .clamp(0.0, 160.0);
        expect(
          (point - (c.bossTarget + c.bossMineExit * along)).distance,
          greaterThan(34),
        );
      }
    }
  });
  test(
    'phase changes remove hostile hazards and summons without free rewards',
    () {
      final g = arena(4);
      phase(g, 1);
      tick(g, 1.05);
      expect(g.enemies.length, greaterThan(1));
      final kills = g.kills;
      g.shots.add(Shot(g.position, Offset.zero, 10, 17, weapon: 'boss-mine'));
      phase(g, 2);
      expect(g.enemies.length, 1);
      expect(g.shots.any((s) => s.hostile), false);
      expect(g.kills, kills);
      expect(g.crystals, isEmpty);
    },
  );
  test('late-world repeated cycles cap summons and hostile actors while preserving telegraphs', () {
    for (final world in [4, 5, 7, 9]) {
      final g = arena(world);
      phase(g, 2);
      for (var i = 0; i < 3400; i++) {
        g.update(.01);
        expect(
          g.enemies.where((e) => e.kind != 3).length,
          lessThanOrEqualTo(4),
        );
        expect(
          g.shots.where((s) => s.hostile).length,
          lessThanOrEqualTo(g.hostileShotLimit),
        );
        expect(g.enemies.length, lessThanOrEqualTo(g.enemyLimit));
      }
      expect(g.bossAttacks, greaterThanOrEqualTo(8));
      expect(g.bossRound, greaterThanOrEqualTo(8));
    }
  });
  test('all phases retain closed bulkhead floors for burst, status and bomb damage', () {
    for (var world = 0; world < 10; world++) {
      final g = arena(world);
      final max = g.boss!.maxHp;
      g.shots.add(Shot(g.boss!.position, Offset.zero, 1000000, 0));
      g.update(.01);
      expect(g.boss!.hp, closeTo(max * .65 + .01, .00001));
      expect(g.bossPhase, 0);
      tick(g, 2.2);
      g.shots.add(Shot(g.boss!.position, Offset.zero, 1000000, 0));
      g.update(.01);
      g.update(.01);
      expect(g.bossPhase, 1);
      expect(g.bossWarning, true);
      g.supplies.add(Supply(g.position, 2));
      g.update(.01);
      expect(g.boss!.hp, greaterThanOrEqualTo(max * .3));
    }
  });
}
