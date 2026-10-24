import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

// Thirty minutes of simulation per fixture, not thirty minutes of phone use.
void main() {
  test(
    '30 minute boss holds keep state bounded and checkpoint continuation exact',
    () {
      final rows = <Map<String, dynamic>>[];
      for (final world in [4, 9])
        for (final weapon in ['pulse', 'void']) {
          var g =
              GameEngine(
                  stageIndex: world * 10 + 9,
                  shipIndex: 0,
                  attackLevel: 3,
                  hullLevel: 3,
                  magnetLevel: 0,
                  equipmentIndex: 0,
                  armament: weapon,
                  seed: 34,
                )
                ..hp = 1e6
                ..maxHp = 1e6
                ..xpNeeded = 1e9;
          g.upgrades.addAll({
            'gun': 5,
            'drone': 5,
            'missile': 5,
            'trail': 5,
            'lightning': 5,
            'durian': 5,
          });
          g.evolved.addAll(g.upgrades.keys);
          g.mainRate = 5;
          g.mainPower = 5;
          g.mainCount = 4;
          g.passives.addAll({
            'attack': 5,
            'area': 5,
            'cooldown': 5,
            'duration': 5,
            'magnet': 5,
            'armor': 5,
          });
          g.elapsed = g.nextBossAt;
          g.update(.01);
          g.boss!.maxHp = 1e11;
          g.boss!.hp = 2e10; // Hold phase3, including reinforcements.
          final samples = <Map<String, dynamic>>[], times = <int>[];
          var peakEnemies = 0, peakShots = 0, peakMotes = 0, peakCrystals = 0;
          final watch = Stopwatch()..start();
          for (var frame = 0; frame < 36000; frame++) {
            g.input = Offset(math.sin(frame * .002), math.cos(frame * .002));
            if (g.choices.isNotEmpty) g.chooseUpgrade(g.choices.first.id);
            final start = watch.elapsedMicroseconds;
            g.update(.05);
            times.add(watch.elapsedMicroseconds - start);
            peakEnemies = math.max(peakEnemies, g.enemies.length);
            peakShots = math.max(peakShots, g.shots.length);
            peakCrystals = math.max(peakCrystals, g.crystals.length);
            peakMotes = math.max(peakMotes, g.absorbingCrystals.length);
            expect(g.finished, false);
            if (frame % 1200 == 1199) {
              final encoded = jsonEncode(g.checkpoint()),
                  bytes = utf8.encode(encoded).length;
              final copy = BattleCheckpoint.restore(jsonDecode(encoded));
              expect(copy.checkpoint(), g.checkpoint());
              expect(bytes, lessThan(2 * 1024 * 1024));
              samples.add({
                'combat': g.combatTime,
                'bytes': bytes,
                'enemies': g.enemies.length,
                'shots': g.shots.length,
                'crystals': g.crystals.length,
                'motes': g.absorbingCrystals.length,
              });
              if (frame == 17999) {
                // Compare recorded identical actions across an actual mid-run restore.
                for (var i = 0; i < 20; i++) {
                  final input = Offset(math.sin(i * .1), math.cos(i * .1));
                  g.input = copy.input = input;
                  g.update(.025);
                  copy.update(.025);
                }
                expect(copy.checkpoint(), g.checkpoint());
                g = copy;
              }
            }
          }
          times.sort();
          expect(g.combatTime, greaterThanOrEqualTo(1800));
          expect(peakEnemies, lessThanOrEqualTo(g.enemyLimit));
          expect(peakShots, lessThan(1000));
          expect(peakMotes, lessThanOrEqualTo(GameEngine.crystalLimit));
          expect(peakCrystals, lessThanOrEqualTo(GameEngine.crystalLimit));
          rows.add({
            'world': world,
            'weapon': weapon,
            'wallMs': watch.elapsedMilliseconds,
            'simulationSeconds': g.combatTime,
            'updateP95Us': times[(times.length * .95).floor()],
            'peakEnemies': peakEnemies,
            'peakShots': peakShots,
            'peakCrystals': peakCrystals,
            'peakMotes': peakMotes,
            'samples': samples,
          });
        }
      Directory('.local/endurance-v34').createSync(recursive: true);
      File('.local/endurance-v34/engine-soak.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'scope': '4x30 simulation minutes, raised hull and boss health, actual phase3 adds/ordnance/upgrades; Dart test-runtime timings are not web frame times or mobile proof',
          'rows': rows,
        }),
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
