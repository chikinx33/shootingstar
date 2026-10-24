import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle.dart';

void main() {
  testWidgets(
    'encounter notices, status and boss transitions keep the battlefield fixed',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.soundEnabled = false;
      final game = GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 17,
      )..developerInvincible = true;
      game.update(.001);
      game.waveNoticeTime = 0;
      game.xpNeeded = 1e9;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: BattleScreen(profile: p, engineFactory: () => game),
        ),
      );
      await tester.pump(const Duration(milliseconds: 32));
      game.waveNoticeTime = 0;
      await tester.pump(const Duration(milliseconds: 1));
      final field = find.byKey(const Key('battle-playing-viewport'));
      final initial = tester.getRect(field);
      final height = game.viewportHeight;
      final camera = game.camera;
      final position = game.position;
      Future<void> unchanged(String event) async {
        await tester.pump(const Duration(milliseconds: 1));
        final current = tester.getRect(field);
        print('VIEWPORT $event: $current (baseline $initial)');
        expect(
          current,
          initial,
          reason: '$event must not resize or move the field',
        );
        expect(game.viewportHeight, height, reason: event);
        expect(game.camera, camera, reason: event);
        expect(game.position, position, reason: event);
        expect(tester.takeException(), isNull);
      }

      game.waveNoticeTime = 2;
      await unchanged('wave spawn notice');
      game.waveNoticeTime = 0;
      await unchanged('wave notice ends');
      final foe = Foe(game.position + const Offset(100, -100), 100, 0, 8, 0);
      game.enemies.add(foe);
      await unchanged('enemy spawn');
      foe.hp = 0;
      await unchanged('enemy death');
      game.mainBranch = MainBranch.pulseSpread;
      await unchanged('specialization status appears');
      game.level = 99;
      game.hp = game.maxHp = 9999;
      await unchanged('HP and level digit growth');
      game.elapsed = game.nextBossAt - 2;
      await unchanged('boss approach warning');
      game.elapsed = game.nextBossAt;
      game.update(.001);
      expect(game.boss, isNotNull);
      await unchanged('boss arrives');
      game.bossCycle = 3.3;
      await unchanged('boss attack cue changes');
      game.boss!.hp = 0;
      game.update(.001);
      expect(game.resolvingBoss, isTrue);
      await unchanged('boss dies');
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
