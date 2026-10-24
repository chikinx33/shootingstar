import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';

// Local-only synthetic checkpoints for the production-entrypoint browser flow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('normal-profile flow and long boss fixtures restore paused without payout', () async {
    Directory('.local/endurance-v34').createSync(recursive: true);
    for (final soak in [false, true]) {
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.onboarded = true;
      p.soundEnabled = false;
      p.runs = 10;
      p.selectedStage = soak ? 99 : 0;
      if (soak) p.clearedStages.addAll(List.generate(99, (i) => i));
      final g =
          GameEngine(
              stageIndex: p.selectedStage,
              shipIndex: 0,
              attackLevel: 3,
              hullLevel: 3,
              magnetLevel: 0,
              equipmentIndex: 0,
              seed: 34,
              gearDamage: .65,
              gearHull: .8,
            )
            ..hp = 1e6
            ..maxHp = 1e6
            ..elapsed = soak ? 80 : 170
            ..combatTime = soak ? 80 : 170
            ..kills = 300;
      g.mainRate = 5;
      g.mainPower = 5;
      g.mainCount = 4;
      g.upgrades.addAll({
        'gun': 5,
        'drone': 5,
        'missile': 5,
        'trail': 5,
        'lightning': 5,
        'durian': 5,
      });
      g.evolved.addAll(g.upgrades.keys);
      g.passives.addAll({
        'attack': 5,
        'area': 5,
        'cooldown': 5,
        'duration': 5,
        'magnet': 5,
        'armor': 5,
      });
      if (soak) {
        // Leave the ring outside pickup range to exercise the long-lived field
        // and its overflow budget throughout the real-time browser run.
        g.passives.remove('magnet');
        g.xpNeeded = 1e9;
        g.update(.01);
        g.boss!.maxHp = 1e11;
        g.boss!.hp = 2e10;
        for (var i = 0; i < 1300; i++)
          g.crystals.add(
            g.position + Offset(math.cos(i * .1) * 180, math.sin(i * .1) * 180),
          );
      } else {
        g.xp = 38; // Two queued drafts: specialize, then exercise reroll.
      }
      final id = soak ? 'endurance-long-v34' : 'endurance-flow-v34';
      expect(await p.checkpointBattle(id, g), true);
      final prefs = await SharedPreferences.getInstance();
      File('.local/endurance-v34/${soak ? 'soak' : 'flow'}-profile.json')
          .writeAsStringSync(prefs.getString(Profile.storageKey)!);
      final copy = p.restoreBattle()!;
      expect(copy.runId, id);
      expect(copy.game.paused, true);
      expect(copy.game.input, Offset.zero);
      expect(p.credits, 150);
      expect(p.runs, 10);
      expect(copy.game.checkpoint()['config'], g.checkpoint()['config']);
      await p.save();
      p.dispose();
    }
  });
}
