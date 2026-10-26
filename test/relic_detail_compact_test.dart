import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tabs.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/collection_screen.dart';
import 'package:shootingstar/ui/components.dart';

import 'ui_actions.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'relic crafting, recycle and invested reset remain intact $width',
      (tester) async {
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        final book = p.collections;
        book.dust = 6;
        book.shards[0] = 20;
        expect(book.upgrade(0), isTrue);
        expect(book.upgrade(0), isTrue);
        final app = ShootingstarApp(
          profile: p,
        ).build(tester.element(find.byType(View).first)) as MaterialApp;
        await tester.pumpWidget(
          MaterialApp(
            theme: app.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
            home: CollectionScreen(profile: p),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> tap(Finder f) async {
          await revealUi(tester, f);
          await tester.tap(f);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await tap(tabWithText('보관함'));
        await tap(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics && (w.properties.label ?? '') == '초신성 프리즘 Lv.2',
          ),
        );
        await tap(find.widgetWithText(GameActionButton, '조각 관리'));
        final shards = book.shards[0];
        await tap(find.widgetWithText(GameActionButton, '조각 제작'));
        await tap(find.widgetWithText(GameActionButton, '가루 3개 사용'));
        expect(book.dust, 3);
        expect(book.shards[0], shards + 1);
        await tap(find.widgetWithText(GameActionButton, '조각 분해'));
        await tap(find.widgetWithText(GameActionButton, '조각 1개 분해'));
        expect(book.dust, 4);
        expect(book.shards[0], shards);
        final refund = book.resetRefund(0);
        await tap(find.widgetWithText(GameActionButton, '강화 초기화'));
        await tap(find.widgetWithText(GameActionButton, '1등급으로 초기화'));
        expect(book.levels[0], 1);
        expect(book.shards[0], shards + refund);
        expect(find.widgetWithText(GameActionButton, '강화 초기화'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      },
    );
  }
}
