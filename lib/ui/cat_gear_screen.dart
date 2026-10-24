import 'package:flutter/material.dart';

import 'arcade_home_widgets.dart';
import '../art/toon_assets.dart';
import '../art/ui_kit.dart';
import 'game_motion.dart';

import '../art/ship_sprite_art.dart';
import '../data/cat_gear.dart';
import '../data/profile.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';
import 'game_dialog.dart';
import 'game_ui.dart';
import 'item_slots.dart';

/// The cat's equipment: five airframe slots around the current ship, set
/// effects, and the owned pieces below (equip, upgrade, dismantle, lock).
class CatGearScreen extends StatefulWidget {
  const CatGearScreen({super.key, required this.profile});
  final Profile profile;

  @override
  State<CatGearScreen> createState() => _CatGearScreenState();
}

class _CatGearScreenState extends State<CatGearScreen> {
  CatGearSlot? _filter;
  Profile get p => widget.profile;

  static Widget gearImage(CatGearItem item, double size) => SizedBox.square(
    dimension: size,
    child: Image.asset(
      catGearSet(item.set).asset(item.slot),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    ),
  );

  Widget _slot(CatGearSlot slot) {
    final item = p.catGear.equippedIn(slot);
    return Semantics(
      button: true,
      label: tr(
        item == null
            ? '${catGearSlotNames[slot]} 비어 있음'
            : '${catGearSlotNames[slot]} ${item.name} Lv.${item.level}',
      ),
      excludeSemantics: true,
      child: InkWell(
        key: Key('cat-gear-slot-${slot.name}'),
        onTap: audible(
          () => item == null ? setState(() => _filter = slot) : _detail(item),
        ),
        borderRadius: BorderRadius.circular(12),
        // v12.9: the rarity slot frame of the generated kit
        child: SizedBox(
          width: 70,
          height: 76,
          child: ToonRarityFrame(
            rank: item?.rarity ?? -1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item != null)
                  gearImage(item, 42)
                else
                  const Icon(Icons.add, size: 32, color: Color(0xFF8EA6C2)),
                Text(
                  item == null
                      ? tr(catGearSlotNames[slot]!)
                      : 'Lv.${item.level}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterTab(CatGearSlot? f) {
    final on = _filter == f;
    final name = f == null ? '전체' : catGearSlotNames[f]!;
    final shown = f == null ? null : p.catGear.equippedIn(f);
    return Semantics(
      button: true,
      selected: on,
      label: tr(name),
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('cat-gear-filter-${f?.name ?? 'all'}'),
        behavior: HitTestBehavior.opaque,
        onTap: audible(() => setState(() => _filter = f)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: UiKitFrame(
            on ? 'tab_on' : 'tab_off',
            child: SizedBox(
              height: 48,
              child: Center(
                child: f == null
                    ? Text(
                        tr(name),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: on ? Colors.white : const Color(0xFFB8C7DA),
                        ),

                        textAlign: TextAlign.center,
                      )
                    : Opacity(
                        opacity: on ? 1 : .7,
                        child: Image.asset(
                          catGearSet(shown?.set ?? 'sunshine').asset(f),
                          width: 34,
                          height: 34,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _setLine() {
    final counts = p.catGear.setCounts;
    final parts = <String>[];
    for (final set in catGearSets) {
      final n = counts[set.id] ?? 0;
      if (n >= 5) {
        parts.add('${set.name} 5세트 · ${set.five}');
      } else if (n >= 3) {
        parts.add('${set.name} 3세트 · ${set.three}');
      }
    }
    return parts.isEmpty ? '같은 세트 3부위·5부위를 장착하면 세트 효과' : parts.join('\n');
  }

  Future<void> _detail(CatGearItem item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: p,
        builder: (context, _) {
          final equipped = p.catGear.isEquipped(item);
          final owned = p.catGear.item(item.id) != null;
          if (!owned) return const SizedBox.shrink();
          return GameDialog(
            title: item.name,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                gearImage(item, 96),
                const SizedBox(height: 6),
                Text(
                  message('{0} · Lv.{1}/{2}', [
                    tr(catGearRarityNames[item.rarity]),
                    item.level,
                    item.maxLevel,
                  ]),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(catGearRarityColors[item.rarity]),
                  ),
                ),
                Text(
                  tr(item.statText),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    '${catGearSet(item.set).name} 세트 · 3부위 ${catGearSet(item.set).three} · 5부위 ${catGearSet(item.set).five}',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFB8C7DA),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.maxed
                      ? tr('최대 레벨')
                      : message('강화 · 츄르 {0}{1}', [
                          item.upgradeChuru,
                          item.upgradeStardust > 0
                              ? message(' · 별가루 {0}', [item.upgradeStardust])
                              : '',
                        ]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFFD27A),
                  ),
                ),
              ],
            ),
            actions: [
              GameActionButton(
                label: equipped ? '장착 중' : '장착',
                icon: Icons.check,
                primary: !equipped,
                onPressed: equipped ? null : () => p.equipCatGear(item.id),
              ),
              GameActionButton(
                label: '강화',
                icon: Icons.upgrade,
                onPressed: p.canUpgradeCatGear(item)
                    ? () => p.upgradeCatGear(item.id)
                    : null,
              ),
              GameActionButton(
                label: item.locked ? '잠금 해제' : '보호 잠금',
                icon: item.locked ? Icons.lock_open : Icons.lock,
                onPressed: () => p.toggleCatGearLock(item.id),
              ),
              GameActionButton(
                label: message('분해 · 츄르 {0} · 별가루 {1}', [
                  item.dismantleChuru,
                  item.dismantleStardust,
                ]),
                displayLabel: '분해',
                icon: Icons.recycling,
                onPressed: equipped || item.locked
                    ? null
                    : () {
                        if (p.dismantleCatGear(item.id)) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final items =
            p.catGear.items
                .where((i) => _filter == null || i.slot == _filter)
                .toList()
              ..sort((a, b) {
                final eq = (p.catGear.isEquipped(b) ? 1 : 0).compareTo(
                  p.catGear.isEquipped(a) ? 1 : 0,
                );
                if (eq != 0) return eq;
                final r = b.rarity.compareTo(a.rarity);
                return r != 0 ? r : b.level.compareTo(a.level);
              });
        return Column(
          children: [
            // v12.8: power and wallet as game plates instead of a text line
            Padding(
              key: const Key('cat-gear-power'),
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  for (final (i, image, value, label) in [
                    (
                      0,
                      'assets/art/menu_v13/trophy_gear_upgrades.webp',
                      p.catGear.power,
                      '장비 전투력',
                    ),
                    (1, CurrencyArt.churu, p.credits, '츄르'),
                    (2, CurrencyArt.stardust, p.blueprints, '별가루'),
                  ]) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Tooltip(
                        message: tr(label),
                        child: UiKitFrame(
                          'plate',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(image, width: 26, height: 26),
                              const SizedBox(width: 4),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: CountUp(
                                    value: value.toDouble(),
                                    format: (v) => '${v.round()}',
                                    duration: 600,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: i == 0
                                          ? const Color(0xFFFFD43D)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 172),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _slot(CatGearSlot.nose),
                      const SizedBox(height: 8),
                      _slot(CatGearSlot.armor),
                    ],
                  ),
                  // the craft hovers over the glowing hangar pedestal
                  Expanded(
                    child: SizedBox(
                      height: 172,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            bottom: 0,
                            child: Image.asset(
                              '${UiKit.root}pedestal.webp',
                              width: 150,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          Positioned.fill(
                            bottom: 22,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Bob(
                                height: 5,
                                period: 2600,
                                child: ShipSprite(
                                  hull: p.selectedShip,
                                  loadout: p.moduleLoadout,
                                  assets: p.shipLayerAssets,
                                  semanticLabel: tr('장착한 기체'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _slot(CatGearSlot.wings),
                      const SizedBox(height: 8),
                      _slot(CatGearSlot.engines),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_slot(CatGearSlot.shield)],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
              child: Text(
                tr(_setLine()),
                key: const Key('cat-gear-sets'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF9FE6B0)),
              ),
            ),
            // v12.9: kit tabs; each part filter shows the part itself
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  for (final f in <CatGearSlot?>[null, ...CatGearSlot.values])
                    Expanded(child: _filterTab(f)),
                ],
              ),
            ),
            Expanded(
              child: GameSlotList(
                listKey: ValueKey('cat-gear-${_filter?.name ?? 'all'}'),
                children: [
                  for (final item in items)
                    GameItemSlot(
                      title:
                          '${catGearSlotNames[item.slot]} · ${catGearSet(item.set).name}',
                      status: 'Lv.${item.level}${item.locked ? ' 🔒' : ''}',
                      image: gearImage(item, 52),
                      rarity: item.rarity,
                      selected: p.catGear.isEquipped(item),
                      semanticLabel:
                          '${item.name} ${catGearRarityNames[item.rarity]} Lv.${item.level}',
                      onTap: () => _detail(item),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
