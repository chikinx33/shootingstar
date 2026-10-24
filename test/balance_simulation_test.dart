import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/survival_skills.dart';

// Synthetic collection policy, not human play or a claimed player win-rate.
void main() {
  test('seeded chapter-one account and movement comparison', () {
    final rows = <Map<String, dynamic>>[];
    for (final account in ['starter', 'mid']) {
      for (final policy in ['idle', 'collect', 'evade']) {
        for (int seed = 0; seed < 3; seed++) {
          final g = GameEngine(
            stageIndex: 0,
            shipIndex: 0,
            attackLevel: account == 'mid' ? 3 : 0,
            hullLevel: account == 'mid' ? 3 : 0,
            magnetLevel: 0,
            equipmentIndex: 0,
            gearDamage: account == 'mid' ? .65 : .05,
            gearHull: account == 'mid' ? .8 : .04,
            petKind: 0,
            petLevel: account == 'mid' ? 5 : 1,
            seed: seed,
          );
          int peakEnemies = 0, peakShots = 0;
          for (int frame = 0; frame < 18000 && !g.finished; frame++) {
            if (g.choices.isNotEmpty) {
              final choices = g.choices.toList();
              int score(UpgradeChoice c) {
                if (c.evolution) return 100;
                if (c.id == 'repair') return g.hp < g.maxHp * .5 ? 75 : -1;
                if (c.specialization) return 75;
                if (c.id == 'hull' && g.hp < g.maxHp * .5) return 80;
                if (c.id == 'attack' && !g.passives.containsKey('attack')) {
                  return 85;
                }
                if (c.id == 'gun') return 90;
                if ([
                  'guardian',
                  'lightning',
                  'missile',
                  'trail',
                ].contains(c.id)) {
                  return 70;
                }
                if (g.missingPartners.contains(c.id)) return 65;
                return skillFor(c.id).passive ? 30 : 40;
              }

              choices.sort((a, b) => score(b).compareTo(score(a)));
              g.chooseUpgrade(choices.first.id);
            }
            if (policy == 'collect') {
              final targets = <Offset>[
                ...g.supplies.map((s) => s.position),
                ...g.crystals,
              ];
              Offset? closest;
              double distance = double.infinity;
              for (final target in targets) {
                final d = (target - g.position).distanceSquared;
                if (d < distance) {
                  distance = d;
                  closest = target;
                }
              }
              g.input = closest == null ? Offset.zero : closest - g.position;
            }
            if (policy == 'evade') {
              var target = Offset(
                900 + 130 * math.cos(g.combatTime * .65),
                1200 + 225 * math.sin(g.combatTime * .65),
              );
              double nearest = 130;
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
              var steer = target - g.position;
              if (steer.distance > 1) steer /= steer.distance;
              for (final e in g.enemies) {
                final away = g.position - e.position;
                if (away.distance < 65 && away.distance > .01) {
                  steer += away / away.distance * (65 - away.distance) / 18;
                }
              }
              g.input = steer;
            }
            g.update(.05);
            if (g.enemies.length > peakEnemies) peakEnemies = g.enemies.length;
            if (g.shots.length > peakShots) peakShots = g.shots.length;
          }
          rows.add({
            'account': account,
            'policy': policy,
            'seed': seed,
            'victory': g.victory,
            'finished': g.finished,
            'chapterSeconds': g.elapsed,
            'combatSeconds': g.combatTime,
            'firstEvolutionSeconds': g.firstEvolutionAt,
            'level': g.level,
            'kills': g.kills,
            'bosses': g.bossesDefeated,
            'evolved': g.evolved.toList(),
            'damage': g.damageByWeapon,
            'peakEnemies': peakEnemies,
            'peakShots': peakShots,
          });
          expect(g.enemies.length, lessThanOrEqualTo(g.enemyLimit));
          expect(peakShots, lessThan(1000));
          expect(g.hp.isFinite, true);
        }
      }
    }
    final out = Directory('tools/qa/evidence/campaign-v5')
      ..createSync(recursive: true);
    File('${out.path}/simulation.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
