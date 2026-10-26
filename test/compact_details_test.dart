import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/cat_gear.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/content_hub.dart';
import 'package:shootingstar/ui/item_slots.dart';

import 'ui_actions.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      // v12.10: the gear slot popup (list + details + one strip of
      // equip / upgrade / lock / dismantle tiles) replaced the old inventory
      // detail with refund and merge pages. Keep the intent: every decision
      // fits and is reachable, there is only the header close, and locked or
      // equipped pieces cannot be dismantled.
      testWidgets(
        'equipment decisions fit; one header close and guarded dismantle $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.credits = 5000;
          p.blueprints = 100;
          final starter = p.catGear.equippedIn(CatGearSlot.nose)!;
          final spare = p.catGear.add('night', CatGearSlot.nose, 1);
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
          await tapUi(tester, find.byKey(const Key('cat-gear-slot-nose')));
          await tester.pumpAndSettle();
          expect(find.byType(GameDialog), findsOneWidget);
          expect(find.widgetWithText(GameActionButton, '닫기'), findsNothing);
          expect(find.byTooltip('닫기'), findsOneWidget);
          final ids = p.catGear.items.map((i) => i.id).toList();
          GameActionTile tile(String key) =>
              tester.widget<GameActionTile>(find.byKey(Key(key)));

          // The equipped starter is picked first: it cannot be dismantled.
          await revealUi(tester, find.byKey(const Key('cat-gear-dismantle')));
          expect(tile('cat-gear-equip').onPressed, isNull);
          expect(tile('cat-gear-dismantle').onPressed, isNull);

          // Pick the spare, equip and upgrade it.
          await tapUi(
            tester,
            find.byKey(ValueKey('cat-gear-item-${spare.id}')),
          );
          await tester.pumpAndSettle();
          await tapUi(tester, find.byKey(const Key('cat-gear-equip')));
          await tester.pumpAndSettle();
          expect(p.catGear.equipped[CatGearSlot.nose], spare.id);
          final cost = spare.upgradeChuru;
          await tapUi(tester, find.byKey(const Key('cat-gear-upgrade')));
          await tester.pumpAndSettle();
          expect(spare.level, 2);
          expect(p.credits, 5000 - cost);

          // The unequipped starter: locking guards it, unlocking frees it.
          await tapUi(
            tester,
            find.byKey(ValueKey('cat-gear-item-${starter.id}')),
          );
          await tester.pumpAndSettle();
          await tapUi(tester, find.byKey(const Key('cat-gear-lock')));
          await tester.pumpAndSettle();
          expect(starter.locked, isTrue);
          await revealUi(tester, find.byKey(const Key('cat-gear-dismantle')));
          expect(tile('cat-gear-dismantle').onPressed, isNull);
          expect(p.catGear.items.map((i) => i.id).toList(), ids);
          await tapUi(tester, find.byKey(const Key('cat-gear-lock')));
          await tester.pumpAndSettle();
          expect(starter.locked, isFalse);
          final credits = p.credits, refund = starter.dismantleChuru;
          await tapUi(tester, find.byKey(const Key('cat-gear-dismantle')));
          await tester.pumpAndSettle();
          expect(p.catGear.item(starter.id), isNull);
          expect(p.credits, credits + refund);
          expect(tester.takeException(), isNull);

          // The sole header close leaves the hub as it was.
          await tester.tap(find.byTooltip('닫기').last);
          await tester.pumpAndSettle();
          expect(find.byType(GameDialog), findsNothing);
          expect(find.byKey(const Key('cat-gear-slot-nose')), findsOneWidget);
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
