import 'ui_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/battle_statistics.dart';

GameEngine fixture() => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 42,
);

void main() {
  test('modular damage sources retain physical mount names', () {
    const labels = {
      'module-main': 'Pulse',
      'module-auxiliary': '회전 포탑',
      'module-wings': '날개 포드',
      'module-rear': '후방 방어포',
      'module-ground': '지상 폭격창',
    };
    for (final e in labels.entries) {
      expect(
        damageSourceLabel(e.key, armament: 'Pulse', pilot: 'Common'),
        e.value,
      );
    }
  });

  test('actual source totals sort consistently and use combat-time DPS', () {
    final summary = BattleDamageSummary.from({
      'drone': 100,
      'gun': 300,
      'missile': 100,
    }, 20);
    expect(summary.totalDamage, 500);
    expect(summary.dps, 25);
    expect(summary.entries.map((e) => e.source), ['gun', 'drone', 'missile']);
    expect(summary.entries.map((e) => e.share), [.6, .2, .2]);
    expect(summary.entries.first.dps, 15);
  });

  test('zero, invalid measurements and unknown source labels remain safe', () {
    final summary = BattleDamageSummary.from({
      'gun': 0,
      'negative': -10,
      'nan': double.nan,
      'infinite': double.infinity,
      ' ': 25,
      'new-source': 60,
    }, 0);
    expect(summary.totalDamage, 60);
    expect(summary.entries.single.source, 'new-source');
    expect(summary.entries.single.share, 1);
    expect(summary.entries.single.dps, 0);
    expect(summary.dps, 0);
    expect(
      damageSourceLabel('new-source', armament: '주포', pilot: '조종사'),
      '기타 공격',
    );
    for (final seconds in [0.0, -1.0, double.nan, double.infinity]) {
      final empty = BattleDamageSummary.from({}, seconds);
      expect(empty.entries, isEmpty);
      expect(empty.totalDamage, 0);
      expect(empty.dps, 0);
      expect(empty.combatSeconds, 0);
    }
  });

  test('snapshot preserves actual learned ranks, recipes, evolution and field axes', () {
    final game = fixture()
      ..combatTime = 40
      ..mainRate = 3
      ..mainPower = 4
      ..mainCount = 2;
    game.damageByWeapon.addAll({'gun': 240, 'missile-evo': 160});
    game.upgrades.addAll({'missile': 5, 'drone': 2});
    game.passives['area'] = 3;
    game.evolved.add('missile');
    final snapshot = BattleStatisticsSnapshot.fromGame(game);
    expect(snapshot.damage.totalDamage, 400);
    expect(snapshot.mainRate, 3);
    expect(snapshot.mainPower, 4);
    expect(snapshot.mainCount, 2);
    expect(
      snapshot.weapons.singleWhere((e) => e.id == 'missile').name,
      '궤도 폭격',
    );
    expect(
      snapshot.weapons.singleWhere((e) => e.id == 'missile').evolved,
      isTrue,
    );
    expect(snapshot.weapons.singleWhere((e) => e.id == 'drone').rank, 2);
    expect(
      snapshot.weapons.singleWhere((e) => e.id == 'drone').recipe,
      contains('5단계'),
    );
    expect(snapshot.passives.single.id, 'area');
    expect(snapshot.passives.single.rank, 3);
    game.damageByWeapon.clear();
    game.upgrades.clear();
    expect(snapshot.damage.totalDamage, 400);
    expect(snapshot.weapons.length, 3);
  });

  testWidgets(
    '320px pause statistics scroll build and close without resuming',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final profile = await Profile.load();
      profile.soundEnabled = false;
      final game = fixture()..combatTime = 60;
      game.damageByWeapon.addAll({'gun': 300, 'missile': 100});
      game.upgrades.addAll({'missile': 3, 'drone': 2, 'ball': 1});
      game.passives.addAll({'area': 2, 'attack': 1});
      game.setPaused(true);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: BattleScreen(profile: profile, engineFactory: () => game),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await revealUi(tester, find.byKey(const Key('pause-battle-statistics')));
      await tester.tap(find.byKey(const Key('pause-battle-statistics')));
      await tester.pump(const Duration(milliseconds: 300));
      // v12.16: the build tab opens first
      expect(
        DefaultTabController.of(tester.element(find.byType(TabBar))).index,
        0,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump(const Duration(seconds: 2));
      expect(game.paused, isTrue);
      expect(game.combatTime, 60);
      expect(game.input, Offset.zero);
      await tester.drag(
        find.byKey(const Key('battle-build-scroll')),
        const Offset(0, -350),
      );
      await tester.pump();
      await tester.tap(find.text('피해 기여'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        DefaultTabController.of(tester.element(find.byType(TabBar))).index,
        1,
      );
      // rows are a picture, a bar and the damage number
      expect(find.text('300.0'), findsOneWidget);
      expect(find.text('100.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('close-battle-statistics')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BattleStatisticsDialog), findsNothing);
      expect(game.paused, isTrue);
      expect(game.combatTime, 60);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      expect(game.input, Offset.zero);
      await revealUi(tester, find.text('계속 비행'));
      await tester.tap(find.text('계속 비행'));
      await tester.pump(const Duration(milliseconds: 32));
      expect(game.paused, isFalse);
      expect(game.combatTime, greaterThan(60));
      expect(profile.credits, 150);
      await tester.pumpWidget(const SizedBox());
      profile.dispose();
    },
  );

  testWidgets(
    'result statistics retain final damage without another settlement',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final profile = await Profile.load();
      profile.soundEnabled = false;
      final game = fixture()
        ..combatTime = 25
        ..finished = true;
      game.damageByWeapon['gun'] = 125;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: BattleScreen(
            profile: profile,
            training: true,
            engineFactory: () => game,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final credits = profile.credits;
      final runs = profile.runs;
      for (int i = 0; i < 2; i++) {
        await revealUi(
          tester,
          find.byKey(const Key('result-battle-statistics')),
        );
        await tester.tap(find.byKey(const Key('result-battle-statistics')));
        await tester.pump(const Duration(milliseconds: 300));
        final dialog = tester.widget<BattleStatisticsDialog>(
          find.byType(BattleStatisticsDialog),
        );
        expect(dialog.snapshot.damage.totalDamage, 125);
        expect(dialog.snapshot.finished, isTrue);
        await tester.pump(const Duration(seconds: 1));
        expect(game.combatTime, 25);
        await tester.tap(find.byKey(const Key('close-battle-statistics')));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(profile.credits, credits);
      expect(profile.runs, runs);
      expect(game.damageByWeapon['gun'], 125);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      profile.dispose();
    },
  );
}
