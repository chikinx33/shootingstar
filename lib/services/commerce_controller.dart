import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cloud_sync.dart';
import '../data/profile.dart';
import 'commerce_platform.dart';
import 'commerce_platform_stub.dart'
    if (dart.library.io) 'commerce_platform_android.dart';

/// Paid ownership lives only in the authenticated server response, separately
/// from cloud/importable game progress. Missing configuration fails closed.
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
  String _owner = '', _binding = '', _productId = '', _adUnit = '', _adApp = '';
  bool _disposed = false, _refreshing = false, _billing = false, _ads = false;
  bool supporter = false, cosmeticSelected = false, busy = false;
  bool _buying = false;
  int remaining = 0;
  StoreProduct? product;
  String status = '후원 외형과 선택형 광고를 준비하고 있습니다.';
  List<Map<String, dynamic>> grants = [];
  bool get cosmeticActive =>
      supporter && cosmeticSelected && online.accountId == _owner;
  bool get canBuy =>
      !_buying &&
      _billing &&
      platform.supported &&
      product != null &&
      !supporter &&
      !busy;
  bool get canAdvertise => _ads && platform.supported && remaining > 0 && !busy;
  bool get privacyRequired => platform.supported && platform.privacyRequired;
  bool get configuredBilling => _billing && platform.supported;
  bool get configuredAds => _ads && platform.supported;

  Future<void> initialize() async {
    if (profile.developerMode) return;
    _prefs = await SharedPreferences.getInstance();
    _purchases = platform.purchases.listen(_purchase);
    online.addListener(_accountChanged);
    WidgetsBinding.instance.addObserver(this);
    _accountChanged();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _accountChanged() {
    if (_owner == online.accountId) return;
    _owner = online.accountId;
    _buying = false;
    supporter = false;
    cosmeticSelected = false;
    product = null;
    _billing = false;
    _ads = false;
    remaining = 0;
    grants = [];
    _notify();
    if (_owner.isNotEmpty) unawaited(refresh(restore: true));
  }

  void _accept(Map<String, dynamic> value) {
    _billing = value['billingAvailable'] == true;
    _ads = value['adsAvailable'] == true;
    _binding = value['accountBinding'] as String? ?? '';
    _productId = value['productId'] as String? ?? '';
    _adUnit = value['adUnitId'] as String? ?? '';
    _adApp = value['adAppId'] as String? ?? '';
    supporter = value['supporter'] == true;
    remaining = (value['remaining'] as int? ?? 0).clamp(0, 2);
    grants = (value['grants'] as List? ?? [])
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }

  Future<void> refresh({bool restore = false}) async {
    if (_refreshing || _owner.isEmpty || profile.developerMode || _disposed) {
      return;
    }
    _refreshing = true;
    final owner = _owner;
    try {
      final value = await online.api.post('commerce/refresh');
      if (owner != _owner || _disposed) return;
      _accept(value);
      cosmeticSelected = _prefs?.getBool('commerce.cosmetic.$owner') ?? false;
      if (_billing && platform.supported) {
        product = await platform.product(_productId);
        if (restore) await platform.restore(_binding);
      }
      if (_ads && platform.supported && !online.inBattle) {
        try {
          await platform.prepareAds(_adApp);
        } catch (_) {
          /* fail closed; billing remains independent */
        }
      }
      if (owner != _owner || _disposed) return;
      status = !platform.supported
          ? '웹에서는 외형을 미리 볼 수 있습니다. 구매·광고는 Android에서 제공됩니다.'
          : !_billing && !_ads
          ? '상품과 광고를 준비하고 있습니다. 기본 게임은 모두 이용할 수 있습니다.'
          : supporter
          ? '후원 외형 보유 중'
          : '무료 게임을 유지하는 선택형 후원입니다.';
    } catch (_) {
      if (owner == _owner) {
        supporter = false;
        _billing = false;
        _ads = false;
        product = null;
        status = '상품 연결을 확인하지 못했습니다. 잠시 후 다시 확인하세요.';
      }
    } finally {
      _refreshing = false;
      _notify();
      if (owner != _owner && _owner.isNotEmpty) unawaited(refresh());
    }
  }

  Future<void> buy() async {
    if (!canBuy || online.inBattle || online.accountId != _owner) return;
    busy = true;
    _buying = true;
    status = 'Google Play 구매 확인 중';
    _notify();
    try {
      await platform.buy(product!, _binding);
    } catch (_) {
      _buying = false;
      status = '구매를 시작하지 못했습니다. 결제 내역은 복원으로 다시 확인할 수 있습니다.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _purchase(StorePurchase purchase) async {
    if (_disposed || _owner.isEmpty || profile.developerMode) return;
    if (purchase.status == StorePurchaseStatus.pending) {
      status = '결제 승인 대기 · 승인 전에는 외형이 지급되지 않습니다.';
      _notify();
      return;
    }
    if (purchase.status == StorePurchaseStatus.cancelled ||
        purchase.status == StorePurchaseStatus.failed) {
      status = purchase.status == StorePurchaseStatus.cancelled
          ? '구매를 취소했습니다.'
          : '구매 확인에 실패했습니다. 복원으로 다시 확인하세요.';
      busy = false;
      _buying = false;
      _notify();
      return;
    }
    if (purchase.productId != _productId ||
        purchase.token.isEmpty ||
        !_billing) {
      return;
    }
    final owner = _owner;
    _buying = false;
    try {
      final value = await online.api.post('commerce/purchase', {
        'productId': purchase.productId,
        'token': purchase.token,
      });
      if (owner != _owner || _disposed) return;
      _accept(value);
      if (value['purchaseState'] == 'purchased' &&
          value['acknowledged'] == true) {
        await platform.complete(purchase);
      }
      if (owner != _owner || _disposed) return;
      status = supporter
          ? '후원 감사합니다. 외형을 장착할 수 있습니다.'
          : '구매 승인 대기 · 복원으로 다시 확인할 수 있습니다.';
    } catch (_) {
      if (owner == _owner) status = '구매 확인을 마치지 못했습니다. 계정을 유지하고 복원해 주세요.';
    }
    _notify();
  }

  Future<void> selectCosmetic(bool value) async {
    if (!supporter || _owner.isEmpty || profile.developerMode) return;
    cosmeticSelected = value;
    await _prefs?.setBool('commerce.cosmetic.$_owner', value);
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

  bool rewardedRun(String runId) =>
      grants.any((grant) => grant['run'] == runId);
  Future<void> watchReward({
    required String runId,
    required int seconds,
    required int kills,
  }) async {
    if (!canAdvertise ||
        rewardedRun(runId) ||
        online.inBattle ||
        seconds < 30 ||
        kills < 10) {
      return;
    }
    final owner = _owner;
    String? nonce;
    busy = true;
    status = '기본 보상 저장 확인 중';
    _notify();
    try {
      await online.sync();
      if (owner != _owner ||
          online.busy ||
          online.dirty ||
          online.conflict != null) {
        throw StateError('sync');
      }
      if (!await platform.prepareAds(_adApp)) throw StateError('consent');
      if (owner != _owner) return;
      final attempt = await online.api.post('commerce/ad-begin', {
        'runId': runId,
        'seconds': seconds,
        'kills': kills,
      });
      if (owner != _owner) return;
      nonce = attempt['nonce'] as String;
      status = '선택형 광고 · 기본 보상은 이미 지급됐습니다.';
      _notify();
      final result = await platform.rewardAd(
        unitId: _adUnit,
        nonce: nonce,
        userId: attempt['userId'] as String,
      );
      if (owner != _owner) return;
      if (result != RewardAdOutcome.completed) {
        await online.api.post('commerce/ad-close', {'nonce': nonce});
        status = result == RewardAdOutcome.closed
            ? '광고를 닫았습니다. 기본 보상은 그대로입니다.'
            : '지금 볼 수 있는 광고가 없습니다. 기본 보상은 그대로입니다.';
        return;
      }
      status = '광고 완료 · 서버 보상 확인 중';
      _notify();
      // Bounded polling for delayed SSV. Re-entry and ordinary cloud sync also
      // recover grants after process termination; no local callback grants.
      for (var i = 0; i < 4; i++) {
        if (i > 0) await Future<void>.delayed(const Duration(seconds: 2));
        if (owner != _owner || _disposed) return;
        final value = await online.api.post('commerce/state');
        if (owner != _owner) return;
        _accept(value);
        if (rewardedRun(runId)) {
          await online.sync();
          status = '추가 보상 20 츄르 지급 · 기기 저장과 동기화됩니다.';
          return;
        }
      }
      status = '서버 확인 대기 · 지급이 확인되면 저장에 자동 반영됩니다.';
    } catch (error) {
      if (owner == _owner) {
        status = error is StateError && error.message == 'sync'
            ? '계정 저장과 충돌 해결이 끝난 뒤 다시 선택하세요. 기본 보상은 그대로입니다.'
            : '광고 연결을 마치지 못했습니다. 기본 보상은 그대로입니다.';
      }
    } finally {
      // Closing is never a success signal. A late valid SSV can still grant.
      if (nonce != null && owner == _owner) {
        try {
          await online.api.post('commerce/ad-close', {'nonce': nonce});
        } catch (_) {
          /* expires automatically */
        }
      }
      busy = false;
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy)
      unawaited(refresh(restore: true));
  }

  @override
  void dispose() {
    _disposed = true;
    online.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    _purchases?.cancel();
    platform.dispose();
    super.dispose();
  }
}
