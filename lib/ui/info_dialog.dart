import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'components.dart';
import '../art/game_icons.dart';

/// v12.4.3 (user 2026-10-25): screens keep only what the player needs on one
/// page. Secondary explanations open here on demand instead of page arrows.
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  List<Widget> Function(BuildContext dialog)? actions,
}) => showDialog<void>(
  context: context,
  builder: (dialog) => GameDialog(
    title: title,
    actions: actions?.call(dialog) ?? const [],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  ),
);

/// One short explanation paragraph inside an info popup.
class InfoText extends StatelessWidget {
  const InfoText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Text(
      tr(text),
      style: const TextStyle(fontSize: GameUi.body),
      textAlign: TextAlign.center,
    );
  }
}

/// 48px AppBar control that opens a screen's secondary information.
class InfoAction extends StatelessWidget {
  const InfoAction({super.key, required this.onPressed, this.label = '자세히'});
  final VoidCallback onPressed;
  final String label;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return IconButton(
      tooltip: tr(label),
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: const RasterIcon(Icons.help_outline, size: 32),
      onPressed: audible(onPressed),
    );
  }
}

/// Fixed spacers shared by the one-page screens and their info popups.
const gap8 = SizedBox(height: 8),
    gap12 = SizedBox(height: 12),
    gap16 = SizedBox(height: 16);

/// v12.15 rule line for '?' popups: a picture and one short line, so rules
/// read as a game's help page instead of a paragraph.
class RuleLine extends StatelessWidget {
  const RuleLine(this.asset, this.text, {super.key});
  final String asset, text;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GameIconImage(asset, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(text),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: GameUi.body,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
