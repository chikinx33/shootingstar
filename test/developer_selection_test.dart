import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/tabs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/developer_screen.dart';
import 'package:shootingstar/ui/item_slots.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'developer picture selectors persist across a session reload $size $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final normal = await Profile.load();
          await normal.save();
          final prefs = await SharedPreferences.getInstance();
          final before = prefs.getString(Profile.storageKey);
          final dev = await normal.startDeveloperSession();
          final theme = (ShootingstarApp(profile: normal).build(
            tester.element(find.byType(View).first),
          ) as MaterialApp).theme;
          Future<void> mount(Widget child) async {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(body: child),
              ),
            );
            await tester.pumpAndSettle();
          }

          Future<void> tab(String name) async {
            await tester.tap(tabWithText(name));
            await tester.pumpAndSettle();
          }

          Future<void> choose(String key) async {
            final item = find.byKey(ValueKey(key));
            final list = find.byType(ListView).last;
            for (var attempt = 0; attempt < 12; attempt++) {
              final bounds = tester.getRect(item),
                  viewport = tester.getRect(list);
              if (bounds.top >= viewport.top &&
                  bounds.bottom <= viewport.bottom)
                break;
              await tester.drag(
                list,
                Offset(0, bounds.top < viewport.top ? 130 : -130),
              );
              await tester.pumpAndSettle();
            }
            await tester.tap(item);
            await tester.pumpAndSettle();
            expect(tester.widget<GameItemSlot>(item).selected, isTrue);
            expect(
              find.descendant(of: item, matching: find.byIcon(Icons.check)),
              findsOneWidget,
            );
          }

          void columns() {
            final slots = find.byType(GameItemSlot);
            final boxes = List.generate(3, (i) => tester.getRect(slots.at(i)));
            expect(boxes[0].top, boxes[1].top);
            expect(boxes[1].top, boxes[2].top);
            expect(boxes[2].right, lessThanOrEqualTo(size.width));
          }

          await mount(DeveloperTestScreen(profile: dev));
          columns();
          await choose('test-weapon-4');
          await tab('기체');
          columns();
          await choose('test-ship-2');
          await tab('항로');
          columns();
          await choose('test-world-6');
          await tab('세부 항로');
          columns();
          await choose('test-route-8');
          await dev.save();
          // The developer session never writes the normal save.
          expect(prefs.getString(Profile.storageKey), before);
          // A restart reloads (and may re-save) the normal profile itself;
          // from then on the restored developer session must not touch it.
          final reload = await Profile.load();
          final reloaded = prefs.getString(Profile.storageKey);
          await reload.restoreDeveloperSession();
          final restored = reload.developerSession!;
          expect(restored.activeArmamentIndex, 4);
          expect(restored.selectedShip, 2);
          expect(restored.selectedStage, 68);
          await mount(DeveloperTestScreen(profile: restored));
          expect(
            tester
                .widget<GameItemSlot>(
                  find.byKey(const ValueKey('test-route-8')),
                )
                .selected,
            isTrue,
          );
          // v12.4.3: the research tab (TalentScreen) became the module
          // workshop, so the old completed-research popup check is gone.
          expect(tester.takeException(), isNull);
          expect(prefs.getString(Profile.storageKey), reloaded);
          await tester.pumpWidget(const SizedBox());
          normal.dispose();
          dev.dispose();
          restored.dispose();
          reload.dispose();
        },
      );
    }
  }
}
