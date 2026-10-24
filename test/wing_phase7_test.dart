import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/campaign.dart';
import 'package:shootingstar/data/daily_challenge.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/waves.dart';

GameEngine arena(int stage, {int cycle = 0, DailyChallengeEntry? daily}) =>
    GameEngine(
        stageIndex: stage,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 73,
        campaignLoop: cycle,
        dailyEntry: daily,
      )
      ..position = const Offset(900, 1680)
      ..hp = 100000
      ..maxHp = 100000
      ..xpNeeded = 1e9
      ..upgrades.clear();

void main() {
  test('100 routes keep boss contract, world threat and six paced beats', () {
    final identities = <String>{};
    for (var stage = 0; stage < 100; stage++) {
      final g = arena(stage);
      identities.add(g.routePlan.name);
      expect(g.duration, stage % 10 == 9 ? 240 : 180);
      expect(
        g.requiredBosses,
        stage % 10 == 9
            ? 3
            : stage % 10 == 4
            ? 2
            : 1,
      );
      expect(g.threat, closeTo(1 + stage * .035, .00001));
      expect(g.routePlan.formations.toSet(), {
        FlightFormation.column,
        FlightFormation.fan,
        FlightFormation.bulwark,
      });
      final period = g.duration / g.requiredBosses;
      for (final progress in [.05, .2, .4, .6, .8, .95]) {
        g.elapsed = period * progress;
        final spec = g.encounter;
        expect(spec.name.startsWith(g.routePlan.name), true);
        expect(spec.count, inInclusiveRange(2, 11));
        expect(spec.runnerChance + spec.heavyChance, lessThanOrEqualTo(1));
        expect(g.waveEnemyBudget, inInclusiveRange(24, 254));
      }
      expect(g.encounter.name, contains('보스 전 소탕'));
      expect(g.encounter.count, 2);
      expect(g.encounter.interval, 1.65);
      expect(g.formationWindowOpen, false);
    }
    expect(identities.length, 10);
  });

  test('route order changes decisions, late pressure stays bounded across worlds and loops', () {
    final opening = arena(0), armor = arena(7), pursuit = arena(6);
    expect(opening.routePlan.formations.first, FlightFormation.column);
    expect(armor.routePlan.formations.first, FlightFormation.bulwark);
    expect(
      pursuit.routePlan.assaultInterval,
      lessThan(opening.routePlan.assaultInterval),
    );
    expect(armor.routePlan.role, EnemyRole.bulwark);
    expect(arena(3).routePlan.role, EnemyRole.spitter);
    expect(arena(5).routePlan.role, EnemyRole.miner);
    for (var sector = 0; sector < 10; sector++) {
      final early = arena(sector)..elapsed = 35;
      final late = arena(90 + sector, cycle: 100)..elapsed = 35;
      expect(late.routePlan, same(early.routePlan));
      expect(
        late.routeFormationInterval,
        closeTo(early.routeFormationInterval - 1.8, .00001),
      );
      expect(late.waveEnemyBudget, early.waveEnemyBudget + 36);
      expect(late.enemyLimit, early.enemyLimit);
    }
  });

  test('ten route archetypes naturally schedule all four groups without overlap or burst debt', () {
    for (var sector = 0; sector < 10; sector++) {
      final g = arena(sector);
      final seen = <FlightFormation>{}, ids = <int>{};
      var previous = -100.0;
      final stopAt = g.nextBossAt - 9.2;
      for (var i = 0; i < (stopAt / .05).floor(); i++) {
        g.update(.05);
        g.enemies.removeWhere((e) => e.formationPattern == null);
        final liveIds = g.enemies.map((e) => e.formationId).toSet();
        expect(liveIds.length, lessThanOrEqualTo(1), reason: 'route $sector');
        for (final e in g.enemies) {
          seen.add(e.formationPattern!);
          if (ids.add(e.formationId)) {
            expect(g.combatTime - previous, greaterThanOrEqualTo(8.99));
            previous = g.combatTime;
          }
        }
        expect(g.enemies.length, lessThanOrEqualTo(6));
        expect(
          g.shots.where((s) => s.hostile).length,
          lessThanOrEqualTo(g.hostileShotLimit),
        );
      }
      expect(seen, FlightFormation.values.toSet(), reason: 'route $sector');
      expect(g.kills, 0);
      expect(g.crystals, isEmpty);
    }
  });

  test('clearing a formation early does not trigger an overdue assault immediately', () {
    final g = arena(0);
    for (var i = 0; i < 161; i++) {
      g.update(.05);
      g.enemies.removeWhere((e) => e.formationPattern == null);
    }
    expect(g.enemies.first.formationPattern, FlightFormation.column);
    g.enemies.clear();
    g.elapsed = 50; // overdue spawn clocks still respect the combat-time rest.
    for (var i = 0; i < 100; i++) {
      g.update(.05);
      g.enemies.removeWhere((e) => e.formationPattern == null);
      expect(g.enemies, isEmpty);
    }
    expect(g.formationWindowOpen, false);
  });

  test(
    'collection windows suppress new formations before every required boss',
    () {
      for (final stage in [0, 4, 9, 99]) {
        final g = arena(stage);
        g.elapsed = g.nextBossAt - 8;
        for (var i = 0; i < 100; i++) {
          g.update(.05);
          expect(g.enemies.any((e) => e.formationPattern != null), false);
        }
        final time = g.combatTime, at = g.elapsed;
        g.setPaused(true);
        g.update(.05);
        g.setPaused(false);
        expect([g.combatTime, g.elapsed], [time, at]);
        g.choices = [const UpgradeChoice('x', 'x', 'x', 'x')];
        g.update(.05);
        expect([g.combatTime, g.elapsed], [time, at]);
      }
    },
  );

  test('ordinary waves stop replenishing at their budget without removing live actors', () {
    for (final stage in [0, 7, 99]) {
      final g = arena(stage)..elapsed = 35;
      final actors = List.generate(
        g.waveEnemyBudget,
        (_) => Foe(g.position + const Offset(0, -250), 100000, 0, 1, 0),
      );
      g.enemies.addAll(actors);
      g.update(.05);
      expect(g.enemies.length, actors.length);
      expect(g.enemies, containsAll(actors));
      g.enemies.removeLast();
      g.update(.05);
      expect(g.enemies.length, actors.length);
      expect(g.enemies.where((e) => e.formationPattern != null), isEmpty);
    }
  });

  test(
    'route role emphasis actually produces different ordinary populations',
    () {
      final counts = <int, int>{};
      for (final stage in [1, 3, 5, 6, 7, 9]) {
        final g = arena(stage)..elapsed = 35;
        var matching = 0, total = 0;
        for (var i = 0; i < 400; i++) {
          g.update(.05);
          final ordinary = g.enemies.where((e) => e.formationPattern == null);
          matching += ordinary.where((e) => e.role == g.routePlan.role).length;
          total += ordinary.length;
          g.enemies.removeWhere((e) => e.formationPattern == null);
        }
        expect(matching / total, greaterThan(.18), reason: 'route $stage');
        counts[stage] = matching;
      }
      expect(counts.length, 6);
    },
  );

  test('ordinary density eases during a live formation and restores after it retires', () {
    final g = arena(7);
    expect(g.formationPopulationFactor, 1);
    for (var i = 0; i < 162; i++) {
      g.update(.05);
      g.enemies.removeWhere((e) => e.formationPattern == null);
    }
    expect(g.formationPopulationFactor, .7);
    for (final e in g.enemies) {
      e.retired = true;
    }
    expect(g.formationPopulationFactor, 1);
  });

  test(
    'daily density/interval and tier modifiers remain composed and capped',
    () {
      const entry = DailyChallengeEntry(
        day: '2026-10-18',
        variant: 0,
        tier: 2,
        seed: 73,
      );
      final normal = arena(0)..elapsed = 35;
      final daily = arena(0, daily: entry)..elapsed = 35;
      expect(daily.waveEnemyBudget, (normal.waveEnemyBudget * 1.3).floor());
      expect(daily.requiredBosses, 1);
      expect(daily.duration, 180);
      expect(daily.threat, normal.threat);
      expect(daily.dailyEntry!.waveIntervalMultiplier, .82);
      expect(daily.dailyEntry!.healthMultiplier, 1.4);
    },
  );

  test(
    'live ordinary late-world encounters stay within actor and ranged budgets',
    () {
      final ranged = {
        EnemyRole.spitter,
        EnemyRole.sniper,
        EnemyRole.miner,
        EnemyRole.carrier,
      };
      for (final stage in [0, 7, 99]) {
        final g = arena(stage);
        for (var i = 0; i < 1250; i++) {
          g.update(.05);
          expect(g.enemies.length, lessThanOrEqualTo(g.enemyLimit));
          expect(
            g.enemies.where((e) => ranged.contains(e.role)).length,
            lessThanOrEqualTo(12),
          );
          expect(
            g.shots.where((s) => s.hostile).length,
            lessThanOrEqualTo(g.hostileShotLimit),
          );
        }
        expect(g.enemies.length, greaterThan(20));
      }
    },
  );
}
