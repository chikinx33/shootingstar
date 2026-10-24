import 'package:flutter/material.dart';

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
    final color = Color(catGearRarityColors[item?.rarity ?? 0]);
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
        child: Container(
          width: 68,
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2C40),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item != null)
                gearImage(item, 40)
              else
                const Icon(Icons.add, size: 32, color: Color(0xFF6E86A0)),
              Text(
                item == null ? tr(catGearSlotNames[slot]!) : 'Lv.${item.level}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
                icon: Icons.check_circle,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(
                message('장비 전투력 {0} · 츄르 {1} · 별가루 {2}', [
                  p.catGear.power,
                  p.credits,
                  p.blueprints,
                ]),
                key: const Key('cat-gear-power'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD43D),
                ),
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
                  Expanded(
                    child: SizedBox(
                      height: 172,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: ShipSprite(
                          hull: p.selectedShip,
                          loadout: p.moduleLoadout,
                          assets: p.shipLayerAssets,
                          semanticLabel: tr('장착한 기체'),
                        ),
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
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  for (final f in <CatGearSlot?>[null, ...CatGearSlot.values])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Opacity(
                          opacity: _filter == f ? 1 : .5,
                          child: FilledButton(
                            style: GameUi.compactButton,
                            onPressed: audible(
                              () => setState(() => _filter = f),
                            ),
                            child: Text(
                              tr(
                                f == null
                                    ? '전체'
                                    : const {
                                        CatGearSlot.nose: '기수',
                                        CatGearSlot.armor: '장갑',
                                        CatGearSlot.wings: '날개',
                                        CatGearSlot.engines: '추진',
                                        CatGearSlot.shield: '보호',
                                      }[f]!,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GameSlotList(
                listKey: ValueKey('cat-gear-${_filter?.name ?? 'all'}'),
                children: [
                  for (final item in items)
                    GameItemSlot(
                      title: '${catGearSlotNames[item.slot]}',
                      status: 'Lv.${item.level}${item.locked ? ' 🔒' : ''}',
                      image: gearImage(item, 52),
                      rarity: item.rarity + 1,
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
