import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../art/arcade_aircraft.dart';
import '../data/profile.dart';
import '../data/shop_ledger.dart';
import 'components.dart';
import 'info_dialog.dart';
import 'supporter_cosmetic.dart';

class SupporterScreen extends StatefulWidget {
  const SupporterScreen({super.key, required this.profile});
  final Profile profile;
  @override
  State<SupporterScreen> createState() => _SupporterScreenState();
}

class _SupporterScreenState extends State<SupporterScreen> {
  bool preview = true;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final p = widget.profile, store = p.commerce;
    final price = store?.product(ShopItem.supporter)?.price;
    return Scaffold(
      appBar: GameAppBar(title: Text(tr('잔광 후원 외형'), textAlign: TextAlign.center)),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([p, ?store]),
          // v12.4.3: one page. Optional reward rules and price notes open in
          // the details popup.
          builder: (_, _) => GamePages(
            centerContent: true,
            padding: const EdgeInsets.all(16),
            framed: true,
            children: [
              Center(
                child: SizedBox.square(
                  dimension: 144,
                  child: SupporterCosmetic(
                    active: preview,
                    child: ArcadeAircraft(shipIndex: p.selectedShip, size: 132),
                  ),
                ),
              ),
              gap8,
              Text(
                tr('로비 기체에 잔광 프레임과 별 배지를 더합니다. 공격력·체력과 무료 해금은 그대로입니다.'),
                textAlign: TextAlign.center,
              ),
              gap12,
              GameActionButton(
                label: preview ? '기본 외형과 비교' : '후원 외형 미리보기',
                icon: Icons.visibility,
                onPressed: audible(() => setState(() => preview = !preview)),
              ),
              gap8,
              Text(
                tr(store?.status ?? '외형을 미리 볼 수 있습니다. 상품을 준비하고 있습니다.'),
                textAlign: TextAlign.center,
              ),
              if (p.shop.supporterOwned) ...[
                Text(
                  tr('보유 중 · Google Play 구매 내역으로 복원됩니다.'),
                  textAlign: TextAlign.center,
                ),
                gap8,
                GameActionButton(
                  primary: true,
                  label: store!.cosmeticSelected ? '기본 외형 사용' : '후원 외형 장착',
                  onPressed: audible(
                    store.busy
                        ? null
                        : () => store.selectCosmetic(!store.cosmeticSelected),
                  ),
                ),
              ] else if (store?.platform.supported == true) ...[
                gap8,
                GameActionButton(
                  label: price == null
                      ? '상품 가격 확인 중'
                      : '$price · 후원 외형 구매',
                  displayLabel: price == null ? '상품 확인 중' : '$price 구매',
                  primary: true,
                  onPressed: audible(
                    store!.canBuy(ShopItem.supporter)
                        ? () => _confirmPurchase(context)
                        : null,
                  ),
                ),
              ],
              if (store?.platform.supported == true) ...[
                gap12,
                GameActionButton(
                  label: '구매 복원',
                  icon: Icons.restore,
                  onPressed: audible(store!.busy ? null : store.restore),
                ),
              ],
              if (store != null && store.privacyRequired) ...[
                gap12,
                GameActionButton(
                  label: '광고 개인정보 선택',
                  icon: Icons.privacy_tip,
                  onPressed: audible(store.busy ? null : store.showPrivacy),
                ),
              ],
              gap12,
              GameActionButton(
                key: const Key('supporter-details'),
                label: '후원·보상 자세히 보기',
                displayLabel: '자세히',
                icon: Icons.question_mark,
                onPressed: audible(() => _details(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _details(BuildContext context) {
    final store = widget.profile.commerce;
    showInfoDialog(
      context,
      title: '후원·보상 안내',
      children: [
        const GameSectionTitle('선택형 추가 보상'),
        gap8,
        const InfoText('유효한 출격 정산 뒤 원할 때만 광고를 선택할 수 있습니다. 기본 보상은 먼저 지급됩니다.'),
        gap8,
        const InfoText(
          '출격 보상 +50% 하루 3회, 순찰 보상 2배 2회, 일일 상자 2배 1회, 광고 보급 상자 1회입니다. 광고를 닫거나 볼 광고가 없어도 기본 보상은 유지됩니다.',
        ),
        gap16,
        const GameSectionTitle('상품 가격'),
        gap8,
        InfoText(
          store?.platform.supported == true
              ? '상품 가격은 Google Play에서 확인한 현지 가격으로 표시됩니다.'
              : '이 웹 버전은 미리보기를 제공합니다. 실제 상품 가격은 Google Play에서 확인한 현지 가격으로 표시됩니다.',
        ),
      ],
    );
  }

  Future<void> _confirmPurchase(BuildContext context) async {
    final store = widget.profile.commerce;
    if (store == null || !store.canBuy(ShopItem.supporter)) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '후원 외형 구매',
        actions: [
          GameActionButton(
            label: '취소',
            onPressed: audible(() => Navigator.pop(dialog, false)),
          ),
          GameActionButton(
            label: '${store.product(ShopItem.supporter)!.price} · Play에서 확인',
            displayLabel: 'Play에서 확인',
            primary: true,
            onPressed: audible(() => Navigator.pop(dialog, true)),
          ),
        ],
        child: Text(
          tr(
            '로비 기체에 잔광 프레임과 후원 배지를 더합니다. 한 번 사면 계속 보유하며 게임 능력치는 바뀌지 않습니다. Google Play에서 결제를 확인합니다.',
          ),

          textAlign: TextAlign.center,
        ),
      ),
    );
    if (yes == true && mounted) await store.buy(ShopItem.supporter);
  }
}
