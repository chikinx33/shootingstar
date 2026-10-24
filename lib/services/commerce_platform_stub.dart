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
  Future<StoreProduct?> product(String id) async => null;
  @override
  Future<void> buy(StoreProduct product, String accountBinding) async =>
      throw StateError('Android Google Play에서 제공됩니다.');
  @override
  Future<void> restore(String accountBinding) async {}
  @override
  Future<void> complete(StorePurchase purchase) async {}
  @override
  Future<bool> prepareAds(String appId) async => false;
  @override
  Future<void> privacyOptions() async {}
  @override
  Future<RewardAdOutcome> rewardAd({
    required String unitId,
    required String nonce,
    required String userId,
  }) async => RewardAdOutcome.unavailable;
  @override
  void dispose() {}
}
