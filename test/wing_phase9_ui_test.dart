import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/campaign_reward_views.dart';

import 'ui_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'result receipt and reward guide use reachable fixed pages $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.soundEnabled = false;
          final g =
              GameEngine(
                  stageIndex: 0,
                  shipIndex: 0,
                  attackLevel: 0,
                  hullLevel: 0,
                  magnetLevel: 0,
                  equipmentIndex: 0,
                )
                ..elapsed = 180
                ..kills = 100
                ..bossesDefeated = 1
                ..victory = true
                ..finished = true;
          final app = ShootingstarApp(
            profile: p,
          ).build(tester.element(find.byType(View).first)) as MaterialApp;
          Widget wrap(Widget child) => MaterialApp(
            theme: app.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: child,
          );
          await tester.pumpWidget(
            wrap(BattleScreen(profile: p, engineFactory: () => g)),
          );
          await tester.pump(const Duration(milliseconds: 32));
          await tester.pump(const Duration(milliseconds: 32));
          expect(p.campaignRewards.routes, {0});
          final balance = p.credits;
          // v12.4.3: the one-page result keeps details behind the '보상' button.
          await tapUi(tester, find.byKey(const Key('result-rewards')));
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.text('보상·기록'), findsOneWidget);
          final receipt = find.widgetWithText(FilledButton, '보상 내역');
          await revealUi(tester, receipt);
          expect(tester.getSize(receipt).height, greaterThanOrEqualTo(64));
          await tester.tap(receipt);
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.text('출격 보상 내역'), findsOneWidget);
          await revealUi(tester, find.text('항로 첫 보너스'));
          expect(find.text('항로 첫 보너스'), findsOneWidget);
          expect(p.credits, balance);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            wrap(
              Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => showCampaignRewardGuide(context, p, 0),
                      child: const Text('안내 열기'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('안내 열기'));
          await tester.pumpAndSettle();
          expect(find.text('보스·항로 보상'), findsOneWidget);
          await revealUi(tester, find.text('항로 첫 보너스 · 수령 완료'));
          expect(p.credits, balance);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await p.save();
          p.dispose();
        },
      );
    }
  }
}
