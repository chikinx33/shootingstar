import 'commerce_platform.dart';

CommercePlatform createCommercePlatform() => _Unavailable();

class _Unavailable implements CommercePlatform {
  @override
  bool get supported => false;
  @override
  bool get privacyRequired => false;
  @override
  Stream<StorePurchase> get purchases => const Stream.empty();
  @override
  Future<Map<String, StoreProduct>> products(Set<String> ids) async => {};
  @override
  Future<void> buy(
    StoreProduct product, {
    required bool consumable,
    required String binding,
  }) async => throw StateError('Android Google Play에서 제공됩니다.');
  @override
  Future<void> restore() async {}
  @override
  Future<void> complete(
    StorePurchase purchase, {
    required bool consume,
  }) async {}
  @override
  Future<bool> prepareAds() async => false;
  @override
  Future<void> privacyOptions() async {}
  @override
  Future<RewardAdOutcome> rewardAd(String unitId) async =>
      RewardAdOutcome.unavailable;
  @override
  void dispose() {}
}
