import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import 'arcade_home_widgets.dart';

/// One stat of an item: a big value over a small label, in its own box.
typedef ItemStat = ({String label, String value, Color color});

/// A set bonus step: "2부위 · 화력 +4%", lit when it is active.
typedef ItemSetStep = ({String count, String effect, bool active});

/// The picked item's details in an item popup (v12.12, user 2026-10-26:
/// plain text lines were hard to read). Name with rarity and level chips,
/// effect tags, stat boxes, set steps and the upgrade cost with the
/// currency pictures, each in its own labelled box.
class ItemInfoCard extends StatelessWidget {
  const ItemInfoCard({
    super.key,
    required this.name,
    this.nameColor = Colors.white,
    this.chips = const [],
    this.tags = const [],
    this.stats = const [],
    this.setName,
    this.setSteps = const [],
    this.note,
    this.churu,
    this.stardust = 0,
  });

  final String name;
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

  /// Upgrade cost; null means the item is at its maximum level.
  final int? churu;
  final int stardust;

  static const _box = Color(0xFF13223F), _rim = Color(0xFF3A5A8C);
  static const _muted = Color(0xFFB8C7DA);

  static Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color, width: 1.5),
    ),
    child: Text(
      tr(text),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        height: 1.25,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    ),
  );

  static BoxDecoration get _boxStyle => BoxDecoration(
    color: _box,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: _rim, width: 1.5),
  );

  Widget _cost() {
    if (churu == null) {
      return _pill('최대 레벨', const Color(0xFFFFD43D));
    }
    Widget amount(String image, int value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(image, width: 20, height: 20),
        const SizedBox(width: 3),
        Text(
          '$value',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          tr('강화 비용'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _muted,
          ),
        ),
        const SizedBox(width: 8),
        amount(CurrencyArt.churu, churu!),
        if (stardust > 0) ...[
          const SizedBox(width: 10),
          amount(CurrencyArt.stardust, stardust),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Column(
      key: const Key('item-detail'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // name and its chips
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
            for (final (text, color) in chips) _pill(text, color),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            runSpacing: 4,
            children: [for (final t in tags) _pill(t, const Color(0xFF8FD3FF))],
          ),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: _boxStyle,
                    child: Column(
                      children: [
                        Text(
                          tr(stats[i].value),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                            color: stats[i].color,
                          ),
                        ),
                        Text(
                          tr(stats[i].label),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (setSteps.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: _boxStyle,
            child: Column(
              children: [
                Text(
                  tr('${setName ?? ''} 세트'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 3),
                for (final step in setSteps)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        _pill(
                          step.count,
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
                              fontSize: 14,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: step.active
                                  ? const Color(0xFF9FE6B0)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
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
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFB55C),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Center(child: _cost()),
      ],
    );
  }
}
