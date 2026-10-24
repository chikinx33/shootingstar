import 'package:flutter/material.dart';

import '../art/ship_sprite_art.dart';
import '../data/houses.dart';
import '../l10n/app_language.dart';

/// The sortie's opening beat: the cat's base pod drops in, then every part
/// and weapon flies in and locks on, and "출격!" flashes. About 1.9 s,
/// never blocks input (the run starts in slow motion until the first touch).
class LaunchAssembly extends StatefulWidget {
  const LaunchAssembly({
    super.key,
    required this.hull,
    required this.hidden,
    required this.assets,
    this.stage,
  });

  /// v12: the house being defended — its owner asks the cat for help.
  final int? stage;
  final int hull;
  final Set<String> hidden;
  final Map<String, String> assets;

  @override
  State<LaunchAssembly> createState() => _LaunchAssemblyState();
}

class _LaunchAssemblyState extends State<LaunchAssembly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.stage == null ? 1900 : 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_run.isAnimating && _run.value == 0) {
      if (ShipSpriteArt.liveMotion(context)) {
        _run.forward();
      } else {
        _run.value = 1; // tests / reduced motion: skip the beat
      }
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _run,
        builder: (context, _) {
          final t = _run.value;
          if (t >= 1 || !ShipSpriteArt.ready) return const SizedBox.shrink();
          final fade = t > .82 ? (1 - t) / .18 : 1.0;
          final word = t > .62 ? ((t - .62) / .12).clamp(0.0, 1.0) : 0.0;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0x99101A2C)),
                if (widget.stage case final stage?)
                  Align(
                    alignment: const Alignment(0, -.78),
                    child: Opacity(
                      opacity: (t * 6).clamp(0.0, 1.0),
                      child: _HousePlea(stage: stage),
                    ),
                  ),
                CustomPaint(
                  painter: _AssemblyPainter(
                    ShipSpriteArt.shipFor(widget.hull),
                    widget.hidden,
                    widget.assets,
                    t,
                  ),
                ),
                Align(
                  alignment: const Alignment(0, .62),
                  child: Transform.scale(
                    scale: .6 + .4 * Curves.easeOutBack.transform(word),
                    child: Opacity(
                      opacity: word,
                      child: Text(
                        tr('출격!'),
                        key: const Key('launch-assembly-word'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFD43D),
                          shadows: [
                            Shadow(color: Color(0xFF3A1A00), blurRadius: 6),
                            Shadow(
                              color: Color(0xFF3A1A00),
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AssemblyPainter extends CustomPainter {
  _AssemblyPainter(this.shipId, this.hidden, this.assets, this.t);
  final String shipId;
  final Set<String> hidden;
  final Map<String, String> assets;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final b = ShipSpriteArt.bounds(shipId);
    final side = (size.shortestSide * .62) / b.longestSide;
    final center = Offset(size.width / 2, size.height * .42) - b.center * side;
    ShipSpriteArt.paint(
      canvas,
      shipId,
      center,
      side,
      time: t * 2,
      hidden: hidden,
      assets: assets,
      // base pod first (0-.25), then each layer in .045 s steps
      assembly: (order) => ((t * 1.9 - order * .07) / .32),
    );
  }

  @override
  bool shouldRepaint(_AssemblyPainter old) => old.t != t;
}

class _HousePlea extends StatelessWidget {
  const _HousePlea({required this.stage});
  final int stage;
  @override
  Widget build(BuildContext context) {
    final house = houseOf(stage);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(houseOwner(stage), width: 72, height: 72),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message('{0} 지키기', [house.place]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD43D),
                    shadows: [Shadow(color: Color(0xFF3A1A00), blurRadius: 6)],
                  ),
                ),
                Text(
                  '“${tr(house.line)}”',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0xFF101A2C), blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
