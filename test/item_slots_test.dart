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

        for (final child in <Widget>[
          SupplyShop(profile: p),
          ArmamentHangar(profile: p),
          ShipHangar(profile: p),
          ContentHub(profile: p, initialPage: 1, showNavigation: false),
          ContentHub(profile: p, initialPage: 2, showNavigation: false),
          BossGearHangar(profile: p),
          const EvolutionCodex(),
          TalentScreen(profile: p),
          HangarPresets(profile: p),
        ]) {
          await mount(child);
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
        await mount(SupplyShop(profile: p));
        final inventory = p.inventory.length;
        await tester.tap(find.byType(GameItemSlot).first);
        await tester.pumpAndSettle();
        // Detail choices are fixed pages; seek the actual purchase action.
        final action = find.widgetWithText(GameActionButton, '장비 보급 열기');
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
        expect(p.inventory.length, inventory + 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      });
    }
  }
}
