import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/ship_sprite_art.dart';
import '../data/profile.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';

/// The lobby's hero: the selected guardian cat in half-side view standing
/// in the living room, with its equipped airframe (top view) beside it.
/// Tapping opens the cat/craft selection.
class LobbyCatHero extends StatefulWidget {
  const LobbyCatHero({
    super.key,
    required this.profile,
    required this.width,
    required this.height,
    required this.onSelectShip,
  });

  final Profile profile;
  final double width, height;
  final VoidCallback onSelectShip;

  static const portraits = [
    'assets/art/cats_v11/cheese_side.png',
    'assets/art/cats_v11/gureum_side.png',
    'assets/art/cats_v11/kami_side.png',
  ];

  @override
  State<LobbyCatHero> createState() => _LobbyCatHeroState();
}

class _LobbyCatHeroState extends State<LobbyCatHero>
    with SingleTickerProviderStateMixin {
  // A slow idle bob so the cat feels alive without distracting.
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
    final p = widget.profile;
    final hull = p.selectedShip.clamp(0, 2);
    final catSize = math.min(widget.width, widget.height * .78);
    final shipSize = catSize * .52;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Semantics(
        button: true,
        label: tr('수호묘 선택'),
        child: InkWell(
          key: const Key('lobby-ship-select'),
          onTap: audible(widget.onSelectShip),
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // soft floor shadow under the cat
              Positioned(
                bottom: widget.height * .08,
                child: Container(
                  width: catSize * .62,
                  height: catSize * .1,
                  decoration: BoxDecoration(
                    color: const Color(0x55000000),
                    borderRadius: BorderRadius.circular(catSize),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _idle,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    0,
                    -4 * Curves.easeInOut.transform(_idle.value),
                  ),
                  child: child,
                ),
                child: Align(
                  alignment: const Alignment(-.2, .25),
                  child: Image.asset(
                    LobbyCatHero.portraits[hull],
                    key: Key('lobby-cat-$hull'),
                    width: catSize,
                    height: catSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(1, -1),
                child: SizedBox(
                  width: shipSize,
                  height: shipSize,
                  child: ShipSprite(
                    hull: hull,
                    loadout: p.moduleLoadout,
                    assets: p.shipLayerAssets,
                    semanticLabel: tr('장착한 기체'),
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
