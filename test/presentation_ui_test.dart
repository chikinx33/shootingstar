import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/reward_popup.dart';
import 'package:shootingstar/ui/arcade_home_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('slots and actual reward transfer $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        p.soundEnabled = false;
        p.onboarded = true;
        final app = ShootingstarApp(
          profile: p,
        ).build(tester.element(find.byType(View).first)) as MaterialApp;
        Widget mount(Widget child) => MaterialApp(
          theme: app.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        );
        final g = GameEngine(
          stageIndex: 0,
          shipIndex: 0,
          attackLevel: 0,
          hullLevel: 0,
          magnetLevel: 0,
          equipmentIndex: 0,
          seed: 623,
        )..developerInvincible = true;
        // v12.4.1: the level-up only opens when a gem reaches the cat.
        g.xp = g.xpNeeded;
        g.crystals.add(g.position);
        g.update(.01);
        await tester.pumpWidget(
          mount(BattleScreen(profile: p, engineFactory: () => g)),
        );
        // v12.7 skill cards deal in from the bottom over ~1.15 s.
        await tester.pump(const Duration(milliseconds: 1300));
        expect(find.byKey(const Key('upgrade-dark-backdrop')), findsOneWidget);
        expect(g.choices.length, 3);
        final choiceIds = g.choices.map((c) => c.id).toList();
        for (final id in choiceIds) {
          final rect = tester.getRect(find.byKey(Key('upgrade-$id')));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(Key('upgrade-${choiceIds.first}')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2100));
        expect(g.choices, isEmpty);
        expect(g.mainBranch, isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        final initial = p.credits;
        var grants = 0;
        await tester.pumpWidget(
          mount(
            Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    ResourceCounter(
                      image: CurrencyArt.churu,
                      label: '츄르',
                      value: p.credits,
                      onTap: () {},
                    ),
                    GameActionButton(
                      label: '보상 테스트',
                      onPressed: () => claimWithRewardPopup(context, p, () {
                        grants++;
                        p.credits += 77;
                        p.contentChanged();
                        return true;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('보상 테스트'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(p.credits, initial + 77);
        // v12.15: the ×N badge is outlined text (stroke + fill layers)
        expect(find.text('×77'), findsWidgets);
        await tester.tap(find.text('확인'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const Key('reward-flight-layer')), findsOneWidget);
        expect(
          find.text('보관함'),
          findsNothing,
          reason: 'visible credit counter is the destination',
        );
        await tester.pump(const Duration(milliseconds: 1400));
        expect(find.byKey(const Key('reward-flight-layer')), findsNothing);
        expect(p.credits, initial + 77);
        expect(grants, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        p.dispose();
      });
    }
  }
}
