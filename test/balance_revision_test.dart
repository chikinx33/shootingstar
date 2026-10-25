import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine game() => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 42,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'short losses retain salvage but full clear beats repeated early returns',
    () async {
      final short = await Profile.load(), long = await Profile.load();
      for (int i = 0; i < 6; i++) {
        short.completeRun(
          victory: false,
          stageIndex: 0,
          kills: 10,
          level: 2,
          seconds: 30,
          training: false,
          runId: 'short-$i',
        );
      }
      long.completeRun(
        victory: true,
        stageIndex: 0,
        kills: 200,
        level: 15,
        seconds: 180,
        bossesDefeated: 1,
        training: false,
        runId: 'clear',
      );
      expect(short.inventory.length - 6, 1);
      expect(long.inventory.length - 6, 3);
      expect(long.credits, greaterThan(short.credits));
      expect(long.blueprints, greaterThan(short.blueprints));
      expect(long.petFood, greaterThan(short.petFood));
      final before = jsonEncode(long.exportProgress());
      long.completeRun(
        victory: true,
        stageIndex: 0,
        kills: 200,
        level: 15,
        seconds: 180,
        bossesDefeated: 1,
        training: false,
        runId: 'clear',
      );
      expect(jsonEncode(long.exportProgress()), before);
    },
  );
  test('legacy progress is preserved and rare-tech reward cannot repeat after reload', () async {
    final original = await Profile.load();
    original.credits = 9999;
    original.blueprints = 55;
    original.gearAt(0)
      ..level = 12
      ..rank = 3
      ..spentCredits = 1680
      ..spentPlans = 12
      ..locked = true;
    original.techStock[4][3] = 2;
    original.petLevels[0] = 9;
    original.clearedStages.add(0);
    final legacy = original.exportProgress();
    final content = legacy['content'] as Map;
    content.remove('salvageSeconds');
    content.remove('starterTechUnlocked');
    content.remove('starterTechClaimed');
    SharedPreferences.setMockInitialValues({
      Profile.storageKey: jsonEncode(legacy),
    });
    final migrated = await Profile.load();
    expect(migrated.credits, 9999);
    expect(migrated.blueprints, 55);
    expect(migrated.gearAt(0).toJson(), original.gearAt(0).toJson());
    expect(migrated.techStock[4][3], 2);
    expect(migrated.petLevels[0], 9);
    expect(migrated.starterTechUnlocked, true);
    expect(migrated.claimStarterTech(0), true);
    expect(migrated.techStock[0][2], 1);
    await migrated.save();
    final reloaded = await Profile.load();
    expect(reloaded.claimStarterTech(1), false);
    expect(reloaded.techStock[0][2], 1);
  });
  test(
    'salvage remainder survives reload and training does not grant progression',
    () async {
      var p = await Profile.load();
      p.completeRun(
        victory: false,
        stageIndex: 0,
        kills: 10,
        level: 2,
        seconds: 90,
        training: false,
        runId: 'part',
      );
      await p.save();
      p = await Profile.load();
      expect(p.salvageSeconds, 90);
      expect(p.inventory.length, 6);
      p.completeRun(
        victory: true,
        stageIndex: 0,
        kills: 100,
        level: 8,
        seconds: 180,
        bossesDefeated: 1,
        training: true,
        runId: 'train',
      );
      expect(p.salvageSeconds, 90);
      expect(p.starterTechUnlocked, false);
      p.completeRun(
        victory: false,
        stageIndex: 0,
        kills: 10,
        level: 2,
        seconds: 30,
        training: false,
        runId: 'part2',
      );
      expect(p.salvageSeconds, 0);
      expect(p.inventory.length, 7);
    },
  );
  test('rerolls are limited and preserve level, XP, slots and pause', () {
    // First level costs 60 XP (v12.9.7) and opens on a gem pickup (v12.4.1).
    final g = game()..xp = GameEngine.firstGrowthCost;
    g.crystals.add(g.position);
    g.update(.01);
    final first = g.choices.map((c) => c.id).toSet();
    for (int n = 0; n < 3; n++) {
      expect(g.rerollChoices(), true);
    }
    expect(g.rerollChoices(), false);
    expect(g.level, 2);
    expect(g.weaponCount, 0);
    expect(g.choices.map((c) => c.id).toSet().length, g.choices.length);
    expect(first, isNotEmpty);
    final time = g.combatTime;
    g.update(1);
    expect(g.combatTime, time);
  });
  test(
    'one passive rescue consumes a choice and removes old hull levels safely',
    () {
      final g = game();
      g.upgrades['drill'] = 1;
      g.passives.addAll({
        'hull': 3,
        'speed': 1,
        'area': 1,
        'magnet': 1,
        'xp': 1,
        'duration': 1,
      });
      g.maxHp += 72;
      g.hp = g.maxHp;
      g.xp = GameEngine.firstGrowthCost;
      g.crystals.add(g.position);
      g.update(.01);
      expect(g.replacePassive('hull', 'projectile'), true);
      expect(g.passives.length, 6);
      expect(g.passives['projectile'], 1);
      expect(g.maxHp, closeTo(144, .01));
      expect(g.hp, lessThanOrEqualTo(g.maxHp));
      expect(g.choices, isEmpty);
      expect(g.passiveReplacements, 0);
      expect(g.replacePassive('speed', 'hull'), false);
    },
  );
  test('boss chest chooses among ready evolutions without paying a level', () {
    final g = game();
    g.upgrades.addAll({'ball': 5, 'missile': 5});
    g.passives.addAll({'speed': 1, 'area': 1});
    g.supplies.add(Supply(g.position, 3));
    g.update(.01);
    expect(g.chestSelection, true);
    expect(g.choices.length, 2);
    expect(g.rerollChoices(), false);
    g.chooseUpgrade('missile');
    expect(g.evolved, {'missile'});
    expect(g.level, 1);
    expect(g.chestSelection, false);
    expect(g.firstEvolutionAt, isNotNull);
  });
  test(
    'overlapping plasma has one target damage cadence, even if patches stagger',
    () {
      final g = game()..upgrades.clear();
      final at = g.position + const Offset(100, 0);
      final target = Foe(at, 1000, 0, 10, 0);
      g.enemies.add(target);
      for (int n = 0; n < 10; n++) {
        g.shots.add(Shot(at, Offset.zero, 20, 5, life: 2, radius: 30));
        g.update(.02);
      }
      expect(target.hp, 980);
      expect(g.damageByWeapon['trail'], 20);
    },
  );
  test('laser hits aligned targets together but not behind, damage excludes overkill', () {
    final g = game()..upgrades['gun'] = 5;
    g.evolved.add('gun');
    final a = Foe(g.position + const Offset(0, -150), 10, 0, 10, 0);
    final b = Foe(g.position + const Offset(0, -250), 200, 0, 10, 0);
    final rear = Foe(g.position + const Offset(0, 100), 200, 0, 10, 0);
    g.enemies.addAll([a, b, rear]);
    g.update(.01);
    expect(a.hp, lessThanOrEqualTo(0));
    expect(b.hp, closeTo(200 - 70 * g.damageFactor, .001));
    expect(rear.hp, 200);
    expect(g.damageByWeapon['gun'], closeTo(10 + 70 * g.damageFactor, .001));
    expect(g.laserLife, greaterThan(0));
  });
  test(
    'duration extends guardian shield and boss phases use independent clock',
    () {
      final g = game()..upgrades['guardian'] = 3;
      g.combatTime = 2;
      expect(g.guardianShieldActive, false);
      g.passives['duration'] = 1;
      expect(g.guardianShieldActive, true);
      g.elapsed = 200;
      g.update(.01);
      final chapter = g.elapsed, combat = g.combatTime;
      final pattern = g.bossPattern;
      g.boss!.hp = g.boss!.maxHp * .5;
      g.update(.05);
      expect(g.bossPhase, 1);
      expect(g.bossPattern, isNot(pattern));
      expect(g.elapsed, chapter);
      expect(g.combatTime, greaterThan(combat));
      expect(g.bossCharging, false);
    },
  );
}
