import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';

import 'ui_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('branch decisions and selected HUD fit $width at $scale', (
        tester,
      ) async {
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
          armament: 'revolver',
          seed: 17,
        );
        // v12.4.1: the level-up only opens when a gem reaches the cat.
        g.xp = g.xpNeeded;
        g.crystals.add(g.position);
        g.update(.001);
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
        // v12.7 skill cards deal in from the bottom over ~1.15 s.
        await tester.pump(const Duration(milliseconds: 1300));
        final branch = find.byKey(const Key('upgrade-main-railCharge'));
        await tester.ensureVisible(branch);
        await tester.pump();
        expect(tester.getSize(branch).height, greaterThanOrEqualTo(88));
        await tester.tap(branch);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.tap(find.byTooltip('전투 정보'));
        await tester.pump(const Duration(milliseconds: 300));
        // v12.15: the main gun and its specialization are tags.
        expect(find.text('축전 레일'), findsWidgets);
        await revealUi(tester, find.textContaining('중형 레일건'));
        expect(find.textContaining('중형 레일건'), findsOneWidget);
        await tapUi(tester, find.byTooltip('전투 정보 닫기').last);
        await tester.pump(const Duration(milliseconds: 300));
        final hud = tester.getRect(find.byKey(const Key('battle-hud-panel')));
        final field = tester.getRect(
          find.byKey(const Key('battle-playing-viewport')),
        );
        expect(field.top, greaterThanOrEqualTo(hud.bottom));
        expect(field.height, greaterThan(100));
        expect(g.mainBranch, MainBranch.railCharge);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      });
    }
  }
}
