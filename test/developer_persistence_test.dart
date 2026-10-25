import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/developer_battle.dart';
import 'package:shootingstar/game/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('developer progress/config survive reload; only explicit exit clears separate record', () async {
    SharedPreferences.setMockInitialValues({});
    final normal = await Profile.load();
    normal.credits = 327;
    await normal.save();
    final prefs = await SharedPreferences.getInstance();
    var before = prefs.getString(Profile.storageKey);
    final dev = await normal.startDeveloperSession();
    dev.selectShip(2);
    dev.selectStage(77);
    dev.selectArmament(4);
    dev.developerConfigure(pilotLevel: 25, armamentLevel: 7);
    final config = DeveloperBattleConfig()
      ..level = 50
      ..rate = 3
      ..power = 4
      ..count = 2
      ..scene = 1
      ..phase = 2
      ..speed = 4
      ..branch = MainBranch.shellSplit
      ..invincible = true;
    config.skills.addAll({'missile': 5, 'area': 3});
    config.evolutions.add('missile');
    dev.developerSettings = {
      'location': 'lab',
      'battle': config.toJson(),
      'ui': {'group': 0, 'menu': 3},
    };
    await dev.save();
    expect(prefs.getString(Profile.storageKey), before);
    final reloaded = await Profile.load();
    // Loading the normal record refreshes its own activity clocks and shop
    // defaults and may save them; from here on only the developer session runs.
    before = prefs.getString(Profile.storageKey);
    expect(jsonDecode(before!)['credits'], 327);
    await reloaded.restoreDeveloperSession();
    final restored = reloaded.developerSession!;
    expect(restored.selectedStage, 77);
    expect(restored.selectedShip, 2);
    expect(restored.activeArmamentLevel, 7);
    expect(restored.pilotLevel, 25);
    expect(restored.online, isNull);
    expect(
      DeveloperBattleConfig.restore(restored.developerSettings['battle'])
          .toJson(),
      config.toJson(),
    );
    restored.buyUpgrade('hull');
    restored.save();
    expect(await restored.endDeveloperSession(), isTrue);
    expect(reloaded.developerSession, isNull);
    await restored.save();
    expect(prefs.containsKey(Profile.developerStorageKey), isFalse);
    expect(prefs.getString(Profile.storageKey), before);
    final finalLoad = await Profile.load();
    await finalLoad.restoreDeveloperSession();
    expect(finalLoad.developerSession, isNull);
    expect(finalLoad.credits, 327);
    normal.dispose();
    dev.dispose();
    restored.dispose();
    reloaded.dispose();
    finalLoad.dispose();
  });

  test('invalid developer record never replaces the normal record', () async {
    SharedPreferences.setMockInitialValues({
      Profile.developerStorageKey: '{broken',
    });
    final normal = await Profile.load();
    await normal.save();
    final before = jsonEncode(normal.exportProgress());
    await normal.restoreDeveloperSession();
    expect(normal.developerSession, isNull);
    expect(jsonEncode(normal.exportProgress()), before);
    normal.dispose();
  });
}
