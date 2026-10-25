import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/raster_assets.dart';
import '../art/toon_assets.dart';
import '../art/ui_kit.dart';
import 'game_motion.dart';

import '../art/ship_sprite_art.dart';
import '../data/cat_gear.dart';
import '../data/profile.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';
import 'game_dialog.dart';
import 'item_slots.dart';

/// The cat's equipment (v12.10, user 2026-10-26): a stat label over a large
/// craft that can be nudged around and springs back, and the five airframe
/// slots around it. A slot opens its owned pieces with the selected piece's
/// details and actions (equip, upgrade, lock, dismantle) in one popup.
class CatGearScreen extends StatefulWidget {
  const CatGearScreen({super.key, required this.profile});
  final Profile profile;

  @override
  State<CatGearScreen> createState() => _CatGearScreenState();
}

class _CatGearScreenState extends State<CatGearScreen> {
  Profile get p => widget.profile;

  static Widget gearImage(CatGearItem item, double size) => SizedBox.square(
    dimension: size,
    child: Image.asset(
      catGearSet(item.set).asset(item.slot),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    ),
  );

  Widget _slot(CatGearSlot slot, double size) {
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
        onTap: audible(() => _slotPopup(slot)),
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: size,
          height: size + 18,
          child: ToonRarityFrame(
            rank: item?.rarity ?? -1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item != null)
                  gearImage(item, size * .62)
                else
                  Icon(
                    Icons.add,
                    size: size * .42,
                    color: const Color(0xFF8EA6C2),
                  ),
                Text(
                  item == null
                      ? tr(catGearSlotNames[slot]!)
                      : 'Lv.${item.level}',
                  textAlign: TextAlign.center,
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
  }

  /// Set effects that are active now (empty when none are).
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
    return parts.join('\n');
  }

  static String _percent(double v) {
    final pct = v * 100;
    return '+${pct >= 10 || pct == pct.roundToDouble() ? pct.round() : pct.toStringAsFixed(1)}%';
  }

  /// Gear power, the five stats the gear adds and the active set effect.
  Widget _stats() {
    final b = p.catGear.bonuses;
    final set = _setLine();
    final stats = [
      ('화력', b.damage, const Color(0xFFFF8A5C)),
      ('선체', b.hull, const Color(0xFF7CE08A)),
      ('피해 감소', b.reduction, const Color(0xFF7CC8FF)),
      ('이동 속도', b.speed, const Color(0xFFFFD43D)),
      ('회수 범위', b.pickup, const Color(0xFFD9A8FF)),
    ];
    return UiKitFrame(
      'panel',
      key: const Key('cat-gear-power'),
      corner: 18,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: message('장비 전투력 {0}', [p.catGear.power]),
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/art/menu_v13/trophy_gear_upgrades.webp',
                  width: 30,
                  height: 30,
                ),
                const SizedBox(width: 6),
                Text(
                  tr('전투력'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB8C7DA),
                  ),
                ),
                const SizedBox(width: 8),
                CountUp(
                  value: p.catGear.power.toDouble(),
                  format: (v) => '${v.round()}',
                  duration: 600,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD43D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                for (final (label, value, color) in stats)
                  Expanded(
                    child: Semantics(
                      label: '${tr(label)} ${_percent(value)}',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Text(
                            _percent(value),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            // five columns: a narrow phone keeps a gap
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
          if (set.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tr(set),
              key: const Key('cat-gear-sets'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.25,
                color: Color(0xFF9FE6B0),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One slot's owned pieces; the chosen piece's details and actions below.
  Future<void> _slotPopup(CatGearSlot slot) async {
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
            // list height: as many rows as needed, at most about 1.5 rows
            final screen = MediaQuery.sizeOf(context);
            final inner = math.min(440.0, screen.width - 24) - 36 - 16;
            final columns = (inner / 112).floor().clamp(3, 5);
            final rows = (items.length / columns).ceil();
            final tile =
                GameItemSlot.imageHeight +
                20 +
                3 * 18 * MediaQuery.textScalerOf(context).scale(1);
            final listHeight = math.min(
              rows * (tile + 8) + 8,
              math.max(tile + 16, math.min(260.0, screen.height * .3)),
            );
            return GameDialog(
              title: catGearSlotNames[slot]!,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (items.isEmpty)
                    Text(
                      tr('보유한 부품이 없습니다. 출격 보상으로 얻을 수 있습니다.'),
                      textAlign: TextAlign.center,
                    )
                  else
                    SizedBox(
                      height: listHeight,
                      child: GameSlotList(
                        listKey: Key('cat-gear-list-${slot.name}'),
                        children: [
                          for (final i in items)
                            _PickedOutline(
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
                      ),
                    ),
                  if (item != null) ...[
                    const SizedBox(height: 12),
                    _itemInfo(item),
                    const SizedBox(height: 14),
                    _itemActions(item),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _itemInfo(CatGearItem item) => Column(
    key: const Key('cat-gear-detail'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        tr(item.name),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w900,
          color: Color(catGearRarityColors[item.rarity]),
        ),
      ),
      Text(
        message('{0} · Lv.{1}/{2} · {3}', [
          tr(catGearRarityNames[item.rarity]),
          item.level,
          item.maxLevel,
          tr(item.statText),
        ]),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      Text(
        tr(
          '${catGearSet(item.set).name} 세트 · 3부위 ${catGearSet(item.set).three} · 5부위 ${catGearSet(item.set).five}',
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Color(0xFFB8C7DA)),
      ),
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
        style: const TextStyle(fontSize: 14, color: Color(0xFFFFD27A)),
      ),
    ],
  );

  /// Equip, upgrade, lock and dismantle side by side in two rows.
  Widget _itemActions(CatGearItem item) {
    final equipped = p.catGear.isEquipped(item);
    final tiles = [
      _GearAction(
        key: const Key('cat-gear-equip'),
        label: equipped ? '장착 중' : '장착',
        icon: Icons.check,
        primary: !equipped,
        onPressed: equipped ? null : () => p.equipCatGear(item.id),
      ),
      _GearAction(
        key: const Key('cat-gear-upgrade'),
        label: '강화',
        icon: Icons.upgrade,
        onPressed: p.canUpgradeCatGear(item)
            ? () => p.upgradeCatGear(item.id)
            : null,
      ),
      _GearAction(
        key: const Key('cat-gear-lock'),
        label: item.locked ? '잠금 해제' : '보호 잠금',
        icon: item.locked ? Icons.lock_open : Icons.lock,
        onPressed: () => p.toggleCatGearLock(item.id),
      ),
      _GearAction(
        key: const Key('cat-gear-dismantle'),
        label: message('분해 · 츄르 {0} · 별가루 {1}', [
          item.dismantleChuru,
          item.dismantleStardust,
        ]),
        displayLabel: '분해',
        icon: Icons.recycling,
        onPressed: equipped || item.locked
            ? null
            : () => p.dismantleCatGear(item.id),
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < 4; r += 2) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: tiles[r]),
              const SizedBox(width: 10),
              Expanded(child: tiles[r + 1]),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: p,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: _stats(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth, h = box.maxHeight;
                // side slots keep clear of the screen edges
                final margin = (w * .06).clamp(16.0, 32.0);
                final slot = math.min(w * .22, h * .2).clamp(64.0, 96.0);
                final slotH = slot + 18;
                const gap = 6.0;
                // The wings pass between the upper and lower side slots, so
                // the craft may span the width inside the margins.
                final craft = math
                    .min(w - 2 * margin, (h - 1.5 * slotH - gap) / .82)
                    .clamp(110.0, 380.0);
                final rise = craft * .38;
                // slots, craft, pedestal and shield slot centred as one group
                final top = math.max(
                  0.0,
                  (h - craft * .82 - 1.5 * slotH - gap) / 2,
                );
                final cx = w / 2, cy = top + rise + slotH / 2;
                Widget at(double x, double y, Widget child) =>
                    Positioned(left: x, top: y, child: child);
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
                      child: _CraftStage(profile: p, size: craft),
                    ),
                    at(
                      margin,
                      cy - rise - slotH / 2,
                      _slot(CatGearSlot.nose, slot),
                    ),
                    at(
                      margin,
                      cy + rise - slotH / 2,
                      _slot(CatGearSlot.armor, slot),
                    ),
                    at(
                      w - margin - slot,
                      cy - rise - slotH / 2,
                      _slot(CatGearSlot.wings, slot),
                    ),
                    at(
                      w - margin - slot,
                      cy + rise - slotH / 2,
                      _slot(CatGearSlot.engines, slot),
                    ),
                    at(
                      cx - slot / 2,
                      math.min(cy + craft * .44 + gap, h - slotH),
                      _slot(CatGearSlot.shield, slot),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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

/// The piece being viewed in the slot popup glows in cyan.
class _PickedOutline extends StatelessWidget {
  const _PickedOutline({required this.on, required this.child});
  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: on
          ? const [BoxShadow(color: Color(0xCC4FE3FF), blurRadius: 10)]
          : const [],
    ),
    child: child,
  );
}

/// A kit button sized for a two-column action grid inside a popup.
class _GearAction extends StatelessWidget {
  const _GearAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.displayLabel,
    this.primary = false,
  });
  final String label;
  final String? displayLabel;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.transparent,
      elevation: 0,
      side: BorderSide.none,
    ).copyWith(backgroundBuilder: (context, states, child) => child!),
    onPressed: audible(onPressed, cue: buttonCue(label)),
    child: Opacity(
      opacity: onPressed == null ? .58 : 1,
      child: RasterPanel(
        skin: onPressed == null ? 4 : (primary ? 2 : 3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RasterIcon(icon, size: 28),
                const SizedBox(width: 6),
                Flexible(
                  child: Semantics(
                    label: tr(label),
                    excludeSemantics: true,
                    child: Text(
                      tr(displayLabel ?? label),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        color: primary ? const Color(0xFF202838) : Colors.white,
                        shadows: [
                          Shadow(
                            color: primary
                                ? const Color(0x88FFFFFF)
                                : const Color(0xFF172031),
                            offset: Offset(0, primary ? 1 : 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
