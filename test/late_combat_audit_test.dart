import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine fixture(int stage, int loop, {String weapon = 'pulse'}) {
  final initial = GameEngine(
    stageIndex: stage,
    campaignLoop: loop,
    armament: weapon,
    shipIndex: 0,
    attackLevel: 3,
    hullLevel: 0,
    magnetLevel: 0,
    equipmentIndex: 0,
    gearDamage: .65,
    seed: 33,
  );
  final data = initial.checkpoint(), state = data['state'] as Map;
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
  return BattleCheckpoint.restore(jsonDecode(jsonEncode(data)))..xpNeeded = 1e9;
}

void main() {
  test(
    'late-route final bosses with matched legal main and auxiliary builds',
    () {
      final rows = <Map<String, dynamic>>[];
      for (final stage in [9, 49, 99]) {
        for (final loop in [0, 3]) {
          for (final weapon in armaments) {
            for (final auxiliary in [false, true]) {
              var g = fixture(stage, loop, weapon: weapon.id);
              g.upgrades['gun'] = 5;
              g.evolved.add('gun');
              g.mainRate = 3;
              g.mainPower = 3;
              g.mainCount = 2;
              g.passives.addAll({'attack': 3, 'area': 3, 'cooldown': 3});
              if (auxiliary) {
                g.upgrades.addAll({
                  'missile': 5,
                  'lightning': 5,
                  'guardian': 5,
                });
                g.passives.addAll({'duration': 3});
                g.evolved.addAll(['missile', 'lightning', 'guardian']);
              }
              final data = g.checkpoint(), state = data['state'] as Map;
              state['_bossWave'] = 2;
              state['bossesDefeated'] = 2;
              g = BattleCheckpoint.restore(jsonDecode(jsonEncode(data)));
              g.hp = g.maxHp =
                  1e6; // Outgoing damage fixture, not survival proof.
              g.elapsed = g.nextBossAt;
              g.update(.025);
              final health = g.boss!.maxHp, start = g.combatTime;
              final phases = <int>{};
              var peak = 0;
              for (
                var frame = 0;
                frame < 4800 && g.bossesDefeated < 3;
                frame++
              ) {
                phases.add(g.bossPhase);
                // Perfect tracking isolates damage at a fixed range.
                // No ultimate, consumables, branch, tech, pet, or kill stacks.
                g.position = g.boss!.position + const Offset(0, 150);
                g.movementAngle = -math.pi / 2;
                g.choices.clear();
                g.update(.025);
                peak = math.max(peak, g.shots.length);
              }
              rows.add({
                'stage': stage,
                'loop': loop,
                'weapon': weapon.id,
                'auxiliary': auxiliary,
                'bossHp': health,
                'seconds': g.combatTime - start,
                'defeated': g.bossesDefeated == 3,
                'attacks': g.bossAttacks,
                'phases': phases.toList(),
                'peakShots': peak,
                'damage': g.damageByWeapon,
              });
              expect(g.hp.isFinite, true);
              expect(
                g.bossesDefeated,
                3,
                reason: '$stage/$loop/${weapon.id}/$auxiliary final boss',
              );
              expect(phases, {0, 1, 2});
              expect(g.bossAttacks, greaterThanOrEqualTo(3));
              expect(g.combatTime - start, inInclusiveRange(9.6, 75));
              expect(peak, lessThan(1000));
              expect(g.enemies.length, lessThanOrEqualTo(g.enemyLimit));
            }
          }
        }
      }
      const label = String.fromEnvironment(
        'LATE_AUDIT_LABEL',
        defaultValue: 'after',
      );
      final dir = Directory('.local/run-v62/late')..createSync(recursive: true);
      File('${dir.path}/boss-$label.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'scope':
              '120 final-boss outgoing-damage fixtures, fixed seed33, same permanent '
              'attack3/gear.65, gun5 EVO R3P3N2, attack/area/cooldown3, perfect tracking '
              'and raised hull; optional missile/lightning/guardian5 EVO+duration3; '
              'not a human win rate or full-run build acquisition test',
          'rows': rows,
        }),
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
