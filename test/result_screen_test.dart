import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/game_ui.dart';

/// v12.4.3 (user 2026-10-25): the result is one simple page — no page
/// arrows, no scrolling, every action visible on the smallest phone.
void main() {
  for (final (width, height) in const [(320.0, 568.0), (390.0, 844.0)]) {
    for (final scale in const [1.0, 1.3]) {
      for (final win in const [true, false]) {
        testWidgets('result fits one page at $width / $scale / win=$win', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final profile = await Profile.load();
          profile.soundEnabled = false;
          final game =
              GameEngine(
                  stageIndex: 0,
                  shipIndex: 0,
                  attackLevel: 0,
                  hullLevel: 0,
                  magnetLevel: 0,
                  equipmentIndex: 0,
                  seed: 42,
                )
                ..combatTime = 125
                ..kills = 48
                ..finished = true
                ..victory = win
                ..lastDamageSource = win ? '' : '레이저';
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: BattleScreen(profile: profile, engineFactory: () => game),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('game-page-next')), findsNothing);
          expect(find.byType(Scrollable), findsNothing);
          final screen = Offset.zero & Size(width, height);
          for (final button in tester.widgetList<GameActionButton>(
            find.byType(GameActionButton),
          )) {
            final rect = tester.getRect(find.byWidget(button));
            expect(screen.contains(rect.topLeft), isTrue, reason: button.label);
            expect(
              screen.contains(rect.bottomRight - const Offset(1, 1)),
              isTrue,
              reason: button.label,
            );
          }
          expect(
            find.bySemanticsLabel('성장 정비 · 귀환'),
            findsOneWidget,
          );
          // the details live in a popup
          await tester.tap(find.byKey(const Key('result-rewards')));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('보상·기록'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          profile.dispose();
        });
      }
    }
  }

  for (final scale in const [1.0, 1.3]) {
    testWidgets('pause panel is one page at 320x568 / $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final profile = await Profile.load();
      profile.soundEnabled = false;
      final game = GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 42,
      )..setPaused(true);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: BattleScreen(profile: profile, engineFactory: () => game),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('계속 비행'), findsOneWidget);
      expect(find.byKey(const Key('game-page-next')), findsNothing);
      expect(
        find.bySemanticsLabel('귀환 · 현재 보상 정산'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      profile.dispose();
    });
  }
}
