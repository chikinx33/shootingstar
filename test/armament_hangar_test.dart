import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/armament_hangar.dart';
import 'package:shootingstar/ui/game_ui.dart';

Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.hitTestable().evaluate().isNotEmpty) return;
  for (final direction in ['previous', 'next']) {
    for (int i = 0; i < 30; i++) {
      final arrow = find.byKey(Key('game-page-$direction')).last;
      if (arrow.evaluate().isEmpty ||
          tester.widget<IconButton>(arrow).onPressed == null)
        break;
      await tester.tap(arrow);
      await tester.pump(const Duration(milliseconds: 40));
      if (target.hitTestable().evaluate().isNotEmpty) return;
    }
  }
  fail('Unreachable decision: $target');
}

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
        'owned growth and refund use reachable fixed pages $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.credits = 3000;
          p.blueprints = 30;
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
              home: ArmamentHangar(profile: p),
            ),
          );
          await tester.pumpAndSettle();
          final detail = find.byKey(const ValueKey('armament-detail-pulse'));
          await tester.ensureVisible(detail);
          await tester.pumpAndSettle();
          expect(tester.getSize(detail).height, greaterThanOrEqualTo(64));
          await tester.tap(detail);
          await tester.pumpAndSettle();
          final upgrade = find.byKey(const ValueKey('armament-upgrade-pulse'));
          await reveal(tester, upgrade);
          expect(tester.getSize(upgrade).height, greaterThanOrEqualTo(64));
          expect(
            tester.getRect(upgrade).bottom,
            lessThanOrEqualTo(width == 320 ? 568 : 844),
          );
          await tester.tap(upgrade);
          await tester.pumpAndSettle();
          expect(p.activeArmamentLevel, 1);
          expect([p.credits, p.blueprints], [2880, 29]);
          final reset = find.byKey(const ValueKey('armament-reset-pulse'));
          await reveal(tester, reset);
          await tester.tap(reset);
          await tester.pumpAndSettle();
          final confirm = find.widgetWithText(GameActionButton, '반환·초기화');
          await reveal(tester, confirm);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(p.activeArmamentLevel, 0);
          expect([p.credits, p.blueprints], [3000, 30]);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
}
