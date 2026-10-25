import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../art/ui_kit.dart';
import 'reward_flight.dart';

import 'components.dart';
import 'game_motion.dart';

/// Only repeated item slots scroll. Titles/navigation stay outside this viewport.
class GameSlotList extends StatelessWidget {
  const GameSlotList({super.key, required this.children, this.listKey});
  final List<Widget> children;
  final Key? listKey;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ListView(
      key: listKey,
      padding: const EdgeInsets.all(8),
      children: [GameSlotRows(children: children)],
    );
  }
}

class GameSlotRows extends StatelessWidget {
  const GameSlotRows({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return LayoutBuilder(
      builder: (context, box) {
        final columns = (box.maxWidth / 112).floor().clamp(3, 5);
        final width = (box.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < children.length; i++)
              SizedBox(
                width: width,
                child: StaggerIn(index: i, child: children[i]),
              ),
          ],
        );
      },
    );
  }
}

/// Overview is image/name/state only. Full text and decisions live in detail.
///
/// Every slot has the same height (user 2026-10-25): a large picture, then
/// two title lines and one status line that never wrap. A title of the form
/// "name · description" (or "name\ndescription") shows name and description
/// on their own lines; a line too long for the cell scales down instead of
/// wrapping.
class GameItemSlot extends StatelessWidget {
  const GameItemSlot({
    super.key,
    required this.title,
    required this.image,
    required this.onTap,
    this.status = '',
    this.selected = false,
    this.rarity = -1,
    this.semanticLabel,
  });
  final String title, status;
  final String? semanticLabel;
  final Widget image;
  final VoidCallback? onTap;
  final bool selected;

  /// Rim colour: -1 the neutral kit slot, 0..5 gray to red rarity.
  final int rarity;

  static const imageHeight = 84.0;

  /// The two visible title lines, each translated on its own.
  static List<String> titleLines(String title) {
    final parts = title.contains('\n') ? title.split('\n') : title.split(' · ');
    if (parts.length == 1) {
      final whole = tr(title);
      final english = whole.split(' · ');
      return english.length == 2 ? english : [whole, ''];
    }
    return [tr(parts.first), tr(parts.skip(1).join(' · '))];
  }

  static Widget _line(String text, TextStyle style) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text.isEmpty ? ' ' : text,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: style,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final lines = titleLines(title);
    const name = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      height: 1.25,
    );
    return RewardTarget(
      name: title,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: onTap != null,
        label: tr(semanticLabel ?? '${title.replaceAll('\n', ' ')} $status'),
        excludeSemantics: true,
        onTap: audible(onTap),
        child: InkWell(
          onTap: audible(onTap),
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF665126) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? const Color(0xFFFFD43D) : Colors.transparent,
                width: 3,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Surface(
                active: selected,
                rarity: rarity,
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Pictures grow to the slot, whatever size the
                          // caller drew them at.
                          Center(
                            child: FittedBox(fit: BoxFit.contain, child: image),
                          ),
                          if (selected)
                            const Positioned(
                              top: 0,
                              right: 0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFFFFD43D),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 24,
                                  color: Color(0xFF142139),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _line(lines[0], name),
                    _line(
                      lines[1],
                      name.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDCE6F2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _line(
                      tr(status),
                      const TextStyle(fontSize: 14, height: 1.2),
                    ),
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

/// The slot currently being looked at glows in cyan (the yellow rim and
/// check of [GameItemSlot.selected] stay for "equipped" / "deployed").
class PickedGlow extends StatelessWidget {
  const PickedGlow({super.key, required this.on, required this.child});
  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: on
          ? const [BoxShadow(color: Color(0xDD4FE3FF), blurRadius: 12)]
          : const [],
    ),
    child: child,
  );
}

/// One kit button of an item's action strip: picture above a short word.
/// The full [label] stays the accessible name (v12.10.1, user 2026-10-26:
/// an item's actions sit on one line instead of two rows).
class GameActionTile extends StatelessWidget {
  const GameActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.displayLabel,
    this.primary = false,
    this.image,
  });
  final String label;
  final String? displayLabel;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  /// A generated icon (ui_v13/act_*.webp, v12.12) drawn instead of [icon].
  final String? image;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    // InkWell, not a button: the tile fills its share of the strip.
    final tap = audible(onPressed, cue: buttonCue(label));
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tr(label),
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(32),
          child: Opacity(
            opacity: onPressed == null ? .58 : 1,
            child: UiKitFrame(
              // always a kit pill: a narrow tile squeezes the round caps instead
              // of turning into the paw-bolt panel
              onPressed == null
                  ? 'tab_off'
                  : (primary ? 'btn_yellow' : 'btn_blue'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      image == null
                          ? RasterIcon(icon, size: 28)
                          : Image.asset(
                              image!,
                              width: 30,
                              height: 30,
                              filterQuality: FilterQuality.medium,
                            ),
                      ExcludeSemantics(
                        child: Text(
                          tr(displayLabel ?? label),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            color: primary
                                ? const Color(0xFF202838)
                                : Colors.white,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An item's actions side by side in one row of equal tiles.
class GameActionStrip extends StatelessWidget {
  const GameActionStrip({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: children[i]),
        ],
      ],
    ),
  );
}
