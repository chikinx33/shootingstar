import 'ui_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/battle_statistics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  for (final width in [320.0, 360.0, 390.0, 430.0])
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'new branch choice, active HUD and frozen gear links fit $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
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
            armament: 'void',
            armamentLevel: 4,
            techRanks: {'gun': 2},
            mainPrecisionLink: true,
            mainCycleLink: true,
            seed: 17,
          );
          g.xp = g.xpNeeded;
          g.update(.001);
          final app = ShootingstarApp(
            profile: p,
          ).build(tester.element(find.byType(View).first)) as MaterialApp;
          Widget wrap(Widget child) => MaterialApp(
            theme: app.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: child,
          );
          await tester.pumpWidget(
            wrap(BattleScreen(profile: p, engineFactory: () => g)),
          );
          await tester.pump(const Duration(milliseconds: 32));
          final card = find.byKey(const Key('upgrade-main-voidDrift'));
          await tester.ensureVisible(card);
          await tester.pump();
          expect(tester.getSize(card).height, greaterThanOrEqualTo(88));
          await tester.tap(card);
          await tester.pump(const Duration(milliseconds: 300));
          expect(g.mainBranch, MainBranch.voidDrift);
          await tester.tap(find.byTooltip('전투 정보'));
          await tester.pump(const Duration(milliseconds: 300));
          await revealUi(tester, find.text('주포 특화 · 이동 공허').last);
          expect(find.text('주포 특화 · 이동 공허'), findsOneWidget);
          await tapUi(tester, find.byTooltip('전투 정보 닫기').last);
          await tester.pump(const Duration(milliseconds: 300));
          final hud = tester.getRect(find.byKey(const Key('battle-hud-panel'))),
              field = tester.getRect(
                find.byKey(const Key('battle-playing-viewport')),
              );
          expect(field.top, greaterThanOrEqualTo(hud.bottom));
          expect(field.height, greaterThan(100));
          g.setPaused(true);
          final snapshot = BattleStatisticsSnapshot.fromGame(g);
          await tester.pumpWidget(
            wrap(BattleStatisticsDialog(snapshot: snapshot)),
          );
          await tester.pump(const Duration(milliseconds: 32));
          await tester.tap(find.text('현재 빌드'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          await revealUi(tester, find.textContaining('정밀 연계 · 활성').last);
          expect(find.textContaining('정밀 연계 · 활성'), findsWidgets);
          await revealUi(tester, find.textContaining('순환 방호 · 활성').last);
          expect(find.textContaining('순환 방호 · 활성'), findsWidgets);
          await revealUi(tester, find.textContaining('발사 분기 · 이동 공허').last);
          expect(find.textContaining('발사 분기 · 이동 공허'), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
}
