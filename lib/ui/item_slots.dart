import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'reward_flight.dart';

import 'components.dart';

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
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// Overview is image/name/state only. Full text and decisions live in detail.
class GameItemSlot extends StatelessWidget {
  const GameItemSlot({
    super.key,
    required this.title,
    required this.image,
    required this.onTap,
    this.status = '',
    this.selected = false,
    this.rarity = 0,
    this.semanticLabel,
  });
  final String title, status;
  final String? semanticLabel;
  final Widget image;
  final VoidCallback? onTap;
  final bool selected;
  final int rarity;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return RewardTarget(
      name: title,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: onTap != null,
        label: tr(semanticLabel ?? '$title $status'),
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
                      height: 60,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(child: image),
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
                    const SizedBox(height: 6),
                    Text(
                      tr(title),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        tr(status),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, height: 1.2),
                      ),
                    ],
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
