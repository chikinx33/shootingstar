import 'dart:math' as math;

import 'cat_gear.dart';
import 'content_systems.dart';
import 'fleet_journal.dart';

/// Rewarded-ad offers (v12.13.0). Every offer is optional and capped per KST
/// day; the base reward never depends on watching.
enum AdOffer { runBonus, patrolDouble, chestDouble, supplyBox }

const adOfferLimits = {
  AdOffer.runBonus: 3,
  AdOffer.patrolDouble: 2,
  AdOffer.chestDouble: 1,
  AdOffer.supplyBox: 1,
};
const adOfferNames = {
  AdOffer.runBonus: '출격 보상 +50%',
  AdOffer.patrolDouble: '순찰 보상 2배',
  AdOffer.chestDouble: '일일 상자 2배',
  AdOffer.supplyBox: '광고 보급 상자',
};

/// Google Play products. Prices always come from Play; none are hard-coded.
enum ShopItem { starter, growthFund, monthly, adPass, supporter }

class ShopProduct {
  const ShopProduct(this.id, this.title, this.summary, {this.consumable = false});
  final String id, title, summary;

  /// Consumables can be bought again; one-time items are owned once.
  final bool consumable;
}

const shopProducts = {
  ShopItem.starter: ShopProduct(
    'purr_starter_pack',
    '첫 출격 꾸러미',
    '츄르 1,000 · 별가루 20 · 장비권 2 · 구조권 1 · 한 번만 구매',
  ),
  ShopItem.growthFund: ShopProduct(
    'purr_growth_fund',
    '수호 성장 기금',
    '월드를 지킬 때마다 별가루 15 · 장비권 1 · 월드 5·10 영웅 장비',
  ),
  ShopItem.monthly: ShopProduct(
    'purr_monthly_snacks',
    '월간 간식 지원',
    '즉시 별가루 20 · 30일 동안 매일 츄르 200 · 별가루 2 · 먹이 20',
    consumable: true,
  ),
  ShopItem.adPass: ShopProduct(
    'purr_ad_pass_30d',
    '광고 패스 30일',
    '광고 보상을 영상 없이 바로 받기 · 하루 한도는 그대로',
    consumable: true,
  ),
  ShopItem.supporter: ShopProduct(
    'purr_supporter_frame',
    '후원 외형',
    '로비 기체에 잔광 프레임과 별 배지 · 능력치 변화 없음',
  ),
};

ShopItem? shopItemOf(String productId) {
  for (final e in shopProducts.entries) {
    if (e.value.id == productId) return e.key;
  }
  return null;
}

const starterReward = FleetReward(credits: 1000, plans: 20, gearKeys: 2, eggs: 1);
const fundReward = FleetReward(plans: 15, gearKeys: 1);
const monthlyFirstReward = FleetReward(plans: 20);
const monthlyDailyReward = FleetReward(credits: 200, plans: 2, food: 20);
const supplyBoxReward = FleetReward(gearKeys: 1);
const _day = Duration(days: 30);

/// Purchases and ad counters live in the save, so they work without a game
/// account. Google Play keeps the receipt; the server only confirms it is
/// real. A purchase token is applied once per save.
class ShopLedger {
  String day = '', monthlyDay = '';

  /// Random per-save id sent to Play as the obfuscated account id.
  String binding = '';
  final Map<AdOffer, int> adsToday = {};
  int adPassUntil = 0, monthlyUntil = 0;
  bool starterGranted = false, fundOwned = false, supporterOwned = false;
  Set<int> fundClaims = {};
  List<String> tokens = [];
  List<String> bonusRuns = [];

  // Doubling offers only exist right after the matching claim, in memory.
  FleetReward? pendingPatrol;
  FleetReward? pendingChest;

  int used(AdOffer offer) => adsToday[offer] ?? 0;
  int left(AdOffer offer) => math.max(0, adOfferLimits[offer]! - used(offer));
  bool adPassActive(DateTime now) =>
      now.toUtc().millisecondsSinceEpoch < adPassUntil;
  bool monthlyActive(DateTime now) =>
      now.toUtc().millisecondsSinceEpoch < monthlyUntil;
  int daysLeft(int until, DateTime now) => math.max(
    0,
    ((until - now.toUtc().millisecondsSinceEpoch) / 86400000).ceil(),
  );

  bool advance(String today) {
    if (day == today) return false;
    day = today;
    adsToday.clear();
    pendingPatrol = null;
    pendingChest = null;
    return true;
  }

  bool owns(ShopItem item) => switch (item) {
    ShopItem.starter => starterGranted,
    ShopItem.growthFund => fundOwned,
    ShopItem.supporter => supporterOwned,
    _ => false,
  };

  Map<String, dynamic> toJson() => {
    'day': day,
    'monthlyDay': monthlyDay,
    'binding': binding,
    'ads': {for (final e in adsToday.entries) e.key.name: e.value},
    'adPassUntil': adPassUntil,
    'monthlyUntil': monthlyUntil,
    'starterGranted': starterGranted,
    'fundOwned': fundOwned,
    'supporterOwned': supporterOwned,
    'fundClaims': fundClaims.toList(),
    'tokens': tokens,
    'bonusRuns': bonusRuns,
  };

  static ShopLedger restore(Object? raw) {
    final l = ShopLedger();
    if (raw is! Map) return l;
    String text(Object? v, int max) =>
        v is String && v.length <= max ? v : '';
    int time(Object? v) => v is num && v.isFinite
        ? v.toInt().clamp(0, 8640000000000000)
        : 0;
    l.day = text(raw['day'], 10);
    l.monthlyDay = text(raw['monthlyDay'], 10);
    l.binding = text(raw['binding'], 64);
    final ads = raw['ads'];
    if (ads is Map) {
      for (final offer in AdOffer.values) {
        final v = ads[offer.name];
        if (v is int) l.adsToday[offer] = v.clamp(0, adOfferLimits[offer]!);
      }
    }
    l.adPassUntil = time(raw['adPassUntil']);
    l.monthlyUntil = time(raw['monthlyUntil']);
    l.starterGranted = raw['starterGranted'] == true;
    l.fundOwned = raw['fundOwned'] == true;
    l.supporterOwned = raw['supporterOwned'] == true;
    if (raw['fundClaims'] is List) {
      l.fundClaims = (raw['fundClaims'] as List)
          .whereType<int>()
          .where((w) => w >= 0 && w < 10)
          .toSet();
    }
    List<String> strings(Object? v) => v is List
        ? v.whereType<String>().where((s) => s.length <= 100).take(100).toList()
        : [];
    l.tokens = strings(raw['tokens']);
    l.bonusRuns = strings(raw['bonusRuns']).take(20).toList();
    return l;
  }
}

/// Grants for ads and purchases. The ledger decides; this only pays.
mixin ShopSystems on ContentSystems {
  ShopLedger shop = ShopLedger();
  CatGearState get catGear;
  Set<int> get clearedStages;

  @override
  bool refreshContentClock(DateTime now) {
    final changed = super.refreshContentClock(now);
    final reset = shop.advance(dayKey);
    return changed || reset;
  }

  @override
  Map<String, dynamic> contentSnapshot() => {
    ...super.contentSnapshot(),
    'shop': shop.toJson(),
  };

  @override
  void restoreContent(Map<String, dynamic> root) {
    super.restoreContent(root);
    final raw = root['content'];
    shop = ShopLedger.restore(raw is Map ? raw['shop'] : null);
  }

  // A successful claim opens its one-time doubling offer.
  @override
  bool claimPatrol(DateTime now) {
    final minutes = patrolMinutes(now);
    final ok = super.claimPatrol(now);
    if (ok) {
      shop.pendingPatrol = FleetReward(
        credits: minutes ~/ 30 * 20,
        plans: minutes ~/ 60,
        food: minutes ~/ 60 * 5,
      );
    }
    return ok;
  }

  @override
  bool claimDailyActivity(int id, {DateTime? now}) {
    final ok = super.claimDailyActivity(id, now: now);
    if (ok) shop.pendingChest = FleetJournal.dailyChestRewards[id];
    return ok;
  }

  void _pay(FleetReward r) {
    credits = (credits + r.credits).clamp(0, 9999999);
    blueprints = (blueprints + r.plans).clamp(0, 999999);
    petFood = (petFood + r.food).clamp(0, 999999);
    gearKeys = (gearKeys + r.gearKeys).clamp(0, 99999);
    techKeys = (techKeys + r.techKeys).clamp(0, 99999);
    petEggs = (petEggs + r.eggs).clamp(0, 99999);
    collections.keys = (collections.keys + r.collectionKeys).clamp(0, 99999);
    lastLoot = r.summary;
  }

  /// Run bonus is half the run's 츄르, at least 10.
  static int runBonus(int runCredits) => math.max(10, (runCredits + 1) ~/ 2);

  bool canOffer(AdOffer offer, {String? runId, int runCredits = 0}) {
    refreshContentClock(DateTime.now());
    if (shop.left(offer) <= 0) return false;
    return switch (offer) {
      AdOffer.runBonus =>
        runId != null && runCredits > 0 && !shop.bonusRuns.contains(runId),
      AdOffer.patrolDouble => shop.pendingPatrol != null,
      AdOffer.chestDouble => shop.pendingChest != null,
      AdOffer.supplyBox => true,
    };
  }

  /// Pays one watched (or ad-pass) offer. Returns false if it is not open.
  bool grantAdOffer(AdOffer offer, {String? runId, int runCredits = 0}) {
    if (!canOffer(offer, runId: runId, runCredits: runCredits)) return false;
    switch (offer) {
      case AdOffer.runBonus:
        _pay(FleetReward(credits: runBonus(runCredits)));
        shop.bonusRuns = [runId!, ...shop.bonusRuns].take(20).toList();
      case AdOffer.patrolDouble:
        _pay(shop.pendingPatrol!);
        shop.pendingPatrol = null;
      case AdOffer.chestDouble:
        _pay(shop.pendingChest!);
        shop.pendingChest = null;
      case AdOffer.supplyBox:
        _pay(supplyBoxReward);
    }
    shop.adsToday[offer] = shop.used(offer) + 1;
    contentChanged();
    return true;
  }

  bool worldCleared(int world) =>
      List.generate(10, (s) => world * 10 + s).every(clearedStages.contains);

  /// Applies a confirmed Play purchase once per token. Returns true when this
  /// call changed the save (false for a token already applied).
  bool applyPurchase(ShopItem item, String tokenHash, DateTime now) {
    if (shop.tokens.contains(tokenHash)) return false;
    final at = now.toUtc().millisecondsSinceEpoch;
    switch (item) {
      case ShopItem.starter:
        if (!shop.starterGranted) _pay(starterReward);
        shop.starterGranted = true;
      case ShopItem.growthFund:
        shop.fundOwned = true;
        lastLoot = '수호 성장 기금 활성';
      case ShopItem.supporter:
        shop.supporterOwned = true;
        lastLoot = '후원 외형 보유';
      case ShopItem.monthly:
        _pay(monthlyFirstReward);
        shop.monthlyUntil = math.max(shop.monthlyUntil, at) + _day.inMilliseconds;
      case ShopItem.adPass:
        shop.adPassUntil = math.max(shop.adPassUntil, at) + _day.inMilliseconds;
        lastLoot = '광고 패스 30일 추가';
    }
    shop.tokens = [tokenHash, ...shop.tokens].take(100).toList();
    contentChanged();
    return true;
  }

  bool get monthlyReady {
    final now = DateTime.now();
    refreshContentClock(now);
    return shop.monthlyActive(now) && shop.monthlyDay != dayKey;
  }

  bool claimMonthly() {
    if (!monthlyReady) return false;
    shop.monthlyDay = dayKey;
    _pay(monthlyDailyReward);
    contentChanged();
    return true;
  }

  bool fundReady(int world) =>
      shop.fundOwned &&
      world >= 0 &&
      world < 10 &&
      !shop.fundClaims.contains(world) &&
      worldCleared(world);

  int get fundAttention =>
      List.generate(10, (w) => w).where(fundReady).length;

  /// World 5 and 10 (index 4, 9) add an epic gear piece; a full bag gets
  /// 별가루 10 instead so nothing is lost.
  bool claimFund(int world) {
    if (!fundReady(world)) return false;
    shop.fundClaims.add(world);
    _pay(fundReward);
    if (world == 4 || world == 9) {
      if (catGear.items.length < CatGearState.capacity) {
        final rng = math.Random(world * 7919 + catGear.items.length);
        final piece = catGear.add(
          catGearSets[rng.nextInt(catGearSets.length)].id,
          CatGearSlot.values[rng.nextInt(CatGearSlot.values.length)],
          3,
        );
        lastLoot = '${fundReward.summary} · ${piece.name} (영웅)';
      } else {
        blueprints = (blueprints + 10).clamp(0, 999999);
        lastLoot = '${fundReward.summary} · 별가루 10 (장비 가방이 가득 참)';
      }
    }
    contentChanged();
    return true;
  }
}
