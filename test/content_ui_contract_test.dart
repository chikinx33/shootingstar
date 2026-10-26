import 'ui_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/tabs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/cat_gear.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/daily_challenge.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/content_hub.dart';
import 'package:shootingstar/ui/pet_bond_screen.dart';
import 'package:shootingstar/ui/daily_challenge_screen.dart';
import 'package:shootingstar/ui/fleet_activity_screen.dart';
import 'package:shootingstar/ui/reward_popup.dart';

void main() {
  test('receipts show capped actual awards and typed supply without aliasing stock', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.credits = 9999997;
    final capped = RewardSnapshot(p);
    expect(p.claimSignIn(), isTrue);
    expect(capped.earned(p).singleWhere((e) => e.name == '츄르').amount, 2);
    p.techKeys = 1;
    final tech = RewardSnapshot(p);
    expect(p.openTechSupply(), isTrue);
    expect(tech.earned(p).single.atlas, 'icons');
    expect(tech.earned(p).single.amount, 1);
    p.gearKeys = 1;
    final gear = RewardSnapshot(p);
    expect(p.openGearSupply(), isTrue);
    expect(gear.earned(p).single.index, p.inventory.last.spec);
    expect(gear.earned(p).single.atlas, 'equipment');
    p.petEggs = 1;
    p.petSerial =
        0; // Existing Lumi: this fixture exercises duplicate-gene display.
    final pet = RewardSnapshot(p);
    expect(p.rescuePet(), isTrue);
    expect(pet.earned(p).single.name, contains('유전자'));
    expect(pet.earned(p).single.amount, 1);
    expect(pet.earned(p).single.atlas, 'ships');
    p.dispose();
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('detail, pets, daily and earned receipts at $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        p.credits = 5000;
        p.blueprints = 100;
        p.petFood = 500;
        p.petLevels[0] = 5;
        p.petRanks[0] = 1;
        p.petShards[0] = 10;
        p.petBond.favor[0] = 50;
        p.dailyChallenge.tokens = 16;
        p.grantItem(0);
        p.grantItem(0);
        final inventoryIds = p.inventory.map((g) => g.id).toList();
        final equipped = [...p.equippedGear];
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
              home: child,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        Future<void> reveal(Finder finder) => revealUi(tester, finder);

        Future<void> tap(Finder finder) async {
          await reveal(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        void checkDecisions() {
          for (final element in find.byType(GameActionButton).evaluate()) {
            final action = element.widget as GameActionButton;
            final painted = find.descendant(
              of: find.byWidget(action),
              matching: find.byType(RasterPanel),
            );
            final box = tester.getSize(painted);
            expect(box.width, lessThanOrEqualTo(264));
            expect(box.height, greaterThanOrEqualTo(action.primary ? 72 : 64));
            expect(box.width / box.height, lessThanOrEqualTo(4.25));
            final label = tester.widget<Text>(
              find.descendant(
                of: find.byWidget(action),
                matching: find.byType(Text),
              ),
            );
            expect(
              label.style!.fontSize,
              greaterThanOrEqualTo(action.primary ? 22 : 20),
            );
          }
          expect(tester.takeException(), isNull);
        }

        await mount(Scaffold(body: ContentHub(profile: p)));
        // v12.10: the growth screen opens one slot popup (list, details and
        // equip/upgrade/lock/dismantle tiles) instead of the old inventory
        // detail with merge; legacy GearItem stock must stay untouched.
        final nose = p.catGear.equippedIn(CatGearSlot.nose)!;
        await tap(find.byKey(const Key('cat-gear-slot-nose')));
        expect(find.byType(GameDialog), findsOneWidget);
        expect(find.byKey(const Key('cat-gear-list-nose')), findsOneWidget);
        checkDecisions();
        final cost = nose.upgradeChuru;
        await tap(find.byKey(const Key('cat-gear-upgrade')));
        expect(nose.level, 2);
        expect(p.credits, 5000 - cost);
        await tap(find.byTooltip('닫기').last);
        expect(find.byType(GameDialog), findsNothing);
        expect(p.inventory.map((g) => g.id).toList(), inventoryIds);

        await mount(PetBondScreen(profile: p, pet: 0));
        await tap(find.widgetWithText(GameActionButton, '선물 10'));
        expect(p.petBond.favor[0], 60);
        expect(p.petFood, 490);
        // A live growth notice must not cover the fixed pagination controls.
        // v12.4.3: phones from 360x720 fit one page; smaller ones still page.
        final back = find.byKey(const Key('game-page-previous'));
        final forward = find.byKey(const Key('game-page-next'));
        if (forward.evaluate().isNotEmpty) {
          final arrow = tester.widget<IconButton>(back).onPressed != null
              ? back
              : forward;
          final pageCounter = find.descendant(
            of: find.byType(GamePages).last,
            matching: find.byWidgetPredicate(
              (w) => w is Text && RegExp(r'^\d+ / \d+$').hasMatch(w.data ?? ''),
            ),
          );
          final pageBefore = tester.widget<Text>(pageCounter).data;
          await tester.tapAt(tester.getCenter(arrow));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.widget<Text>(pageCounter).data, isNot(pageBefore));
        }

        await tap(find.widgetWithText(GameActionButton, '각성 1단계'));
        expect(p.petBond.awakening[0], 1);
        expect(p.petFood, 470);
        await tap(find.text('신속 동행'));
        expect(p.petBond.skills[0], 1);
        await tap(find.widgetWithText(GameActionButton, '각성 되돌리기'));
        checkDecisions();
        await tap(find.widgetWithText(GameActionButton, '취소'));
        expect(p.petBond.awakening[0], 1);
        expect(p.petBond.favor[0], 60);

        DailyChallengeEntry? launched;
        await mount(
          DailyChallengeScreen(
            profile: p,
            onLaunch: (entry) async => launched = entry,
            onExchange: p.exchangeDailyChallenge,
          ),
        );
        await tap(find.byKey(const ValueKey('daily-launch-0')));
        expect(launched!.seed, p.dailyChallenge.begin(0)!.seed);
        await tester.drag(find.byType(ListView), const Offset(0, 10000));
        await tester.pumpAndSettle();
        await tap(tabWithText('토큰 교환'));
        final keys = p.collections.keys;
        await tap(find.byKey(const ValueKey('daily-exchange-2')));
        expect(find.byType(RewardPopup), findsOneWidget);
        expect(p.dailyChallenge.tokens, 8);
        expect(p.collections.keys, keys + 1);
        checkDecisions();
        final receipt = tester.widget<RewardPopup>(find.byType(RewardPopup));
        expect(receipt.entries.single.name, '수집품 보급권');
        expect(receipt.entries.single.amount, 1);
        final once = p.exportProgress();
        await tester.tap(find.byTooltip('보상 닫기'));
        await tester.pumpAndSettle();
        expect(p.exportProgress(), once);
        expect(p.dailyChallenge.canExchange(2), isFalse);

        await mount(FleetActivityScreen(profile: p));
        final credits = p.credits;
        // v12.15: today's glowing day card claims on tap
        await tap(find.text('1일'));
        expect(p.credits, credits + 30);
        expect(find.byType(RewardPopup), findsOneWidget);
        checkDecisions();
        final earned = p.exportProgress();
        await tap(find.widgetWithText(GameActionButton, '확인'));
        expect(p.exportProgress(), earned);
        expect(p.claimSignIn(), isFalse);
        await p.save();
        final restored = await Profile.load();
        expect(restored.inventory.map((g) => g.id).toList(), inventoryIds);
        expect(restored.equippedGear, equipped);
        expect(restored.catGear.equippedIn(CatGearSlot.nose)!.level, 2);
        expect(restored.petBond.favor[0], 60);
        expect(restored.petBond.awakening[0], 1);
        expect(restored.dailyChallenge.purchases[2], 1);
        expect(restored.journal.signedInToday, isTrue);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
        restored.dispose();
      });
    }
  }
}
