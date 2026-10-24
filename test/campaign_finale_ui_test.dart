import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';

import 'ui_actions.dart';

GameEngine engine(int stage, int loop) => GameEngine(
  stageIndex: stage,
  campaignLoop: loop,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 33,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  test(
    'final destruction can resume and settle the next loop exactly once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.onboarded = true;
      p.soundEnabled = false;
      p.selectedStage = 99;
      p.clearedStages.addAll(List.generate(99, (i) => i));
      final initial = engine(99, 0)
        ..elapsed = 240
        ..kills = 300
        ..bossesDefeated = 2;
      final boss = Foe(initial.position + const Offset(0, -150), 100, 0, 34, 3)
        ..hp = .1;
      initial.enemies.add(boss);
      final data = initial.checkpoint(), state = data['state'] as Map;
      state['_bossWave'] = 3;
      state['_lastBossPhase'] = 2;
      state['bossCycle'] = 3.3;
      final g = BattleCheckpoint.restore(jsonDecode(jsonEncode(data)));
      g.shots.add(Shot(g.boss!.position, Offset.zero, 100, 0));
      g.update(.01);
      expect(g.resolvingBoss, true);
      expect(g.finished, false);
      expect(await p.checkpointBattle('finale-v33', g), true);
      Directory('.local/balance-v33').createSync(recursive: true);
      final prefs = await SharedPreferences.getInstance();
      File('.local/balance-v33/finale-profile.json')
          .writeAsStringSync(prefs.getString(Profile.storageKey)!);
      final restored = p.restoreBattle()!.game;
      expect(restored.paused, true);
      restored.setPaused(false);
      for (var frame = 0; frame < 120; frame++) {
        restored.update(.05);
      }
      expect(restored.victory, true);
      void settle() => p.completeRun(
        victory: restored.victory,
        stageIndex: 99,
        kills: restored.kills,
        level: restored.level,
        seconds: restored.elapsed.floor(),
        bossesDefeated: restored.bossesDefeated,
        training: false,
        runId: 'finale-v33',
      );
      settle();
      final credits = p.credits;
      settle();
      expect(p.credits, credits);
      expect(p.campaignLoop, 1);
      expect(p.selectedStage, 0);
      expect(p.hasSuspendedBattle, false);
      await p.save();
      p.dispose();
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('campaign finale leads to next loop once $size/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        p.onboarded = true;
        p.soundEnabled = false;
        p.campaignLoop = 3;
        p.selectedStage = 99;
        p.clearedStages.addAll(List.generate(100, (i) => i));
        p.cycleClears.addAll(List.generate(99, (i) => i));
        p.attackLevel = 3;
        final g = engine(99, 3)
          ..finished = true
          ..victory = true
          ..elapsed = 240
          ..kills = 300
          ..bossesDefeated = 3
          ..level = 20;
        var launches = 0;
        final app = ShootingstarApp(
          profile: p,
        ).build(tester.element(find.byType(View).first)) as MaterialApp;
        await tester.pumpWidget(
          MaterialApp(
            theme: app.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: BattleScreen(
              profile: p,
              engineFactory: () =>
                  launches++ == 0 ? g : engine(p.selectedStage, p.campaignLoop),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 32));
        await revealUi(tester, find.text('100개 항로 완주'));
        expect(find.text('CAMPAIGN COMPLETE'), findsOneWidget);
        expect(p.campaignLoop, 4);
        expect(p.selectedStage, 0);
        expect(p.clearedStages.length, 100);
        expect(p.attackLevel, 3);
        final credits = p.credits;
        await tester.pump(const Duration(milliseconds: 100));
        expect(p.credits, credits);
        await tapUi(tester, find.text('다음 회차 출격'));
        expect(launches, 2);
        expect(find.text('100개 항로 완주'), findsNothing);
        expect(p.campaignLoop, 4);
        expect(p.selectedStage, 0);
        expect(p.canStage(1), false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await p.save();
        p.dispose();
      });
    }
  }
}
