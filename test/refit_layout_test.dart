import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/arcade_home_widgets.dart';
import 'package:shootingstar/ui/item_slots.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('refit lobby controls and ship entry $size scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        // Static layout fixtures opt out of ambient lobby motion.
        p.reducedEffects = true;
        if (size.width == 320) p.selectedStage = 99;
        final before = jsonEncode(p.exportProgress());
        final app = ShootingstarApp(
          profile: p,
        ).build(tester.element(find.byType(View).first)) as MaterialApp;
        await tester.pumpWidget(
          MaterialApp(
            theme: app.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 24, bottom: 20),
              ),
              child: child!,
            ),
            home: app.home,
          ),
        );
        await tester.pumpAndSettle();
        final controls = [
          find.byKey(const Key('launch')),
          find.bySemanticsLabel('45초 훈련'),
          find.bySemanticsLabel('비행 가이드'),
          find.bySemanticsLabel('챕터 선택'),
          ...find
              .byType(BridgeAction)
              .evaluate()
              .map((e) => find.byWidget(e.widget)),
        ];
        final bounds = controls.map(tester.getRect).toList();
        for (var i = 0; i < controls.length; i++) {
          expect(controls[i].hitTestable(), findsOneWidget);
          expect(bounds[i].height, greaterThanOrEqualTo(48));
          expect(bounds[i].top, greaterThanOrEqualTo(24));
          expect(bounds[i].bottom, lessThanOrEqualTo(size.height - 20));
          for (var j = 0; j < i; j++) {
            expect(bounds[i].overlaps(bounds[j]), isFalse);
          }
        }
        final field = tester.getRect(
          find.byKey(const Key('fixed-lobby-field')),
        );
        final craft = tester.getRect(
          find.byKey(const Key('lobby-ship-select')),
        );
        expect(craft.height, greaterThanOrEqualTo(48));
        expect(craft.width, lessThanOrEqualTo(248));
        expect(field.contains(craft.center), isTrue);
        for (final box in bounds.skip(3)) {
          expect(craft.overlaps(box), isFalse);
        }
        expect(find.byType(Scrollable), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('lobby-ship-select')));
        await tester.pumpAndSettle();
        expect(find.byType(GameItemSlot), findsNWidgets(3));
        expect(jsonEncode(p.exportProgress()), before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      });
    }
  }
}
