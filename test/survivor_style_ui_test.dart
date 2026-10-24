import 'ui_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/home.dart';
import 'package:shootingstar/ui/game_ui.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets(
      'three skill cards pause the run and apply a real choice at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        // Static layout fixtures opt out of ambient lobby motion.
        p.reducedEffects = true;
        p.onboarded = true;
        p.soundEnabled = false;
        final game = GameEngine(
          stageIndex: 0,
          shipIndex: 0,
          attackLevel: 0,
          hullLevel: 0,
          magnetLevel: 0,
          equipmentIndex: 0,
          seed: 17,
        );
        game.choices = const [
          UpgradeChoice('gun', '펄스 블래스터', '기체 전방의 주포를 강화합니다.', 'gun'),
          UpgradeChoice(
            'missile',
            '추적 로켓',
            '강한 적을 추적하는 범위 폭발을 추가합니다.',
            'missile',
          ),
          UpgradeChoice('attack', '고출력 탄두', '모든 무기의 피해량을 높입니다.', 'attack'),
        ];
        await tester.pumpWidget(ShootingstarApp(profile: p));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(HomeScreen))).push<void>(
          MaterialPageRoute(
            builder: (_) => BattleScreen(profile: p, engineFactory: () => game),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final before = game.elapsed;
        await tester.pump(const Duration(milliseconds: 800));
        expect(game.elapsed, before);
        final cards = [
          for (final id in ['gun', 'missile', 'attack'])
            tester.getRect(find.byKey(Key('upgrade-$id'))),
        ];
        expect(cards[0].top, cards[1].top);
        expect(cards[1].top, cards[2].top);
        expect(cards[0].right, lessThan(cards[1].left));
        expect(cards[2].right, lessThanOrEqualTo(size.width));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('upgrade-missile')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(game.upgrades['missile'], 1);
        expect(game.choices, isEmpty);
        await tester.pump(const Duration(milliseconds: 32));
        expect(game.elapsed, greaterThan(before));
        // The choice is run-local; the permanent inventory and currency survive.
        expect(p.credits, 150);
        expect(p.inventory.length, 6);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      },
    );
  }

  testWidgets(
    'bottom supply tab spends one ticket and preserves the item on reload',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      // Static layout fixtures opt out of ambient lobby motion.
      p.reducedEffects = true;
      await tester.pumpWidget(ShootingstarApp(profile: p));
      await tester.pumpAndSettle();
      await tester.tap(find.text('보급'));
      await tester.pumpAndSettle();
      await tapUi(tester, find.bySemanticsLabel('장비 보급 상세'));
      await revealUi(tester, find.widgetWithText(GameActionButton, '장비 보급 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('장비 보급 열기'));
      await tester.pumpAndSettle();
      expect(p.gearKeys, 0);
      expect(p.inventory.length, 7);
      final earned = p.inventory.last.id;
      final restored = await Profile.load();
      expect(restored.gearKeys, 0);
      expect(restored.inventory.last.id, earned);
      expect(restored.credits, p.credits);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
      restored.dispose();
    },
  );
}
