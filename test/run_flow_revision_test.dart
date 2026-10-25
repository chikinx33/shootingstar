import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/game/engine.dart';

import 'support/run_driver.dart';

GameEngine flowArena(int seed, bool developed) => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  aircraft: AircraftAssembly.initial(0),
  attackLevel: developed ? 3 : 0,
  hullLevel: developed ? 3 : 0,
  magnetLevel: developed ? 5 : 0,
  equipmentIndex: 0,
  gearDamage: developed ? .9 : 0,
  gearHull: developed ? .65 : 0,
  bonusPickup: developed ? .7 : 0,
  damageReduction: developed ? .15 : 0,
  seed: seed,
);

void main() {
  test('compare stationary and active full-speed run flow', () {
    final rows = <Map<String, dynamic>>[];
    for (final developed in [false, true]) {
      for (final active in [false, true]) {
        for (final seed in [11, 31]) {
          final g = flowArena(seed, developed);
          double? bossStart, firstDraft;
          var bossSeconds = 0.0, peak = 0, drafts = 0;
          final draftTimes = <double>[], patterns = <int>{};
          var minimumHp = 1.0;
          for (var frame = 0; frame < 16000 && !g.finished; frame++) {
            if (g.choices.isNotEmpty) {
              final choices = g.choices.toList()
                ..sort(
                  (a, b) => choiceScore(g, b).compareTo(choiceScore(g, a)),
                );
              firstDraft ??= g.combatTime;
              draftTimes.add(g.combatTime);
              g.chooseUpgrade(choices.first.id);
              drafts++;
            }
            g.input = active ? steer(g) : Offset.zero;
            g.update(.025);
            minimumHp = math.min(minimumHp, g.hp / g.maxHp);
            if (g.boss != null) {
              bossStart ??= g.combatTime;
              patterns.add(g.bossPattern);
            }
            if (g.boss == null && bossStart != null) {
              bossSeconds += g.combatTime - bossStart;
              bossStart = null;
            }
            peak = math.max(peak, g.crystals.length);
          }
          final row = {
            'developed': developed,
            'active': active,
            'seed': seed,
            'finished': g.finished,
            'victory': g.victory,
            'time': g.combatTime,
            'level': g.level,
            'drafts': drafts,
            'firstDraft': firstDraft,
            'draftTimes': draftTimes,
            'kills': g.kills,
            'minimumHp': minimumHp,
            'bossPatterns': patterns.toList(),
            'bossAttacks': g.bossAttacks,
            'hpFraction': g.hp / g.maxHp,
            'peakCrystals': peak,
            'bossSeconds': bossSeconds,
            'damage': g.damageTakenBySource,
          };
          rows.add(row);
          print('FLOW ${jsonEncode(row)}');
        }
      }
    }
    Directory('.local/run-v62').createSync(recursive: true);
    final label = Platform.environment['FLOW_LABEL'] ?? 'after';
    File('.local/run-v62/$label.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
    if (label == 'after') {
      expect(
        rows.where((r) => r['active'] == false && r['victory'] == true),
        isEmpty,
      );
      final active = rows.where((r) => r['active'] == true);
      expect(active.every((r) => r['victory'] == true), true);
      // v12.9.1/v12.9.7: calmer level-ups (first level 60 XP, then
      // 60 + level * 16; house gems 4, wiped formation 8) mean fewer, later
      // drafts than the v10.0.62 18 XP curve. v12.5.2 removed the hidden
      // 8-second wait between drafts: every level opens exactly one draft.
      for (final row in active) {
        expect(row['level'], inInclusiveRange(5, 10));
        expect(row['firstDraft'], inInclusiveRange(20, 70));
        expect(row['drafts'], (row['level'] as int) - 1);
        expect(row['bossSeconds'], inInclusiveRange(8, 80));
        expect(row['peakCrystals'], lessThan(100));
        expect(row['bossPatterns'].length, 3);
      }
    }
  });
}
