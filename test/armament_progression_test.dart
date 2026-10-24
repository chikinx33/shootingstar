import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/armament_collection.dart';
import 'package:shootingstar/data/combat_loadout.dart';
import 'package:shootingstar/data/hangar_preset.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle_statistics.dart';

GameEngine arena(String weapon, int level) => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  armament: weapon,
  armamentLevel: level,
  seed: 17,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('fresh ownership, locked selection and paid unlock survive reload without duplicate spending', () async {
    final p = await Profile.load();
    expect(p.armamentCollection.toJson(), {'pulse': 0});
    p.selectArmament(5);
    expect(p.selectedArmament, 0);
    expect(p.unlockArmament('revolver'), false);
    p.credits = 1000;
    p.blueprints = 10;
    expect(p.unlockArmament('revolver'), true);
    expect([p.credits, p.blueprints], [700, 7]);
    expect(p.unlockArmament('revolver'), false);
    expect(p.unlockArmament('unknown'), false);
    p.selectArmament(5);
    await p.save();
    final restored = await Profile.load();
    expect(restored.selectedArmament, 5);
    expect(restored.armamentCollection.toJson(), {'pulse': 0, 'revolver': 0});
    expect([restored.credits, restored.blueprints], [700, 7]);
  });
  test('legacy profile keeps all ten choices, preset identity and raw one-time backup', () async {
    final old = Profile.freshProgress()
      ..remove('armamentProgressionVersion')
      ..remove('armamentCollection');
    old['selectedArmament'] = 9;
    old['credits'] = 777;
    final raw = jsonEncode(old);
    SharedPreferences.setMockInitialValues({Profile.storageKey: raw});
    final p = await Profile.load();
    expect(p.armamentCollection.ownedCount, 10);
    expect(p.selectedArmament, 9);
    expect(p.credits, 777);
    expect(p.activeArmamentLevel, 0);
    final prefs = await SharedPreferences.getInstance();
    final backupKey = '${Profile.storageKey}.beforeArmamentProgression';
    expect(prefs.getString(backupKey), raw);
    p.selectArmament(2);
    await p.save();
    final again = await Profile.load();
    expect(again.armamentCollection.ownedCount, 10);
    expect(prefs.getString(backupKey), raw);
    final beforeContent = p.exportProgress()['content'] as Map;
    final afterContent = again.exportProgress()['content'] as Map;
    // Existing activity clocks and daily shop defaults normalize on load.
    for (final key in ['inventory', 'advancedEquipment', 'collections']) {
      expect(afterContent[key], beforeContent[key]);
    }
  });
  test('per-weapon reinforcement is bounded, atomic and fully refundable with no minting', () async {
    final p = await Profile.load();
    p.credits = 10000;
    p.blueprints = 100;
    p.unlockArmament('shotgun');
    final beforeC = p.credits, beforeB = p.blueprints;
    for (int i = 0; i < 10; i++) {
      expect(p.upgradeArmament('shotgun', expectedLevel: i), true);
    }
    expect(p.armamentCollection.level('pulse'), 0);
    expect(p.armamentCollection.level('shotgun'), 10);
    expect(ArmamentCollection.damageBonus(10), .2);
    expect(p.upgradeArmament('shotgun', expectedLevel: 10), false);
    expect(p.upgradeArmament('kunai', expectedLevel: 0), false);
    p.selectArmament(4);
    p.hangarPresets[0] = HangarPreset.capture(p, '산탄');
    await p.save();
    final restored = await Profile.load();
    expect(restored.activeArmamentLevel, 10);
    expect(restored.hangarPresets[0]!.apply(restored), true);
    expect(restored.resetArmament('shotgun', expectedLevel: 10), true);
    expect(restored.resetArmament('shotgun', expectedLevel: 10), false);
    expect([restored.credits, restored.blueprints], [beforeC, beforeB]);
    expect(restored.selectedArmament, 4);
    expect(restored.armamentCollection.owns('shotgun'), true);
    expect(restored.hangarPresets[0]!.issue(restored), isNull);
  });
  test('insufficient currency, stale decisions and refund overflow cannot partially change a save', () async {
    final p = await Profile.load();
    p.credits = 1000;
    p.blueprints = 0;
    final before = p.exportProgress();
    expect(p.upgradeArmament('pulse', expectedLevel: 0), false);
    expect(p.exportProgress(), before);
    p.blueprints = 10;
    expect(p.upgradeArmament('pulse', expectedLevel: 0), true);
    final paid = p.exportProgress();
    expect(p.upgradeArmament('pulse', expectedLevel: 0), false);
    expect(p.resetArmament('pulse', expectedLevel: 0), false);
    expect(p.exportProgress(), paid);
    p.credits = 9999999;
    expect(p.resetArmament('pulse', expectedLevel: 1), false);
    expect(p.armamentCollection.level('pulse'), 1);
    expect(p.blueprints, 9);
  });
  test('malformed ownership is normalized and account replacement never merges paid power', () async {
    final p = await Profile.load();
    final raw = Profile.freshProgress();
    raw['armamentCollection'] = {
      'pulse': -1,
      'kunai': 999,
      'katana': 3.5,
      'bat': '9',
      'shotgun': 4,
      'injected': 10,
    };
    raw['selectedArmament'] = 9;
    await p.replaceProgress(raw);
    expect(p.armamentCollection.toJson(), {
      'pulse': 0,
      'kunai': 10,
      'shotgun': 4,
    });
    expect(p.selectedArmament, 0);
    p.hangarPresets[0] = HangarPreset.capture(p, '펄스');
    p.selectedArmament = 5;
    final locked = HangarPreset.capture(p, '미보유');
    final before = p.exportProgress();
    expect(locked.apply(p), false);
    expect(p.exportProgress(), before);
    await p.replaceProgress(Profile.freshProgress());
    expect(p.armamentCollection.toJson(), {'pulse': 0});
    expect(p.activeArmamentLevel, 0);
    expect(p.hangarPresets[0], isNull);
  });
  test('legacy cloud replacement gets compensation while fresh export retains its ownership marker', () async {
    final p = await Profile.load();
    final old = Profile.freshProgress()
      ..remove('armamentProgressionVersion')
      ..remove('armamentCollection');
    old['selectedArmament'] = 7;
    await p.replaceProgress(old);
    expect(p.activeArmamentIndex, 7);
    expect(p.armamentCollection.ownedCount, 10);
    expect(p.exportProgress()['armamentProgressionVersion'], 1);
    expect(Profile.freshProgress()['armamentCollection'], {'pulse': 0});
  });
  for (final weapon in armaments) {
    for (final evolved in [false, true]) {
      test(
        '${weapon.id} evolved=$evolved receives exactly 20% permanent main damage through its real attack path',
        () {
          final scores = <double>[];
          for (final level in [0, 10]) {
            final g = arena(weapon.id, level);
            g.mainCount = 2;
            g.mainPower = 2;
            g.soulStacks = 10;
            if (evolved) g.evolved.add('gun');
            final target = Foe(
              g.position + const Offset(0, -80),
              100000,
              0,
              12,
              0,
            );
            g.enemies.add(target);
            g.update(.001);
            final shotDamage = g.shots
                .where((s) => !s.hostile)
                .fold(0.0, (n, s) => n + s.damage);
            // Exclude overkill-capped damage to random low-HP spawns.
            scores.add(shotDamage + target.maxHp - target.hp);
            expect([g.mainRate, g.mainPower, g.mainCount], [0, 2, 2]);
            final snap = BattleStatisticsSnapshot.fromGame(g);
            expect(snap.armamentLevel, level);
          }
          expect(scores.first, greaterThan(0));
          expect(scores.last, closeTo(scores.first * 1.2, .001));
        },
      );
    }
  }
  test('reinforcement never increases global damage, auxiliary weapons or ultimate and does not pre-evolve a run', () {
    final scores = <double>[];
    for (final level in [0, 10]) {
      final g = arena('pulse', level);
      expect(g.damageFactor, arena('pulse', 0).damageFactor);
      expect([g.mainRate, g.mainPower, g.mainCount], [0, 0, 0]);
      expect(g.evolved, isEmpty);
      g.upgrades.clear();
      g.upgrades['missile'] = 1;
      g.enemies.add(Foe(g.position + const Offset(0, -100), 100000, 0, 12, 0));
      g.update(.001);
      scores.add(g.shots.where((s) => s.weapon == 'missile').first.damage);
    }
    expect(scores[0], scores[1]);
    expect(arena('pulse', -999).armamentLevel, 0);
    expect(arena('pulse', 999).armamentLevel, 10);
  });
}
