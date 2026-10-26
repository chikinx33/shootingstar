import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../data/shop_ledger.dart';
import '../l10n/app_language.dart';
import 'ad_offer.dart';
import 'audio_feedback.dart';
import 'catalog_screens.dart' show RewardChips, RewardGroup;
import 'components.dart';
import 'item_slots.dart';
import 'reward_popup.dart';
import 'supporter_screen.dart';

/// Shop art, one generated sheet (assets/concept/shop_icons_v1).
abstract final class ShopArt {
  static const starter = 'assets/art/shop_v1/starter.webp';
  static const fund = 'assets/art/shop_v1/fund.webp';
  static const monthly = 'assets/art/shop_v1/monthly.webp';
  static const adPass = 'assets/art/shop_v1/adpass.webp';
  static const supporter = 'assets/art/shop_v1/supporter.webp';
  static const ad = 'assets/art/shop_v1/ad.webp';
  static String of(ShopItem item) => switch (item) {
    ShopItem.starter => starter,
    ShopItem.growthFund => fund,
    ShopItem.monthly => monthly,
    ShopItem.adPass => adPass,
    ShopItem.supporter => supporter,
  };
}

/// The 상점 tab of 함대 보급: Google Play products, their claims and the
/// daily ad supply box. Prices are only what Play returns.
class ShopProductList extends StatelessWidget {
  const ShopProductList({super.key, required this.profile});
  final Profile profile;

  String _status(ShopItem item) {
    final p = profile, store = p.commerce, now = DateTime.now();
    if (item == ShopItem.growthFund && p.shop.fundOwned) {
      return p.fundAttention > 0
          ? message('보상 {0}개 받기', [p.fundAttention])
          : message('보유 · {0}/10 수령', [p.shop.fundClaims.length]);
    }
    if (item == ShopItem.monthly && p.shop.monthlyActive(now)) {
      return p.monthlyReady
          ? '오늘 간식 받기'
          : message('{0}일 남음', [p.shop.daysLeft(p.shop.monthlyUntil, now)]);
    }
    if (item == ShopItem.adPass && p.shop.adPassActive(now)) {
      return message('{0}일 남음', [p.shop.daysLeft(p.shop.adPassUntil, now)]);
    }
    if (p.shop.owns(item)) return '보유 중';
    return store?.product(item)?.price ??
        (store?.platform.supported == true ? '가격 확인 중' : 'Android 전용');
  }

  /// The product picture with its limit badge (1회 / 30일) in the corner.
  Widget _badged(ShopItem item) {
    final badge = switch (item) {
      ShopItem.starter => '1회 한정',
      ShopItem.monthly || ShopItem.adPass => '30일',
      ShopItem.growthFund => '10단계',
      ShopItem.supporter => null,
    };
    return SizedBox.square(
      dimension: 76,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Image.asset(ShopArt.of(item), width: 72, height: 72),
          if (badge != null)
            Positioned(
              top: -4,
              left: -4,
              child: GameTag(
                badge,
                tone: item == ShopItem.starter
                    ? GameTone.danger
                    : GameTone.gold,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final p = profile, store = p.commerce;
    return AnimatedBuilder(
      animation: Listenable.merge([p, ?store]),
      builder: (context, _) => GameSlotList(
        listKey: const ValueKey('supply-items-2'),
        children: [
          for (final item in ShopItem.values)
            GameItemSlot(
              key: ValueKey('shop-${item.name}'),
              title: shopProducts[item]!.title,
              image: _badged(item),
              status: _status(item),
              selected:
                  (item == ShopItem.growthFund && p.fundAttention > 0) ||
                  (item == ShopItem.monthly && p.monthlyReady),
              semanticLabel: '${shopProducts[item]!.title} 상세',
              onTap: audible(() => _open(context, item)),
            ),
          if (store != null && store.offerVisible(AdOffer.supplyBox))
            GameItemSlot(
              key: const ValueKey('shop-ad-box'),
              title: adOfferNames[AdOffer.supplyBox]!,
              image: Image.asset(ShopArt.ad, width: 72, height: 72),
              status: message('오늘 {0}회 남음', [p.shop.left(AdOffer.supplyBox)]),
              semanticLabel: '광고 보급 상자 상세',
              onTap: audible(() => _adBox(context)),
            ),
        ],
      ),
    );
  }

  void _adBox(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialog) => GameDialog(
      title: adOfferNames[AdOffer.supplyBox]!,
      actions: [
        AdOfferButton(
          profile: profile,
          offer: AdOffer.supplyBox,
          reward: '장비권 1',
          onDone: () => Navigator.of(dialog).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Image.asset(ShopArt.ad, width: 96, height: 96)),
          gap(8),
          RewardGroup(
            label: '광고 한 편 보면',
            chips: RewardChips.of(supplyBoxReward),
          ),
          gap(6),
          GameHint(
            message('오늘 {0}회 남음', [profile.shop.left(AdOffer.supplyBox)]),
            tone: GameTone.sky,
          ),
        ],
      ),
    ),
  );

  void _open(BuildContext context, ShopItem item) {
    if (item == ShopItem.supporter) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SupporterScreen(profile: profile),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialog) => AnimatedBuilder(
        animation: Listenable.merge([profile, ?profile.commerce]),
        builder: (dialog, _) => _ProductDialog(profile: profile, item: item),
      ),
    );
  }
}

class _ProductDialog extends StatelessWidget {
  const _ProductDialog({required this.profile, required this.item});
  final Profile profile;
  final ShopItem item;

  List<Widget> _contents() => switch (item) {
    ShopItem.starter => [
      RewardGroup(
        label: '구성품',
        tone: GameTone.gold,
        chips: RewardChips.of(starterReward),
      ),
      gap(6),
      const Center(child: GameTag('1회 한정', tone: GameTone.danger)),
    ],
    ShopItem.growthFund => [
      RewardGroup(label: '동네를 지킬 때마다', chips: RewardChips.of(fundReward)),
      gap(6),
      const GameInfoBlock(
        label: '특별 보상',
        tone: GameTone.gold,
        lead: '동네 5·10을 지키면 영웅 장비',
      ),
    ],
    ShopItem.monthly => [
      RewardGroup(
        label: '구매 즉시',
        tone: GameTone.gold,
        chips: RewardChips.of(monthlyFirstReward),
      ),
      gap(8),
      RewardGroup(
        label: '30일 동안 매일',
        chips: RewardChips.of(monthlyDailyReward),
      ),
    ],
    ShopItem.adPass => const [
      GameInfoBlock(
        label: '혜택',
        tone: GameTone.good,
        lead: '광고 보상을 영상 없이 바로 받기',
        detail: '하루 받을 수 있는 횟수는 그대로입니다',
      ),
      SizedBox(height: 6),
      Center(child: GameTag('30일', tone: GameTone.sky)),
    ],
    ShopItem.supporter => const [
      GameInfoBlock(
        label: '혜택',
        tone: GameTone.gold,
        lead: '로비 기체에 잔광 프레임과 별 배지',
        detail: '능력치는 바뀌지 않습니다',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final p = profile, store = p.commerce, info = shopProducts[item]!;
    final price = store?.product(item)?.price;
    final now = DateTime.now();
    final claim = switch (item) {
      ShopItem.growthFund when p.shop.fundOwned => GameActionButton(
        key: const Key('shop-fund-claim'),
        label: message('기금 보상 {0}개 받기', [p.fundAttention]),
        primary: true,
        icon: Icons.card_giftcard,
        onPressed: audible(
          p.fundAttention > 0
              ? () => claimWithRewardPopup(context, p, () {
                  var any = false;
                  for (var w = 0; w < 10; w++) {
                    if (p.claimFund(w)) any = true;
                  }
                  return any;
                })
              : null,
        ),
      ),
      ShopItem.monthly when p.shop.monthlyActive(now) => GameActionButton(
        key: const Key('shop-monthly-claim'),
        label: '오늘 간식 받기',
        primary: true,
        icon: Icons.card_giftcard,
        onPressed: audible(
          p.monthlyReady
              ? () => claimWithRewardPopup(context, p, p.claimMonthly)
              : null,
        ),
      ),
      _ => null,
    };
    final buyable = !p.shop.owns(item) && store?.platform.supported == true;
    return GameDialog(
      title: info.title,
      actions: [
        ?claim,
        if (buyable)
          GameActionButton(
            key: Key('shop-buy-${item.name}'),
            label: price == null ? '상품 가격 확인 중' : '$price · ${info.title} 구매',
            displayLabel: price == null ? '가격 확인 중' : '$price 구매',
            primary: claim == null,
            onPressed: audible(
              store!.canBuy(item) ? () => store.buy(item) : null,
            ),
          ),
      ],
      // v12.14: what the product gives as labelled reward chips; limits
      // and store notes are tags and quiet hints, never reward lines.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Image.asset(ShopArt.of(item), width: 96, height: 96)),
          gap(8),
          ..._contents(),
          if (item == ShopItem.growthFund && p.shop.fundOwned) ...[
            gap(8),
            GameFactRow([
              GameFact(
                '받은 동네 보상',
                '${p.shop.fundClaims.length}/10',
                tone: GameTone.gold,
              ),
            ]),
          ],
          if (store != null && store.status.isNotEmpty) ...[
            gap(8),
            GameHint(store.status),
          ],
          if (store?.platform.supported != true) ...[
            gap(8),
            const GameHint('구매는 Android Google Play 앱에서 할 수 있습니다.'),
          ],
        ],
      ),
    );
  }
}
