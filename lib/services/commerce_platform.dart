import 'dart:async';

enum StorePurchaseStatus { pending, purchased, restored, cancelled, failed }

class StorePurchase {
  const StorePurchase(
    this.productId,
    this.token,
    this.status, {
    this.handle,
    this.binding = '',
  });
  final String productId, token;
  final StorePurchaseStatus status;
  final Object? handle;

  /// The obfuscated id the purchase was made with (this save's binding).
  final String binding;
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
  Future<Map<String, StoreProduct>> products(Set<String> ids);
  Future<void> buy(
    StoreProduct product, {
    required bool consumable,
    required String binding,
  });
  Future<void> restore();

  /// Finishes a confirmed purchase: consumables are consumed so they can be
  /// bought again, one-time items are acknowledged.
  Future<void> complete(StorePurchase purchase, {required bool consume});
  Future<bool> prepareAds();
  Future<void> privacyOptions();
  Future<RewardAdOutcome> rewardAd(String unitId);
  void dispose();
}
