import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/battle_painter.dart';
import 'package:shootingstar/ui/game_dialog.dart';

import 'ui_actions.dart';

void main() {
  Future<Profile> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    // Static layout fixtures opt out of ambient lobby motion.
    p.reducedEffects = true;
    p.onboarded = true;
    p.soundEnabled = false;
    await tester.pumpWidget(ShootingstarApp(profile: p));
    await tester.pumpAndSettle();
    return p;
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'portrait ${size.width}x${size.height}: launch visible, growth fits, battle fills height',
      (tester) async {
        final p = await mount(tester, size);
        final launch = tester.getRect(find.byKey(const Key('launch')));
        expect(launch.bottom, lessThan(size.height - 64));
        expect(launch.height, greaterThanOrEqualTo(48));
        expect(
          tester.getSize(find.byKey(const Key('portrait-viewport'))).width,
          size.width,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('성장'));
        await tester.pumpAndSettle();
        for (final label in ['장비', '펫', '테크', '장착', '보관', '관리']) {
          final chip = find.widgetWithText(ChoiceChip, label).first;
          expect(tester.getRect(chip).right, lessThanOrEqualTo(size.width));
          // Larger readable navigation may occupy more height than the old 230px cap.
          // It must still leave at least half the short screen for page content.
          expect(tester.getRect(chip).bottom, lessThan(size.height / 2));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('출격').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('launch')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        final field = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is BattlePainter,
        );
        final rect = tester.getRect(field);
        final painter =
            tester.widget<CustomPaint>(field).painter! as BattlePainter;
        expect(rect.width, size.width);
        // The HUD owns real space; combat fills the area below it.
        final hud = tester.getRect(find.byKey(const Key('battle-hud-panel')));
        expect(rect.top, greaterThanOrEqualTo(hud.bottom));
        expect(rect.left, 0);
        expect(rect.bottom, size.height);
        expect(rect.height, greaterThan(size.height * .4));
        final playerOnScreen =
            rect.topLeft +
            (painter.game.position - painter.game.camera) * (rect.width / 420);
        expect(playerOnScreen.dx, closeTo(size.width / 2, .01));
        expect(playerOnScreen.dy, closeTo(rect.center.dy, .01));
        expect(
          painter.game.viewportHeight,
          closeTo(rect.height * 420 / rect.width, .01),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('일시정지'));
        await tester.pump();
        expect(find.text('계속 비행'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      },
    );
  }
  testWidgets(
    'desktop dialogs stay inside portrait frame and landscape keeps state',
    (tester) async {
      final p = await mount(tester, const Size(1280, 900));
      final frame = tester.getRect(find.byKey(const Key('portrait-viewport')));
      expect(frame.width, closeTo(900 * 9 / 19.5, .1));
      await tester.tap(find.byTooltip('설정'));
      await tester.pumpAndSettle();
      final dialog = tester.getRect(find.byType(Dialog));
      expect(dialog.left, greaterThanOrEqualTo(frame.left));
      expect(dialog.right, lessThanOrEqualTo(frame.right));
      await tapUi(tester, find.byTooltip('닫기').last);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(find.text('기기를 세로로 돌려주세요'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('launch')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
  testWidgets(
    'notch and bottom gesture inset keep launch and chapter sheet usable',
    (tester) async {
      tester.view.padding = FakeViewPadding(top: 44, bottom: 34);
      tester.view.viewPadding = FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final p = await mount(tester, const Size(360, 640));
      expect(
        tester.getRect(find.byKey(const Key('launch'))).bottom,
        lessThan(640 - 34 - 64),
      );
      await tester.tap(find.bySemanticsLabel('챕터 선택'));
      await tester.pumpAndSettle();
      expect(find.text('선택 완료'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('선택 완료'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
