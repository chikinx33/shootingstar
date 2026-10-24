import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/data/online_api.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/services/commerce_controller.dart';
import 'package:shootingstar/services/commerce_platform.dart';
import 'package:shootingstar/services/commerce_platform_stub.dart' as web;
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/supporter_screen.dart';

import 'ui_actions.dart';

class FixturePlatform implements CommercePlatform {
  final events = StreamController<StorePurchase>.broadcast();
  int buys = 0, restores = 0, completed = 0, ads = 0;
  bool consent = true;
  RewardAdOutcome outcome = RewardAdOutcome.completed;
  void Function()? afterAd;
  @override
  bool get supported => true;
  @override
  bool get privacyRequired => false;
  @override
  Stream<StorePurchase> get purchases => events.stream;
  @override
  Future<StoreProduct?> product(String id) async => StoreProduct(id, '₩4,900');
  @override
  Future<void> buy(StoreProduct product, String accountBinding) async {
    buys++;
  }

  @override
  Future<void> restore(String accountBinding) async {
    restores++;
  }

  @override
  Future<void> complete(StorePurchase purchase) async {
    completed++;
  }

  @override
  Future<bool> prepareAds(String appId) async => consent;
  @override
  Future<void> privacyOptions() async {}
  @override
  Future<RewardAdOutcome> rewardAd({
    required String unitId,
    required String nonce,
    required String userId,
  }) async {
    ads++;
    afterAd?.call();
    return outcome;
  }

  @override
  void dispose() {
    events.close();
  }
}

class FixtureApi extends OnlineApi {
  bool configured = true, supporter = false, grant = false, reject = false;
  String purchaseState = 'purchased';
  bool acknowledged = true;
  int begins = 0, closes = 0, purchaseCalls = 0, revision = 0;
  Map<String, dynamic> remote = Profile.freshProgress();
  Completer<Map<String, dynamic>>? purchaseWait;
  Map<String, dynamic> state() => {
    'billingAvailable': configured,
    'adsAvailable': configured,
    'productId': 'supporter',
    'accountBinding': 'bound-one',
    'adUnitId': 'isolated-test-unit',
    'adAppId': 'isolated-test-app',
    'supporter': supporter,
    'remaining': grant ? 1 : 2,
    'grants': [
      if (grant) {'id': 'grant-one', 'run': 'run1', 'credits': 20},
    ],
  };
  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (reject) throw StateError('isolated unavailable');
    switch (path) {
      case 'commerce/refresh':
      case 'commerce/state':
        return state();
      case 'commerce/purchase':
        purchaseCalls++;
        if (purchaseWait != null) return purchaseWait!.future;
        supporter = purchaseState == 'purchased';
        return {
          ...state(),
          'purchaseState': purchaseState,
          'acknowledged': acknowledged,
        };
      case 'commerce/ad-begin':
        begins++;
        return {...state(), 'nonce': 'isolated-nonce', 'userId': 'bound-one'};
      case 'commerce/ad-close':
        closes++;
        return state();
      case 'cloud/read':
        return {'revision': revision, 'updatedAt': 1, 'profile': remote};
      case 'cloud/write':
        remote = Map<String, dynamic>.from(data['profile']);
        revision++;
        return {
          'revision': revision,
          'updatedAt': 1,
          'verifiedAdCredits': remote['verifiedAdCredits'],
        };
      default:
        throw StateError('Unexpected request $path');
    }
  }
}

class FixtureCloud extends CloudSync {
  FixtureCloud(super.profile, {required super.api});
  void switchTo(String id) {
    account = id.isEmpty ? null : {'id': id};
    notifyListeners();
  }
}

Future<void> flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<
    (Profile, FixtureApi, FixtureCloud, FixturePlatform, CommerceController)
  >
  setup({bool configured = true}) async {
    final p = await Profile.load(), api = FixtureApi()..configured = configured;
    final cloud = FixtureCloud(p, api: api)
      ..ready = true
      ..boundId = 'one'
      ..account = {'id': 'one'};
    final platform = FixturePlatform(),
        store = CommerceController(p, cloud, platform: platform);
    await store.initialize();
    await flush();
    addTearDown(() {
      store.dispose();
      cloud.dispose();
      p.dispose();
    });
    return (p, api, cloud, platform, store);
  }

  test(
    'missing IDs prevent purchases and ads without touching base credits',
    () async {
      final (p, api, _, platform, store) = await setup(configured: false);
      await store.buy();
      await store.watchReward(runId: 'run1', seconds: 60, kills: 20);
      expect(store.canBuy, false);
      expect(platform.buys, 0);
      expect(platform.ads, 0);
      expect(api.begins, 0);
      expect(p.credits, 150);
      final stub = web.createCommercePlatform();
      expect(stub.supported, false);
      expect(await stub.prepareAds('anything'), false);
      stub.dispose();
    },
  );
  test('Play pending/cancel/error events never grant; verified purchase completes after server approval', () async {
    final (p, api, _, platform, store) = await setup();
    await store.buy();
    await store.buy();
    expect(platform.buys, 1, reason: 'duplicate taps must not start a second checkout');
    platform.events.add(
      const StorePurchase('supporter', 'token', StorePurchaseStatus.pending),
    );
    await flush();
    expect(store.supporter, false);
    expect(platform.completed, 0);
    platform.events.add(
      const StorePurchase('supporter', 'token', StorePurchaseStatus.cancelled),
    );
    await flush();
    expect(store.canBuy, true);
    api.purchaseState = 'pending';
    platform.events.add(
      const StorePurchase('supporter', 'token', StorePurchaseStatus.purchased),
    );
    await flush();
    expect(store.supporter, false);
    expect(platform.completed, 0);
    api.purchaseState = 'purchased';
    platform.events.add(
      const StorePurchase('supporter', 'token', StorePurchaseStatus.restored),
    );
    await flush();
    expect(store.supporter, true);
    expect(platform.completed, 1);
    await store.selectCosmetic(true);
    expect(store.cosmeticActive, true);
    final saved = jsonEncode(p.exportProgress());
    expect(saved.contains('supporter'), false);
    expect(saved.contains('"token"'), false);
    api.supporter = false;
    await store.refresh(restore: true);
    expect(store.cosmeticActive, false);
    expect(platform.restores, 2);
  });
  test('account switch discards a late ownership response and account-bound cosmetic selection', () async {
    final (_, api, cloud, platform, store) = await setup();
    api.purchaseWait = Completer();
    platform.events.add(
      const StorePurchase('supporter', 'token', StorePurchaseStatus.purchased),
    );
    await flush();
    cloud.switchTo('two');
    await flush();
    api.purchaseWait!.complete({
      ...api.state(),
      'supporter': true,
      'purchaseState': 'purchased',
      'acknowledged': true,
    });
    await flush();
    expect(store.supporter, false);
    expect(store.cosmeticActive, false);
    expect(platform.completed, 0);
  });
  test('advert completion alone cannot mint credits; consent/no-fill/closed preserve base reward', () async {
    final (p, api, _, platform, store) = await setup();
    platform.consent = false;
    await store.watchReward(runId: 'run1', seconds: 60, kills: 20);
    expect(platform.ads, 0);
    expect(api.begins, 0);
    expect(p.credits, 150);
    platform.consent = true;
    platform.outcome = RewardAdOutcome.unavailable;
    await store.watchReward(runId: 'run1', seconds: 60, kills: 20);
    expect(p.credits, 150);
    expect(store.remaining, 2);
    platform.outcome = RewardAdOutcome.closed;
    await store.watchReward(runId: 'run1', seconds: 60, kills: 20);
    expect(p.credits, 150);
  });
  test('server grant restores credits once through cloud sync, preserving recent local flight history', () async {
    final (p, api, cloud, platform, store) = await setup();
    final game =
        GameEngine(
            stageIndex: 0,
            shipIndex: 0,
            attackLevel: 0,
            hullLevel: 0,
            magnetLevel: 0,
            equipmentIndex: 0,
          )
          ..elapsed = 60
          ..kills = 20;
    game.abandon();
    p.recordFlight('run1', game);
    platform.afterAd = () {
      api.grant = true;
      api.remote = {
        ...p.exportProgress(),
        'credits': 170,
        'verifiedAdCredits': 20,
      };
      api.revision = 1;
    };
    await store.watchReward(runId: 'run1', seconds: 60, kills: 20);
    expect(p.credits, 170);
    expect(store.rewardedRun('run1'), true);
    expect(p.flightHistory.length, 1);
    await store.watchReward(runId: 'run1', seconds: 60, kills: 20);
    await cloud.sync();
    expect(p.credits, 170);
    expect(platform.ads, 1);
    expect((await Profile.load()).credits, 170);
  });
  test('provider completed event without signed grant leaves credits unchanged and recoverable', () async {
    final (p, _, _, _, store) = await setup();
    await store.watchReward(runId: 'run1', seconds: 60, kills: 20);
    expect(p.credits, 150);
    expect(store.status, contains('서버 확인 대기'));
  });
  test('verified counter applies once and importing spoofed ownership cannot create a paid entitlement', () async {
    final (p, _, _, _, store) = await setup();
    p.acceptVerifiedAdCredits(20);
    p.acceptVerifiedAdCredits(20);
    expect(p.credits, 170);
    await p.replaceProgress({
      ...p.exportProgress(),
      'supporter': true,
      'cosmeticActive': true,
    });
    expect(store.supporter, false);
    expect(store.cosmeticActive, false);
    expect(Profile.developerCopy(p).commerce, isNull);
    expect(Profile.presentationCopy(p).commerce, isNull);
  });
  testWidgets(
    'supporter preview and optional reward explanation fit mobile fixed pages at 130 percent',
    (tester) async {
      final p = await Profile.load();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!,
          ),
          home: SupporterScreen(profile: p),
        ),
      );
      await tester.pumpAndSettle();
      final compare = find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == '기본 외형과 비교',
      );
      await revealUi(tester, compare);
      await tester.tapAt(tester.getCenter(compare));
      await tester.pumpAndSettle();
      // v12.4.3: optional reward rules moved into the details popup.
      final details = find.byKey(const Key('supporter-details'));
      await revealUi(tester, details);
      await tester.tapAt(tester.getCenter(details));
      await tester.pumpAndSettle();
      await revealUi(tester, find.text('선택형 추가 보상'));
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsNothing);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
