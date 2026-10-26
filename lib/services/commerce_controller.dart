import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cloud_sync.dart';
import '../data/profile.dart';
import '../data/shop_ledger.dart';
import 'commerce_config.dart';
import 'commerce_platform.dart';
import 'commerce_platform_stub.dart'
    if (dart.library.io) 'commerce_platform_android.dart';

/// Rewarded ads and Google Play products without a game account (v12.13.0).
/// Ads pay locally after a completed view; purchases pay only after the
/// server confirms the Play receipt, and each receipt pays once per save.
class CommerceController extends ChangeNotifier with WidgetsBindingObserver {
  CommerceController(this.profile, this.online, {CommercePlatform? platform})
    : platform = platform ?? createCommercePlatform() {
    profile.commerce = this;
  }
  final Profile profile;
  final CloudSync online;
  final CommercePlatform platform;
  StreamSubscription<StorePurchase>? _purchases;
  SharedPreferences? _prefs;
  bool _disposed = false, _restoring = false;
  bool busy = false, cosmeticSelected = false;
  Map<String, StoreProduct> products = {};
  String status = '';

  ShopLedger get _shop => profile.shop;
  bool get billingReady => platform.supported && products.isNotEmpty;
  bool get adsConfigured =>
      platform.supported && CommerceConfig.rewardedUnit.isNotEmpty;
  bool get privacyRequired => platform.supported && platform.privacyRequired;
  bool get adPassActive => _shop.adPassActive(DateTime.now());
  bool get cosmeticActive => _shop.supporterOwned && cosmeticSelected;

  /// Whether the offer button can be pressed right now.
  bool canWatch(AdOffer offer, {String? runId, int runCredits = 0}) =>
      !busy &&
      !profile.developerMode &&
      (adPassActive || adsConfigured) &&
      profile.canOffer(offer, runId: runId, runCredits: runCredits);

  /// Whether the offer is worth showing at all (greyed out when not ready).
  bool offerVisible(AdOffer offer) =>
      !profile.developerMode && (adPassActive || platform.supported);

  StoreProduct? product(ShopItem item) => products[shopProducts[item]!.id];
  bool canBuy(ShopItem item) =>
      !busy &&
      !profile.developerMode &&
      product(item) != null &&
      !_shop.owns(item);

  Future<void> initialize() async {
    if (profile.developerMode) return;
    _prefs = await SharedPreferences.getInstance();
    cosmeticSelected = _prefs?.getBool('commerce.cosmetic') ?? false;
    if (_shop.binding.isEmpty) {
      final r = math.Random.secure();
      _shop.binding = List.generate(
        16,
        (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      profile.contentChanged();
    }
    _purchases = platform.purchases.listen(_purchase);
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed || !platform.supported) return;
    try {
      products = await platform.products({
        for (final p in shopProducts.values) p.id,
      });
      await restore(quiet: true);
      // The consent form (EEA/UK) appears once at start, not mid-offer.
      if (adsConfigured && !online.inBattle) unawaited(platform.prepareAds());
    } catch (_) {
      products = {};
    }
    _notify();
  }

  Future<void> restore({bool quiet = false}) async {
    if (_restoring || !platform.supported) return;
    _restoring = true;
    try {
      await platform.restore();
      if (!quiet) status = '구매 내역을 확인했습니다.';
    } catch (_) {
      if (!quiet) status = '구매 내역을 확인하지 못했습니다. 잠시 후 다시 시도하세요.';
    } finally {
      _restoring = false;
      _notify();
    }
  }

  /// Shows a rewarded ad (or skips it with the ad pass) and pays [offer].
  Future<bool> watch(AdOffer offer, {String? runId, int runCredits = 0}) async {
    if (!canWatch(offer, runId: runId, runCredits: runCredits)) return false;
    busy = true;
    _notify();
    try {
      if (!adPassActive) {
        if (!await platform.prepareAds()) {
          status = '지금은 광고를 볼 수 없습니다. 기본 보상은 그대로입니다.';
          return false;
        }
        final result = await platform.rewardAd(CommerceConfig.rewardedUnit);
        if (result != RewardAdOutcome.completed) {
          status = result == RewardAdOutcome.closed
              ? '광고를 끝까지 보지 않아 추가 보상이 없습니다.'
              : '지금 볼 수 있는 광고가 없습니다. 기본 보상은 그대로입니다.';
          return false;
        }
      }
      final ok = profile.grantAdOffer(
        offer,
        runId: runId,
        runCredits: runCredits,
      );
      status = ok ? '추가 보상 지급 · ${profile.lastLoot}' : '이미 받은 보상입니다.';
      return ok;
    } catch (_) {
      status = '광고를 마치지 못했습니다. 기본 보상은 그대로입니다.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> buy(ShopItem item) async {
    if (!canBuy(item) || online.inBattle) return;
    busy = true;
    status = 'Google Play 결제 화면을 여는 중';
    _notify();
    try {
      await platform.buy(
        product(item)!,
        consumable: shopProducts[item]!.consumable,
        binding: _shop.binding,
      );
    } catch (_) {
      busy = false;
      status = '구매를 시작하지 못했습니다. 잠시 후 다시 시도하세요.';
    }
    _notify();
  }

  static Future<String> _hash(String token) async {
    final digest = await Sha256().hash(utf8.encode(token));
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .substring(0, 40);
  }

  Future<void> _purchase(StorePurchase purchase) async {
    if (_disposed || profile.developerMode) return;
    switch (purchase.status) {
      case StorePurchaseStatus.pending:
        status = '결제 승인 대기 · 승인되면 자동으로 지급됩니다.';
        _notify();
        return;
      case StorePurchaseStatus.cancelled:
      case StorePurchaseStatus.failed:
        busy = false;
        status = purchase.status == StorePurchaseStatus.cancelled
            ? '구매를 취소했습니다.'
            : '구매를 마치지 못했습니다. 결제되었다면 다음 실행 때 자동으로 지급됩니다.';
        _notify();
        return;
      case StorePurchaseStatus.purchased:
      case StorePurchaseStatus.restored:
        break;
    }
    final item = shopItemOf(purchase.productId);
    if (item == null || purchase.token.isEmpty) return;
    final consumable = shopProducts[item]!.consumable;
    try {
      final hash = await _hash(purchase.token);
      final applied = profile.shop.tokens.contains(hash);
      if (!applied) {
        final value = await online.api.post('shop/verify', {
          'productId': purchase.productId,
          'token': purchase.token,
        });
        if (value['state'] != 'purchased') {
          status = value['state'] == 'pending'
              ? '결제 승인 대기 · 승인되면 자동으로 지급됩니다.'
              : '확인되지 않은 구매입니다. 지급하지 않았습니다.';
          return;
        }
        profile.applyPurchase(item, hash, DateTime.now());
        await profile.save();
        status = '${shopProducts[item]!.title} 지급 완료';
      }
      // Finish only after the save holds the reward.
      await platform.complete(purchase, consume: consumable);
    } catch (_) {
      status = '구매 확인을 마치지 못했습니다. 다음 실행 때 다시 확인합니다.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> selectCosmetic(bool value) async {
    if (!_shop.supporterOwned || profile.developerMode) return;
    cosmeticSelected = value;
    await _prefs?.setBool('commerce.cosmetic', value);
    _notify();
  }

  Future<void> showPrivacy() async {
    try {
      await platform.privacyOptions();
    } catch (_) {
      status = '광고 개인정보 선택을 열지 못했습니다.';
    }
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _purchases?.cancel();
    platform.dispose();
    super.dispose();
  }
}
