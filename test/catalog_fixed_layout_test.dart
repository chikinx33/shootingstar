import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/content_catalog.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/arcade_home_widgets.dart';
import 'package:shootingstar/ui/catalog_screens.dart';
import 'package:shootingstar/ui/collection_screen.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/reward_popup.dart';

import 'ui_actions.dart';

import 'package:shootingstar/ui/item_slots.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('fixed lobby and catalog transactions $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        p.onboarded = true;
        p.soundEnabled = false;
        p.credits = 7000;
        p.seasonXp = 2000;
        p.collections.keys = 1;
        p.collections.dust = 3;
        p.mail.add(
          RewardMail(
            'fixed-ui-mail',
            '원정 지원 보상 · 오래 보관한 우편',
            credits: 70,
            plans: 3,
            food: 15,
            gearKeys: 1,
          ),
        );
        final originalIds = p.inventory.map((g) => g.id).toList();
        final app = ShootingstarApp(
          profile: p,
        ).build(tester.element(find.byType(View).first)) as MaterialApp;
        Future<void> mount(Widget child, {bool notch = false}) async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            MaterialApp(
              theme: app.theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: notch
                      ? const EdgeInsets.only(top: 24, bottom: 20)
                      : EdgeInsets.zero,
                ),
                child: child!,
              ),
              home: child,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        Finder action(String label) => find.byWidgetPredicate(
          (w) => w is GameActionButton && w.label == label,
        );
        await mount(app.home!, notch: true);
        expect(find.byType(Scrollable), findsNothing);
        final controls = [
          find.byKey(const Key('launch')),
          find.bySemanticsLabel('45초 훈련'),
          find.bySemanticsLabel('비행 가이드'),
          ...find
              .byType(BridgeAction)
              .evaluate()
              .map((e) => find.byWidget(e.widget)),
        ];
        final field = tester.getRect(
          find.byKey(const Key('fixed-lobby-field')),
        );
        final before = controls.map(tester.getRect).toList();
        for (var i = 0; i < controls.length; i++) {
          expect(before[i].top, greaterThanOrEqualTo(24));
          expect(before[i].bottom, lessThanOrEqualTo(size.height - 20));
          expect(
            controls[i].hitTestable(),
            findsOneWidget,
            reason: 'control $i field $field bounds $before',
          );
          if (i >= 3) {
            expect(
              field.contains(before[i].bottomRight - const Offset(.1, .1)),
              isTrue,
            );
          }
          for (var j = 0; j < i; j++) {
            expect(before[i].overlaps(before[j]), isFalse);
          }
        }
        final unchanged = jsonEncode(p.exportProgress());
        await tester.dragFrom(field.center, const Offset(0, -150));
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: field.center,
            scrollDelta: const Offset(0, 400),
          ),
        );
        await tester.pumpAndSettle();
        expect(controls.map(tester.getRect).toList(), before);
        expect(jsonEncode(p.exportProgress()), unchanged);
        await mount(Scaffold(body: SupplyShop(profile: p)));
        final heading = tester.getRect(find.text('함대 보급'));
        await tester.drag(find.byType(ListView), const Offset(0, -240));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('함대 보급')), heading);
        await tapUi(tester, find.text('교환'));
        // v12.15: exchange goods are product cards with their price button.
        final credits = p.credits, plans = p.blueprints;
        await tapUi(tester, action('별가루 교환'));
        expect(p.credits, credits - 100);
        expect(p.blueprints, plans + 3);
        expect(find.byType(RewardPopup), findsOneWidget);
        final earned = jsonEncode(p.exportProgress());
        await tapUi(tester, action('확인'));
        expect(jsonEncode(p.exportProgress()), earned);
        await mount(Scaffold(body: SeasonMailbox(profile: p)));
        // v12.15: the season is a tier track; the reached reward is tapped.
        await tapUi(tester, find.byKey(const ValueKey('season-claim-1')));
        expect(p.seasonClaims.contains(1), isTrue);
        await tapUi(tester, action('확인'));
        await tapUi(tester, find.text('우편'));
        final mailHeader = tester.getRect(find.text('보상 우편').first);
        final mailCredits = p.credits;
        await tapUi(tester, find.byKey(const ValueKey('mail-claim-fixed-ui-mail')));
        expect(p.credits, mailCredits + 70);
        await tapUi(tester, action('확인'));
        expect(p.claimMail('fixed-ui-mail'), isFalse);
        expect(tester.getRect(find.text('보상 우편').first), mailHeader);
        await mount(CollectionScreen(profile: p));
        expect(find.byType(Scrollable), findsNothing);
        await tapUi(tester, action('유물 조사 · 탐사권 1'));
        expect(p.collections.keys, 0);
        expect(p.collections.shards[0], 3);
        expect(
          tester
              .widget<RewardPopup>(find.byType(RewardPopup))
              .entries
              .single
              .amount,
          3,
        );
        await tapUi(tester, action('확인'));
        await tapUi(tester, find.text('보관함'));
        final collectionHeader = tester.getRect(find.text('수집품').last);
        await tester.drag(find.byType(ListView), const Offset(0, -240));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('수집품').last), collectionHeader);
        await tapUi(
          tester,
          find.byWidgetPredicate(
            (w) => w is GameItemSlot && w.title == '초신성 프리즘',
          ),
        );
        await tapUi(tester, action('초신성 프리즘 상세'));
        expect(
          find.descendant(
            of: find.byType(GameDialog),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
        await tapUi(tester, action('조각 제작 · 가루 3'));
        await tapUi(tester, action('취소'));
        expect(p.collections.dust, 3);
        expect(p.collections.shards[0], 3);
        await tapUi(tester, action('조각 제작 · 가루 3'));
        await tapUi(tester, action('가루 3개 사용'));
        expect(p.collections.dust, 0);
        expect(p.collections.shards[0], 4);
        await tester.pumpWidget(const SizedBox());
        await p.save();
        final restored = await Profile.load();
        expect(restored.inventory.map((g) => g.id).toList(), originalIds);
        expect(restored.collections.shards[0], 4);
        expect(
          restored.mail.singleWhere((m) => m.id == 'fixed-ui-mail').claimed,
          isTrue,
        );
        expect(restored.seasonClaims.contains(1), isTrue);
        expect(tester.takeException(), isNull);
        p.dispose();
        restored.dispose();
      });
    }
  }
}
