import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../main.dart';
import 'game_ui.dart';
import 'reward_flight.dart';

/// Original Flutter art informed by the supplied reference's hierarchy:
/// strong silhouettes, outlined surfaces and a larger central battle tab.
class FlightNavigation extends StatelessWidget {
  const FlightNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Container(
      color: const Color(0xFF13243A),
      foregroundDecoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFF151A23), width: 3),
        ),
      ),
      child: SizedBox(
        height:
            88 +
            24 * (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in const [
              (5, '보급', 'supply'),
              (2, '성장', 'growth'),
              (0, '출격', 'launch'),
              (3, '도전', 'challenge'),
              (4, '연구', 'research'),
            ])
              Expanded(
                // The reference prefab expands the battle slot to 344 vs 184.
                flex: entry.$1 == 0 ? 12 : 10,
                child: Semantics(
                  selected:
                      selected == entry.$1 || (selected == 1 && entry.$1 == 2),
                  button: true,
                  child: InkWell(
                    onTap: audible(() => onSelect(entry.$1)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                      decoration: BoxDecoration(
                        color:
                            selected == entry.$1 ||
                                (selected == 1 && entry.$1 == 2)
                            ? const Color(0xFF2A465F)
                            : const Color(0xFF192C42),
                        borderRadius: BorderRadius.zero,
                        border: selected == entry.$1
                            ? const Border(
                                top: BorderSide(
                                  color: Color(0xFFFFD261),
                                  width: 3,
                                ),
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          MenuArtIcon(
                            entry.$3,
                            size: entry.$1 == 0 ? 54 : GameUi.navigationIcon,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLanguage.instance.english && entry.$1 == 4
                                ? 'Lab'
                                : AppLanguage.instance.english && entry.$1 == 3
                                ? 'Trials'
                                : tr(entry.$2),
                            style: TextStyle(
                              fontSize: GameUi.navigationLabel,
                              fontWeight: FontWeight.w900,
                              color:
                                  selected == entry.$1 ||
                                      (selected == 1 && entry.$1 == 2)
                                  ? const Color(0xFFFFD261)
                                  : const Color(0xFFB7CDDC),
                              height: 1.2,
                            ),

                            textAlign: TextAlign.center,
                          ),
                        ],
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
}

/// v13 menu art (one generated sheet, cut by tools/slice_icon_sheet.py):
/// mission, season, hangar, patrol, guild, achievement, supply, growth,
/// launch, challenge, research.
class MenuArtIcon extends StatelessWidget {
  const MenuArtIcon(this.name, {super.key, this.size = 40});

  /// Every menu picture the lobby and its navigation show.
  static const lobby = [
    'mission',
    'season',
    'hangar',
    'patrol',
    'guild',
    'achievement',
    'supply',
    'growth',
    'launch',
    'challenge',
    'research',
  ];
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/art/menu_v13/$name.webp',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
  );
}

/// The three lobby currencies, each with the picture of what it is.
abstract final class CurrencyArt {
  static const churu = 'assets/art/icons_v11/churu.webp';
  static const stardust = 'assets/art/icons_v11/stardust.webp';
  static const gearTicket = 'assets/art/menu_v13/gear_ticket.webp';
}

/// A header currency: picture and amount only. The name stays available as
/// a long-press tooltip and to screen readers.
class ResourceCounter extends StatelessWidget {
  const ResourceCounter({
    super.key,
    required this.image,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String image;
  final String label;
  final int value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return RewardTarget(
      name: label,
      child: Tooltip(
        message: tr(label),
        child: Semantics(
          label: '${tr(label)} $value',
          button: true,
          excludeSemantics: true,
          child: InkWell(
            onTap: audible(onTap),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1D30),
                border: Border.all(color: const Color(0xFF49617A)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    image,
                    width: 30,
                    height: 30,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr(_shortValue(value)),
                        maxLines: 1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
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
}

class BridgeAction extends StatelessWidget {
  const BridgeAction({
    super.key,
    required this.art,
    required this.label,
    required this.onTap,
    this.color = cyan,
    this.displayLabel,
    this.height = 84,
    this.width = 76,
    this.compact = false,
  });

  /// A [MenuArtIcon] name.
  final String art;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final String? displayLabel;
  final double height, width;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      label: tr(label),
      button: true,
      excludeSemantics: true,
      onTap: audible(onTap),
      child: SizedBox(
        width: width,
        height: height,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          onPressed: audible(onTap),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Fill the existing shortcut area without squeezing the label.
              Flexible(child: MenuArtIcon(art, size: 56)),
              const SizedBox(height: 2),
              Text(
                tr(displayLabel ?? label),
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Color(0xFF111318),
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                    Shadow(
                      color: Color(0xFF111318),
                      offset: Offset(-1, -1),
                      blurRadius: 2,
                    ),
                  ],
                ),

                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Full values remain available to screen readers through ResourceCounter.
String _shortValue(int value) => value >= 1000000
    ? '${(value / 1000000).round()}M'
    : value >= 1000
    ? '${(value / 1000).round()}K'
    : '$value';
