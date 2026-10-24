import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/survival_skills.dart';

// Fixed heuristic with normal hull and naturally acquired upgrades. This bot
// cannot establish human win rates, comfort, or optimal build strength.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('late full runs retain finite state and bounded actors with natural drafts', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.pilotLevel = 30;
    for (var slot = 0; slot < 6; slot++) {
      p.gearAt(slot)
        ..rank = 3
        ..level = 30;
    }
    final rows = <Map<String, dynamic>>[];
    for (final stage in [9, 49, 99]) {
      for (final weapon in ['pulse', 'katana', 'void']) {
        for (final seed in [1, 33]) {
          for (final developed in [false, true]) {
            final g = GameEngine(
              stageIndex: stage,
              armament: weapon,
              shipIndex: 0,
              attackLevel: developed ? 5 : 3,
              hullLevel: developed ? 5 : 3,
              magnetLevel: developed ? 5 : 2,
              equipmentIndex: 0,
              gearDamage: developed ? p.gearDamage + p.pilotDamage : .65,
              gearHull: developed ? p.gearHull + p.pilotHull : .8,
              bonusCooldown: developed ? p.gearCooldown : 0,
              damageReduction: developed ? p.gearReduction : 0,
              armamentLevel: developed ? 5 : 0,
              petKind: 0,
              petLevel: 5,
              seed: seed,
            );
            final initialHp = g.maxHp;
            var enemies = 0, shots = 0;
            for (var frame = 0; frame < 12000 && !g.finished; frame++) {
              if (g.choices.isNotEmpty) {
                int score(UpgradeChoice c) {
                  if (c.evolution) return 120;
                  if (c.id == 'repair') return g.hp < g.maxHp * .6 ? 115 : -1;
                  if (c.specialization) return 105;
                  if (c.id == 'gun') return 100;
                  if (['guardian', 'lightning', 'missile'].contains(c.id))
                    return 90;
                  if (g.missingPartners.contains(c.id)) return 85;
                  if (c.id == 'attack') return 80;
                  return skillFor(c.id).passive ? 30 : 40;
                }

                final choices = g.choices.toList()
                  ..sort((a, b) => score(b).compareTo(score(a)));
                g.chooseUpgrade(choices.first.id);
              }
              var target = g.boss == null
                  ? Offset(
                      900 + 180 * math.cos(g.combatTime * .4),
                      1200 + 210 * math.sin(g.combatTime * .4),
                    )
                  : g.boss!.position + Offset(65 * math.sin(g.combatTime), 150);
              if (g.boss == null) {
                var nearest = 170.0;
                for (final at in [
                  ...g.crystals,
                  ...g.supplies.map((s) => s.position),
                ]) {
                  final distance = (at - g.position).distance;
                  if (distance < nearest) {
                    nearest = distance;
                    target = at;
                  }
                }
              }
              if (g.hazardVisible && g.hazardHits(target)) {
                final safe =
                    <Offset>[
                          for (var x = -180; x <= 180; x += 60)
                            for (var y = -180; y <= 180; y += 60)
                              g.hazardCenter +
                                  Offset(x.toDouble(), y.toDouble()),
                        ]
                        .where(
                          (at) =>
                              at.dx >= 32 &&
                              at.dx <= 1768 &&
                              at.dy >= 32 &&
                              at.dy <= 2368 &&
                              !g.hazardHits(at),
                        )
                        .toList()
                      ..sort(
                        (a, b) => (a - g.position).distanceSquared.compareTo(
                          (b - g.position).distanceSquared,
                        ),
                      );
                if (safe.isNotEmpty) target = safe.first;
              }
              var steer = target - g.position;
              if (steer.distance > 1) steer /= steer.distance;
              for (final e in g.enemies) {
                final away = g.position - e.position;
                if (away.distance < 65 && away.distance > .01) {
                  steer += away / away.distance * (65 - away.distance) / 18;
                }
              }
              g.input = steer;
              if (g.ultimateReady) g.activateCommonUltimate();
              g.update(.05);
              enemies = math.max(enemies, g.enemies.length);
              shots = math.max(shots, g.shots.length);
            }
            rows.add({
              'stage': stage,
              'account': developed ? 'developed' : 'moderate',
              'initialMaxHp': initialHp,
              'maxHpAtEnd': g.maxHp,
              'weapon': weapon,
              'seed': seed,
              'victory': g.victory,
              'finished': g.finished,
              'hp': g.hp,
              'chapterSeconds': g.elapsed,
              'combatSeconds': g.combatTime,
              'level': g.level,
              'firstEvolution': g.firstEvolutionAt,
              'evolved': g.evolved.toList(),
              'bosses': g.bossesDefeated,
              'peakEnemies': enemies,
              'peakShots': shots,
              'damageTaken': g.damageTakenBySource,
              'lastDamage': g.lastDamageSource,
            });
            expect(g.hp.isFinite, true);
            expect(enemies, lessThanOrEqualTo(g.enemyLimit));
            expect(shots, lessThan(1000));
            expect(
              g.finished,
              true,
              reason:
                  '$stage/$weapon/$seed must resolve within 600 simulation seconds',
            );
          }
        }
      }
    }
    p.dispose();
    Directory('.local/balance-v33').createSync(recursive: true);
    File('.local/balance-v33/full-runs.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'scope':
            '36 normal-hull, natural-draft fixed-heuristic runs; moderate attack/hull3, magnet2, '
            'gearDamage.65/gearHull.8; developed uses actual profile stats from six rank3 level30 gear '
            'and pilot30, research5, armament5; pet0 level5; input always active, automatic '
            'ultimate, near-loot collection and field avoidance; no boss telegraph '
            'evasion policy; not human win rate or release difficulty approval',
        'rows': rows,
      }),
    );
  }, timeout: const Timeout(Duration(seconds: 90)));
}
