import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/data/content_catalog.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/developer_battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'developer copy unlocks all content, purchases are free and never save',
    () async {
      SharedPreferences.setMockInitialValues({});
      final normal = await Profile.load();
      normal.credits = 0;
      normal.blueprints = 0;
      await normal.save();
      final before = jsonEncode(normal.exportProgress());
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(Profile.storageKey);
      final dev = Profile.developerCopy(normal);
      expect(dev.online, isNull);
      expect(dev.developerMode, isTrue);
      expect(dev.unlockedShips.length, ships.length);
      expect(dev.armamentCollection.ownedCount, armaments.length);
      expect(List.generate(100, dev.canStage).every((v) => v), isTrue);
      expect(
        dev.inventory.map((g) => g.spec).toSet().length,
        gearCatalog.length,
      );
      expect(dev.petLevels.every((v) => v > 0), isTrue);
      expect(dev.techStock.every((s) => s.any((v) => v > 0)), isTrue);
      final cash = dev.credits, plans = dev.blueprints;
      for (var i = 0; i < 10; i++) {
        expect(dev.buyMaterial('tech'), isTrue);
        expect(dev.openTechSupply(), isTrue);
        expect(dev.upgradeArmament('pulse', expectedLevel: i), isTrue);
      }
      expect(dev.credits, cash);
      expect(dev.blueprints, plans);
      final hull = dev.developerGear(12, 2, 5)!;
      final thruster = dev.developerGear(13, 2, 5)!;
      expect(dev.equipItem(hull.id), isTrue);
      expect(dev.equipItem(thruster.id), isTrue);
      expect(dev.activeBossSetWorld, 0);
    expect(dev.claimBossGear(0), isTrue);
      await dev.save();
      expect(prefs.getString(Profile.storageKey), stored);
      expect(jsonEncode(normal.exportProgress()), before);
      dev.dispose();
      expect(normal.developerMode, isFalse);
      expect(normal.canStage(99), isFalse);
      expect(normal.buyMaterial('tech'), isFalse);
      normal.dispose();
    },
  );

  test(
    'all primary branches and world boss phases use the real engine',
    () async {
      SharedPreferences.setMockInitialValues({});
      final normal = await Profile.load(),
          p = Profile.developerCopy(await Profile.load());
      final config = DeveloperBattleConfig();
      expect(() => config.build(normal), throwsStateError);
      for (final b in mainBranches) {
        p.selectArmament(armaments.indexWhere((a) => a.id == b.armament));
        config.branch = b.branch;
        expect(config.build(p).mainBranch, b.branch);
      }
      for (var w = 0; w < 10; w++) {
        p.selectStage(w * 10);
        for (var phase = 0; phase < 3; phase++) {
          config.scene = 1;
          config.phase = phase;
          final game = config.build(p);
          expect(game.worldIndex, w);
          expect(game.boss, isNotNull);
          expect(game.bossPhase, phase);
          expect(game.bossPattern, inInclusiveRange(0, 5));
        }
      }
      for (var scene = 2; scene <= 5; scene++) {
        config.scene = scene;
        final game = config.build(p);
        final pattern = {
          2: FlightFormation.bulwark,
          3: FlightFormation.assault,
          4: FlightFormation.column,
          5: FlightFormation.fan,
        }[scene];
        expect(game.enemies, isNotEmpty);
        expect(
          game.enemies.every((e) => e.formationPattern == pattern),
          isTrue,
        );
      }
      config.scene = 6;
      config.enemyCount = 260;
      config.shotCount = 1000;
    config.sparkCount = 160;
      final load = config.build(p);
      expect(load.enemies.length, 260);
      expect(load.shots.length, 1000);
    expect(load.sparks.length, 160);
      for (var i = 0; i < 60; i++) {
        load.update(1 / 60);
      }
      expect(load.hp.isFinite, isTrue);
      config.scene = 0;
      config.ultimateReady = true;
      config.supplyKind = 2;
      p.selectPilot(0);
      final ready = config.build(p);
      expect(ready.ultimateReady, isTrue);
      expect(ready.activateCommonUltimate(), isTrue);
      expect(ready.supplies.single.kind, 2);
      for (var i = 1; i <= 6; i++) {
        config.preset(i);
        final preset = config.build(p);
        if (i >= 4) expect(preset.evolved, isNotEmpty);
        if (i == 3) {
          expect(preset.upgrades['guardian'], 3);
          expect(preset.passives['armor'], 1);
        }
      }
      normal.dispose();
      p.dispose();
    },
  );
}
