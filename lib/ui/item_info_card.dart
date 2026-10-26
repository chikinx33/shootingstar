import 'package:flutter/material.dart';

import '../art/game_icons.dart';
import '../art/toon_assets.dart';
import '../l10n/app_language.dart';
import 'game_ui.dart';

/// One stat of an item: label, shown value and its colour. [was] is the
/// value of the piece it would replace (drawn "was → value", green arrow).
typedef ItemStat = ({String label, String value, Color color});

/// A set bonus step: "2부위 · 화력 +4%", lit when it is active.
typedef ItemSetStep = ({String count, String effect, bool active});

/// v12.15 mobile-RPG item read-out (user 2026-10-26: info is pictures and
/// numbers, not sentences). Each stat is one line: its icon picture, a short
/// label and the number; a change reads "old → new" with a green arrow.
abstract final class StatIcons {
  static String of(String label) {
    for (final (key, asset) in _table) {
      if (label.contains(key)) return asset;
    }
    return GameIcons.gem;
  }

  static const _table = [
    ('보스', GameIcons.bomb),
    ('피해 감소', GameIcons.shield),
    ('피해', GameIcons.crosshair),
    ('화력', GameIcons.crosshair),
    ('메인건', GameIcons.crosshair),
    ('주포', GameIcons.crosshair),
    ('초당', GameIcons.bolt),
    ('연사', GameIcons.bolt),
    ('지원', GameIcons.bolt),
    ('발사', 'assets/art/icons_v12/item_bullet.webp'),
    ('관통', 'assets/art/icons_v12/paw_laser.webp'),
    ('폭발', GameIcons.bomb),
    ('사거리', GameIcons.speed),
    ('복귀', GameIcons.hourglass),
    ('체력', GameIcons.heal),
    ('선체', GameIcons.heal),
    ('이동', GameIcons.speed),
    ('회수', GameIcons.magnet),
    ('궁극', GameIcons.gem),
    ('장착', 'assets/art/menu_v13/hangar.webp'),
  ];
}

/// One stat as a single line: icon, label, value (or "was → value").
class StatLine extends StatelessWidget {
  const StatLine({
    super.key,
    required this.label,
    required this.value,
    this.was,
    this.color = Colors.white,
    this.icon,
  });
  final String label, value;
  final String? was, icon;
  final Color color;

  static const _muted = Color(0xFFB8C7DA);

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    const style = TextStyle(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w900,
    );
    return Semantics(
      label: '${tr(label)} ${was == null ? '' : '$was → '}$value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
        decoration: BoxDecoration(
          color: const Color(0xFF13223F),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            GameIconImage(icon ?? StatIcons.of(label), size: 26),
            const SizedBox(width: 6),
            // label and value share the line; each shrinks rather than
            // overflowing a narrow half-width cell
            Flexible(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tr(label),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: GameUi.caption,
                      fontWeight: FontWeight.w800,
                      color: _muted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (was != null) ...[
                        Text(
                          tr(was!),
                          textAlign: TextAlign.center,
                          style: style.copyWith(color: _muted),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Color(0xFF7CE08A),
                          ),
                        ),
                      ],
                      Text(
                        tr(value),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: style.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat lines two per row (one per row when there is a single stat).
class StatGrid extends StatelessWidget {
  const StatGrid(this.lines, {super.key});
  final List<StatLine> lines;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < lines.length; i += 2)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
          child: Row(
            children: [
              Expanded(child: lines[i]),
              if (i + 1 < lines.length) ...[
                const SizedBox(width: 4),
                Expanded(child: lines[i + 1]),
              ],
            ],
          ),
        ),
    ],
  );
}

/// A price: currency pictures with amounts on a dark pill (no words). Used
/// right above the action it pays for.
class CostLabel extends StatelessWidget {
  const CostLabel({
    super.key,
    required this.churu,
    this.stardust = 0,
    this.affordable = true,
    this.gain = false,
  });
  final int churu, stardust;
  final bool affordable;

  /// A gain (salvage) shows "+" amounts in green.
  final bool gain;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final color = gain
        ? const Color(0xFF7CE08A)
        : affordable
        ? Colors.white
        : const Color(0xFFFF7A6B);
    Widget amount(String image, int value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIconImage(image, size: 26),
        const SizedBox(width: 2),
        Text(
          '${gain ? '+' : ''}$value',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
    return Semantics(
      label: '${tr('츄르')} $churu ${tr('별가루')} $stardust',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xE60B1830),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFF3A5A8C), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            amount(GameIcons.churu, churu),
            if (stardust > 0) ...[
              const SizedBox(width: 10),
              amount(GameIcons.stardust, stardust),
            ],
          ],
        ),
      ),
    );
  }
}

/// The item's big picture in its rarity frame beside its name and chips.
class ItemHero extends StatelessWidget {
  const ItemHero({
    super.key,
    required this.image,
    required this.name,
    this.rarity = 0,
    this.nameColor = Colors.white,
    this.chips = const [],
    this.size = 76,
  });
  final Widget image;
  final String name;
  final int rarity;
  final Color nameColor;
  final List<(String, Color)> chips;
  final double size;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Row(
      children: [
        SizedBox.square(
          dimension: size,
          child: ToonRarityFrame(
            rank: rarity.clamp(0, 5),
            child: Padding(
              padding: EdgeInsets.all(size * .1),
              child: Center(child: image),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tr(name),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    color: nameColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 5,
                runSpacing: 4,
                children: [for (final (t, c) in chips) ItemPill(t, c)],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small coloured pill (rarity, level, "locked", effect keyword).
class ItemPill extends StatelessWidget {
  const ItemPill(this.text, this.color, {super.key});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color, width: 1.5),
    ),
    child: Text(
      tr(text),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: GameUi.caption,
        height: 1.3,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    ),
  );
}

/// The picked item's details in an item popup: picture and name, effect
/// keywords, one line per stat, set steps and the upgrade price.
class ItemInfoCard extends StatelessWidget {
  const ItemInfoCard({
    super.key,
    required this.name,
    this.image,
    this.rarity = 0,
    this.nameColor = Colors.white,
    this.chips = const [],
    this.tags = const [],
    this.stats = const [],
    this.setName,
    this.setSteps = const [],
    this.note,
    this.churu,
    this.stardust = 0,
    this.affordable = true,
  });

  /// Short phones: the item list above already shows the picture, so the
  /// card drops it and puts both set steps on one row.
  static bool compactFor(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 700;

  final String name;
  final Widget? image;
  final int rarity;
  final Color nameColor;

  /// Small coloured pills after the name (rarity, level, "locked").
  final List<(String, Color)> chips;

  /// Effect keywords ("정밀 운동탄", "보스 피해 +50%").
  final List<String> tags;
  final List<ItemStat> stats;
  final String? setName;
  final List<ItemSetStep> setSteps;

  /// A warning line (why an action is unavailable).
  final String? note;

  /// Upgrade price; null means the item is at its maximum level.
  final int? churu;
  final int stardust;
  final bool affordable;

  Widget _step(ItemSetStep step, {bool column = false}) {
    final color = step.active
        ? const Color(0xFF7CE08A)
        : const Color(0xFF8A98AE);
    final effect = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        tr(step.effect),
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: GameUi.caption,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: step.active
              ? const Color(0xFF9FE6B0)
              : const Color(0xFFB8C7DA),
        ),
      ),
    );
    return Column(
      children: [ItemPill('${setName ?? ''} ${step.count}', color), effect],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final compact = compactFor(context);
    final gap = compact ? 4.0 : 6.0;
    return Column(
      key: const Key('item-detail'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (image != null && !compact)
          ItemHero(
            image: image!,
            name: name,
            rarity: rarity,
            nameColor: nameColor,
            chips: chips,
            size: 64,
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                tr(name),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  color: nameColor,
                ),
              ),
              for (final (text, color) in chips) ItemPill(text, color),
            ],
          ),
        if (tags.isNotEmpty) ...[
          SizedBox(height: gap),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            runSpacing: 4,
            children: [
              for (final t in tags) ItemPill(t, const Color(0xFF8FD3FF)),
            ],
          ),
        ],
        if (stats.isNotEmpty) ...[
          SizedBox(height: gap),
          StatGrid([
            for (final s in stats)
              StatLine(label: s.label, value: s.value, color: s.color),
          ]),
        ],
        if (setSteps.isNotEmpty && compact) ...[
          SizedBox(height: gap),
          Row(
            children: [
              for (final (i, step) in setSteps.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _step(step, column: true)),
              ],
            ],
          ),
        ] else if (setSteps.isNotEmpty) ...[
          SizedBox(height: gap),
          for (final step in setSteps)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  ItemPill(
                    '${setName ?? ''} ${step.count}',
                    step.active
                        ? const Color(0xFF7CE08A)
                        : const Color(0xFF8A98AE),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr(step.effect),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: GameUi.caption,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: step.active
                            ? const Color(0xFF9FE6B0)
                            : const Color(0xFFB8C7DA),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (note != null && note!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            tr(note!),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: GameUi.caption,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFB55C),
            ),
          ),
        ],
        SizedBox(height: gap),
        Center(
          child: churu == null
              ? const ItemPill('최대 레벨', Color(0xFFFFD43D))
              : CostLabel(
                  churu: churu!,
                  stardust: stardust,
                  affordable: affordable,
                ),
        ),
      ],
    );
  }
}
