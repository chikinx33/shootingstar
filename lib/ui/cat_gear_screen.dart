import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/toon_assets.dart';
import '../art/ui_kit.dart';
import 'game_motion.dart';

import '../art/ship_sprite_art.dart';
import '../data/cat_gear.dart';
import '../data/content.dart';
import '../data/profile.dart';
import '../data/ship_modules.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';
import 'game_dialog.dart';
import 'game_ui.dart';
import 'item_info_card.dart';
import 'item_slots.dart';
import 'module_workshop.dart' show showAirframeDetails;

/// Growth > equipment and weapons (v12.10, user 2026-10-26): a stat label
/// over a large craft that can be nudged around and springs back, with its
/// slots around it. The equipment and weapon tabs swap the slots in place:
/// one set sweeps into the craft and the other springs out of it. A slot
/// opens one popup with that slot's items, the picked item's details and its
/// actions on one line.
class CatGearScreen extends StatefulWidget {
  const CatGearScreen({super.key, required this.profile, this.weapons = false});
  final Profile profile;

  /// Shows the seven weapon/support mounts instead of the five gear slots.
  final bool weapons;

  @override
  State<CatGearScreen> createState() => _CatGearScreenState();
}

/// Where a slot sits and what it draws.
typedef _Placed = ({Key key, Offset at, Widget child});

class _CatGearScreenState extends State<CatGearScreen>
    with SingleTickerProviderStateMixin {
  Profile get p => widget.profile;

  /// 0 = gear slots out, 1 = weapon slots out.
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    value: widget.weapons ? 1 : 0,
  );

  @override
  void didUpdateWidget(CatGearScreen old) {
    super.didUpdateWidget(old);
    if (old.weapons == widget.weapons) return;
    if (liveMotion(context)) {
      _swap.animateTo(widget.weapons ? 1 : 0);
    } else {
      _swap.value = widget.weapons ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _swap.dispose();
    super.dispose();
  }

  static Widget gearImage(CatGearItem item, double size) => SizedBox.square(
    dimension: size,
    child: Image.asset(
      catGearSet(item.set).asset(item.slot),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    ),
  );

  /// The shared slot look: rarity rim, big picture, one line below.
  Widget _frame({
    required Key key,
    required String semantics,
    required double size,
    required int rank,
    required Widget? image,
    required String line,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    label: tr(semantics),
    excludeSemantics: true,
    child: InkWell(
      key: key,
      onTap: audible(onTap),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size + 18,
        child: ToonRarityFrame(
          rank: rank,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              image ??
                  Icon(
                    Icons.add,
                    size: size * .42,
                    color: const Color(0xFF8EA6C2),
                  ),
              Text(
                tr(line),
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _gearSlot(CatGearSlot slot, double size) {
    final item = p.catGear.equippedIn(slot);
    return _frame(
      key: Key('cat-gear-slot-${slot.name}'),
      semantics: item == null
          ? '${catGearSlotNames[slot]} 비어 있음'
          : '${catGearSlotNames[slot]} ${item.name} Lv.${item.level}',
      size: size,
      rank: item?.rarity ?? -1,
      image: item == null ? null : gearImage(item, size * .62),
      line: item == null ? catGearSlotNames[slot]! : 'Lv.${item.level}',
      onTap: () => _gearPopup(slot),
    );
  }

  /// A part drawn with the very sprite it shows on the airframe (v12.11,
  /// user 2026-10-26): wing gun, wing missile, tail gun or mortar, or the
  /// support device core.
  static Widget partSprite(ModulePart part, double size, {String? mount}) {
    const root = 'assets/art/ship_parts/sunshine/';
    final asset = switch (part.category) {
      PartCategory.missile => '${root}missile.webp',
      PartCategory.support => supportOrbAsset(part.id),
      PartCategory.drone => ShipSpriteArt.droneAsset,
      PartCategory.gun when part.id == 'mortar_cat' => mortarMountAsset,
      PartCategory.gun when mount == 'W3' => '${root}reargun.webp',
      PartCategory.gun => '${root}winggun.webp',
    };
    final image = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    // the mortar's sprite is stored upside down for the tail layer
    return part.id == 'mortar_cat'
        ? RotatedBox(quarterTurns: 2, child: image)
        : image;
  }

  Widget _weaponSlot(String mount, double size) {
    final part = p.moduleLoadout.parts[mount];
    final name = mountProfile(mount).name;
    return _frame(
      key: Key('weapon-slot-$mount'),
      semantics: part == null
          ? '$name 비어 있음'
          : '$name ${part.definition.name} Lv.${part.level}',
      size: size,
      rank: -1,
      image: part == null
          ? null
          : partSprite(part.definition, size * .58, mount: mount),
      line: part == null ? name : 'Lv.${part.level}',
      onTap: () => _weaponPopup(mount),
    );
  }

  /// The nose gun: the airframe's own signature weapon, drawn on its body.
  /// Fixed to the craft; it opens the airframe details and upgrade.
  Widget _mainGunSlot(double size) {
    final snap = p.moduleLoadout;
    final ship = ShipSpriteArt.shipIds[p.selectedShip.clamp(0, 2)];
    return _frame(
      key: const Key('weapon-slot-main'),
      semantics: '메인건 ${snap.signatureName} 기체 Lv.${snap.airframeLevel}',
      size: size,
      rank: -1,
      image: Image.asset(
        'assets/art/ship_parts/$ship/maingun.webp',
        width: size * .58,
        height: size * .58,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
      line: 'Lv.${snap.airframeLevel}',
      onTap: () => showAirframeDetails(context, p),
    );
  }

  /// Set effects that are active now (a hint when none are).
  String _setLine() {
    final counts = p.catGear.setCounts;
    final parts = <String>[];
    for (final set in catGearSets) {
      final n = counts[set.id] ?? 0;
      if (n >= 4) {
        parts.add('${set.name} 4세트 · ${set.four}');
      } else if (n >= 2) {
        parts.add('${set.name} 2세트 · ${set.two}');
      }
    }
    return parts.isEmpty ? '같은 세트 2·4부위를 장착하면 세트 효과' : parts.join('\n');
  }

  static String _percent(double v) {
    final pct = v * 100;
    return '+${pct >= 10 || pct == pct.roundToDouble() ? pct.round() : pct.toStringAsFixed(1)}%';
  }

  static const _bigValue = TextStyle(
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w900,
    color: Color(0xFFFFD43D),
  );

  /// The label over the craft: a title row, a row of values, one note.
  Widget _label({
    required Key key,
    required String image,
    required String title,
    required Widget value,
    required List<(String, String, Color)> stats,
    required String note,
    String semantics = '',
    VoidCallback? onTap,
  }) {
    final panel = UiKitFrame(
      'panel',
      key: key,
      corner: 18,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: semantics,
            excludeSemantics: semantics.isNotEmpty,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(image, width: 30, height: 30),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tr(title),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB8C7DA),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                value,
              ],
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                for (final (label, shown, color) in stats)
                  Expanded(
                    child: Semantics(
                      label: '${tr(label)} ${tr(shown)}',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Text(
                            tr(shown),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            // a narrow phone keeps a gap between columns
                            style: TextStyle(
                              fontSize: box.maxWidth < 300 ? 14 : 16,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                          Text(
                            tr(label),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB8C7DA),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(note),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 13,
              height: 1.25,
              color: Color(0xFF9FE6B0),
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? panel
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: audible(onTap),
            child: panel,
          );
  }

  /// Gear power, the five stats the gear adds and the active set effect.
  Widget _gearLabel() {
    final b = p.catGear.bonuses;
    return _label(
      key: const Key('cat-gear-power'),
      image: 'assets/art/menu_v13/trophy_gear_upgrades.webp',
      title: '전투력',
      semantics: message('장비 전투력 {0}', [p.catGear.power]),
      value: CountUp(
        value: p.catGear.power.toDouble(),
        format: (v) => '${v.round()}',
        duration: 600,
        style: _bigValue,
      ),
      stats: [
        ('화력', _percent(b.damage), const Color(0xFFFF8A5C)),
        ('선체', _percent(b.hull), const Color(0xFF7CE08A)),
        ('피해 감소', _percent(b.reduction), const Color(0xFF7CC8FF)),
        ('이동 속도', _percent(b.speed), const Color(0xFFFFD43D)),
        ('회수 범위', _percent(b.pickup), const Color(0xFFD9A8FF)),
      ],
      note: _setLine(),
    );
  }

  /// The airframe and its weapons; tapping opens the airframe upgrade.
  Widget _weaponLabel() {
    final snap = p.moduleLoadout;
    final fitted = moduleProfiles
        .where((m) => snap.parts.containsKey(m.id))
        .length;
    return _label(
      key: const Key('weapon-label'),
      image: 'assets/art/menu_v13/hangar.webp',
      title: ships[p.selectedShip].name,
      semantics: message('{0} 기체 Lv.{1} · 기체 정보', [
        ships[p.selectedShip].name,
        snap.airframeLevel,
      ]),
      value: Text(
        'Lv.${snap.airframeLevel}',
        textAlign: TextAlign.center,
        style: _bigValue,
      ),
      stats: [
        ('메인건', snap.signatureName, const Color(0xFFFF8A5C)),
        ('궁극기', snap.ultimateName, const Color(0xFFD9A8FF)),
        ('장착', '$fitted/${moduleProfiles.length}', const Color(0xFF7CC8FF)),
      ],
      note: message('보유 파츠 {0}/240 · 눌러서 기체 강화', [p.shipModules.owned.length]),
      onTap: () => showAirframeDetails(context, p),
    );
  }

  /// The shared popup: the slot's items, then the picked item's few lines
  /// and its actions on one line.
  Widget _popup({
    required BuildContext context,
    required String title,
    required Key listKey,
    required List<Widget> tiles,
    required String empty,
    required Widget? info,
    required List<Widget> actions,
  }) {
    final screen = MediaQuery.sizeOf(context);
    final inner = math.min(440.0, screen.width - 24) - 36 - 16;
    final columns = (inner / 112).floor().clamp(3, 5);
    final rows = (tiles.length / columns).ceil();
    final tile =
        GameItemSlot.imageHeight +
        20 +
        3 * 18 * MediaQuery.textScalerOf(context).scale(1);
    // as many rows as needed, up to about two and a half
    final listHeight = math.min(
      rows * (tile + 8) + 8,
      math.max(tile + 16, math.min(400.0, screen.height * .42)),
    );
    return GameDialog(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tiles.isEmpty)
            Text(tr(empty), textAlign: TextAlign.center)
          else
            SizedBox(
              height: listHeight,
              child: GameSlotList(listKey: listKey, children: tiles),
            ),
          if (info != null) ...[
            const SizedBox(height: 10),
            info,
            const SizedBox(height: 10),
            GameActionStrip(children: actions),
          ],
        ],
      ),
    );
  }

  /// One gear slot's owned pieces, the picked piece and its four actions.
  Future<void> _gearPopup(CatGearSlot slot) async {
    int? picked = p.catGear.equipped[slot];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setPicked) => AnimatedBuilder(
          animation: p,
          builder: (context, _) {
            final items = p.catGear.items.where((i) => i.slot == slot).toList()
              ..sort((a, b) {
                final eq = (p.catGear.isEquipped(b) ? 1 : 0).compareTo(
                  p.catGear.isEquipped(a) ? 1 : 0,
                );
                if (eq != 0) return eq;
                final r = b.rarity.compareTo(a.rarity);
                return r != 0 ? r : b.level.compareTo(a.level);
              });
            final item =
                (picked == null ? null : p.catGear.item(picked!)) ??
                items.firstOrNull;
            final equipped = item != null && p.catGear.isEquipped(item);
            final set = item == null ? null : catGearSet(item.set);
            return _popup(
              context: context,
              title: catGearSlotNames[slot]!,
              listKey: Key('cat-gear-list-${slot.name}'),
              empty: '보유한 부품이 없습니다. 출격 보상으로 얻을 수 있습니다.',
              tiles: [
                for (final i in items)
                  PickedGlow(
                    on: i.id == item?.id,
                    child: GameItemSlot(
                      key: ValueKey('cat-gear-item-${i.id}'),
                      title:
                          '${catGearSet(i.set).name} · ${catGearRarityNames[i.rarity]}',
                      status: 'Lv.${i.level}${i.locked ? ' 🔒' : ''}',
                      image: gearImage(i, 60),
                      rarity: i.rarity,
                      selected: p.catGear.isEquipped(i),
                      semanticLabel:
                          '${i.name} ${catGearRarityNames[i.rarity]} Lv.${i.level}',
                      onTap: audible(
                        () => setPicked(() => picked = i.id),
                        cue: 'select',
                      ),
                    ),
                  ),
              ],
              info: item == null
                  ? null
                  : ItemInfoCard(
                      name: item.name,
                      nameColor: Color(catGearRarityColors[item.rarity]),
                      chips: [
                        (
                          catGearRarityNames[item.rarity],
                          Color(catGearRarityColors[item.rarity]),
                        ),
                        (
                          'Lv.${item.level}/${item.maxLevel}',
                          const Color(0xFFFFD43D),
                        ),
                        if (item.locked) ('잠김', const Color(0xFFFFB55C)),
                      ],
                      stats: [
                        (
                          label: item.statLabel,
                          value: '+${(item.value * 100).toStringAsFixed(1)}%',
                          color: const Color(0xFFFF8A5C),
                        ),
                      ],
                      setName: set!.name,
                      setSteps: [
                        (
                          count: '2부위',
                          effect: set.two,
                          active: (p.catGear.setCounts[set.id] ?? 0) >= 2,
                        ),
                        (
                          count: '4부위',
                          effect: set.four,
                          active: (p.catGear.setCounts[set.id] ?? 0) >= 4,
                        ),
                      ],
                      churu: item.maxed ? null : item.upgradeChuru,
                      stardust: item.upgradeStardust,
                    ),
              actions: item == null
                  ? const []
                  : [
                      GameActionTile(
                        key: const Key('cat-gear-equip'),
                        label: equipped ? '장착 중' : '장착',
                        icon: Icons.check,
                        image: 'assets/art/ui_v13/act_check.webp',
                        primary: !equipped,
                        onPressed: equipped
                            ? null
                            : () => p.equipCatGear(item.id),
                      ),
                      GameActionTile(
                        key: const Key('cat-gear-upgrade'),
                        label: '강화',
                        icon: Icons.upgrade,
                        image: 'assets/art/ui_v13/act_upgrade.webp',
                        onPressed: p.canUpgradeCatGear(item)
                            ? () => p.upgradeCatGear(item.id)
                            : null,
                      ),
                      GameActionTile(
                        key: const Key('cat-gear-lock'),
                        label: item.locked ? '잠금 해제' : '보호 잠금',
                        displayLabel: item.locked ? '잠금 해제' : '잠금',
                        icon: item.locked ? Icons.lock_open : Icons.lock,
                        image: item.locked
                            ? 'assets/art/ui_v13/act_unlock.webp'
                            : 'assets/art/ui_v13/act_lock.webp',
                        onPressed: () => p.toggleCatGearLock(item.id),
                      ),
                      GameActionTile(
                        key: const Key('cat-gear-dismantle'),
                        label: message('분해 · 츄르 {0} · 별가루 {1}', [
                          item.dismantleChuru,
                          item.dismantleStardust,
                        ]),
                        displayLabel: '분해',
                        icon: Icons.recycling,
                        image: 'assets/art/ui_v13/act_dismantle.webp',
                        onPressed: equipped || item.locked
                            ? null
                            : () => p.dismantleCatGear(item.id),
                      ),
                    ],
            );
          },
        ),
      ),
    );
  }

  /// One mount's fitting parts (also those on other mounts: equipping moves
  /// them, level kept), the picked part and its actions.
  Future<void> _weaponPopup(String mount) async {
    final profile = mountProfile(mount);
    String? picked = p.moduleLoadout.parts[mount]?.instanceId;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setPicked) => AnimatedBuilder(
          animation: p,
          builder: (context, _) {
            final snap = p.moduleLoadout;
            String? mountOf(String id) => snap.parts.entries
                .where((e) => e.value.instanceId == id)
                .firstOrNull
                ?.key;
            int order(OwnedModulePart i) {
              final m = mountOf(i.instanceId);
              return m == mount ? 2 : (m == null ? 1 : 0);
            }

            final items =
                p.shipModules.owned.values
                    .where((i) => mountAccepts(mount, i.definition))
                    .toList()
                  ..sort((a, b) {
                    final r = order(b).compareTo(order(a));
                    return r != 0 ? r : b.level.compareTo(a.level);
                  });
            final part =
                (picked == null ? null : p.shipModules.owned[picked]) ??
                items.firstOrNull;
            final from = part == null ? null : mountOf(part.instanceId);
            final here = from == mount;
            final duplicate =
                part != null &&
                !part.definition.weapon &&
                snap.parts.entries.any(
                  (e) =>
                      e.key != mount &&
                      e.value.partId == part.partId &&
                      e.value.instanceId != part.instanceId,
                );
            var stats = <ItemStat>[];
            var note = '';
            if (part != null) {
              final s = resolvePartStats(part, profile);
              String n(double v) => v.toStringAsFixed(1);
              stats = part.definition.weapon
                  ? [
                      (
                        label: '피해',
                        value: n(s.damage),
                        color: const Color(0xFFFF8A5C),
                      ),
                      (
                        label: '초당 발사',
                        value: n(s.fireRate),
                        color: const Color(0xFFFFD43D),
                      ),
                      (
                        label: '발사 수',
                        value: '${s.count}',
                        color: const Color(0xFF7CC8FF),
                      ),
                      if (s.pierce > 0)
                        (
                          label: '관통',
                          value: '+${s.pierce}',
                          color: const Color(0xFFD9A8FF),
                        ),
                    ]
                  : [
                      (
                        label: '지원 효율',
                        value: '${(s.supportPower * 100).round()}%',
                        color: const Color(0xFF7CE08A),
                      ),
                    ];
              note = duplicate
                  ? '같은 보조 부품은 중복 장착할 수 없습니다.'
                  : from != null && !here
                  ? '${mountProfile(from).name}에 장착 중 · 옮겨도 레벨 유지'
                  : '';
            }
            return _popup(
              context: context,
              title: profile.name,
              listKey: Key('weapon-list-$mount'),
              empty: '보유한 파츠가 없습니다. 보급에서 파츠를 얻을 수 있습니다.',
              tiles: [
                for (final i in items)
                  PickedGlow(
                    on: i.instanceId == part?.instanceId,
                    child: GameItemSlot(
                      key: ValueKey('weapon-item-${i.instanceId}'),
                      title: i.definition.name,
                      status: [
                        'Lv.${i.level}',
                        if (mountOf(i.instanceId) case final m? when m != mount)
                          mountProfile(m).name,
                      ].join(' · '),
                      image: partSprite(i.definition, 60, mount: mount),
                      selected: mountOf(i.instanceId) == mount,
                      semanticLabel: '${i.definition.name} Lv.${i.level}',
                      onTap: audible(
                        () => setPicked(() => picked = i.instanceId),
                        cue: 'select',
                      ),
                    ),
                  ),
              ],
              info: part == null
                  ? null
                  : ItemInfoCard(
                      name: part.definition.name,
                      chips: [
                        ('Lv.${part.level}/40', const Color(0xFFFFD43D)),
                        if (here) ('장착 중', const Color(0xFF7CE08A)),
                      ],
                      tags: part.definition.effect.split(' · '),
                      stats: stats,
                      note: note,
                      churu: part.level >= 40
                          ? null
                          : p.moduleUpgradeCredits(part.level),
                      stardust: p.moduleUpgradePlans(part.level),
                    ),
              actions: part == null
                  ? const []
                  : [
                      GameActionTile(
                        key: const Key('weapon-equip'),
                        label: here ? '해제' : '장착',
                        icon: here ? Icons.close : Icons.check,
                        image: here
                            ? 'assets/art/ui_v13/act_cross.webp'
                            : 'assets/art/ui_v13/act_check.webp',
                        primary: !here,
                        onPressed: duplicate
                            ? null
                            : () => p.equipModule(
                                mount,
                                here ? null : part.instanceId,
                              ),
                      ),
                      GameActionTile(
                        key: const Key('weapon-upgrade'),
                        label: '강화',
                        icon: Icons.upgrade,
                        image: 'assets/art/ui_v13/act_upgrade.webp',
                        onPressed:
                            part.level < 40 &&
                                p.credits >=
                                    p.moduleUpgradeCredits(part.level) &&
                                p.blueprints >= p.moduleUpgradePlans(part.level)
                            ? () => p.upgradeModule(part.instanceId)
                            : null,
                      ),
                      GameActionTile(
                        key: const Key('weapon-salvage'),
                        label: '분해',
                        icon: Icons.recycling,
                        image: 'assets/art/ui_v13/act_dismantle.webp',
                        onPressed: p.canSalvageModule(part.instanceId)
                            ? () => _confirmSalvage(part)
                            : null,
                      ),
                    ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmSalvage(OwnedModulePart part) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '파츠 분해',
        actions: [
          GameActionButton(
            label: '분해',
            primary: true,
            icon: Icons.recycling,
            onPressed: () => Navigator.pop(dialog, true),
          ),
          GameActionButton(
            label: '취소',
            onPressed: () => Navigator.pop(dialog, false),
          ),
        ],
        child: Text(
          message('{0} Lv.{1}\n{2} 츄르 · 별가루 {3}', [
            part.definition.name,
            part.level,
            20 + part.level * 5,
            1 + part.level ~/ 3,
          ]),
          textAlign: TextAlign.center,
        ),
      ),
    );
    if (yes == true) p.salvageModule(part.instanceId);
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: Listenable.merge([p, _swap]),
      builder: (context, _) {
        final t = _swap.value;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: t < .5 ? _gearLabel() : _weaponLabel(),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => _stage(box.biggest, t),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The craft, its pedestal and both slot sets; [t] runs the swap.
  Widget _stage(Size box, double t) {
    final w = box.width, h = box.height;
    // side slots keep clear of the screen edges
    final margin = (w * .06).clamp(16.0, 32.0);
    final slot = math.min(w * .22, h * .2).clamp(64.0, 96.0);
    final slotH = slot + 18;
    const gap = 6.0;
    // The wings pass between the upper and lower side slots, so the craft
    // may span the width inside the margins. Gear: four corner slots.
    // Weapons (v12.11): main gun over the nose, mortar under the tail,
    // missile and wing gun in the lower corners, support device upper left.
    // The craft keeps one size and place for both.
    final craft = math
        .min(w - 2 * margin, (h - 2 * slotH - gap) / .80)
        .clamp(110.0, 380.0);
    final rise = craft * .38;
    final above = craft * .36 + slotH, below = craft * .44 + gap + slotH;
    final top = math.max(0.0, (h - above - below) / 2);
    final cx = w / 2, cy = top + above;
    final left = margin + slot / 2, right = w - margin - slot / 2;
    final gear = <_Placed>[
      for (final (s, at) in [
        (CatGearSlot.nose, Offset(left, cy - rise)),
        (CatGearSlot.armor, Offset(left, cy + rise)),
        (CatGearSlot.wings, Offset(right, cy - rise)),
        (CatGearSlot.engines, Offset(right, cy + rise)),
      ])
        (key: ValueKey('g-${s.name}'), at: at, child: _gearSlot(s, slot)),
    ];
    final tail = math.min(cy + craft * .44 + gap, h - slotH) + slotH / 2;
    final weapons = <_Placed>[
      (
        key: const ValueKey('w-main'),
        at: Offset(cx, cy - craft * .36 - slotH / 2),
        child: _mainGunSlot(slot),
      ),
      for (final (m, at) in [
        ('S1', Offset(left, cy - rise)),
        ('W2', Offset(left, cy + rise)),
        ('W1', Offset(right, cy + rise)),
        ('W3', Offset(cx, tail)),
      ])
        (key: ValueKey('w-$m'), at: at, child: _weaponSlot(m, slot)),
    ];
    // gear sweeps into the craft fast, then the weapons spring out
    final gearOut = 1 - Curves.easeInCubic.transform((t / .4).clamp(0.0, 1.0));
    final weaponOut = Curves.easeOutBack.transform(
      ((t - .4) / .6).clamp(0.0, 1.0),
    );
    // the craft swallows one set and pushes out the other with a pulse
    final pulse = math.sin(math.pi * ((t - .25) / .35).clamp(0.0, 1.0));
    final centre = Offset(cx, cy);
    Iterable<Widget> placed(List<_Placed> slots, double out) sync* {
      if (out <= .001) return;
      for (final s in slots) {
        final at = Offset.lerp(centre, s.at, out)!;
        yield Positioned(
          key: s.key,
          left: at.dx - slot / 2,
          top: at.dy - slotH / 2,
          child: IgnorePointer(
            ignoring: out < .98,
            child: Opacity(
              opacity: out.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: (.2 + .8 * out).clamp(0.0, 1.1),
                child: s.child,
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: cx - craft * .28,
          top: cy - craft * .02,
          width: craft * .56,
          child: Image.asset(
            '${UiKit.root}pedestal.webp',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
        Positioned(
          left: cx - craft / 2,
          top: cy - craft / 2,
          width: craft,
          height: craft,
          child: Transform.scale(
            scale: 1 + .06 * pulse,
            child: _CraftStage(profile: p, size: craft),
          ),
        ),
        ...placed(gear, gearOut),
        ...placed(weapons, weaponOut),
      ],
    );
  }
}

/// The equipped craft over the pedestal. Dragging moves it inside a small
/// rubber-band radius; on release it springs home. It rolls into sideways
/// motion and stretches its flames going forward, as in flight.
class _CraftStage extends StatefulWidget {
  const _CraftStage({required this.profile, required this.size});
  final Profile profile;
  final double size;

  @override
  State<_CraftStage> createState() => _CraftStageState();
}

class _CraftStageState extends State<_CraftStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _prev = Duration.zero;
  Offset _raw = Offset.zero, _offset = Offset.zero, _last = Offset.zero;
  Offset _release = Offset.zero;
  double _back = 1, _bank = 0, _thrust = 0;
  bool _dragging = false;

  double get _reach => widget.size * .18;

  void _start() {
    if (_ticker.isActive) return;
    _prev = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _prev).inMicroseconds / 1e6;
    _prev = elapsed;
    if (dt <= 0) return;
    final step = math.min(dt, .05);
    if (!_dragging) {
      _back = math.min(1, _back + step / .5);
      final t = Curves.elasticOut.transform(_back);
      _offset = Offset.lerp(_release, Offset.zero, t)!;
    }
    final v = (_offset - _last) / step;
    _last = _offset;
    final ref = _reach * 5;
    final k = math.min(1.0, step / .09);
    _bank += ((v.dx / ref).clamp(-1.0, 1.0) - _bank) * k;
    _thrust += ((-v.dy / (ref * .8)).clamp(-1.0, 1.0) - _thrust) * k;
    final settled =
        !_dragging && _back >= 1 && _bank.abs() < .005 && _thrust.abs() < .005;
    setState(() {
      if (settled) {
        _offset = _last = Offset.zero;
        _bank = _thrust = 0;
      }
    });
    if (settled) _ticker.stop();
  }

  /// Soft limit: the craft follows the finger less the farther it goes.
  Offset _bounded(Offset raw) {
    final d = raw.distance;
    if (d < .01) return Offset.zero;
    return raw / d * (_reach * _tanh(d / _reach));
  }

  static double _tanh(double x) {
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  void _down(DragStartDetails _) {
    _dragging = true;
    _raw = _offset;
    if (liveMotion(context)) _start();
  }

  void _move(DragUpdateDetails d) {
    _raw += d.delta;
    _offset = _bounded(_raw);
    if (!_ticker.isActive) setState(() {});
  }

  void _up() {
    _dragging = false;
    _release = _offset;
    _back = 0;
    if (!_ticker.isActive) setState(() => _offset = Offset.zero);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final lift = _offset.distance / _reach;
    return GestureDetector(
      key: const Key('cat-gear-craft'),
      behavior: HitTestBehavior.opaque,
      onPanStart: _down,
      onPanUpdate: _move,
      onPanEnd: (_) => _up(),
      onPanCancel: _up,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // the shadow on the pedestal trails behind and spreads as it lifts
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(_offset.dx * .55, size * .16 + _offset.dy * .25),
              child: Center(
                child: Container(
                  width: size * (.36 + .06 * lift),
                  height: size * .09,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .32 - .1 * lift),
                        blurRadius: size * .08,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Transform.translate(
              offset: _offset,
              child: Transform.scale(
                scale: 1 + .04 * lift,
                child: Bob(
                  height: 5,
                  period: 2600,
                  child: ShipSprite(
                    hull: p.selectedShip,
                    loadout: p.moduleLoadout,
                    assets: p.shipLayerAssets,
                    semanticLabel: tr('장착한 기체'),
                    bank: _bank,
                    flameScale:
                        1 +
                        1.3 * math.max(0, _thrust) -
                        .3 * math.max(0, -_thrust),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get size => widget.size;
}
