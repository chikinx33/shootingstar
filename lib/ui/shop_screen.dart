import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../data/shop_ledger.dart';
import '../l10n/app_language.dart';
import 'ad_offer.dart';
import 'audio_feedback.dart';
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
              image: Image.asset(ShopArt.of(item), width: 72, height: 72),
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
              status: message('장비권 1 · 오늘 {0}회', [
                p.shop.left(AdOffer.supplyBox),
              ]),
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
        children: [
          Image.asset(ShopArt.ad, width: 96, height: 96),
          gap(8),
          Text(
            tr('광고 한 편을 보면 장비 보급권 1장을 받습니다. 하루 1회입니다.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: GameUi.body),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(ShopArt.of(item), width: 96, height: 96),
          gap(8),
          for (final line in info.summary.split(' · '))
            Text(
              tr(line),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: GameUi.body),
            ),
          if (item == ShopItem.growthFund && p.shop.fundOwned) ...[
            gap(8),
            Text(
              message('지킨 월드 보상 {0}/10 수령', [p.shop.fundClaims.length]),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFE27A)),
            ),
          ],
          if (store != null && store.status.isNotEmpty) ...[
            gap(8),
            Text(
              tr(store.status),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
          if (store?.platform.supported != true) ...[
            gap(8),
            Text(
              tr('구매는 Android Google Play 앱에서 할 수 있습니다.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
