import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/developer_screen.dart';
import 'package:shootingstar/ui/item_slots.dart';
import 'package:shootingstar/ui/talent_screen.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'picture selectors persist and completed research is compact $size $scale',
        (tester) async {
          final semantics = tester.ensureSemantics();
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
            await tester.tap(find.widgetWithText(ChoiceChip, name));
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
          final reload = await Profile.load();
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
          restored.developerConfigure(researchLevel: 3);
          await mount(TalentScreen(profile: restored));
          await tester.tap(find.byType(GameItemSlot).first);
          await tester.pumpAndSettle();
          expect(
            tester.getSize(find.byKey(const Key('game-dialog-panel'))).height,
            lessThan(300),
          );
          expect(find.text('연구 완료'), findsOneWidget);
          final labels = <String>[];
          void visit(dynamic node) {
            labels.add(node.getSemanticsData().label as String);
            node.visitChildren((dynamic child) {
              visit(child);
              return true;
            });
          }

          visit(
            tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!,
          );
          expect(labels.join('\n'), contains('연구 완료'));
          expect(find.byType(GameActionButton), findsNothing);
          expect(find.byKey(const Key('game-page-next')), findsNothing);
          expect(tester.takeException(), isNull);
          expect(prefs.getString(Profile.storageKey), before);
          await tester.pumpWidget(const SizedBox());
          normal.dispose();
          dev.dispose();
          restored.dispose();
          reload.dispose();
          semantics.dispose();
        },
      );
    }
  }
}
