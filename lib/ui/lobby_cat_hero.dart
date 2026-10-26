import 'package:flutter/material.dart';

import '../art/ship_sprite_art.dart';
import '../data/profile.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';

/// The lobby's hero: the selected guardian cat in half-side view standing
/// on the living-room cushion, its feet on a soft shadow (user 2026-10-25:
/// no craft beside it, no floating). Tapping opens the cat/craft selection.
class LobbyCatHero extends StatefulWidget {
  const LobbyCatHero({
    super.key,
    required this.profile,
    required this.size,
    required this.onSelectShip,
  });

  final Profile profile;

  /// Side of the square picture.
  final double size;
  final VoidCallback onSelectShip;

  static const portraits = [
    'assets/art/cats_v11/cheese_side.webp',
    'assets/art/cats_v11/gureum_side.webp',
    'assets/art/cats_v11/kami_side.webp',
  ];

  /// The same cats' faces, cropped for the header's account button.
  static const faces = [
    'assets/art/cats_v11/cheese_face.webp',
    'assets/art/cats_v11/gureum_face.webp',
    'assets/art/cats_v11/kami_face.webp',
  ];

  /// Where each portrait's feet touch the floor, as fractions of its side.
  static const feet = [
    Offset(.529, .951),
    Offset(.523, .922),
    Offset(.518, .932),
  ];

  static Offset feetOf(Profile profile) =>
      feet[profile.selectedShip.clamp(0, 2)];

  @override
  State<LobbyCatHero> createState() => _LobbyCatHeroState();
}

class _LobbyCatHeroState extends State<LobbyCatHero>
    with SingleTickerProviderStateMixin {
  // A slow breath anchored at the feet: alive, but always standing.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ShipSpriteArt.liveMotion(context)) {
      if (!_idle.isAnimating) _idle.repeat(reverse: true);
    } else {
      _idle.stop();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final hull = widget.profile.selectedShip.clamp(0, 2);
    final side = widget.size;
    final foot = LobbyCatHero.feet[hull];
    final anchor = Alignment(foot.dx * 2 - 1, foot.dy * 2 - 1);
    return SizedBox.square(
      dimension: side,
      child: Semantics(
        button: true,
        label: tr('수호묘 선택'),
        child: InkWell(
          key: const Key('lobby-ship-select'),
          onTap: audible(widget.onSelectShip),
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Contact shadow: the feet stand on its upper half.
              Positioned(
                left: side * (foot.dx - .27),
                width: side * .54,
                top: side * (foot.dy - .045),
                height: side * .08,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x66000000),
                    borderRadius: BorderRadius.all(Radius.elliptical(99, 30)),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _idle,
                builder: (context, child) => Transform.scale(
                  alignment: anchor,
                  scaleX: 1 - .012 * Curves.easeInOut.transform(_idle.value),
                  scaleY: 1 + .02 * Curves.easeInOut.transform(_idle.value),
                  child: child,
                ),
                child: Image.asset(
                  LobbyCatHero.portraits[hull],
                  key: Key('lobby-cat-$hull'),
                  width: side,
                  height: side,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
