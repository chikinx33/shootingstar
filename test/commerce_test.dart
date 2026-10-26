import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/data/online_api.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/shop_ledger.dart';
import 'package:shootingstar/services/commerce_controller.dart';
import 'package:shootingstar/services/commerce_platform.dart';
import 'package:shootingstar/services/commerce_platform_stub.dart' as web;
import 'package:shootingstar/ui/supporter_screen.dart';

import 'ui_actions.dart';

class FixturePlatform implements CommercePlatform {
  final events = StreamController<StorePurchase>.broadcast();
  int buys = 0, restores = 0, ads = 0;
  final completed = <(String, bool)>[];
  bool consent = true;
  RewardAdOutcome outcome = RewardAdOutcome.completed;
  @override
  bool get supported => true;
  @override
  bool get privacyRequired => false;
  @override
  Stream<StorePurchase> get purchases => events.stream;
  @override
  Future<Map<String, StoreProduct>> products(Set<String> ids) async => {
    for (final id in ids) id: StoreProduct(id, '₩1,200'),
  };
  @override
  Future<void> buy(
    StoreProduct product, {
    required bool consumable,
    required String binding,
  }) async {
    buys++;
  }

  @override
  Future<void> restore() async {
    restores++;
  }

  @override
  Future<void> complete(StorePurchase purchase, {required bool consume}) async {
    completed.add((purchase.productId, consume));
  }

  @override
  Future<bool> prepareAds() async => consent;
  @override
  Future<void> privacyOptions() async {}
  @override
  Future<RewardAdOutcome> rewardAd(String unitId) async {
    ads++;
    return outcome;
  }

  @override
  void dispose() {
    events.close();
  }
}

class FixtureApi extends OnlineApi {
  String state = 'purchased';
  bool down = false;
  int verifies = 0;
  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (path != 'shop/verify') throw StateError('Unexpected request $path');
    verifies++;
    if (down) throw StateError('isolated outage');
    return {'state': state};
  }
}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<(Profile, FixtureApi, FixturePlatform, CommerceController)>
  setup() async {
    final p = await Profile.load(), api = FixtureApi();
    final cloud = CloudSync(p, api: api);
    final platform = FixturePlatform(),
        store = CommerceController(p, cloud, platform: platform);
    await store.initialize();
    await flush();
    addTearDown(() {
      store.dispose();
      cloud.dispose();
      p.dispose();
    });
    return (p, api, platform, store);
  }

  StorePurchase bought(ShopItem item, String token, StorePurchaseStatus s) =>
      StorePurchase(shopProducts[item]!.id, token, s);

  test('works without an account: products load and purchases restore', () async {
    final (p, _, platform, store) = await setup();
    expect(p.online!.signedIn, isFalse, reason: 'no account needed');
    expect(store.billingReady, isTrue);
    expect(platform.restores, 1);
    expect(p.shop.binding, hasLength(32));
    expect(store.canBuy(ShopItem.starter), isTrue);
    await store.buy(ShopItem.starter);
    expect(platform.buys, 1);
  });

  test('pending, cancelled and failed purchases never pay', () async {
    final (p, api, platform, _) = await setup();
    final credits = p.credits;
    for (final s in [
      StorePurchaseStatus.pending,
      StorePurchaseStatus.cancelled,
      StorePurchaseStatus.failed,
    ]) {
      platform.events.add(bought(ShopItem.starter, 'tok-starter-1', s));
      await flush();
    }
    expect(p.credits, credits);
    expect(api.verifies, 0);
    expect(platform.completed, isEmpty);
  });

  test('a confirmed purchase pays once, then is consumed or acknowledged', () async {
    final (p, api, platform, _) = await setup();
    final dust = p.blueprints;
    platform.events.add(
      bought(ShopItem.monthly, 'tok-monthly-1', StorePurchaseStatus.purchased),
    );
    await flush();
    expect(p.blueprints, dust + 20);
    expect(p.shop.monthlyActive(DateTime.now()), isTrue);
    expect(platform.completed.single, ('purr_monthly_snacks', true));

    // the same receipt restored again pays nothing and is not re-checked
    platform.events.add(
      bought(ShopItem.monthly, 'tok-monthly-1', StorePurchaseStatus.restored),
    );
    await flush();
    expect(p.blueprints, dust + 20);
    expect(api.verifies, 1);

    platform.events.add(
      bought(ShopItem.supporter, 'tok-frame-1', StorePurchaseStatus.purchased),
    );
    await flush();
    expect(p.shop.supporterOwned, isTrue);
    expect(platform.completed.last, ('purr_supporter_frame', false));
  });

  test('an unconfirmed receipt or a server outage leaves it unfinished', () async {
    final (p, api, platform, _) = await setup();
    final credits = p.credits;
    api.state = 'invalid';
    platform.events.add(
      bought(ShopItem.starter, 'tok-fake-1', StorePurchaseStatus.purchased),
    );
    await flush();
    api.state = 'purchased';
    api.down = true;
    platform.events.add(
      bought(ShopItem.starter, 'tok-real-1', StorePurchaseStatus.purchased),
    );
    await flush();
    expect(p.credits, credits);
    expect(platform.completed, isEmpty, reason: 'Play refunds or retries it');

    api.down = false;
    platform.events.add(
      bought(ShopItem.starter, 'tok-real-1', StorePurchaseStatus.restored),
    );
    await flush();
    expect(p.credits, credits + 1000);
    expect(platform.completed.single, ('purr_starter_pack', false));
  });

  test('ads pay only a finished view; the ad pass skips the video', () async {
    final (p, _, platform, store) = await setup();
    final keys = p.gearKeys;
    platform.outcome = RewardAdOutcome.closed;
    expect(await store.watch(AdOffer.supplyBox), isFalse);
    platform.outcome = RewardAdOutcome.unavailable;
    expect(await store.watch(AdOffer.supplyBox), isFalse);
    expect(p.gearKeys, keys);
    platform.outcome = RewardAdOutcome.completed;
    expect(await store.watch(AdOffer.supplyBox), isTrue);
    expect(p.gearKeys, keys + 1);
    expect(store.canWatch(AdOffer.supplyBox), isFalse, reason: 'once a day');

    p.applyPurchase(ShopItem.adPass, 'pass', DateTime.now());
    final ads = platform.ads;
    expect(
      await store.watch(AdOffer.runBonus, runId: 'r1', runCredits: 100),
      isTrue,
    );
    expect(platform.ads, ads);
  });

  test('the web build offers no ads and no checkout', () async {
    final p = await Profile.load();
    final store = CommerceController(
      p,
      CloudSync(p, api: FixtureApi()),
      platform: web.createCommercePlatform(),
    );
    await store.initialize();
    expect(store.offerVisible(AdOffer.runBonus), isFalse);
    expect(store.canBuy(ShopItem.starter), isFalse);
  });

  testWidgets('supporter screen offers restore and equips an owned look', (
    tester,
  ) async {
    final (p, _, platform, store) = await tester.runAsync(setup) ??
        (throw StateError('setup'));
    p.applyPurchase(ShopItem.supporter, 'frame', DateTime.now());
    await tester.pumpWidget(MaterialApp(home: SupporterScreen(profile: p)));
    await tester.pump();
    // the long screen is split into pages; walk them to collect actions
    final seen = <String>{};
    for (var i = 0; i < 4; i++) {
      for (final t in ['구매 복원', '후원 외형 장착']) {
        if (find.text(t).evaluate().isNotEmpty) seen.add(t);
      }
      if (find.text('후원 외형 장착').evaluate().isNotEmpty) {
        await tapUi(tester, find.text('후원 외형 장착'));
        break;
      }
      final next = find.byKey(const Key('game-page-next'));
      if (next.evaluate().isEmpty) break;
      await tapUi(tester, next);
    }
    for (var i = 0; i < 4 && !seen.contains('구매 복원'); i++) {
      final next = find.byKey(const Key('game-page-next'));
      if (next.evaluate().isEmpty) break;
      await tapUi(tester, next);
      if (find.text('구매 복원').evaluate().isNotEmpty) seen.add('구매 복원');
    }
    expect(seen, containsAll(['구매 복원', '후원 외형 장착']));
    await tester.runAsync(flush);
    await tester.pump();
    expect(store.cosmeticActive, isTrue);
    expect(platform.buys, 0);
  });
}
