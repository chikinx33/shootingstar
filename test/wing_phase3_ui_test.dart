import 'ui_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/star_cannon_button.dart';
import 'package:shootingstar/ui/game_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'common ultimate controls and two synergy lines fit $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.onboarded = true;
          p.soundEnabled = false;
          final g = GameEngine(
            stageIndex: 0,
            shipIndex: 0,
            attackLevel: 0,
            hullLevel: 0,
            magnetLevel: 0,
            equipmentIndex: 0,
            seed: 17,
          );
          g.upgrades.clear();
          g.xpNeeded = 1e9;
          g.hp = g.maxHp = 100000;
          for (int i = 0; i < 1005; i++) {
            g.update(.02);
            g.enemies.clear();
            g.shots.clear();
            g.supplies.clear();
          }
          g.mainBranch = MainBranch.pulseFocus;
          g.upgrades.addAll({'gun': 1, 'laser': 1, 'guardian': 3});
          g.passives['armor'] = 1;
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
              home: BattleScreen(profile: p, engineFactory: () => g),
            ),
          );
          await tester.pump(const Duration(milliseconds: 32));
          final button = find.byKey(const Key('common-ultimate'));
          // v12.4: round, text-free side button
          expect(tester.widget<StarCannonButton>(button).onPressed, isNotNull);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(56));
          final field = tester.getRect(
            find.byKey(const Key('battle-playing-viewport')),
          );
          final action = tester.getRect(button);
          expect(action.top, greaterThanOrEqualTo(field.top));
          expect(action.bottom, lessThanOrEqualTo(field.bottom));
          expect(action.right, lessThanOrEqualTo(width));
          await tester.tap(find.byTooltip('전투 정보'));
          await tester.pump(const Duration(milliseconds: 300));
          await revealUi(tester, find.textContaining('방패 역습 · 준비').last);
          await revealUi(tester, find.textContaining('정면 돌파 · 준비').last);
          await tapUi(tester, find.byTooltip('전투 정보 닫기').last);
          if (width == 390 && scale == 1)
            await tester.tap(button);
          else
            await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump(const Duration(milliseconds: 32));
          expect(g.ultimateRemaining, greaterThan(0));
          expect(tester.widget<StarCannonButton>(button).onPressed, isNull);
          expect(tester.widget<StarCannonButton>(button).firing, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
          await tester.pump();
          expect(button, findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
  }
  testWidgets(
    'existing active pilots retain their own control and no common ultimate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.soundEnabled = false;
      final g = GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        pilot: 'yang',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BattleScreen(profile: p, engineFactory: () => g),
        ),
      );
      await tester.pump(const Duration(milliseconds: 32));
      expect(find.byKey(const Key('common-ultimate')), findsNothing);
      expect(find.text('보호 자세'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
