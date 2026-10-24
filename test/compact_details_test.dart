import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/content_hub.dart';

import 'ui_actions.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'equipment decisions fit; no empty refund or duplicate close $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.credits = 5000;
          p.blueprints = 100;
          p.grantItem(0);
          p.grantItem(0);
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
              home: Scaffold(body: ContentHub(profile: p)),
            ),
          );
          await tester.pumpAndSettle();
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
          expect(find.widgetWithText(GameActionButton, '닫기'), findsNothing);
          expect(find.text('재료 반환'), findsNothing);
          expect(find.byTooltip('장비 상세 닫기'), findsOneWidget);
          final gear = p.gearAt(0),
              original = p.inventory.map((g) => g.id).toList();
          final cost = p.itemUpgradeCost(gear);
          final upgrade = find.widgetWithText(GameActionButton, '강화');
          await revealUi(tester, upgrade);
          await tester.tap(upgrade);
          await tester.pumpAndSettle();
          expect(gear.level, 1);
          expect(p.credits, 5000 - cost);
          expect(p.blueprints, 99);
          final refund = find.text('재료 반환');
          await revealUi(tester, refund);
          await tester.tap(refund);
          await tester.pumpAndSettle();
          final confirm = find.widgetWithText(GameActionButton, '반환 확정');
          await revealUi(tester, confirm);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(gear.level, 0);
          expect(p.credits, 5000);
          expect(p.blueprints, 100);
          final merge = find.widgetWithText(FilledButton, '합성');
          await revealUi(tester, merge);
          await tester.tap(merge);
          await tester.pumpAndSettle();
          expect(find.text('합성 재료 확인'), findsOneWidget);
          // Cancelling via the sole header close must leave every item intact.
          await tester.tap(find.byTooltip('닫기').last);
          await tester.pumpAndSettle();
          expect(p.inventory.map((g) => g.id).toList(), original);
          await revealUi(tester, merge);
          await tester.tap(merge);
          await tester.pumpAndSettle();
          final accept = find.widgetWithText(GameActionButton, '합성 확정');
          await revealUi(tester, accept);
          await tester.tap(accept);
          await tester.pumpAndSettle();
          expect(gear.rank, 1);
          expect(p.inventory.length, original.length - 2);
          await tester.tap(find.byTooltip('장비 상세 닫기'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
  }
  testWidgets('last fixed page shrinks to visible content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => GameDialog(
                  title: '높이 검사',
                  child: Column(
                    children: [
                      for (var i = 0; i < 9; i++)
                        SizedBox(height: 100, child: Text('항목 $i')),
                    ],
                  ),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    final panel = find.byKey(const Key('game-dialog-panel'));
    final first = tester.getSize(panel).height;
    for (var i = 0; i < 5; i++) {
      final next = find.byKey(const Key('game-page-next'));
      if (tester.widget<IconButton>(next).onPressed == null) break;
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(tester.getSize(panel).height, lessThan(first - 100));
    expect(find.text('항목 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
