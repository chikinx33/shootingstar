import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/ship_hangar.dart';
import 'package:shootingstar/ui/item_slots.dart';

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
      testWidgets(
        'ship showcase decision fits and charges only once $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.credits = 1000;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ShipHangar(profile: p),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> openShip(int i) async {
            await tester.tap(find.byType(GameItemSlot).at(i));
            await tester.pumpAndSettle();
          }
          await openShip(1);
          final vector = find.byKey(const ValueKey('ship-select-1'));
          await revealUi(tester, vector);
          final rect = tester.getRect(vector);
          expect(rect.height, greaterThanOrEqualTo(72));
          expect(rect.width, lessThanOrEqualTo(264));
          expect(
            rect.bottom,
            lessThanOrEqualTo(tester.view.physicalSize.height),
          );
          await tester.tap(vector);
          await tester.pumpAndSettle();
          expect(p.selectedShip, 1);
          expect(p.credits, 800);
          expect(p.unlockedShips, contains(1));
          await openShip(0);
          final aurora = find.byKey(const ValueKey('ship-select-0'));
          await revealUi(tester, aurora);
          await tester.tap(aurora);
          await tester.pumpAndSettle();
          await openShip(1);
          await revealUi(tester, vector);
          await tester.tap(vector);
          await tester.pumpAndSettle();
          expect(p.selectedShip, 1);
          expect(p.credits, 800);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
  }
}
