import 'package:flutter/material.dart';

import '../art/toon_assets.dart';
import '../data/campaign.dart';
import '../l10n/app_language.dart';
import 'game_decor.dart';
import 'game_info.dart';

/// Slides in when a Vacuum Empire commander arrives: portrait, name and a
/// one-line taunt. Never takes input, so steering is not interrupted.
class BossIntroCard extends StatefulWidget {
  const BossIntroCard({super.key, required this.world, required this.arrival});

  final int world;

  /// Changes on every arrival so the card replays for each commander.
  final int arrival;

  @override
  State<BossIntroCard> createState() => _BossIntroCardState();
}

class _BossIntroCardState extends State<BossIntroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _show = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.arrival > 0) _show.forward();
  }

  @override
  void didUpdateWidget(BossIntroCard old) {
    super.didUpdateWidget(old);
    if (old.arrival != widget.arrival && widget.arrival > 0) {
      _show.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final w = widget.world.clamp(0, bossNames.length - 1);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _show,
        builder: (context, child) {
          final t = _show.value;
          if (t <= 0 || t >= 1) return const SizedBox.shrink();
          // in 0-.12, hold, out .88-1
          final slide = t < .12
              ? Curves.easeOutBack.transform(t / .12)
              : t > .88
              ? 1 - Curves.easeIn.transform((t - .88) / .12)
              : 1.0;
          return Opacity(
            opacity: slide.clamp(0, 1),
            child: Transform.translate(
              offset: Offset((1 - slide) * -220, 0),
              child: child,
            ),
          );
        },
        // v12.15 (mobile boss warning): the fortress itself, big, over a
        // red "보스 출현" tag, its name in outlined lettering and the taunt
        // in a speech bubble.
        child: Align(
          alignment: const Alignment(0, -.55),
          child: Container(
            key: const Key('boss-intro-card'),
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              color: const Color(0xEE2A1640),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF4D9A), width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x88000000), blurRadius: 12),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GameTag('보스 출현 · 진공 제국 사령관', tone: GameTone.danger),
                const SizedBox(height: 4),
                ToonTile('bosses', w, size: 112),
                GameLettering(
                  bossNames[w],
                  size: 24,
                  colors: const [Color(0xFFFFE3F0), Color(0xFFFF5FA8)],
                ),
                const SizedBox(height: 6),
                GameQuote(bossTaunts[w]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// After each commander falls, the Vacuum King cuts in on the comms — a
/// shadowy silhouette and one grumble. Never takes input.
class VacuumKingTransmission extends StatefulWidget {
  const VacuumKingTransmission({super.key, required this.defeat});

  /// Changes on every defeat so the transmission replays.
  final int defeat;

  static const lines = [
    '흐으읍… 고작 고양이 따위가?!',
    '내 함대를 감히… 다음 사령관을 보내라!',
    '봉인이 버티는 것도 지금뿐이다, 털뭉치들!',
    '크윽… 청소기 소리가 무섭지 않단 말이냐?',
  ];

  @override
  State<VacuumKingTransmission> createState() => _VacuumKingTransmissionState();
}

class _VacuumKingTransmissionState extends State<VacuumKingTransmission>
    with SingleTickerProviderStateMixin {
  late final AnimationController _show = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  @override
  void didUpdateWidget(VacuumKingTransmission old) {
    super.didUpdateWidget(old);
    if (old.defeat != widget.defeat && widget.defeat > 0) {
      _show.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final line = VacuumKingTransmission
        .lines[widget.defeat % VacuumKingTransmission.lines.length];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _show,
        builder: (context, child) {
          final t = _show.value;
          if (t <= 0 || t >= 1) return const SizedBox.shrink();
          final fade = t < .1 ? t / .1 : (t > .85 ? (1 - t) / .15 : 1.0);
          return Opacity(opacity: fade.clamp(0, 1), child: child);
        },
        child: Align(
          alignment: const Alignment(0, .55),
          child: Container(
            key: const Key('vacuum-king-transmission'),
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: const Color(0xEE12061E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF9B4DFF), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // a shadowy, flickering silhouette: the King never shows fully
                Opacity(
                  opacity: .85,
                  child: Image.asset(
                    'assets/art/story_v11/vacuum_king.webp',
                    width: 64,
                    height: 64,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GameTag('흡입대왕 바큠 · 통신', tone: GameTone.danger),
                      Text(
                        tr(line),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
