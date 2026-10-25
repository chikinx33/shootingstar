import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/campaign.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/danmaku_patterns.dart';
import 'package:shootingstar/game/engine.dart';

Future<GameEngine> arena() async {
  SharedPreferences.setMockInitialValues({});
  final p = await Profile.load();
  return GameEngine(
      stageIndex: 0,
      shipIndex: p.selectedShip,
      aircraft: p.aircraftAssembly,
      supportLevels: p.aircraftSupportLevels,
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: -1,
      armament: p.moduleLoadout.signature,
      seed: 3,
    )
    ..viewportHeight = 760
    ..developerInvincible = true;
}

/// Runs [set] on a stationary unit for [seconds]; returns the weapons fired.
Map<String, int> fire(GameEngine g, List<Emit> set, double seconds) {
  g.shots.clear();
  final unit = Foe(g.position + const Offset(0, -320), 1e9, 0, 40, 3);
  g.enemies
    ..clear()
    ..add(unit);
  final fired = <String, int>{};
  for (var t = 0.0; t < seconds; t += .025) {
    g.runDanmaku(unit, set, .025, damage: 10, limit: 400);
    for (final s in g.shots) {
      if (s.age == 0) fired[s.weapon] = (fired[s.weapon] ?? 0) + 1;
      s.age += .025;
    }
    g.updateDanmaku(.025);
  }
  return fired;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eleven distinct stage bosses, phases follow the reference shares', () {
    expect(BossPatterns.sets.length, 11);
    expect(BossPatterns.sets.map((s) => s.name).toSet().length, 11);
    for (final set in BossPatterns.sets) {
      final total = set.phases.fold(0.0, (a, p) => a + p.share);
      expect(total, closeTo(1, .02), reason: set.name);
      expect(set.phases.length, inInclusiveRange(3, 4), reason: set.name);
    }
    // neighbouring houses never share a boss set
    for (var i = 0; i < 10; i++) {
      expect(
        identical(BossPatterns.forStage(i), BossPatterns.forStage(i + 1)),
        isFalse,
      );
    }
  });

  test('every boss phase actually fires', () async {
    final g = await arena();
    for (final set in BossPatterns.sets) {
      for (final (i, phase) in set.phases.indexed) {
        final fired = fire(g, phase.emits, 12);
        final count = fired.values.fold(0, (a, b) => a + b);
        expect(count, greaterThan(0), reason: '${set.name} P${i + 1}');
      }
    }
  });

  test('six mid-boss types, each on a three-step tempo ladder', () async {
    final g = await arena();
    expect(MidBossPatterns.sets.length, 6);
    for (final (m, ladder) in MidBossPatterns.sets.indexed) {
      expect(ladder.length, 3);
      final counts = [
        for (final tier in ladder)
          fire(g, tier, 10).values.fold(0, (a, b) => a + b),
      ];
      expect(counts.every((c) => c > 0), isTrue, reason: 'M${m + 1}');
      // the crazy step fires at least as much as the base step
      expect(counts[2], greaterThanOrEqualTo(counts[0]), reason: 'M${m + 1}');
    }
  });

  test('spreads are orbs, aimed shots bars, snipes telegraphed', () async {
    final g = await arena();
    expect(fire(g, NormalPatterns.n5, 6)['enemy-orb'], greaterThan(0));
    expect(fire(g, NormalPatterns.n1, 6)['enemy-bullet'], greaterThan(0));
    g.shots.clear();
    final unit = Foe(g.position + const Offset(0, -320), 1e9, 0, 20, 0);
    g.enemies
      ..clear()
      ..add(unit);
    var warned = false;
    for (var t = 0.0; t < 3; t += .025) {
      g.runDanmaku(unit, NormalPatterns.n9, .025, damage: 10, limit: 400);
      g.updateDanmaku(.025);
      if (g.dangerLines.isNotEmpty) warned = true;
      if (g.shots.any((s) => s.weapon == 'enemy-needle')) break;
    }
    expect(warned, isTrue, reason: 'the snipe shows its warning line first');
    expect(g.shots.any((s) => s.weapon == 'enemy-needle'), isTrue);
    // rammers never shoot, miners keep their mines
    expect(NormalPatterns.forRole(EnemyRole.kamikaze, true), isNull);
    expect(NormalPatterns.forRole(EnemyRole.miner, false), isNull);
  });
}
