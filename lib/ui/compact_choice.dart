import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../art/raster_assets.dart';
import 'game_ui.dart';

/// A short option cell for 2-3 equal choices placed side by side in one row.
/// Long explanations belong in an info popup; the cell keeps the 48px touch
/// height, the 15px compact label and an optional 14px caption.
class GameCompactChoice extends StatelessWidget {
  const GameCompactChoice({
    super.key,
    required this.title,
    required this.selected,
    required this.onPressed,
    this.caption,
    this.icon,
  });
  final String title;
  final String? caption;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: message("{0}{1}{2}", [
        selected ? '선택 중 · ' : '',
        title,
        caption == null ? '' : '\n${tr(caption!)}',
      ]),
      onTap: audible(onPressed),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: audible(onPressed),
          child: Opacity(
            opacity: selected || enabled ? 1 : .58,
            child: RasterPanel(
              skin: selected ? 1 : 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: GameUi.compactHeight,
                  minWidth: 48,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        RasterIcon(icon!, size: 28),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        tr(title),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: GameUi.compactLabel,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? const Color(0xFFFFE07A)
                              : Colors.white,
                        ),
                      ),
                      if (caption != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          tr(caption!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: GameUi.caption,
                            height: 1.3,
                          ),
                        ),
                      ],
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

/// Equal-width row of compact choices with a centered label above it.
class GameChoiceRow extends StatelessWidget {
  const GameChoiceRow({super.key, required this.children, this.label});
  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              tr(label!),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: GameUi.body,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
