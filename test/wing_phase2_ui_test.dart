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
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('synergy choices, HUD and frozen build fit $width / $scale', (
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
          armament: 'shotgun',
          seed: 17,
        )..mainBranch = MainBranch.shellSplit;
        g.choices = [
          const UpgradeChoice(
            'missile',
            '추적 로켓',
            '강한 적을 추적하는 범위 폭발',
            'missile',
          ),
          const UpgradeChoice('area', '고출력 연료', '폭발·장판 범위 +12%', 'area'),
          const UpgradeChoice(
            'guardian',
            '궤도 수호자',
            '회전하며 접근을 막는 방어 무장',
            'guardian',
          ),
        ];
        g.passives['area'] = 1;
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
        await tester.longPress(find.byKey(const Key('upgrade-missile')));
        await tester.pump(const Duration(milliseconds: 300));
        await revealUi(tester, find.textContaining('우선 표적 · 폭발').last);
        await tapUi(tester, find.byTooltip('닫기').last);
        final card = find.byKey(const Key('upgrade-missile'));
        await tester.ensureVisible(card);
        await tester.pump();
        await tester.tap(card);
        await tester.pump(const Duration(milliseconds: 300));
        expect(g.upgrades['missile'], 1);
        await tester.tap(find.byTooltip('전투 정보'));
        await tester.pump(const Duration(milliseconds: 300));
        await revealUi(tester, find.textContaining('폭발 확산 · 준비').last);
        expect(find.textContaining('폭발 확산 · 준비'), findsWidgets);
        await tapUi(tester, find.byTooltip('전투 정보 닫기').last);
        await tester.pump(const Duration(milliseconds: 300));
        final hud = tester.getRect(find.byKey(const Key('battle-hud-panel')));
        final field = tester.getRect(
          find.byKey(const Key('battle-playing-viewport')),
        );
        expect(field.top, greaterThanOrEqualTo(hud.bottom));
        expect(field.height, greaterThan(100));
        expect(tester.takeException(), isNull);
        final snap = BattleStatisticsSnapshot.fromGame(g);
        await tester.pumpWidget(wrap(BattleStatisticsDialog(snapshot: snap)));
        await tester.pump(const Duration(milliseconds: 32));
        await tester.tap(find.text('현재 빌드'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await revealUi(tester, find.textContaining('폭발 확산 · 활성').last);
        expect(find.textContaining('폭발 확산 · 활성'), findsWidgets);
        await revealUi(tester, find.textContaining('우선 표적 · 폭발').last);
        expect(find.textContaining('우선 표적 · 폭발'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      });
    }
  }
}
