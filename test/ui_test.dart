import 'ui_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/ui/game_ui.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/app_version.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/battle_painter.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/game_dialog.dart';
import 'package:shootingstar/ui/module_workshop.dart';
import 'package:shootingstar/ui/ship_hangar.dart';

void main() {
  Future<Profile> setup(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    // Static layout fixtures opt out of ambient lobby motion.
    p.reducedEffects = true;
    p.updateSettings(soundEnabled: false);
    await tester.pumpWidget(ShootingstarApp(profile: p));
    await tester.pumpAndSettle();
    return p;
  }

  testWidgets('mobile menus, onboarding and settings are readable at 360px', (
    tester,
  ) async {
    final p = await setup(tester, const Size(360, 800));
    // v12.6: the lobby header has no title; the launch button is the anchor.
    expect(find.byKey(const Key('launch')), findsOneWidget);
    expect(find.text(AppVersion.label), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(find.text('옵션'), findsOneWidget);
    expect(find.text(AppVersion.label), findsOneWidget);
    await tapUi(tester, find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('격납고'));
    await tester.pumpAndSettle();
    // The hangar tab is the embedded module workshop (weapon bays on the
    // airframe); its 기체 선택 button opens the one-screen ship hangar.
    expect(find.byType(ModuleWorkshop), findsOneWidget);
    for (final m in ['W1', 'W2', 'W3', 'S1']) {
      expect(find.bySemanticsLabel('$m 모듈 편집'), findsOneWidget, reason: m);
    }
    await tapUi(tester, find.text('기체 선택'));
    await tester.pumpAndSettle();
    expect(find.byType(ShipHangar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });
  testWidgets('battle overlays center their content on a tall screen', (
    tester,
  ) async {
    const size = Size(432, 932);
    final p = await setup(tester, size);
    p.onboarded = true;
    await tester.tap(find.byKey(const Key('launch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('일시정지'));
    await tester.pump();
    await tester.pump();

    void expectCentered() {
      // v12.4.3: pause/result are fixed one-page overlays (no pager)
      final bounds = tester.getRect(
        find
            .byWidgetPredicate(
              (w) =>
                  w is ConstrainedBox &&
                  (w.constraints.maxWidth == 344 ||
                      w.constraints.maxWidth == 360),
            )
            .last,
      );
      expect(bounds.height, lessThan(size.height - 80));
      expect(bounds.center.dy, closeTo(size.height / 2, 1));
      expect(find.byKey(const Key('game-page-next')), findsNothing);
      expect(tester.takeException(), isNull);
    }

    expect(find.text('일시정지'), findsOneWidget);
    expectCentered();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == '귀환 · 현재 보상 정산',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('다음엔 꼭 이긴다냥'), findsOneWidget);
    expectCentered();
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets('launch pause resume return rewards once and retry cleanly', (
    tester,
  ) async {
    final p = await setup(tester, const Size(1100, 900));
    await revealUi(tester, find.byKey(const Key('launch')));
    await tester.tap(find.byKey(const Key('launch')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(GameDialog),
        matching: find.text('비행 가이드'),
      ),
      findsOneWidget,
    );
    await tapUi(tester, find.text('비행 준비 완료'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(p.onboarded, isTrue);
    expect(find.byType(BattleScreen), findsOneWidget);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<BattlePainter>()
        .first;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await tester.pump(const Duration(milliseconds: 32));
    expect(painter.game.input.dx, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(painter.game.paused, isTrue);
    expect(painter.game.input, Offset.zero);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    await tester.tap(find.text('계속 비행'));
    await tester.pump();
    expect(painter.game.input, Offset.zero);
    await tester.tap(find.byTooltip('일시정지'));
    await tester.pump();
    expect(find.text('일시정지'), findsOneWidget);
    await tester.tap(find.text('계속 비행'));
    await tester.pump();
    expect(find.text('일시정지'), findsNothing);
    await tester.tap(find.byTooltip('일시정지'));
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == '귀환 · 현재 보상 정산',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('다음엔 꼭 이긴다냥'), findsOneWidget);
    final rewarded = p.credits;
    expect(rewarded, 150);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(p.credits, rewarded);
    expect(p.runs, 0);
    await tester.tap(find.text('다시 출격'));
    await tester.pump();
    expect(find.text('다음엔 꼭 이긴다냥'), findsNothing);
    tester.view.physicalSize = const Size(360, 780);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    p.dispose();
    expect(tester.takeException(), isNull);
  });
}
