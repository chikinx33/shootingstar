import 'dart:async';

enum StorePurchaseStatus { pending, purchased, restored, cancelled, failed }

class StorePurchase {
  const StorePurchase(this.productId, this.token, this.status, {this.handle});
  final String productId, token;
  final StorePurchaseStatus status;
  final Object? handle;
}

class StoreProduct {
  const StoreProduct(this.id, this.price);
  final String id, price;
}

enum RewardAdOutcome { completed, closed, unavailable, failed }

abstract class CommercePlatform {
  bool get supported;
  Stream<StorePurchase> get purchases;
  bool get privacyRequired;
  Future<StoreProduct?> product(String id);
  Future<void> buy(StoreProduct product, String accountBinding);
  Future<void> restore(String accountBinding);
  Future<void> complete(StorePurchase purchase);
  Future<bool> prepareAds(String appId);
  Future<void> privacyOptions();
  Future<RewardAdOutcome> rewardAd({
    required String unitId,
    required String nonce,
    required String userId,
  });
  void dispose();
}
