import '../l10n/app_language.dart';

import 'package:flutter/material.dart';

import 'game_ui.dart';

/// Compact identity and state, with artwork kept secondary to useful data.
class GameDetailHeader extends StatelessWidget {
  const GameDetailHeader({
    super.key,
    required this.image,
    required this.title,
    required this.status,
    this.trailing,
  });
  final Widget image;
  final String title, status;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox.square(dimension: 72, child: image),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: ValueKey('$title$status'),
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(title),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),

                    textAlign: TextAlign.center,
                  ),
                  Text(
                    tr(status),
                    style: const TextStyle(
                      fontSize: GameUi.caption,
                      color: Color(0xFFB9D0DF),
                    ),

                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Secondary management cells. Purchase/upgrade decisions use GameActionButton.
class GameDetailTools extends StatelessWidget {
  const GameDetailTools({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: children[i] is GameActionButton
                ? Center(child: children[i])
                : children[i],
          ),
        ],
      ],
    );
  }
}
