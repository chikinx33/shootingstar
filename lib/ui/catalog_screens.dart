import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../art/ui_kit.dart';
import '../services/audio_director.dart';
import 'game_motion.dart';
import 'game_decor.dart';

import '../data/profile.dart';
import '../data/shop_ledger.dart';
import 'shop_screen.dart';
import '../art/toon_assets.dart';
import '../art/menu_art.dart';
import '../data/content_catalog.dart';
import '../data/fleet_journal.dart';
import '../data/content_systems.dart';
import 'arcade_home_widgets.dart' show CurrencyArt;
import 'components.dart';
import 'reward_popup.dart';
import 'item_slots.dart';
import 'fleet_activity_screen.dart';

/// Titles and categories stay fixed; only repeated products/rewards scroll.
class CatalogTabs extends StatelessWidget {
  const CatalogTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.tight = false,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onSelected;
  final bool tight;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    if (labels.isEmpty) return const SizedBox();
    final scaler = MediaQuery.textScalerOf(context);
    var requiredWidth = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: tr(label),
          style: const TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final width = painter.width + (tight ? 28 : 52);
      if (width > requiredWidth) requiredWidth = width;
      painter.dispose();
    }
    Widget chip(int i) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GameTab(
        label: labels[i],
        selected: selected == i,
        tight: tight,
        onTap: onSelected == null ? null : () => onSelected!(i),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: LayoutBuilder(
        builder: (context, bounds) {
          var columns = labels.length;
          while (columns > 1 && bounds.maxWidth / columns < requiredWidth) {
            columns--;
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var first = 0; first < labels.length; first += columns)
                Row(
                  children: [
                    for (var slot = 0; slot < columns; slot++)
                      Expanded(
                        child: first + slot < labels.length
                            ? chip(first + slot)
                            : const SizedBox(),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// v12.8: a ribbon title over a status plate, with an optional mascot.
class CatalogHeader extends StatelessWidget {
  const CatalogHeader({
    super.key,
    required this.title,
    required this.status,
    required this.icon,
    this.action,
    this.localizeStatus = true,
    this.mascot,
    this.facts,
  });
  final bool localizeStatus;

  /// v12.14: labelled values shown on the plate instead of [status]
  /// ("Lv.3 · 350 XP · 12일 남음" → 등급 Lv.3 / XP 350 / 남은 기간 12일).
  final List<GameFact>? facts;
  final String title, status;
  final IconData icon;
  final Widget? action;

  /// A [Mascot] pose shown beside the title instead of the small icon.
  final String? mascot;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return StaggerIn(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Center(
                    child: mascot != null
                        ? MascotImage(mascot!, size: 60)
                        : RasterIcon(icon, size: 40),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: RibbonTitle(title, width: 320, height: 56, size: 22),
                  ),
                ),
                SizedBox(width: 64, child: Center(child: action)),
              ],
            ),
            if (facts != null)
              UiKitFrame(
                'plate',
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 3,
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  children: [
                    for (final f in facts!)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${tr(f.label)} ',
                              style: TextStyle(
                                color: f.tone.color,
                                fontSize: GameUi.caption,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: tr(f.value),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.3),
                      ),
                  ],
                ),
              )
            else if (status.isNotEmpty)
              UiKitFrame(
                'plate',
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 3,
                ),
                child: Text(
                  localizeStatus ? tr(status) : status,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CatalogCard extends StatelessWidget {
  const CatalogCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class SupplyShop extends StatefulWidget {
  const SupplyShop({super.key, required this.profile});
  final Profile profile;
  @override
  State<SupplyShop> createState() => _SupplyShopState();
}

class _SupplyShopState extends State<SupplyShop> {
  int tab = 0;
  Profile get p => widget.profile;
  static const offers = [
    ('plans', '별가루', 3, 100, Icons.description),
    ('gear', '장비 보급권', 1, 180, Icons.vpn_key),
    ('tech', '테크 보급권', 1, 180, Icons.precision_manufacturing),
    ('egg', '보조 보급권', 1, 200, Icons.favorite),
  ];
  @override
  void initState() {
    super.initState();
    if (p.developerMode) {
      tab = (p.developerSettings['supplyTab'] as int? ?? 0).clamp(0, 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: p,
      builder: (context, _) => Column(
        children: [
          CatalogHeader(
            title: '함대 보급',
            mascot: Mascot.supply,
            // the lobby header already shows the churu balance (no duplicates)
            status: p.developerMode ? '개발자 · 무료 구매' : '',
            icon: Icons.inventory_2,
          ),
          CatalogTabs(
            labels: const ['보급', '교환', '상점'],
            selected: tab,
            onSelected: audibleChange((v) {
              setState(() => tab = v);
              if (p.developerMode) {
                p.developerSettings['supplyTab'] = v;
                p.save();
              }
            }),
          ),
          Expanded(
            child: tab == 2
                ? ShopProductList(profile: p)
                : tab == 0
                ? GameItemList(
                    key: const ValueKey('supply-items-0'),
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    child: Column(
                      children: [
                        for (final (i, card) in <Widget>[
                          supply(
                            '무기 파츠 보급',
                            'gear-cargo',
                            () => p.gearKeys,
                            '윙건·미사일·자주포를 차례로 하나씩 · Lv.1 파츠',
                            '무기 파츠 보급 열기',
                            () =>
                                p.gearKeys > 0 &&
                                p.shipModules.owned.length < 240,
                            p.openModuleSupply,
                          ),
                          supply(
                            '테크 보급',
                            'tech-cargo',
                            () => p.techKeys,
                            '테크 부품 8종을 순서대로 획득합니다.',
                            '테크 보급 열기',
                            () => p.techKeys > 0,
                            p.openTechSupply,
                          ),
                          supply(
                            '보조 파츠 보급',
                            'pet-cargo',
                            () => p.petEggs,
                            '방어·공격 보조·유틸 7종을 차례로 하나씩',
                            '보조 파츠 보급 열기',
                            () =>
                                p.petEggs > 0 &&
                                p.shipModules.owned.length < 240,
                            () => p.openModuleSupply(support: true),
                          ),
                        ].indexed)
                          StaggerIn(index: i, child: card),
                      ],
                    ),
                  )
                : GameSlotList(
                    listKey: ValueKey('supply-items-$tab'),
                    children: <Widget>[
                      for (final offer in offers)
                        GameItemSlot(
                          title: offer.$2,
                          image: RasterIcon(offer.$5, size: 52),
                          status:
                              '×${offer.$3}\n${p.developerMode ? '무료' : '${offer.$4} 츄르'}',
                          semanticLabel: '${offer.$2} 교환 상세',
                          onTap: audible(
                            () => showDialog<void>(
                              context: context,
                              builder: (_) => AnimatedBuilder(
                                animation: p,
                                builder: (_, _) => GameDialog(
                                  title: offer.$2,
                                  actions: [
                                    GameActionButton(
                                      label: '${offer.$2} 교환',
                                      primary: true,
                                      icon: Icons.shopping_bag,
                                      onPressed: audible(
                                        p.credits >= offer.$4 &&
                                                (p.shopCounts[offer.$1] ?? 0) <
                                                    3 &&
                                                (offer.$1 != 'gear' ||
                                                    p.inventory.length < 240)
                                            ? () => claimWithRewardPopup(
                                                context,
                                                p,
                                                () => p.buyMaterial(offer.$1),
                                                title: '교환 완료',
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                  // v12.14: quantity, price and the daily
                                  // limit each get their own labelled tile.
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Center(
                                        child: RasterIcon(offer.$5, size: 80),
                                      ),
                                      gap(8),
                                      GameFactRow([
                                        GameFact(
                                          '받는 수량',
                                          '×${offer.$3}',
                                          tone: GameTone.good,
                                        ),
                                        GameFact(
                                          '가격',
                                          p.developerMode
                                              ? '무료'
                                              : message('{0} 츄르', [offer.$4]),
                                          tone: GameTone.gold,
                                        ),
                                        GameFact(
                                          '오늘 남은 횟수',
                                          '${3 - (p.shopCounts[offer.$1] ?? 0)}/3',
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget supply(
    String title,
    String asset,
    int Function() keys,
    String description,
    String action,
    bool Function() enabled,
    bool Function() claim,
  ) => SupplyShelfCard(
    title: title,
    description: description,
    image: MenuImage(asset, size: 84),
    count: keys(),
    canOpen: enabled(),
    openLabel: action,
    onOpen: () => claimWithRewardPopup(context, p, claim),
    onDetails: audible(
      () => showDialog<void>(
        context: context,
        builder: (_) => AnimatedBuilder(
          animation: p,
          builder: (_, _) => GameDialog(
            title: title,
            actions: [
              GameActionButton(
                label: action,
                primary: true,
                icon: Icons.inventory_2,
                onPressed: audible(
                  enabled()
                      ? () => claimWithRewardPopup(context, p, claim)
                      : null,
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: MenuImage(asset, size: 72)),
                gap(8),
                GameFactRow([
                  GameFact(
                    '보유 보급권',
                    message('{0}장', [keys()]),
                    tone: GameTone.gold,
                  ),
                ]),
                gap(8),
                GameInfoBlock(
                  label: '나오는 것',
                  tone: GameTone.good,
                  lead: description,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SeasonMailbox extends StatefulWidget {
  const SeasonMailbox({super.key, required this.profile});
  final Profile profile;
  @override
  State<SeasonMailbox> createState() => _SeasonMailboxState();
}

class _SeasonMailboxState extends State<SeasonMailbox> {
  int tab = 0;
  Profile get p => widget.profile;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: p,
      builder: (context, _) => Column(
        children: [
          CatalogHeader(
            title: tab == 2 ? '보상 우편' : '항성 원정',
            status: '',
            facts: tab == 2
                ? [
                    GameFact(
                      '안 받은 우편',
                      message('{0}건', [p.mail.where((m) => !m.claimed).length]),
                      tone: GameTone.gold,
                    ),
                  ]
                : [
                    GameFact(
                      '등급',
                      'Lv.${(p.seasonXp ~/ 100).clamp(0, 20)}',
                      tone: GameTone.gold,
                    ),
                    GameFact('XP', '${p.seasonXp}'),
                    GameFact(
                      '남은 기간',
                      message('{0}일', [p.seasonDaysLeft(DateTime.now())]),
                      tone: GameTone.muted,
                    ),
                  ],
            icon: tab == 2 ? Icons.card_giftcard : Icons.workspace_premium,
          ),
          CatalogTabs(
            labels: const ['보상', '임무', '우편'],
            selected: tab,
            onSelected: audibleChange((v) => setState(() => tab = v)),
          ),
          Expanded(
            child: tab == 1
                ? GameItemList(child: Column(children: _missions()))
                : GameSlotList(
                    listKey: ValueKey('season-items-$tab'),
                    children: tab == 0
                        ? <Widget>[
                            for (var tier = 1; tier <= 20; tier++)
                              GameItemSlot(
                                title: '$tier단계',
                                image: const RasterIcon(
                                  Icons.workspace_premium,
                                  size: 52,
                                ),
                                status: p.seasonClaims.contains(tier)
                                    ? '완료'
                                    : '${tier * 100} XP',
                                onTap: audible(
                                  () => _itemDetail('시즌 보상', () => _tier(tier)),
                                ),
                              ),
                          ]
                        : <Widget>[
                            for (final m in p.mail.reversed)
                              GameItemSlot(
                                title: m.title,
                                image: const ToonTile('icons', 63, size: 56),
                                status: m.claimed ? '수령 완료' : '미수령',
                                onTap: audible(
                                  () => _itemDetail('보상 우편', () => _mail(m)),
                                ),
                              ),
                          ],
                  ),
          ),
        ],
      ),
    );
  }

  void _itemDetail(String title, CatalogCard Function() card) =>
      showDialog<void>(
        context: context,
        builder: (_) => AnimatedBuilder(
          animation: p,
          builder: (_, _) => GameDialog(
            title: title,
            child: Column(children: card().children),
          ),
        ),
      );
  CatalogCard _tier(int tier) => CatalogCard(
    children: [
      Row(
        children: [
          const RasterIcon(Icons.workspace_premium, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message("{0}단계", [tier]),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),

              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      gap(8),
      GameFactRow([
        GameFact('필요 XP', '${tier * 100}'),
        GameFact(
          '내 XP',
          '${p.seasonXp}',
          tone: p.seasonXp >= tier * 100 ? GameTone.good : GameTone.gold,
        ),
      ]),
      gap(10),
      RewardGroup(
        label: '단계 보상',
        claimed: p.seasonClaims.contains(tier),
        chips: RewardPreview(reward: p.seasonReward(p.seasonKey, tier)),
      ),
      gap(16),
      Center(
        child: GameActionButton(
          key: ValueKey('season-claim-$tier'),
          label: '$tier단계 보상 수령',
          displayLabel: p.seasonClaims.contains(tier) ? '수령 완료' : '받기',
          primary: true,
          icon: Icons.card_giftcard,
          onPressed: audible(
            p.seasonXp >= tier * 100 && !p.seasonClaims.contains(tier)
                ? () => claimWithRewardPopup(
                    context,
                    p,
                    () => p.claimSeason(tier),
                  )
                : null,
          ),
        ),
      ),
    ],
  );
  CatalogCard _mail(RewardMail m) => CatalogCard(
    children: [
      Row(
        children: [
          const ToonTile('icons', 63, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr(m.title),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),

              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      gap(12),
      RewardGroup(
        label: '우편 보상',
        claimed: m.claimed,
        chips: RewardPreview(reward: m),
      ),
      gap(16),
      Center(
        child: GameActionButton(
          label: '우편 보상 받기',
          displayLabel: m.claimed ? '수령 완료' : '보상 받기',
          primary: true,
          icon: Icons.card_giftcard,
          onPressed: audible(
            m.claimed
                ? null
                : () =>
                      claimWithRewardPopup(context, p, () => p.claimMail(m.id)),
          ),
        ),
      ),
    ],
  );

  /// Accumulated patrol time and what claiming now would give.
  Widget _patrolNow(int minutes) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      KitGauge(minutes / 480, height: 14),
      gap(4),
      GameHint(message('누적 {0}분 / 최대 480분', [minutes]), tone: GameTone.sky),
      gap(8),
      RewardGroup(
        label: '지금 회수하면',
        chips: minutes < 30
            ? const GameHint('30분부터 회수할 수 있습니다')
            : RewardChips(
                credits: minutes ~/ 30 * 20,
                plans: minutes ~/ 60,
                food: minutes ~/ 60 * 5,
              ),
      ),
      gap(4),
      const GameHint('30분마다 츄르 20\n1시간마다 별가루 1과 먹이 5'),
    ],
  );

  List<Widget> _missions() => [
    Center(
      child: GameActionButton(
        label: '출석·주간 임무·활동 상자',
        displayLabel: '활동 임무',
        icon: Icons.assignment_turned_in,
        onPressed: audible(
          () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => FleetActivityScreen(profile: p, initialPage: 1),
            ),
          ),
        ),
      ),
    ),
    gap(12),
    for (var i = 0; i < 3; i++)
      CatalogCard(
        children: [
          Text(
            tr(ContentSystems.dailyNames[i]),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),

            textAlign: TextAlign.center,
          ),
          gap(8),
          // v12.14: progress as a gauge with its count, reward as chips
          KitGauge(
            p.dailyProgress(i) / ContentSystems.dailyTargets[i],
            height: 14,
          ),
          gap(4),
          GameHint(
            message('진행 {0} / {1}', [
              p.dailyProgress(i).clamp(0, ContentSystems.dailyTargets[i]),
              ContentSystems.dailyTargets[i],
            ]),
            tone: GameTone.sky,
          ),
          gap(8),
          RewardGroup(
            label: '보상',
            claimed: p.dailyClaims.contains(i),
            chips: RewardChips(
              credits: 50,
              food: 10,
              seasonXp: 50,
              gearKeys: i == 0 ? 1 : 0,
              techKeys: i == 1 ? 1 : 0,
              eggs: i == 2 ? 1 : 0,
            ),
          ),
          gap(12),
          Center(
            child: GameActionButton(
              label: '일일 보상 수령',
              primary: true,
              displayLabel: p.dailyClaims.contains(i) ? '수령 완료' : '보상 받기',
              icon: Icons.card_giftcard,
              onPressed: audible(
                !p.dailyClaims.contains(i) &&
                        p.dailyProgress(i) >= ContentSystems.dailyTargets[i]
                    ? () => claimWithRewardPopup(
                        context,
                        p,
                        () => p.claimDaily(i),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    CatalogCard(
      children: [
        Text(
          tr('자동 순찰'),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),

          textAlign: TextAlign.center,
        ),
        gap(8),
        _patrolNow(p.patrolMinutes(DateTime.now())),
        gap(12),
        Center(
          child: GameActionButton(
            label: '순찰 보상 회수',
            primary: true,
            icon: Icons.card_giftcard,
            onPressed: audible(
              p.patrolMinutes(DateTime.now()) >= 30
                  ? () => claimWithRewardPopup(
                      context,
                      p,
                      () => p.claimPatrol(DateTime.now()),
                      adOffer: AdOffer.patrolDouble,
                    )
                  : null,
            ),
          ),
        ),
      ],
    ),
  ];
}

/// A mail or season reward as item chips (v12.14: kit pictures, not the old
/// icon sheet).
class RewardPreview extends StatelessWidget {
  const RewardPreview({super.key, required this.reward});
  final RewardMail reward;
  @override
  Widget build(BuildContext context) => RewardChips(
    credits: reward.credits,
    plans: reward.plans,
    food: reward.food,
    gearKeys: reward.gearKeys,
    techKeys: reward.techKeys,
    eggs: reward.eggs,
  );
}

/// v12.8 game kit tab: the chosen one glows orange and sits raised.
class GameTab extends StatelessWidget {
  const GameTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tight = false,
  });
  final String label;
  final bool selected, tight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      button: true,
      selected: selected,
      label: tr(label),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                AudioDirector.current?.unlock();
                AudioDirector.current?.play('select');
                onTap!();
              },
        child: AnimatedScale(
          scale: selected ? 1.0 : .94,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: UiKitFrame(
            selected ? 'tab_on' : 'tab_off',
            padding: EdgeInsets.symmetric(
              horizontal: tight ? 6 : 10,
              vertical: tight ? 12 : 10,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                tr(label),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFC6D3E2),
                  fontFamily: 'NotoSansKR',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Color(0xFF3A1A06), offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// v12.8.1: one supply on the shop shelf - a big bobbing crate (glowing when
/// there is something to open), its name, what it gives, the count and an
/// open button. Tapping the card shows its details.
class SupplyShelfCard extends StatelessWidget {
  const SupplyShelfCard({
    super.key,
    required this.title,
    required this.description,
    required this.image,
    required this.count,
    required this.canOpen,
    required this.openLabel,
    required this.onOpen,
    required this.onDetails,
  });
  final String title, description, openLabel;
  final Widget image;
  final int count;
  final bool canOpen;
  final VoidCallback onOpen;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        button: true,
        label: tr('$title 상세'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDetails,
          child: UiKitFrame(
            'slot',
            corner: 18,
            padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (count > 0) const GlowRays(size: 120, opacity: .55),
                      Bob(height: 4, child: image),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: UiKitFrame(
                          'plate',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          child: Text(
                            '×$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFE27A),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        tr(title),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(description),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: Color(0xFFB9C8D8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        button: true,
                        enabled: canOpen,
                        label: tr(openLabel),
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: canOpen ? audible(onOpen, cue: 'chest') : null,
                          child: Opacity(
                            opacity: canOpen ? 1 : .45,
                            child: UiKitFrame(
                              canOpen ? 'btn_yellow' : 'tab_off',
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                                vertical: 11,
                              ),
                              child: Text(
                                tr(canOpen ? '열기' : '보급권 없음'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: canOpen
                                      ? const Color(0xFF2A1A06)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// v12.14: a reward as item chips (picture, name, amount) instead of a
/// "50 츄르 · 먹이 10" sentence. Shared by the supply, season, activity and
/// quest screens.
class RewardChips extends StatelessWidget {
  const RewardChips({
    super.key,
    this.credits = 0,
    this.plans = 0,
    this.food = 0,
    this.gearKeys = 0,
    this.techKeys = 0,
    this.eggs = 0,
    this.collectionKeys = 0,
    this.seasonXp = 0,
    this.extra = const [],
  });
  RewardChips.of(FleetReward r, {Key? key, int seasonXp = 0})
    : this(
        key: key,
        credits: r.credits,
        plans: r.plans,
        food: r.food,
        gearKeys: r.gearKeys,
        techKeys: r.techKeys,
        eggs: r.eggs,
        collectionKeys: r.collectionKeys,
        seasonXp: seasonXp,
      );
  final int credits, plans, food, gearKeys, techKeys, eggs, collectionKeys;
  final int seasonXp;

  /// Rewards without an amount picture (e.g. a guaranteed gear piece).
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        if (credits > 0)
          GameRewardChip('츄르', credits, image: CurrencyArt.churu),
        if (plans > 0)
          GameRewardChip('별가루', plans, image: CurrencyArt.stardust),
        if (food > 0) GameRewardChip('먹이', food),
        if (gearKeys > 0)
          GameRewardChip('장비 보급권', gearKeys, image: CurrencyArt.gearTicket),
        if (techKeys > 0)
          GameRewardChip(
            '테크 보급권',
            techKeys,
            image: 'assets/art/icons_v11/blueprint.webp',
          ),
        if (eggs > 0)
          GameRewardChip('펫 구조권', eggs, image: 'assets/art/icons_v11/egg.webp'),
        if (collectionKeys > 0)
          GameRewardChip(
            '수집품 보급권',
            collectionKeys,
            image: 'assets/art/icons_v11/crate.webp',
          ),
        if (seasonXp > 0) GameRewardChip('시즌 XP', seasonXp),
        ...extra,
      ],
    );
  }
}

/// A labelled reward group: coloured tag (and a "받음" tag once claimed)
/// over the reward chips.
class RewardGroup extends StatelessWidget {
  const RewardGroup({
    super.key,
    required this.label,
    required this.chips,
    this.tone = GameTone.good,
    this.claimed = false,
  });
  final String label;
  final Widget chips;
  final GameTone tone;
  final bool claimed;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Opacity(
      opacity: claimed ? .55 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: GameTag(label, tone: tone)),
              if (claimed) ...[
                const SizedBox(width: 6),
                const GameTag('받음', tone: GameTone.muted),
              ],
            ],
          ),
          const SizedBox(height: 6),
          chips,
        ],
      ),
    );
  }
}
