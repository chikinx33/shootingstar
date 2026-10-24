import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'commerce_platform.dart';

CommercePlatform createCommercePlatform() => _GooglePlayCommerce();

class _GooglePlayCommerce implements CommercePlatform {
  final _events = StreamController<StorePurchase>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;
  bool _adsReady = false, _privacyRequired = false;
  bool _consentChecked = false;
  Future<bool>? _consentRequest;
  @override
  bool get supported => Platform.isAndroid;
  @override
  bool get privacyRequired => _privacyRequired;
  @override
  Stream<StorePurchase> get purchases => _events.stream;

  void _listen() {
    if (!supported || _subscription != null) return;
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      (updates) {
        for (final purchase in updates) {
          _events.add(
            StorePurchase(
              purchase.productID,
              purchase.verificationData.serverVerificationData,
              switch (purchase.status) {
                PurchaseStatus.pending => StorePurchaseStatus.pending,
                PurchaseStatus.purchased => StorePurchaseStatus.purchased,
                PurchaseStatus.restored => StorePurchaseStatus.restored,
                PurchaseStatus.canceled => StorePurchaseStatus.cancelled,
                PurchaseStatus.error => StorePurchaseStatus.failed,
              },
              handle: purchase,
            ),
          );
        }
      },
      onError: (Object _) {
        _events.add(const StorePurchase('', '', StorePurchaseStatus.failed));
      },
    );
  }

  @override
  Future<StoreProduct?> product(String id) async {
    if (!supported) return null;
    _listen();
    if (!await InAppPurchase.instance.isAvailable()) return null;
    final response = await InAppPurchase.instance.queryProductDetails({id});
    if (response.error != null ||
        response.productDetails.length != 1 ||
        response.productDetails.single.id != id) {
      return null;
    }
    _product = response.productDetails.single;
    return StoreProduct(id, _product!.price);
  }

  @override
  Future<void> buy(StoreProduct product, String accountBinding) async {
    if (!supported || _product?.id != product.id) {
      throw StateError('상품을 다시 확인하세요.');
    }
    if (!await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: _product!,
        applicationUserName: accountBinding,
      ),
    )) {
      throw StateError('구매 화면을 열지 못했습니다.');
    }
  }

  @override
  Future<void> restore(String accountBinding) async {
    if (!supported) return;
    _listen();
    await InAppPurchase.instance.restorePurchases(
      applicationUserName: accountBinding,
    );
  }

  @override
  Future<void> complete(StorePurchase purchase) async {
    final handle = purchase.handle;
    if (handle is PurchaseDetails && handle.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(handle);
    }
  }

  @override
  Future<bool> prepareAds(String appId) async {
    if (_consentChecked) return ConsentInformation.instance.canRequestAds();
    return _consentRequest ??= _prepareAds(appId)
        .whenComplete(() => _consentRequest = null);
  }

  Future<bool> _prepareAds(String appId) async {
    if (!supported) return false;
    // Gradle and the server must agree on the real app ID. Without it the
    // native initialization provider stays disabled; no example ID is used.
    final configured = await const MethodChannel('shootingstar/commerce_config')
        .invokeMethod<String>('admobAppId');
    if (configured != appId || appId.isEmpty) return false;
    final consent = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((error) {
            if (!consent.isCompleted) consent.complete(error == null);
          });
        } catch (_) {
          if (!consent.isCompleted) consent.complete(false);
        }
      },
      (_) {
        if (!consent.isCompleted) consent.complete(false);
      },
    );
    if (!await consent.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => false,
    )) {
      return false;
    }
    _privacyRequired =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (!await ConsentInformation.instance.canRequestAds()) return false;
    if (!_adsReady) {
      await MobileAds.instance.initialize();
      _adsReady = true;
    }
    _consentChecked = true;
    return true;
  }

  @override
  Future<void> privacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error == null) {
        done.complete();
      } else {
        done.completeError(StateError('광고 개인정보 선택을 열지 못했습니다.'));
      }
    });
    await done.future;
  }

  @override
  Future<RewardAdOutcome> rewardAd({
    required String unitId,
    required String nonce,
    required String userId,
  }) async {
    if (!_adsReady || !await ConsentInformation.instance.canRequestAds()) {
      return RewardAdOutcome.unavailable;
    }
    final loaded = Completer<RewardedAd?>();
    await RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (loaded.isCompleted) {
            ad.dispose();
          } else {
            loaded.complete(ad);
          }
        },
        onAdFailedToLoad: (_) {
          if (!loaded.isCompleted) loaded.complete(null);
        },
      ),
    );
    final ad = await loaded.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        if (!loaded.isCompleted) loaded.complete(null);
        return null;
      },
    );
    if (ad == null) return RewardAdOutcome.unavailable;
    final dismissed = Completer<RewardAdOutcome>();
    var earned = false;
    try {
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(customData: nonce, userId: userId),
      );
      ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdDismissedFullScreenContent: (_) {
          if (!dismissed.isCompleted) {
            dismissed.complete(
              earned ? RewardAdOutcome.completed : RewardAdOutcome.closed,
            );
          }
        },
        onAdFailedToShowFullScreenContent: (_, _) {
          if (!dismissed.isCompleted) {
            dismissed.complete(RewardAdOutcome.failed);
          }
        },
      );
      await ad.show(
        onUserEarnedReward: (_, _) {
          earned = true;
        },
      );
      // The callback only describes UI completion. It never changes credits.
      return await dismissed.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () => RewardAdOutcome.failed,
      );
    } finally {
      await ad.dispose();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _events.close();
  }
}
