import 'package:flutter/material.dart';

import '../art/toon_assets.dart';
import '../data/campaign.dart';
import '../l10n/app_language.dart';

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
        child: Align(
          alignment: const Alignment(0, -.62),
          child: Container(
            key: const Key('boss-intro-card'),
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: const Color(0xEE2A1640),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF4D9A), width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x88000000), blurRadius: 12),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13091F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ToonTile('bosses', w, size: 70),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('진공 제국 함대 사령관'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF8DC0),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        tr(bossNames[w]),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(bossTaunts[w]),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFFE9A8),
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
                      Text(
                        tr('흡입대왕 바큠 · 통신'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC79BFF),
                        ),
                      ),
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
