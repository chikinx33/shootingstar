import '../l10n/app_language.dart';

import 'audio_feedback.dart';
import 'module_workshop.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../data/profile.dart';
import '../art/arcade_aircraft.dart';
import '../art/toon_assets.dart';
import '../art/menu_art.dart';
import '../art/gear_art.dart';
import '../data/gear_traits.dart';
import '../data/content.dart';
import '../data/content_catalog.dart';
import '../main.dart';
import 'components.dart';
import 'reward_popup.dart';
import 'guild_screen.dart';
import 'collection_screen.dart';
import 'advanced_equipment_screen.dart';
import 'pet_bond_screen.dart';
import 'talent_screen.dart';
import 'catalog_screens.dart';
import 'armament_hangar.dart';
import 'ship_hangar.dart';
import 'boss_gear_hangar.dart';
import 'item_slots.dart';
import 'cat_gear_screen.dart';
import 'detail_widgets.dart';
import 'supporter_screen.dart';

/// Generated equipment illustrations retain the original item and slot IDs.
class AtlasIcon extends StatelessWidget {
  const AtlasIcon({
    super.key,
    required this.index,
    this.tech = false,
    this.spec,
    this.size = 64,
  });
  final int index;
  final bool tech;
  final int? spec;
  final double size;
  static const gearIcons = [
    Icons.rocket_launch,
    Icons.gps_fixed,
    Icons.bolt,
    Icons.shield,
    Icons.security,
    Icons.air,
  ];
  static const techIcons = [
    Icons.local_fire_department,
    Icons.satellite_alt,
    Icons.navigation,
    Icons.blur_circular,
    Icons.shield,
    Icons.ac_unit,
    Icons.electric_bolt,
    Icons.explore,
  ];
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return SizedBox.square(
      dimension: size,
      child: tech
          ? ToonTile(
              'icons',
              [18, 25, 15, 22, 28, 32, 30, 31][index.clamp(0, 7)],
              size: size,
            )
          : GearIcon(spec ?? index.clamp(0, 5) * 2, size: size),
    );
  }
}

class ContentHub extends StatefulWidget {
  const ContentHub({
    super.key,
    required this.profile,
    this.initialPage = 0,
    this.showNavigation = true,
  });
  final Profile profile;
  final int initialPage;
  final bool showNavigation;
  @override
  State<ContentHub> createState() => _ContentHubState();
}

class _ContentHubState extends State<ContentHub> {
  late int page = widget.initialPage;
  int filter = -1, gearTab = 0;
  bool bestFirst = true;
  Profile get p => widget.profile;
  Timer? timer;
  static const colors = [
    Color(0xFFD2DAE6),
    Colors.greenAccent,
    Colors.lightBlueAccent,
    Colors.purpleAccent,
    Colors.amber,
    Colors.redAccent,
  ];
  @override
  void initState() {
    super.initState();
    p.addListener(refresh);
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (p.refreshContentClock(DateTime.now())) {
        p.contentChanged();
      } else {
        refresh();
      }
    });
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    p.removeListener(refresh);
    super.dispose();
  }

  void act(bool Function() action, {RewardEntry? item}) {
    final before = RewardSnapshot(p);
    final done = action();
    if (done) showTransactionFeedback(context, p, before, item: item);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            done
                ? (p.lastLoot.isEmpty ? '적용했습니다.' : p.lastLoot)
                : '재료·츄르·장착 슬롯을 확인하세요.',
          ),

          textAlign: TextAlign.center,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    p.lastLoot = '';
  }

  Widget title(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          tr(a),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),

          textAlign: TextAlign.center,
        ),
        gap(6),
        Text(
          tr(b),
          style: const TextStyle(color: muted),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
  Widget card(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Surface(child: child),
  );
  Widget button(String label, bool allowed, bool Function() action) =>
      FilledButton(
        onPressed: audible(allowed ? () => act(action) : null),
        child: Text(tr(label), textAlign: TextAlign.center),
      );
  Widget rewardButton(String label, bool allowed, bool Function() action) =>
      Center(
        child: GameActionButton(
          label: label,
          primary: true,
          icon: Icons.card_giftcard,
          onPressed: audible(
            allowed ? () => claimWithRewardPopup(context, p, action) : null,
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Column(
      children: [
        if (widget.showNavigation)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
            child: LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final i in [0, 1, 2])
                    SizedBox(
                      width: (c.maxWidth - 12) / 3,
                      child: GameTab(
                        label: ['장비', '무기', '병아리'][i],
                        selected: page == i,
                        onTap: () {
                          p.refreshContentClock(DateTime.now());
                          setState(() => page = i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: page == 0
              ? gearScreen()
              : page == 1
              ? ModuleWorkshop(profile: p, embedded: true)
              : page == 3
              ? SupplyShop(profile: p)
              : page == 4
              ? SeasonMailbox(profile: p)
              : ListView(
                  key: ValueKey(page),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  children: switch (page) {
                    2 => pets(),
                    3 => [],
                    _ => [],
                  },
                ),
        ),
      ],
    );
  }

  Widget gearScreen() => CatGearScreen(profile: p);
  Widget legacyGearScreen() => Column(
    children: [
      CatalogTabs(
        labels: const ['장착', '보관', '관리'],
        selected: gearTab,
        onSelected: audibleChange((v) => setState(() => gearTab = v)),
      ),
      Expanded(
        child: gearTab == 0
            ? LayoutBuilder(
                builder: (context, c) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final tileHeight = 56 + 19 + 2 * 14 * 1.1 * scale + 4;
                  final tall = c.maxHeight - 76 >= tileHeight * 3 + 4;
                  return GamePages(
                    key: const ValueKey('equipment-overview'),
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (tall)
                        Row(
                          children: [
                            Column(
                              children: [
                                for (final i in [0, 1, 2]) _equippedSlot(i),
                              ],
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  ArcadeAircraft(
                                    shipIndex: p.selectedShip,
                                    assembly: p.aircraftAssembly,
                                    height: 160,
                                    semanticLabel:
                                        '${ships[p.selectedShip].name} 장착 기체',
                                  ),
                                  Text(
                                    tr(ships[p.selectedShip].name),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    message("화력 +{0}%", [
                                      (p.gearDamage * 100).round(),
                                    ]),
                                    style: const TextStyle(fontSize: 16),

                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    message("선체 +{0}%", [
                                      (p.gearHull * 100).round(),
                                    ]),
                                    style: const TextStyle(fontSize: 16),

                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                for (final i in [3, 4, 5]) _equippedSlot(i),
                              ],
                            ),
                          ],
                        )
                      else ...[
                        Center(
                          child: ArcadeAircraft(
                            shipIndex: p.selectedShip,
                            assembly: p.aircraftAssembly,
                            height: 100,
                            semanticLabel:
                                '${ships[p.selectedShip].name} 장착 기체',
                          ),
                        ),
                        GameSectionTitle(ships[p.selectedShip].name),
                        Text(
                          message("화력 +{0}% · 선체 +{1}%", [
                            (p.gearDamage * 100).round(),
                            (p.gearHull * 100).round(),
                          ]),
                          style: const TextStyle(fontSize: 16),

                          textAlign: TextAlign.center,
                        ),
                        for (final pair in [
                          [0, 3],
                          [1, 4],
                          [2, 5],
                        ])
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [for (final i in pair) _equippedSlot(i)],
                          ),
                      ],
                    ],
                  );
                },
              )
            : gearTab == 1
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            message("인벤토리 {0}/240", [p.inventory.length]),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),

                            textAlign: TextAlign.center,
                          ),
                        ),
                        TextButton(
                          onPressed: audible(
                            () => setState(() => bestFirst = !bestFirst),
                          ),
                          child: Text(
                            tr(bestFirst ? '등급순' : '최신순'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (int i = -1; i < 6; i++)
                          ChoiceChip(
                            label: Text(
                              tr(i < 0 ? '전체' : slotNames[i]),
                              textAlign: TextAlign.center,
                            ),
                            selected: filter == i,
                            onSelected: audibleChange(
                              (_) => setState(() => filter = i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('equipment-items'),
                      padding: const EdgeInsets.all(12),
                      children: gearInventory(),
                    ),
                  ),
                ],
              )
            : GamePages(
                key: const ValueKey('equipment-tools'),
                children: [
                  const Center(child: MenuImage('growth-badge', size: 96)),
                  const GameSectionTitle('정비와 성장'),
                  GameActionButton(
                    label: '보스 전용 장비',
                    icon: Icons.shield,
                    onPressed: audible(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => BossGearHangar(profile: p),
                        ),
                      ),
                    ),
                  ),
                  gap(12),
                  GameActionButton(
                    label: '기체 선택',
                    icon: Icons.flight,
                    onPressed: audible(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ShipHangar(profile: p),
                        ),
                      ),
                    ),
                  ),
                  if (!p.developerMode)
                    GameActionButton(
                      label: '후원 외형 미리보기',
                      icon: Icons.auto_awesome,
                      onPressed: audible(
                        () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SupporterScreen(profile: p),
                          ),
                        ),
                      ),
                    ),
                  gap(12),
                  GameActionButton(
                    label: '주무기 소유·성장',
                    icon: Icons.rocket_launch,
                    onPressed: audible(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ArmamentHangar(profile: p),
                        ),
                      ),
                    ),
                  ),
                  gap(12),
                  GameActionButton(
                    label: '수집품 ${p.collections.discoveredCount}/12',
                    displayLabel: '수집품',
                    icon: Icons.auto_awesome,
                    onPressed: audible(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CollectionScreen(profile: p),
                        ),
                      ),
                    ),
                  ),
                  gap(12),
                  GameActionButton(
                    label: '진화 연구',
                    icon: Icons.account_tree,
                    onPressed: audible(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: GameAppBar(
                              title: Text(
                                tr('함대 진화 연구'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            body: TalentScreen(profile: p),
                          ),
                        ),
                      ),
                    ),
                  ),
                  gap(12),
                  GameActionButton(
                    label: '고급 장비 성장 · 정련·융합',
                    displayLabel: '고급 장비 성장',
                    icon: Icons.auto_fix_high,
                    onPressed: audible(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AdvancedEquipmentScreen(profile: p),
                        ),
                      ),
                    ),
                  ),
                  gap(12),
                  GameActionButton(
                    label: '보급',
                    onPressed: audible(() => setState(() => page = 3)),
                  ),
                  gap(12),
                  GameActionButton(
                    label: '시즌',
                    onPressed: audible(() => setState(() => page = 4)),
                  ),
                  gap(12),
                  GameActionButton(
                    label: '길드',
                    onPressed: audible(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => GuildScreen(profile: p),
                        ),
                      ),
                    ),
                  ),
                  gap(16),
                  Text(
                    tr(
                      '동일 장비·등급 3개를 합성합니다. 잠금·장착·강화된 장비는 재료에서 제외됩니다. 강화 재료는 초기화 시 전액 반환됩니다.',
                    ),
                    style: TextStyle(fontSize: 16),

                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    ],
  );
  List<Widget> gearInventory() {
    final items =
        p.inventory
            .where((g) => filter < 0 || g.definition.slot == filter)
            .toList()
          ..sort(
            (a, b) => bestFirst
                ? (b.rank * 100 + b.level).compareTo(a.rank * 100 + a.level)
                : b.id.compareTo(a.id),
          );
    return [
      GameSlotRows(
        children: [
          for (final g in items)
            GameItemSlot(
              title: g.definition.name,
              image: AtlasIcon(
                index: g.definition.slot,
                spec: g.spec,
                size: 56,
              ),
              rarity: g.rank,
              selected: p.equippedGear.contains(g.id),
              status: '${qualityNames[g.rank]}\nLv.${g.level}',
              semanticLabel:
                  '${g.definition.name} ${qualityNames[g.rank]} 레벨 ${g.level} 장비 ${g.id}',
              onTap: audible(() => details(g)),
            ),
        ],
      ),
      gap(12),
      for (int i = 0; i < 6; i++)
        if (p.gearCopies[i] > 0)
          button(
            '기존 ${slotNames[i]} 부품 ${p.gearCopies[i]}개 · 1개 변환',
            true,
            () => p.convertLegacyPart(i),
          ),
    ];
  }

  Widget _equippedSlot(int slot) {
    final g = p.gearAt(slot);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Semantics(
        button: true,
        label: message("{0} {1} {2} 레벨 {3}", [
          slotNames[slot],
          g.definition.name,
          qualityNames[g.rank],
          g.level,
        ]),
        child: InkWell(
          onTap: audible(() => details(g)),
          child: ToonRarityFrame(
            rank: g.rank,
            child: Container(
              width: 104,
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  AtlasIcon(index: slot, spec: g.spec, size: 56),
                  Text(
                    tr(slotNames[slot]),
                    style: const TextStyle(
                      color: muted,
                      fontSize: 14,
                      height: 1.1,
                    ),

                    textAlign: TextAlign.center,
                  ),
                  Text(
                    message("+{0}", [g.level]),
                    style: TextStyle(
                      color: colors[g.rank],
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),

                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> details(GearItem g) async {
    await showDialog<void>(
      context: context,
      builder: (c) => AnimatedBuilder(
        animation: p,
        builder: (_, _) {
          if (p.item(g.id) == null) {
            return GameDialog(
              title: '장비 정보 변경',
              child: Text(
                tr('저장 진행이 바뀌어 이 장비를 찾을 수 없습니다. 닫은 뒤 보관함에서 다시 선택하세요.'),
                textAlign: TextAlign.center,
              ),
            );
          }
          final cost = p.itemUpgradeCost(g);
          const plans = 1;
          final atMax = g.level >= (20 + g.rank * 10);
          final equipped = p.equippedGear.contains(g.id);
          final materials = p.mergeMaterials(g);
          void change(bool Function() fn) {
            act(
              fn,
              item: RewardEntry(
                g.definition.name,
                1,
                Icons.inventory_2,
                atlas: 'equipment',
                index: g.spec,
                rarity: g.rank,
              ),
            );
          }

          return GameDialog(
            title: g.definition.name,
            closeLabel: '장비 상세 닫기',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GameDetailHeader(
                  image: ToonRarityFrame(
                    rank: g.rank,
                    child: AtlasIcon(
                      index: g.definition.slot,
                      spec: g.spec,
                      size: 64,
                    ),
                  ),
                  title:
                      '${qualityNames[g.rank]} · Lv.${g.level}/${(20 + g.rank * 10)}',
                  status: '${equipped ? '장착 중 · ' : ''}장비 #${g.id}',
                  trailing: IconButton(
                    tooltip: tr(g.locked ? '잠금 해제' : '보호 잠금'),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: Icon(
                      g.locked ? Icons.lock : Icons.lock_open,
                      color: g.locked ? cyan : muted,
                    ),
                    onPressed: audible(() => change(() => p.lockItem(g.id))),
                  ),
                ),
                Text(
                  tr(g.definition.perk),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),

                  textAlign: TextAlign.center,
                ),
                if (g.spec != 7)
                  Text(
                    tr(gearTraitDescription(g.spec)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF97D6EF),
                    ),
                  ),
                gap(8),
                if (!atMax) ...[
                  Text(
                    message("강화 {0} 츄르 · 별가루 {1}", [cost, plans]),
                    style: const TextStyle(fontSize: 16),

                    textAlign: TextAlign.center,
                  ),
                  Text(
                    message("보유 {0} 츄르 · 별가루 {1}", [p.credits, p.blueprints]),
                    style: const TextStyle(fontSize: 14, color: muted),

                    textAlign: TextAlign.center,
                  ),
                ] else
                  Text(
                    tr('최대 강화 완료'),
                    style: TextStyle(color: cyan, fontSize: 16),

                    textAlign: TextAlign.center,
                  ),
                gap(12),
                GameDetailTools(
                  children: [
                    if (!equipped)
                      GameActionButton(
                        label: '장착',
                        onPressed: audible(
                          () => change(() => p.equipItem(g.id)),
                        ),
                      ),
                    if (!atMax)
                      GameActionButton(
                        label: '장비 강화',
                        displayLabel: '강화',
                        primary: true,
                        onPressed: audible(
                          p.credits >= cost && p.blueprints >= plans
                              ? () => change(() => p.enhanceItem(g.id))
                              : null,
                        ),
                      ),
                  ],
                ),
                if (g.rank < 5 || g.level > 0) ...[
                  gap(12),
                  GameDetailTools(
                    children: [
                      if (g.rank < 5)
                        FilledButton(
                          style: GameUi.compactButton,
                          onPressed: audible(() => _mergeDetails(c, g)),
                          child: Text(tr('합성'), textAlign: TextAlign.center),
                        ),
                      if (g.level == 0 && g.rank < 5)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            message("재료 {0}/2 · {1}", [
                              materials.length,
                              qualityNames[(g.rank + 1).clamp(0, 5)],
                            ]),
                            style: const TextStyle(fontSize: 14, color: muted),

                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (g.level > 0)
                        FilledButton(
                          style: GameUi.compactButton,
                          onPressed: audible(() => _refundDetails(c, g)),
                          child: Text(tr('재료 반환'), textAlign: TextAlign.center),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _mergeDetails(BuildContext parent, GearItem g) async {
    final materials = p.mergeMaterials(g);
    final yes = await showDialog<bool>(
      context: parent,
      builder: (c) => GameDialog(
        title: '합성 재료 확인',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameDetailHeader(
              image: AtlasIcon(
                index: g.definition.slot,
                spec: g.spec,
                size: 64,
              ),
              title:
                  '${qualityNames[g.rank]} → ${qualityNames[(g.rank + 1).clamp(0, 5)]}',
              status: '동일 장비 3개 · 장착·잠금 재료 제외',
            ),
            Text(
              tr(
                materials.length == 2
                    ? '#${g.id} 유지 · #${materials[0].id}, #${materials[1].id} 소모'
                    : '추가 재료 ${2 - materials.length}개 필요',
              ),
              style: const TextStyle(fontSize: 16),

              textAlign: TextAlign.center,
            ),
            if (materials.length == 2) ...[
              gap(12),
              Center(
                child: GameActionButton(
                  label: '동일 장비 3개 합성',
                  displayLabel: '합성 확정',
                  primary: true,
                  icon: Icons.compare_arrows,
                  onPressed: audible(() => Navigator.pop(c, true)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (yes == true && mounted) act(() => p.mergeItem(g.id));
  }

  Future<void> _refundDetails(BuildContext parent, GearItem g) async {
    final yes = await showDialog<bool>(
      context: parent,
      builder: (c) => GameDialog(
        title: '강화 재료 반환',
        child: Column(
          children: [
            Text(
              message("{0} 츄르 · 별가루 {1} 반환\n장비 소유·등급·장착 상태 유지, 강화 Lv.0", [
                g.spentCredits,
                g.spentPlans,
              ]),
              style: const TextStyle(fontSize: 16),

              textAlign: TextAlign.center,
            ),
            gap(12),
            Center(
              child: GameActionButton(
                label: '강화 재료 반환 확정',
                displayLabel: '반환 확정',
                primary: true,
                onPressed: audible(() => Navigator.pop(c, true)),
              ),
            ),
          ],
        ),
      ),
    );
    if (yes == true && mounted) act(() => p.resetItem(g.id));
  }

  void slotDetails(String title, List<Widget> Function() parts) =>
      showDialog<void>(
        context: context,
        builder: (_) => AnimatedBuilder(
          animation: p,
          builder: (_, _) => GameDialog(
            title: title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: parts(),
            ),
          ),
        ),
      );

  List<Widget> pets() => [
    GameSlotRows(
      children: [
        for (var i = 0; i < 3; i++)
          GameItemSlot(
            title: petNames[i],
            image: ToonTile('ships', 3 + i, size: 56),
            status: p.petLevels[i] == 0 ? '미구조' : 'Lv.${p.petLevels[i]}',
            selected: p.activePet == i,
            rarity: p.petRanks[i],
            onTap: audible(
              () => slotDetails(
                petNames[i],
                () => [
                  GameDetailHeader(
                    image: ToonTile('ships', 3 + i, size: 72),
                    title: p.activePet == i
                        ? '출전 중'
                        : (p.petLevels[i] > 0 ? '대기 중' : '미구조'),
                    status:
                        'Lv.${p.petLevels[i]} · ${qualityNames[p.petRanks[i]]}',
                  ),
                  Text(tr(petDescriptions[i]), textAlign: TextAlign.center),
                  Text(
                    message("Lv.{0} · {1} · 먹이 {2}", [
                      p.petLevels[i],
                      qualityNames[p.petRanks[i]],
                      p.petFood,
                    ]),

                    textAlign: TextAlign.center,
                  ),
                  if (p.petLevels[i] > 0) ...[
                    if (p.activePet != i)
                      GameActionButton(
                        label: '출전',
                        primary: true,
                        onPressed: audible(
                          p.activePet == i
                              ? null
                              : () => act(() => p.deployPet(i)),
                        ),
                      ),
                    if (p.activePet != i)
                      GameActionButton(
                        label: p.assistingPets.contains(i) ? '보조 해제' : '보조 배치',
                        onPressed: audible(
                          p.activePet == i
                              ? null
                              : () => act(() => p.assistPet(i)),
                        ),
                      ),
                    GameCostLine('먹이 ${p.petLevels[i] * 10}'),
                    if (p.petLevels[i] < 20 + p.petRanks[i] * 10)
                      GameActionButton(
                        label: '펫 육성',
                        onPressed: audible(
                          p.petFood >= p.petLevels[i] * 10 &&
                                  p.petLevels[i] < 20 + p.petRanks[i] * 10
                              ? () => act(() => p.feedPet(i))
                              : null,
                        ),
                      ),
                    if (p.petRanks[i] < 5)
                      GameActionButton(
                        label: '펫 승급',
                        onPressed: audible(
                          p.petRanks[i] < 5 &&
                                  p.petShards[i] >= 3 * (p.petRanks[i] + 1)
                              ? () => act(() => p.evolvePet(i))
                              : null,
                        ),
                      ),
                    GameActionButton(
                      label: '각성·호감도',
                      icon: Icons.favorite,
                      onPressed: audible(
                        () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => PetBondScreen(profile: p, pet: i),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    GameActionButton(
                      label: '펫 구조하기',
                      primary: true,
                      onPressed: audible(
                        p.petEggs > 0
                            ? () =>
                                  claimWithRewardPopup(context, p, p.rescuePet)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  ];

  List<Widget> tech() => [
    GameSlotRows(
      children: [
        for (var i = 0; i < techNames.length; i++)
          GameItemSlot(
            title: techNames[i],
            image: AtlasIcon(index: i, tech: true, size: 56),
            status: p.techRank(i) < 0 ? '미보유' : qualityNames[p.techRank(i)],
            selected: p.equippedTech.contains(i),
            rarity: p.techRank(i).clamp(0, 5),
            onTap: audible(
              () => slotDetails(
                techNames[i],
                () => [
                  GameDetailHeader(
                    image: AtlasIcon(index: i, tech: true, size: 72),
                    title: p.equippedTech.contains(i) ? '장착 중' : '보조 부품',
                    status: p.techRank(i) < 0
                        ? '미보유'
                        : qualityNames[p.techRank(i)],
                  ),
                  Text(tr(techPerks[i]), textAlign: TextAlign.center),
                  Text(
                    tr(
                      [
                        for (var r = 0; r < 6; r++)
                          if (p.techStock[i][r] > 0)
                            '${qualityNames[r]} ${p.techStock[i][r]}개',
                      ].join(' · '),
                    ),

                    textAlign: TextAlign.center,
                  ),
                  if (p.techRank(i) >= 0)
                    GameActionButton(
                      label: p.equippedTech.contains(i) ? '부품 해제' : '부품 장착',
                      primary: true,
                      onPressed: audible(
                        p.techRank(i) >= 0 &&
                                (p.equippedTech.contains(i) ||
                                    p.equippedTech
                                            .where((t) => (t < 4) == (i < 4))
                                            .length <
                                        3)
                            ? () => act(() => p.equipTech(i))
                            : null,
                      ),
                    ),
                  for (var r = 0; r < 5; r++)
                    if (p.techStock[i][r] >= 3)
                      GameActionButton(
                        label: '${qualityNames[r]} 3개 합성',
                        onPressed: audible(() => act(() => p.mergeTech(i, r))),
                      ),
                  if (p.starterTechUnlocked && !p.starterTechClaimed)
                    GameActionButton(
                      label: '희귀 테크 선택',
                      primary: true,
                      onPressed: audible(
                        () => claimWithRewardPopup(
                          context,
                          p,
                          () => p.claimStarterTech(i),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  ];
}
