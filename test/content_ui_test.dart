import 'package:shootingstar/ui/item_slots.dart';

import 'ui_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/content_hub.dart';
import 'package:shootingstar/ui/game_ui.dart';

void main() {
  testWidgets(
    '360px content tabs, merge review and pet feeding work without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.grantItem(0);
      p.grantItem(0);
      p.blueprints = 2;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: ContentHub(profile: p)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  (w.properties.label ?? '').startsWith('주무장 '),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tapUi(tester, find.text('합성'));
      await tester.pumpAndSettle();
      expect(find.text('합성 재료 확인'), findsOneWidget);
      await tester.tap(find.text('합성 확정'));
      await tester.pumpAndSettle();
      expect(p.gearAt(0).rank, 1);
      await tapUi(tester,find.byTooltip('장비 상세 닫기').last);
      await tester.tap(find.widgetWithText(ChoiceChip, '펫'));
      await tester.pumpAndSettle();
      await tapUi(
        tester,
        find.byWidgetPredicate(
          (w) => w is GameItemSlot && w.title.startsWith('삐약'),
        ),
      );
      await tapUi(tester, find.bySemanticsLabel('펫 육성').last);
      await tester.pumpAndSettle();
      expect(p.petLevels[0], 2);
      expect(tester.takeException(), isNull);
      await tapUi(tester, find.byTooltip('닫기').last);
      await tester.tap(find.widgetWithText(ChoiceChip, '테크'));
      await tester.pumpAndSettle();
      for (final name in ['보급', '시즌']) {
        await tester.tap(find.widgetWithText(ChoiceChip, '장비'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, '관리'));
        await tester.pumpAndSettle();
        await tapUi(tester, find.widgetWithText(GameActionButton, name));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
