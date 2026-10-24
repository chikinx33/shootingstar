import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

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
