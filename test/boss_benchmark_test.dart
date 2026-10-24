import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

// Controlled DPS fixture: player hull is raised to isolate outgoing damage.
// Full-run survival is tested separately without this fixture assistance.
void main() {
  test('matched boss loadouts across chapters and account bands', () {
    final rows = <Map<String, dynamic>>[];
    for (final stage in [0, 1, 2]) {
      for (final band in ['basic', 'evolved', 'strong']) {
        for (final seed in [0, 1, 2]) {
          final g = GameEngine(
            stageIndex: stage,
            shipIndex: 0,
            attackLevel: band == 'strong' ? 3 : 0,
            hullLevel: 0,
            magnetLevel: 0,
            equipmentIndex: 0,
            seed: seed,
            gearDamage: band == 'strong' ? .65 : .05,
            bonusCooldown: band == 'strong' ? .12 : 0,
          );
          final weapons = band == 'basic'
              ? ['gun', 'missile']
              : ['gun', 'missile', 'drone', 'lightning', 'guardian', 'trail'];
          g.upgrades
            ..clear()
            ..addEntries(
              weapons.map((id) => MapEntry(id, band == 'basic' ? 3 : 5)),
            );
          if (band != 'basic') {
            g.evolved.addAll(weapons);
            g.passives.addAll({
              'attack': 5,
              'area': 5,
              'cooldown': 5,
              'xp': 5,
              'duration': 5,
              'magnet': 5,
            });
          }
          g.hp = g.maxHp = 100000;
          g.elapsed = g.nextBossAt;
          g.update(.05);
          final start = g.combatTime;
          final phases = <int>{};
          int projectileFrames = 0;
          for (int n = 0; n < 2400 && g.bossesDefeated == 0; n++) {
            final boss = g.boss;
            if (boss == null) break;
            phases.add(g.bossPhase);
            // Track below the boss, strafe across the forward firing lane.
            final target =
                boss.position + Offset(85 * math.sin(g.combatTime * 1.1), 180);
            g.input = target - g.position;
            g.choices.clear();
            g.update(.05);
            if (g.shots.any((s) => s.kind == 4)) projectileFrames++;
          }
          rows.add({
            'stage': stage,
            'band': band,
            'seed': seed,
            'seconds': g.combatTime - start,
            'defeated': g.bossesDefeated > 0,
            'phases': phases.toList(),
            'attacks': g.bossAttacks,
            'projectileFrames': projectileFrames,
            'damage': g.damageByWeapon,
          });
          expect(g.hp.isFinite, true);
          expect(g.bossesDefeated, 1, reason: '$stage/$band/$seed must finish');
          expect(phases, {0, 1, 2});
          expect(g.bossAttacks, greaterThanOrEqualTo(3));
          expect(g.combatTime - start, inInclusiveRange(9.6, 90));
        }
      }
    }
    const label = String.fromEnvironment(
      'BOSS_BENCH_LABEL',
      defaultValue: 'after',
    );
    final dir = Directory('tools/qa/evidence/run-v62')
      ..createSync(recursive: true);
    File('${dir.path}/boss-$label.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  });
}
