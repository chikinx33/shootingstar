import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../art/raster_assets.dart';

/// Canonical logical-pixel sizes. See docs/UI_DESIGN_SYSTEM.md before UI work.
abstract final class GameUi {
  static const primaryHeight = 72.0;
  static const secondaryHeight = 64.0;
  static const actionMaxWidth = 264.0;
  static const primaryLabel = 22.0;
  static const secondaryLabel = 20.0;
  static const primaryIcon = 36.0;
  static const secondaryIcon = 32.0;

  /// A picture inside a button is drawn large (user 2026-10-25): it fills
  /// the panel's height instead of sitting beside the text as a small glyph.
  static const primaryImage = 60.0;
  static const secondaryImage = 50.0;
  static const buttonHeight = 60.0;
  static const buttonLabel = 18.0;
  static const compactHeight = 48.0;
  static const compactLabel = 15.0;
  static const body = 16.0;
  static const caption = 14.0;
  static const minimumLabel = 12.0;
  static const navigationIcon = 44.0;
  static const navigationLabel = 14.0;

  /// Only for narrow inventory/research cells, never a screen's main action.
  static ButtonStyle get compactButton => FilledButton.styleFrom(
    minimumSize: const Size(48, compactHeight),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    textStyle: const TextStyle(
      fontFamily: 'NotoSansKR',
      fontSize: compactLabel,
      fontWeight: FontWeight.w900,
    ),
  );
}

/// A bounded, visibly thick action. Text wraps and grows instead of shrinking.
/// The minimum height belongs to the painted panel, not an invisible hit area.
class GameActionButton extends StatelessWidget {
  const GameActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.displayLabel,
    this.icon,
    this.primary = false,
    this.panelColor,
    this.leading,
    this.image,
  });

  final String label;

  /// Optional concise visible wording; the full label remains accessible.
  final String? displayLabel;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final Color? panelColor;
  final Widget? leading;

  /// An illustration asset shown before the label at [GameUi.primaryImage]
  /// or [GameUi.secondaryImage]; the panel's padding shrinks to fit it.
  final String? image;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Align(
      alignment: Alignment.center,
      widthFactor: 1,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: GameUi.actionMaxWidth),
        child: FilledButton(
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
              color: panelColor,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: primary
                      ? GameUi.primaryHeight
                      : GameUi.secondaryHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: image == null ? 14 : 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (image != null) ...[
                        Image.asset(
                          image!,
                          width: primary
                              ? GameUi.primaryImage
                              : GameUi.secondaryImage,
                          height: primary
                              ? GameUi.primaryImage
                              : GameUi.secondaryImage,
                          filterQuality: FilterQuality.medium,
                        ),
                        const SizedBox(width: 10),
                      ] else if (leading != null || icon != null) ...[
                        leading ??
                            RasterIcon(
                              icon!,
                              size: primary
                                  ? GameUi.primaryIcon
                                  : GameUi.secondaryIcon,
                            ),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: Semantics(
                          label: tr(label),
                          excludeSemantics: true,
                          child: Text(
                            tr(displayLabel ?? label),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: primary
                                  ? GameUi.primaryLabel
                                  : GameUi.secondaryLabel,
                              height: 1.25,
                              fontWeight: FontWeight.w900,
                              color: primary
                                  ? const Color(0xFF202838)
                                  : Colors.white,
                              shadows: primary
                                  ? const [
                                      Shadow(
                                        color: Color(0x88FFFFFF),
                                        offset: Offset(0, 1),
                                      ),
                                    ]
                                  : const [
                                      Shadow(
                                        color: Color(0xFF172031),
                                        offset: Offset(0, 2),
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
        ),
      ),
    );
  }
}
