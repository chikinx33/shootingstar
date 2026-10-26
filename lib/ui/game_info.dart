import '../l10n/app_language.dart';

import 'package:flutter/material.dart';

import 'game_ui.dart';

/// v12.14 labelled information (user 2026-10-26: text must read as organised
/// game info, not a stack of same-white lines). Every value carries a label,
/// facts sit in their own tiles instead of one "a · b · c" string, and the
/// tone colour tells what kind of information it is.
enum GameTone {
  /// Key facts: names, levels, owned counts.
  gold(Color(0xFFFFD447)),

  /// Neutral rules and numbers.
  sky(Color(0xFF73D8FF)),

  /// Threats, costs that hurt, warnings.
  danger(Color(0xFFFF7A6B)),

  /// Rewards, unlocks, bonuses.
  good(Color(0xFF7DE08A)),

  /// Hints and secondary notes.
  muted(Color(0xFFB4C2D6));

  const GameTone(this.color);
  final Color color;
}

/// Dark inset that groups one piece of information inside a panel.
class GameInset extends StatelessWidget {
  const GameInset({
    super.key,
    required this.child,
    this.tone,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 10),
  });
  final Widget child;
  final GameTone? tone;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xCC0B1830),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: (tone?.color ?? const Color(0xFF5B7AA6)).withValues(alpha: .55),
        width: 2,
      ),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// A small coloured label pill: "노리는 보스", "집사", "공략".
class GameTag extends StatelessWidget {
  const GameTag(this.text, {super.key, this.tone = GameTone.gold});
  final String text;
  final GameTone tone;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: Text(
          tr(text),
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tone.color,
            fontSize: GameUi.caption,
            height: 1.35,
            fontWeight: FontWeight.w900,
            shadows: const [],
          ),
        ),
      ),
    );
  }
}

/// One labelled value of a [GameFactRow].
class GameFact {
  const GameFact(this.label, this.value, {this.tone = GameTone.sky});
  final String label, value;
  final GameTone tone;
}

/// Facts side by side in equal tiles: label above, big value below. Replaces
/// strings such as "3분 · 보스 1회 · 위험도 1".
class GameFactRow extends StatelessWidget {
  const GameFactRow(this.facts, {super.key});
  final List<GameFact> facts;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GameInset(
                tone: facts[i].tone,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr(facts[i].label),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: facts[i].tone.color,
                          fontSize: GameUi.caption,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr(facts[i].value),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled group: tag on top, then its lines. [lead] is the main line
/// (white, bold); [detail] reads as a softer explanation.
class GameInfoBlock extends StatelessWidget {
  const GameInfoBlock({
    super.key,
    required this.label,
    this.lead,
    this.detail,
    this.children = const [],
    this.tone = GameTone.gold,
  });
  final String label;
  final String? lead, detail;
  final List<Widget> children;
  final GameTone tone;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return GameInset(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: GameTag(label, tone: tone)),
          if (lead != null) ...[
            const SizedBox(height: 4),
            Text(
              tr(lead!),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              tr(detail!),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTone.muted.color,
                fontSize: GameUi.caption + 1,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// A character's own words in a cream speech bubble, so flavour text never
/// looks like a rule or a stat. [speaker] names who says it.
class GameQuote extends StatelessWidget {
  const GameQuote(this.text, {super.key, this.speaker});
  final String text;
  final String? speaker;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A2410), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (speaker != null)
              Text(
                tr(speaker!),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB2541A),
                  fontSize: GameUi.caption,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                  shadows: [],
                ),
              ),
            Text(
              '“${tr(text)}”',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4A2A12),
                fontSize: GameUi.body,
                height: 1.35,
                fontWeight: FontWeight.w800,
                shadows: [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet one-line hint below the facts ("집을 지키면 다음 집이 열립니다").
class GameHint extends StatelessWidget {
  const GameHint(this.text, {super.key, this.tone = GameTone.muted});
  final String text;
  final GameTone tone;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Text(
      tr(text),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: tone.color,
        fontSize: GameUi.caption + 1,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// One reward amount as a chip: picture (when the item has one), name and
/// amount. Rewards read as items, not as a "20 츄르 · 별가루 2" sentence.
class GameRewardChip extends StatelessWidget {
  const GameRewardChip(this.name, this.amount, {super.key, this.image});
  final String name;
  final int amount;
  final String? image;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF14284A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF7FA6D6), width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(image == null ? 12 : 4, 2, 12, 2),
        // a chip in a narrow cell shrinks as one piece instead of overflowing
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null) ...[
                Image.asset(
                  image!,
                  width: 30,
                  height: 30,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                tr(name),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GameTone.muted.color,
                  fontSize: GameUi.caption,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$amount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
