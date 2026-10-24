import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shootingstar/data/profile.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  int finish(Profile p, String id) => p.completeRun(
    victory: true,
    stageIndex: 0,
    kills: 80,
    level: 7,
    seconds: 150,
    training: false,
    runId: id,
  );

  test('same run ID cannot pay twice, including after reload', () async {
    final p = await Profile.load();
    expect(finish(p, 'battle-1'), 160);
    await p.save();
    var notifications = 0;
    p.addListener(() => notifications++);
    expect(finish(p, 'battle-1'), 0);
    expect(notifications, 0);
    expect(p.credits, 310);
    expect(p.runs, 1);
    final restored = await Profile.load();
    expect(finish(restored, 'battle-1'), 0);
    expect(restored.credits, 310);
    expect(finish(restored, 'battle-2'), 160);
    await restored.save();
  });

  test('processed run history is limited to latest 100 IDs', () async {
    final p = await Profile.load();
    for (var i = 0; i < 105; i++) {
      finish(p, 'battle-$i');
    }
    await p.save();
    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString(Profile.storageKey)!) as Map;
    expect(stored['processedRunIds'], hasLength(100));
    expect((stored['processedRunIds'] as List).first, 'battle-5');
    expect(finish(await Profile.load(), 'battle-104'), 0);
  });

  test(
    'unavailable storage permits in-memory play and retains warning',
    () async {
      final p = await Profile.load(
        preferencesLoader: () async => throw StateError('Storage denied'),
      );
      expect(p.saveError, isNotNull);
      expect(p.credits, 150);
      expect(finish(p, 'offline-1'), 160);
      expect(p.buyUpgrade('hull'), isTrue);
      await p.save();
      expect(p.credits, 230);
      expect(p.hullLevel, 1);
      expect(p.saveError, contains('앱을 종료하면'));
      expect(finish(p, 'offline-1'), 0);
    },
  );

  test(
    'fresh profile has useful starter credits and gates progression',
    () async {
      final p = await Profile.load();
      expect(p.credits, 150);
      expect(p.unlockedShips, {0});
      expect(p.canStage(0), isTrue);
      expect(p.canStage(1), isFalse);
      expect(p.unlockShip(1), isFalse);
      p.selectShip(2);
      p.selectStage(2);
      expect(p.selectedShip, 0);
      expect(p.selectedStage, 0);
    },
  );

  test('purchases consume credits once and enforce upgrade cap', () async {
    final p = await Profile.load();
    p.credits = 10000;
    expect(p.unlockShip(1), isTrue);
    expect(p.credits, 9800);
    expect(p.unlockShip(1), isFalse);
    expect(p.unlockShip(-1), isFalse);
    for (var i = 0; i < 5; i++) {
      expect(p.buyUpgrade('attack'), isTrue);
    }
    expect(p.attackLevel, 5);
    expect(p.hullLevel, 0);
    expect(p.buyUpgrade('attack'), isFalse);
    expect(p.buyUpgrade('unknown'), isFalse);
    await p.save();
  });

  test('completion rewards and unlocks survive reloading', () async {
    final p = await Profile.load();
    final reward = p.completeRun(
      victory: true,
      stageIndex: 0,
      kills: 80,
      level: 7,
      seconds: 150,
      training: false,
    );
    expect(reward, 160);
    expect(p.credits, 310);
    expect(p.runs, 1);
    expect(p.bestKills, 80);
    expect(p.canStage(1), isTrue);
    expect(p.canStage(2), isFalse);
    p.selectStage(1);
    p.finishOnboarding();
    p.selectEquipment(2);
    p.updateSettings(soundEnabled: false, reducedEffects: true, volume: .2);
    await p.save();
    final restored = await Profile.load();
    expect(restored.credits, 310);
    expect(restored.selectedStage, 1);
    expect(restored.equipment, 2);
    expect(restored.clearedStages, {0});
    expect(restored.onboarded, isTrue);
    expect(restored.soundEnabled, isFalse);
    expect(restored.reducedEffects, isTrue);
    expect(restored.volume, .2);
  });

  test('training and invalid stages do not grant progression', () async {
    final p = await Profile.load();
    for (final stage in [0, -1, 2, 99]) {
      final reward = p.completeRun(
        victory: true,
        stageIndex: stage,
        kills: 500,
        level: 20,
        seconds: 300,
        training: stage == 0,
      );
      expect(reward, 0);
    }
    expect(p.credits, 150);
    expect(p.runs, 0);
    expect(p.clearedStages, isEmpty);
  });

  test('malformed saves recover without throwing', () async {
    SharedPreferences.setMockInitialValues({Profile.storageKey: '{broken'});
    final p = await Profile.load();
    expect(p.credits, 150);
    expect(p.saveError, isNotNull);
    await p.save();
    expect(p.saveError, isNull);
  });

  test('loaded numbers, selections and ID sets are validated', () async {
    SharedPreferences.setMockInitialValues({
      Profile.storageKey: jsonEncode({
        'credits': -50,
        'attackLevel': 900,
        'hullLevel': 'bad',
        'magnetLevel': -2,
        'unlockedShips': [-1, 0, 99, '1'],
        'clearedStages': [-1, 99, '0'],
        'selectedShip': 2,
        'selectedStage': 2,
        'equipment': 999,
        'volume': 7,
        'runs': -1,
        'bestKills': 'bad',
      }),
    });
    final p = await Profile.load();
    expect(p.credits, 0);
    expect(p.attackLevel, 5);
    expect(p.hullLevel, 0);
    expect(p.magnetLevel, 0);
    expect(p.unlockedShips, {0});
    expect(p.clearedStages, isEmpty);
    expect(p.selectedShip, 0);
    expect(p.selectedStage, 0);
    expect(p.equipment, 2);
    expect(p.volume, 1);
    expect(p.runs, 0);
    expect(p.bestKills, 0);
  });

  test(
    'rapid writes preserve the latest snapshot and disposed writes finish',
    () async {
      final p = await Profile.load();
      p.credits = 200;
      final first = p.save();
      p.credits = 300;
      final second = p.save();
      p.dispose();
      await Future.wait([first, second]);
      expect((await Profile.load()).credits, 300);
    },
  );
}
