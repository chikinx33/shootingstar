import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_motion.dart';

import '../art/raster_assets.dart';
import 'game_decor.dart';
import 'game_ui.dart';
import 'game_pages.dart';

/// Gold header and persistent close control, with fixed pages for long content.
/// No modal scrolling or reduced text; all actions stay reachable by page buttons.
class GameDialog extends StatelessWidget {
  const GameDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.closeLabel = '닫기',
  });
  final String title, closeLabel;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return PopIn(
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        constraints: const BoxConstraints(maxWidth: 440),
        child: RasterPanel(
          key: const Key('game-dialog-panel'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RasterPanel(
                skin: 6,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const SizedBox(width: 56),
                      Expanded(
                        child: Semantics(
                          header: true,
                          label: tr(title),
                          excludeSemantics: true,
                          child: Text(
                            tr(title),
                            style: const TextStyle(
                              fontSize: 28,
                              height: 1.25,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Color(0xFF172031),
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),

                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      KitCloseButton(
                        tooltip: closeLabel,
                        onPressed: audible(
                          () => Navigator.of(context).pop(),
                          cue: 'back',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: GamePages(
                    key: const Key('game-dialog-pages'),
                    shrinkWrap: true,
                    centerContent: true,
                    // v12.8: clear of the kit panel's gold rim and paw bolts
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DefaultTextStyle(
                          // This build context is above Dialog's Material. Inheriting
                          // DefaultTextStyle here can pick Flutter's red error style.
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                fontSize: GameUi.body,
                                height: 1.4,
                                decoration: TextDecoration.none,
                              ),
                          child: child,
                        ),
                        if (actions.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            Center(child: actions[i]),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameChoiceTile extends StatelessWidget {
  const GameChoiceTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });
  final String title, description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label: message("{0}{1}\n{2}", [
        selected ? '선택 중 · ' : '',
        title,
        description,
      ]),
      onTap: audible(onPressed),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: audible(onPressed),
          child: Opacity(
            opacity: selected || onPressed != null ? 1 : .58,
            child: RasterPanel(
              skin: selected ? 1 : 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 88),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RasterIcon(icon, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              message("{0}{1}", [
                                selected ? '선택 중 · ' : '',
                                title,
                              ]),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),

                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr(description),
                              style: const TextStyle(fontSize: GameUi.body),

                              textAlign: TextAlign.center,
                            ),
                          ],
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

class GameSectionTitle extends StatelessWidget {
  const GameSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      header: true,
      label: tr(text),
      excludeSemantics: true,
      child: Text(
        tr(text),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),

        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Costs remain next to the decision rather than becoming tiny button copy.
class GameCostLine extends StatelessWidget {
  const GameCostLine(this.text, {super.key, this.icon = Icons.hexagon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RasterIcon(icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr(text),
              style: const TextStyle(fontSize: GameUi.body),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
