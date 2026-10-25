import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/item_slots.dart';
import 'package:shootingstar/ui/catalog_screens.dart';
import 'package:shootingstar/ui/content_hub.dart';
import 'package:shootingstar/ui/armament_hangar.dart';
import 'package:shootingstar/ui/ship_hangar.dart';
import 'package:shootingstar/ui/boss_gear_hangar.dart';
import 'package:shootingstar/ui/evolution_codex.dart';
import 'package:shootingstar/ui/talent_screen.dart';
import 'package:shootingstar/ui/hangar_presets.dart';
import 'package:shootingstar/ui/game_ui.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('3+ column slots and real supply/gear details $size $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = Profile.developerCopy(await Profile.load());
        final app = ShootingstarApp(
          profile: p,
        ).build(tester.element(find.byType(View).first)) as MaterialApp;
        Future<void> mount(Widget child) async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            MaterialApp(
              theme: app.theme,
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

        // v12.8.1 the supply tab is a shelf of big crate cards and v12.10 the
        // weapon tab is the airframe slot screen, so neither is a slot grid;
        // the supply exchange tab and the pet row still are.
        Future<void> exchangeTab() async {
          await tester.tap(find.text('교환'));
          await tester.pumpAndSettle();
        }

        for (final (child, prepare) in <(Widget, Future<void> Function()?)>[
          (SupplyShop(profile: p), exchangeTab),
          (ArmamentHangar(profile: p), null),
          (ShipHangar(profile: p), null),
          (ContentHub(profile: p, initialPage: 2, showNavigation: false), null),
          (BossGearHangar(profile: p), null),
          (const EvolutionCodex(), null),
          (TalentScreen(profile: p), null),
          (HangarPresets(profile: p), null),
        ]) {
          await mount(child);
          await prepare?.call();
          final slots = find.byType(GameItemSlot);
          expect(slots.evaluate().length, greaterThanOrEqualTo(3));
          final a = tester.getRect(slots.at(0)),
              b = tester.getRect(slots.at(1)),
              c = tester.getRect(slots.at(2));
          expect(a.top, b.top);
          expect(b.top, c.top);
          expect(a.right, lessThan(b.left));
          expect(c.right, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
        }
        // The first supply crate's details open the real weapon part supply.
        await mount(SupplyShop(profile: p));
        // developer profiles remember the exchange tab picked above
        await tester.tap(find.text('보급'));
        await tester.pumpAndSettle();
        final owned = p.shipModules.owned.length;
        await tester.tap(find.bySemanticsLabel('무기 파츠 보급 상세'));
        await tester.pumpAndSettle();
        final action = find.widgetWithText(GameActionButton, '무기 파츠 보급 열기');
        for (
          var i = 0;
          i < 8 && !action.hitTestable().evaluate().isNotEmpty;
          i++
        ) {
          await tester.tap(find.byKey(const Key('game-page-next')).last);
          await tester.pumpAndSettle();
        }
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(p.shipModules.owned.length, owned + 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      });
    }
  }
}
