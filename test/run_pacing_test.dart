import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/experience_crystals.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine quietArena({int world = 0}) {
  final source = GameEngine(
    stageIndex: world * 10,
    shipIndex: 0,
    attackLevel: 0,
    hullLevel: 0,
    magnetLevel: 0,
    equipmentIndex: 0,
    seed: 62,
  );
  final data = source.checkpoint(), state = data['state'] as Map;
  for (final key in [
    '_spawn',
    '_flightFormationClock',
    '_formationClock',
    '_supplyClock',
    '_mainClock',
    '_magnetClock',
  ]) {
    state[key] = 1e6;
  }
  state['_lastEncounter'] = 0;
  return BattleCheckpoint.restore(jsonDecode(jsonEncode(data)))
    ..upgrades.clear();
}

void main() {
  test('a full gauge keeps opening drafts and survives pause and resume', () {
    final g = quietArena()..xp = 1000;
    g.crystals.add(ExperienceCrystal.at(g.position, 1));
    g.update(.025);
    expect(g.level, 2);
    g.chooseUpgrade(g.choices.first.id);
    // Still a full bar: the next draft opens right after the choice.
    expect(g.level, 3);
    expect(g.choices, isNotEmpty);
    final saved = BattleCheckpoint.restore(
      jsonDecode(jsonEncode(g.checkpoint())),
    );
    expect(saved.choices.map((c) => c.id), g.choices.map((c) => c.id));
    saved.setPaused(true);
    for (var i = 0; i < 40; i++) {
      saved.update(.025);
    }
    expect(saved.level, 3);
    expect(saved.xp, greaterThan(900)); // Excess XP stays banked.
    // Saves from before v12.5.2 still carry the retired growth clock.
    final legacy = g.checkpoint();
    (legacy['state'] as Map)['nextGrowthAt'] = 42.0;
    expect(BattleCheckpoint.restore(legacy).level, 3);
  });

  test(
    'pickup upgrades stay local; magnets leave distant resources untouched',
    () {
      final g = quietArena()..xpNeeded = 1e9;
      g.crystals.addAll([
        ExperienceCrystal.at(g.position + const Offset(200, 0), 8),
        ExperienceCrystal.at(g.position + const Offset(500, 0), 16),
      ]);
      g.supplies.add(Supply(g.position, 1));
      g.update(.025);
      expect(g.crystals.length, 1);
      expect(ExperienceCrystal.valueOf(g.crystals.single), 16);
      for (var i = 0; i < 80; i++) {
        g.update(.025);
      }
      expect(g.xp, 8);
      final upgraded = GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 30,
        equipmentIndex: 2,
        bonusPickup: 4,
      )..passives['magnet'] = 5;
      expect(upgraded.collectionRadius, lessThanOrEqualTo(112));
      expect(upgraded.collectionRadius, greaterThan(g.collectionRadius));
    },
  );

  test('bomb is a local tool, not a global kill or boss skip', () {
    final g = quietArena();
    final near = Foe(g.position + const Offset(120, 0), 500, 0, 10, 0);
    final far = Foe(g.position + const Offset(400, 0), 500, 0, 10, 0);
    g.enemies.addAll([near, far]);
    g.supplies.add(Supply(g.position, 2));
    g.update(.025);
    expect(near.hp, 260);
    expect(far.hp, 500);
  });

  test(
    'all world bosses rotate three distinct attacks without needing HP loss',
    () {
      for (var world = 0; world < 10; world++) {
        final g = quietArena(world: world)..developerInvincible = true;
        g.elapsed = g.nextBossAt;
        final seen = <int>{};
        for (var i = 0; i < 720; i++) {
          g.update(.025);
          seen.add(g.bossPattern);
        }
        expect(seen.length, 3, reason: 'world $world');
        expect(g.bossAttacks, greaterThanOrEqualTo(3));
      }
    },
  );

  test(
    'radial warning always offers an in-bounds exit away from locked aim',
    () {
      for (final at in [
        const Offset(32, 32),
        const Offset(1768, 32),
        const Offset(32, 2368),
        const Offset(1768, 2368),
      ]) {
        final g = quietArena()..position = at;
        g.elapsed = g.nextBossAt;
        g.update(.025);
        final exit = g.bossOrigin + g.bossSafeDirection * 180;
        expect(exit.dx, inInclusiveRange(34, 1766));
        expect(exit.dy, inInclusiveRange(34, 2366));
        final dot =
            g.bossSafeDirection.dx * g.bossAim.dx +
            g.bossSafeDirection.dy * g.bossAim.dy;
        expect(dot, lessThan(math.cos(.42)));
      }
    },
  );

  test(
    'reading boss tells and moving avoids more damage than standing still',
    () {
      final damage = <double>[];
      for (final evade in [false, true]) {
        final g = quietArena();
        g.elapsed = g.nextBossAt;
        var target = g.position;
        for (var i = 0; i < 2000 && !g.finished; i++) {
          if (evade && g.boss != null && g.bossWarning && g.bossCycle > .2) {
            final normal = Offset(-g.bossAim.dy, g.bossAim.dx);
            target = switch (g.bossPattern) {
              0 => g.bossOrigin + g.bossSafeDirection * 180,
              1 || 2 => g.bossTarget + normal * 130,
              _ => g.position,
            };
          }
          final delta = target - g.position;
          g.input = evade && delta.distance > 5
              ? delta / math.max(1, delta.distance)
              : Offset.zero;
          g.update(.025);
        }
        damage.add(g.damageTakenBySource.values.fold(0, (a, b) => a + b));
      }
      print('BOSS_DODGE stationary=${damage[0]} evading=${damage[1]}');
      expect(damage[0], greaterThan(50));
      expect(damage[1], lessThan(damage[0] * .7));
    },
  );
  test(
    'closing mines threaten the center and leave their displayed exit open',
    () {
      for (final leave in [false, true]) {
        final g = quietArena(world: 5);
        g.elapsed = g.nextBossAt;
        g.update(.025);
        expect(g.bossPattern, 5);
        final center = g.bossTarget;
        if (leave) g.position = center + g.bossMineExit * 160;
        for (var i = 0; i < 125; i++) {
          g.update(.025);
        }
        expect(
          g.damageTakenBySource['기뢰'] ?? 0,
          leave ? equals(0) : greaterThan(0),
        );
      }
    },
  );
  test('boss recovery moves smoothly away from the bottom flight boundary', () {
    final g = quietArena()..position = const Offset(900, 2350);
    g.elapsed = g.nextBossAt;
    g.update(.025);
    g.boss!.position = const Offset(900, 2366);
    g.bossCycle = 2.3;
    final from = g.boss!.position;
    g.update(.025);
    expect((g.boss!.position - from).distance, lessThanOrEqualTo(5.001));
    for (var i = 0; i < 34; i++) {
      g.update(.025);
    }
    expect(g.position.dy - g.boss!.position.dy, greaterThan(150));
  });
}
