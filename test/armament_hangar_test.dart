import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/game_ui.dart';
import 'package:shootingstar/ui/item_slots.dart';
import 'package:shootingstar/ui/module_workshop.dart';

import 'ui_actions.dart';

// v12.9+: the old ten-weapon armament list is gone (the main gun is fixed to
// the airframe). Every "주무기" entry point now opens the module workshop, so
// owned part growth and salvage refunds must be reachable there instead.
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
        'module growth and salvage refund are reachable on one screen $width / $scale',
        (tester) async {
          final height = width == 320 ? 568.0 : 844.0;
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.credits = 3000;
          p.blueprints = 30;
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
              home: ModuleWorkshop(profile: p),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byType(GameItemSlot),
            findsNWidgets(moduleProfiles.length),
          );
          expect(tester.takeException(), isNull);

          // Growth: the equipped wing gun is upgraded from its detail popup.
          final id = p.moduleLoadout.parts['W1']!.instanceId;
          final level = p.shipModules.owned[id]!.level;
          final cost = p.moduleUpgradeCredits(level),
              plans = p.moduleUpgradePlans(level);
          await tapUi(tester, find.bySemanticsLabel('W1 모듈 편집'));
          await tester.pumpAndSettle();
          await tapUi(tester, find.byKey(ValueKey('module-item-$id')));
          await tester.pumpAndSettle();
          // v12.15: the part popup's actions are one strip of tiles
          final upgrade = find.byKey(const Key('part-detail-upgrade'));
          await revealUi(tester, upgrade);
          expect(tester.getRect(upgrade).bottom, lessThanOrEqualTo(height));
          await tester.tap(upgrade);
          await tester.pumpAndSettle();
          expect(p.shipModules.owned[id]!.level, level + 1);
          expect([p.credits, p.blueprints], [3000 - cost, 30 - plans]);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('닫기').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('닫기').last);
          await tester.pumpAndSettle();

          // Refund: a spare part is salvaged after an explicit confirmation.
          final spare = p.shipModules.add('gun_vulcan', level: 3);
          final credits = p.credits, dust = p.blueprints;
          await tapUi(tester, find.bySemanticsLabel('W1 모듈 편집'));
          await tester.pumpAndSettle();
          await tapUi(
            tester,
            find.byKey(ValueKey('module-item-${spare.instanceId}')),
          );
          await tester.pumpAndSettle();
          final salvage = find.byKey(const Key('part-detail-salvage'));
          await revealUi(tester, salvage);
          expect(tester.getRect(salvage).bottom, lessThanOrEqualTo(height));
          await tester.tap(salvage);
          await tester.pumpAndSettle();
          final confirm = find.widgetWithText(GameActionButton, '분해');
          await tapUi(tester, confirm);
          await tester.pumpAndSettle();
          expect(p.shipModules.owned.containsKey(spare.instanceId), isFalse);
          expect([p.credits, p.blueprints], [
            credits + 20 + 3 * 5,
            dust + 1 + 3 ~/ 3,
          ]);
          expect(p.moduleLoadout.parts['W1']!.instanceId, id);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
}
