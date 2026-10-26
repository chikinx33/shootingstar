import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../art/ui_kit.dart';
import '../services/audio_director.dart';
import 'game_motion.dart';
import 'game_decor.dart';

import '../data/profile.dart';
import 'shop_screen.dart';
import '../art/menu_art.dart';
import '../data/content_catalog.dart';
import '../data/fleet_journal.dart';
import '../art/game_icons.dart';
import 'game_slots.dart';
import 'components.dart';
import 'reward_popup.dart';

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
    ('plans', '별가루', 3, 100, GameIcons.stardust),
    ('gear', '장비 보급권', 1, 180, GameIcons.gearTicket),
    ('tech', '테크 보급권', 1, 180, GameIcons.techTicket),
    ('egg', '보조 보급권', 1, 200, GameIcons.petTicket),
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
                            const [
                              'assets/art/ship_parts/sunshine/winggun.webp',
                              'assets/art/ship_parts/sunshine/missile.webp',
                              'assets/art/ship_parts/sunshine/reargun.webp',
                            ],
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
                            const [
                              GameIcons.bolt,
                              GameIcons.gem,
                              GameIcons.crosshair,
                            ],
                            () => p.techKeys > 0,
                            p.openTechSupply,
                          ),
                          supply(
                            '보조 파츠 보급',
                            'pet-cargo',
                            () => p.petEggs,
                            '방어·공격 보조·유틸 7종을 차례로 하나씩',
                            '보조 파츠 보급 열기',
                            const [
                              'assets/art/ship_parts/orbs/shield.webp',
                              'assets/art/ship_parts/orbs/magnet.webp',
                              'assets/art/ship_parts/orbs/repair.webp',
                            ],
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
                : GameItemList(
                    key: ValueKey('supply-items-$tab'),
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    // v12.15: exchange goods as product cards - the picture
                    // with its ×N badge, today's limit, and the price button
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final w = (box.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final offer in offers)
                              SizedBox(width: w, child: _exchange(offer)),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _exchange((String, String, int, int, String) offer) {
    final left = 3 - (p.shopCounts[offer.$1] ?? 0);
    final can =
        p.credits >= offer.$4 &&
        left > 0 &&
        (offer.$1 != 'gear' || p.inventory.length < 240);
    return UiKitFrame(
      'slot',
      corner: 18,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Column(
        children: [
          GameRewardSlot(
            GameReward(offer.$5, offer.$3, offer.$2, rarity: 2),
            size: 72,
            state: left > 0 ? SlotState.open : SlotState.locked,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tr(offer.$2),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 2),
          GameTag(
            message('오늘 {0}/3', [left]),
            tone: left > 0 ? GameTone.sky : GameTone.muted,
          ),
          const SizedBox(height: 6),
          GameActionButton(
            label: '${offer.$2} 교환',
            displayLabel: p.developerMode ? '무료' : '${offer.$4}',
            image: GameIcons.churu,
            onPressed: audible(
              can
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
      ),
    );
  }

  Widget supply(
    String title,
    String asset,
    int Function() keys,
    String description,
    String action,
    List<String> contents,
    bool Function() enabled,
    bool Function() claim,
  ) => SupplyShelfCard(
    title: title,
    description: description,
    contents: contents,
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
                const Center(child: GameTag('나오는 것', tone: GameTone.good)),
                gap(6),
                _ContentStrip(contents, size: 48),
                gap(4),
                GameHint(description),
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

/// v12.15 (user 2026-10-26): the season is a battle-pass track - one row per
/// tier with its number, the XP gauge for that step and the reward slots
/// (check once taken, lock until reached, a glowing 받기 when ready; tap the
/// reward to take it). Mail is a row per letter. The daily missions and the
/// patrol live in 함대 활동 only (no duplicate tab here).
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
            title: tab == 1 ? '보상 우편' : '항성 원정',
            status: '',
            facts: tab == 1
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
            icon: tab == 1 ? Icons.card_giftcard : Icons.workspace_premium,
          ),
          CatalogTabs(
            labels: const ['보상', '우편'],
            selected: tab,
            onSelected: audibleChange((v) => setState(() => tab = v)),
          ),
          Expanded(
            child: GameItemList(
              key: ValueKey('season-items-$tab'),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              child: Column(
                children: tab == 0
                    ? [for (var tier = 1; tier <= 20; tier++) _tierRow(tier)]
                    : [
                        if (p.mail.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: GameHint('받을 우편이 없습니다'),
                          ),
                        for (final m in p.mail.reversed) _mailRow(m),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierRow(int tier) {
    final need = tier * 100, from = need - 100;
    final claimed = p.seasonClaims.contains(tier);
    final reached = p.seasonXp >= need;
    final ready = reached && !claimed;
    final current = p.seasonXp >= from && p.seasonXp < need;
    final state = claimed
        ? SlotState.claimed
        : reached
        ? SlotState.open
        : SlotState.locked;
    final gold = GameTone.gold.color;
    void take() => claimWithRewardPopup(context, p, () => p.claimSeason(tier));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF14284A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ready || current ? gold : const Color(0xFF0B1830),
            width: ready || current ? 3 : 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: [
              // tier number
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reached ? gold : const Color(0xFF3A5A8C),
                  border: Border.all(color: const Color(0xFF0B1830), width: 2),
                ),
                child: Text(
                  '$tier',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: reached ? const Color(0xFF3A2410) : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    shadows: const [],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // this step's XP
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KitGauge(
                      ((p.seasonXp - from) / 100).clamp(0.0, 1.0),
                      height: 12,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.seasonXp.clamp(from, need)} / $need',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: GameTone.muted.color,
                        fontSize: GameUi.caption,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // the reward; tap to take it once reached (a long bundle
              // shrinks as one piece)
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Semantics(
                    button: ready,
                    label: message('{0}단계 보상 수령', [tier]),
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: ValueKey('season-claim-$tier'),
                      behavior: HitTestBehavior.opaque,
                      onTap: ready ? audible(take, cue: 'chest') : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RewardSlotScope(
                            state: state,
                            child: RewardPreview(
                              reward: p.seasonReward(p.seasonKey, tier),
                              size: 46,
                            ),
                          ),
                          if (ready) ...[
                            const SizedBox(height: 2),
                            const GameTag('받기'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mailRow(RewardMail m) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: UiKitFrame(
      'slot',
      corner: 16,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          Opacity(
            opacity: m.claimed ? .5 : 1,
            child: GameIconImage(GameIcons.chest, size: 44),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tr(m.title.split(' · ').first),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // many rewards shrink together instead of overflowing
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RewardSlotScope(
                    state: m.claimed ? SlotState.claimed : SlotState.open,
                    child: RewardPreview(reward: m, size: 40),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // a compact claim button: the row keeps its rewards readable
          SizedBox(
            width: 72,
            child: Semantics(
              button: true,
              label: tr('우편 보상 받기'),
              excludeSemantics: true,
              child: FilledButton(
                key: ValueKey('mail-claim-${m.id}'),
                style: GameUi.compactButton,
                onPressed: audible(
                  m.claimed
                      ? null
                      : () => claimWithRewardPopup(
                          context,
                          p,
                          () => p.claimMail(m.id),
                        ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tr(m.claimed ? '완료' : '받기'),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A mail or season reward as picture slots.
class RewardPreview extends StatelessWidget {
  const RewardPreview({super.key, required this.reward, this.size = 52});
  final RewardMail reward;
  final double size;
  @override
  Widget build(BuildContext context) => RewardChips(
    credits: reward.credits,
    plans: reward.plans,
    food: reward.food,
    gearKeys: reward.gearKeys,
    techKeys: reward.techKeys,
    eggs: reward.eggs,
    size: size,
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
    this.contents = const [],
  });
  final String title, description, openLabel;

  /// Pictures of what comes out, shown instead of the description line.
  final List<String> contents;
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
                      if (contents.isEmpty)
                        Text(
                          tr(description),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            color: Color(0xFFB9C8D8),
                          ),
                        )
                      else
                        _ContentStrip(contents, size: 34),
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

/// What a supply box can give: its pictures in a dark strip.
class _ContentStrip extends StatelessWidget {
  const _ContentStrip(this.assets, {this.size = 34});
  final List<String> assets;
  final double size;
  @override
  Widget build(BuildContext context) => Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x990B1830),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        // a narrow shelf card shrinks the strip instead of overflowing
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < assets.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                GameIconImage(assets[i], size: size),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// v12.15 (user 2026-10-26): a reward is a row of picture slots with ×N
/// badges, never a sentence or name chips. Shared by the supply, season,
/// activity and quest screens; inside a claimed [RewardGroup] every slot
/// carries the 받음 check.
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
    this.size = 52,
  });
  RewardChips.of(FleetReward r, {Key? key, int seasonXp = 0, double size = 52})
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
        size: size,
      );
  final int credits, plans, food, gearKeys, techKeys, eggs, collectionKeys;
  final int seasonXp;
  final double size;

  /// Rewards without an amount picture (e.g. a guaranteed gear piece).
  final List<Widget> extra;

  List<GameReward> get rewards => GameReward.of(
    FleetReward(
      credits: credits,
      plans: plans,
      food: food,
      gearKeys: gearKeys,
      techKeys: techKeys,
      eggs: eggs,
      collectionKeys: collectionKeys,
    ),
    seasonXp: seasonXp,
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final state = RewardSlotScope.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in rewards) GameRewardSlot(r, size: size, state: state),
        ...extra,
      ],
    );
  }
}

/// The slot state (받음 check, 잠김 lock) the [RewardChips] below draw.
class RewardSlotScope extends InheritedWidget {
  const RewardSlotScope({super.key, required this.state, required super.child});
  final SlotState state;
  static SlotState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RewardSlotScope>()?.state ??
      SlotState.open;
  @override
  bool updateShouldNotify(RewardSlotScope old) => old.state != state;
}

/// A small coloured tag over the reward slots; claimed slots carry checks.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: GameTag(label, tone: claimed ? GameTone.muted : tone)),
        const SizedBox(height: 6),
        RewardSlotScope(
          state: claimed ? SlotState.claimed : SlotState.open,
          child: chips,
        ),
      ],
    );
  }
}
