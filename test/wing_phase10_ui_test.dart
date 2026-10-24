import 'package:shootingstar/ui/item_slots.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/boss_gear_hangar.dart';

import 'ui_actions.dart';

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
        'boss gear claim receipt, matching equip and world list fit $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.bossGear.record(0, 3);
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
              home: BossGearHangar(profile: p),
            ),
          );
          await tester.pumpAndSettle();
          await tapUi(
            tester,
            find.byWidgetPredicate(
              (w) => w is GameItemSlot && w.title == '잔광 외곽',
            ),
          );
          final before = p.inventory.length;
          final ids = <int>[];
          for (var i = 0; i < 2; i++) {
            final claim = find.widgetWithText(FilledButton, '장비 회수').first;
            await revealUi(tester, claim);
            expect(tester.getSize(claim).height, greaterThanOrEqualTo(72));
            expect(tester.getSize(claim).width, lessThanOrEqualTo(264));
            await tester.tap(claim);
            await tester.pumpAndSettle();
            expect(find.text('보스 장비 회수'), findsOneWidget);
            expect(p.inventory.last.spec, 12 + i);
            ids.add(p.inventory.last.id);
            final ok = find.widgetWithText(FilledButton, '확인');
            await revealUi(tester, ok);
            await tester.tap(ok);
            await tester.pumpAndSettle();
          }
          await tapUi(tester, find.byTooltip('닫기').last);
          expect(p.inventory.length, before + 2);
          expect(p.bossGear.pending(0), 0);
          p.equipItem(ids[0]);
          p.equipItem(ids[1]);
          await tester.pumpAndSettle();
          expect(p.activeBossSetWorld, 0);
          expect(find.textContaining('활성: 잔광 외곽 2피스'), findsOneWidget);
          await revealUi(tester, find.text('특이점 심장'));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await p.save();
          p.dispose();
        },
      );
    }
}
