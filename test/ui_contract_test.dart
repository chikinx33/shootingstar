import 'ui_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/components.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('menus reflow at $size with 130 percent text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final profile = await Profile.load();
      profile.reducedEffects = true;
      final app = ShootingstarApp(
        profile: profile,
      ).build(tester.element(find.byType(View).first)) as MaterialApp;
      await tester.pumpWidget(
        MaterialApp(
          theme: app.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: app.home,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('launch'))).bottom,
        lessThan(size.height - 88),
      );
      expect(tester.takeException(), isNull);
      for (final label in ['성장', '연구', '보급']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.pumpWidget(const SizedBox());
      profile.dispose();
    });
    for (final scale in [1.0, 1.3]) {
      testWidgets('painted actions stay thick and readable at $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
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
          seed: 17,
        )..setPaused(true);
        final app = ShootingstarApp(
          profile: profile,
        ).build(tester.element(find.byType(View).first)) as MaterialApp;
        await tester.pumpWidget(
          MaterialApp(
            theme: app.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: BattleScreen(profile: profile, engineFactory: () => game),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        // Pause: resume, statistics, return. v12.8 result: next sortie and a
        // row of rewards, statistics and lobby.
        Future<void> checkActions(int count) async {
          final actions = find.byType(GameActionButton, skipOffstage: false);
          expect(actions, findsNWidgets(count));
          for (final element in actions.evaluate().toList()) {
            final action = element.widget as GameActionButton;
            final actionFinder = find.byWidgetPredicate(
              (w) => w is GameActionButton && w.label == action.label,
            );
            await revealUi(tester, actionFinder);
            final painted = find.descendant(
              of: actionFinder,
              matching: find.byType(RasterPanel),
            );
            final rect = tester.getRect(painted);
            expect(rect.width, lessThanOrEqualTo(264));
            expect(rect.height, greaterThanOrEqualTo(action.primary ? 72 : 64));
            expect(rect.width / rect.height, lessThanOrEqualTo(4.25));
            expect(rect.left, greaterThanOrEqualTo(16));
            expect(rect.right, lessThanOrEqualTo(size.width - 16));
            final label = tester.widget<Text>(
              find.descendant(
                of: actionFinder,
                // v12.8: a short visible displayLabel, full label in semantics
                matching: find.text(action.displayLabel ?? action.label),
              ),
            );
            expect(
              label.style!.fontSize,
              greaterThanOrEqualTo(action.primary ? 22 : 20),
            );
            for (final icon in tester.widgetList<RasterIcon>(
              find.descendant(
                of: actionFinder,
                matching: find.byType(RasterIcon),
              ),
            )) {
              expect(icon.size, greaterThanOrEqualTo(32));
            }
          }
          expect(tester.takeException(), isNull);
        }

        // v12.15: resume is the one big button; the rest are round icons
        await checkActions(1);
        await revealUi(tester, find.text('계속 비행'));
        await tester.tap(find.text('계속 비행'));
        await tester.pump(const Duration(milliseconds: 32));
        expect(game.paused, isFalse);
        await tester.tap(find.byTooltip('일시정지'));
        await tester.pump();
        final exit = find.byKey(const Key('pause-return'));
        await revealUi(tester, exit);
        await tester.tap(exit);
        await tester.pump(const Duration(milliseconds: 100));
        expect(game.finished, isTrue);
        await checkActions(1);
        final credits = profile.credits;
        await tester.pump(const Duration(seconds: 1));
        expect(profile.credits, credits);
        await tester.pumpWidget(const SizedBox());
        profile.dispose();
      });
    }
  }
}
