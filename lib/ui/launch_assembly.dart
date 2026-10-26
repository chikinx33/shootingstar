import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/flight_scene_art.dart';
import '../art/ship_sprite_art.dart';
import '../data/houses.dart';
import '../l10n/app_language.dart';
import '../art/ui_kit.dart';
import 'game_decor.dart';
import 'lobby_cat_hero.dart';

/// The sortie's opening (v12.9.3, v12.16). The cat's craft sits complete on
/// the roof of its home (top view) and takes off; clouds stream in and hide
/// the town; above the clouds the craft breaks apart (user 2026-10-27): with
/// a flash every shed part — wings, engines, gear and weapons — flies off in
/// all directions, leaving the base hull and its pilot; then it shrinks to
/// its combat size and spot while the clouds clear, and [onDone] starts the
/// run. The parts come back one by one on level-ups. The battle is held
/// until then.
class SortieIntro extends StatefulWidget {
  const SortieIntro({
    super.key,
    required this.hull,
    required this.hidden,
    this.shed = const {},
    required this.assets,
    required this.target,
    required this.onDone,
    this.stage,
    this.onCue,
  });

  final int hull;
  final Set<String> hidden;

  /// Layers that break away above the clouds (empty: the whole craft stays).
  final Set<String> shed;
  final Map<String, String> assets;

  /// The craft's battle spot in 420-wide view units (cat position minus
  /// camera); its combat size is [shipCombatSide] view units per canvas unit.
  final Offset target;
  final VoidCallback onDone;

  /// The house being defended; null for daily runs.
  final int? stage;

  /// Sound beats: 'launch' on take-off, 'equip' on each attach.
  final void Function(String event)? onCue;

  /// Total length in seconds.
  static const seconds = 4.8;

  /// Beat times (seconds): take-off, clouds full, break-apart, shrink.
  static const takeOff = .5, cloudsFull = 1.9, wingsAt = 2.45;
  static const weaponsAt = 3.2, shrinkAt = 3.8;

  /// When the shed parts burst away and how long they fly.
  static const breakAt = 2.6, breakFor = .7;

  /// Which beat a layer joins: 1 base + pilot, 2 wings + engines, 3 the rest.
  static int beatOf(String id) {
    if (id == 'base' || id == 'canopy' || id == 'flame_base') return 1;
    if (ShipSpriteArt.sidewaysLayer(id)) return 2;
    return 3;
  }

  @override
  State<SortieIntro> createState() => _SortieIntroState();
}

class _SortieIntroState extends State<SortieIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800), // [SortieIntro.seconds]
  );
  static ui.Image? _roof;
  final _cued = <String>{};
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _run.addListener(_beats);
    _run.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      await ShipSpriteArt.load();
      if (_roof == null) {
        final data = await rootBundle.load('assets/art/houses_v12/house_9.jpg');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: 720,
        );
        _roof = (await codec.getNextFrame()).image;
        codec.dispose();
      }
    } catch (_) {
      // the beat still plays over the sky colour
    }
    if (!mounted || _started) return;
    _started = true;
    _run.forward();
  }

  void _beats() {
    final s = _run.value * SortieIntro.seconds;
    void cue(String key, double at, String event) {
      if (s >= at && _cued.add(key)) widget.onCue?.call(event);
    }

    cue('launch', SortieIntro.takeOff, 'launch');
    if (widget.shed.isNotEmpty) {
      cue('break', SortieIntro.breakAt, 'equip');
    } else {
      cue('wings', SortieIntro.wingsAt, 'equip');
      cue('weapons', SortieIntro.weaponsAt, 'equip');
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
          final s = _run.value * SortieIntro.seconds;
          final title = _window(s, 2.0, 2.3, 3.6, 3.9);
          final word = _window(s, 3.35, 3.5, 3.95, 4.15);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                key: const Key('sortie-intro'),
                painter: _SortiePainter(
                  s: s,
                  hull: widget.hull,
                  hidden: widget.hidden,
                  shed: widget.shed,
                  assets: widget.assets,
                  target: widget.target,
                  roof: _roof,
                ),
              ),
              if (widget.stage case final stage? when title > 0)
                Align(
                  alignment: const Alignment(0, -.82),
                  child: Opacity(
                    opacity: title,
                    child: _Resolve(stage: stage, hull: widget.hull),
                  ),
                ),
              if (word > 0)
                Align(
                  alignment: const Alignment(0, .5),
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
          );
        },
      ),
    );
  }

  /// 0 → 1 between [a] and [b], 1 until [c], back to 0 at [d].
  static double _window(double s, double a, double b, double c, double d) {
    if (s <= a || s >= d) return 0;
    if (s < b) return (s - a) / (b - a);
    if (s <= c) return 1;
    return (d - s) / (d - c);
  }
}

double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

class _SortiePainter extends CustomPainter {
  _SortiePainter({
    required this.s,
    required this.hull,
    required this.hidden,
    required this.shed,
    required this.assets,
    required this.target,
    required this.roof,
  });
  final double s;
  final int hull;
  final Set<String> hidden, shed;
  final Map<String, String> assets;
  final Offset target;
  final ui.Image? roof;

  /// The roof's middle on the home map (fractions of house_9.jpg).
  static const _roofSpot = Offset(.5, .34);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shipId = ShipSpriteArt.shipFor(hull);
    final k = size.width / 420;
    final b = ShipSpriteArt.bounds(shipId);
    final big = size.shortestSide * .56 / b.longestSide;
    final park = big * .42;
    final hover = Offset(size.width / 2, size.height * .46);

    // 1. the home map under the roof, receding as the craft climbs
    final climb = _smooth((s - SortieIntro.takeOff) / 1.2);
    final cover = s < SortieIntro.shrinkAt
        ? _smooth((s - 1.1) / (SortieIntro.cloudsFull - 1.1))
        : 1 - _smooth((s - SortieIntro.shrinkAt) / 1.0);
    if (s < SortieIntro.cloudsFull + .1) {
      final art = roof;
      if (art != null) {
        final scale =
            math.max(size.width / art.width, size.height / art.height) *
            (1.55 - .5 * climb);
        final w = art.width * scale, h = art.height * scale;
        // the roof sits under the craft, then drifts down (flying forward)
        final at = Offset(
          hover.dx - _roofSpot.dx * w,
          hover.dy - _roofSpot.dy * h + climb * size.height * .35,
        );
        canvas.drawImageRect(
          art,
          Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble()),
          at & Size(w, h),
          Paint()..filterQuality = FilterQuality.medium,
        );
      } else {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFF7FB3D9),
        );
      }
    }

    // 2. clouds stream in (the boss transition's veil) and later clear
    FlightSceneArt.paintCloudVeil(canvas, size, cover, s * .9);

    // 3. the craft: parked → climbing → assembling → shrinking into place
    final shrink = _smooth((s - SortieIntro.shrinkAt) / 1.0);
    final grown = park + (big - park) * climb;
    final side = s < SortieIntro.shrinkAt
        ? grown
        : big + (shipCombatSide * k - big) * shrink;
    final bob = s > SortieIntro.cloudsFull && s < SortieIntro.shrinkAt
        ? math.sin(s * 5) * size.height * .006
        : 0.0;
    var center = s < SortieIntro.shrinkAt
        ? hover + Offset(0, bob)
        : Offset.lerp(hover, target * k, shrink)!;

    // a hit-stop shake right after each attach (or the break-apart)
    for (final at
        in shed.isNotEmpty
            ? [SortieIntro.breakAt]
            : [SortieIntro.wingsAt, SortieIntro.weaponsAt]) {
      final d = s - at;
      if (d >= 0 && d < .18) {
        final amp = (1 - d / .18) * size.shortestSide * .012;
        center += Offset(math.sin(d * 140) * amp, math.cos(d * 110) * amp);
      }
    }

    final breaking = shed.isNotEmpty;
    // v12.16: complete until the break, then the shed parts fly off
    // outward (attach progress runs back from 1 to 0); without a shed set
    // the classic three-beat assembly plays.
    double attach(String id) => breaking
        ? (shed.contains(id)
              ? 1 - (s - SortieIntro.breakAt) / SortieIntro.breakFor
              : 1)
        : switch (SortieIntro.beatOf(id)) {
            1 => 1,
            2 => (s - (SortieIntro.wingsAt - .22)) / .22,
            _ => (s - (SortieIntro.weaponsAt - .22)) / .22,
          };
    double flashOf(double at) {
      final d = s - at;
      return d < 0 || d > .3 ? 0 : 1 - d / .3;
    }

    final flash = breaking
        ? flashOf(SortieIntro.breakAt)
        : math.max(
            flashOf(SortieIntro.wingsAt),
            flashOf(SortieIntro.weaponsAt),
          );
    final fade = s > SortieIntro.seconds - .15
        ? ((SortieIntro.seconds - s) / .15).clamp(0.0, 1.0)
        : 1.0;

    // its shadow on the roof shrinks away as it climbs
    if (s < SortieIntro.cloudsFull) {
      final lift = climb * size.height * .08;
      canvas.saveLayer(
        null,
        Paint()
          ..colorFilter = ColorFilter.mode(
            const Color(0xFF0B1420).withValues(alpha: .38 * (1 - climb)),
            BlendMode.srcIn,
          ),
      );
      ShipSpriteArt.paint(
        canvas,
        shipId,
        center + Offset(lift * .4, lift + park * .05) - b.center * side,
        side * (1 - .25 * climb),
        hidden: hidden,
        assets: assets,
        attach: attach,
      );
      canvas.restore();
    }
    ShipSpriteArt.paint(
      canvas,
      shipId,
      center - b.center * side,
      side,
      time: s,
      hidden: hidden,
      assets: assets,
      opacity: fade,
      attach: attach,
      flash: flash,
    );

    // impact sparks where the parts locked on (or broke away)
    for (final (at, beat)
        in breaking
            ? [(SortieIntro.breakAt, 0)]
            : [(SortieIntro.wingsAt, 2), (SortieIntro.weaponsAt, 3)]) {
      final d = s - at;
      if (d < 0 || d > .35) continue;
      final grow = Curves.easeOutCubic.transform(d / .35);
      for (final point in ShipSpriteArt.layerPoints(
        shipId,
        (id) => beat == 0 ? shed.contains(id) : SortieIntro.beatOf(id) == beat,
        hidden: hidden,
      )) {
        ShipSpriteArt.paintFx(
          canvas,
          'hit_spark',
          center + (point - b.center) * side,
          side * (.18 + .32 * grow),
          d * 6,
          opacity: 1 - d / .35,
        );
      }
      ShipSpriteArt.paintFx(
        canvas,
        'level_burst',
        center,
        side * (.6 + 1.1 * grow),
        0,
        opacity: (1 - d / .35) * .7,
      );
    }
  }

  @override
  bool shouldRepaint(_SortiePainter old) =>
      old.s != s || old.roof != roof || old.target != target;
}

/// "{House} 지키기" and the cat's own resolve for the people living there
/// (humans never ask the cats for help, user 2026-10-25).
class _Resolve extends StatelessWidget {
  const _Resolve({required this.stage, required this.hull});
  final int stage, hull;
  @override
  Widget build(BuildContext context) {
    final house = houseOf(stage);
    // outlined lettering on a kit plate: readable over white clouds
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: UiKitFrame(
        'plate',
        padding: const EdgeInsets.fromLTRB(14, 8, 22, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              LobbyCatHero.faces[hull.clamp(0, LobbyCatHero.faces.length - 1)],
              width: 56,
              height: 56,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameLettering(message('{0} 지키기', [house.place]), size: 22),
                  Text(
                    '“${tr(house.line)}”',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
