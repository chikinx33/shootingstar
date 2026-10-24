import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/ui_kit.dart';
import '../l10n/app_language.dart';
import 'game_motion.dart';
import 'skill_cards.dart';

/// v12.8 shared game decoration: ribbon titles, mascots, light rays.
abstract final class Mascot {
  static const victory = '${UiKit.root}cat_victory.webp';
  static const defeat = '${UiKit.root}cat_defeat.webp';
  static const pause = '${UiKit.root}cat_pause.webp';
  static const stats = '${UiKit.root}cat_stats.webp';
  static const supply = '${UiKit.root}cat_supply.webp';
  static const hangar = '${UiKit.root}cat_hangar.webp';
}

/// Big outlined game lettering with a top-to-bottom colour gradient.
class GameLettering extends StatelessWidget {
  const GameLettering(
    this.text, {
    super.key,
    this.size = 26,
    this.colors = const [Color(0xFFFFF6C2), Color(0xFFFFB627)],
    this.outline = const Color(0xFF2A1206),
  });
  final String text;
  final double size;
  final List<Color> colors;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final label = tr(text);
    final style = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 1.15,
    );
    return Stack(
      children: [
        // the outline is a raw RichText: only the fill is a Text widget
        RichText(
          textAlign: TextAlign.center,
          textScaler: MediaQuery.textScalerOf(context),
          text: TextSpan(
            text: label,
            style: DefaultTextStyle.of(context).style.merge(
              style.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * .18
                  ..strokeJoin = StrokeJoin.round
                  ..color = outline,
              ),
            ),
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(bounds),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: style.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// A title on the wide red ribbon: the tails keep their shape, the band
/// stretches to [width] (or the available width), and the text is centred
/// inside the measured red band so it never touches the gold edges.
class RibbonTitle extends StatelessWidget {
  const RibbonTitle(
    this.text, {
    super.key,
    this.width = 300,
    this.height = 58,
    this.size = 23,
  });
  final String text;
  final double width, height, size;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = math.min(width, box.maxWidth.isFinite ? box.maxWidth : width);
      final band = UiKit.ribbonBand;
      final k = height / band.height;
      return SizedBox(
        width: w,
        height: height,
        child: CustomPaint(
          painter: const _RibbonPainter(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              72 * k,
              band.top * k,
              72 * k,
              (band.height - band.bottom) * k,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: GameLettering(
                  text,
                  size: size,
                  colors: const [Colors.white, Color(0xFFFFEDB0)],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();
  @override
  void paint(Canvas canvas, Size size) =>
      UiKit.paint(canvas, 'ribbon', Offset.zero & size);
  @override
  bool shouldRepaint(_RibbonPainter old) => false;
}

/// A mascot pose that bobs gently.
class MascotImage extends StatelessWidget {
  const MascotImage(this.asset, {super.key, this.size = 120, this.sway = 0});
  final String asset;
  final double size, sway;

  @override
  Widget build(BuildContext context) => Bob(
    height: size * .04,
    sway: sway,
    child: Image.asset(
      asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    ),
  );
}

/// Slowly turning light rays (victory, rewards), tinted [color].
class GlowRays extends StatefulWidget {
  const GlowRays({
    super.key,
    this.size = 260,
    this.color = const Color(0xFFFFD447),
    this.opacity = .8,
  });
  final double size, opacity;
  final Color color;

  @override
  State<GlowRays> createState() => _GlowRaysState();
}

class _GlowRaysState extends State<GlowRays>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (liveMotion(context)) {
      if (!_c.isAnimating) _c.repeat(count: 20);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.rotate(
        angle: _c.value * 2 * math.pi,
        child: Opacity(
          opacity: widget.opacity * (.75 + .25 * math.sin(_c.value * 12)),
          child: child,
        ),
      ),
      child: Image.asset(
        SkillCardArt.fx('rays'),
        width: widget.size,
        height: widget.size,
        color: widget.color,
        colorBlendMode: BlendMode.modulate,
      ),
    ),
  );
}

/// One burst of sparkles that plays when it first appears.
class SparkleBurst extends StatelessWidget {
  const SparkleBurst({
    super.key,
    this.size = 220,
    this.count = 10,
    this.delay = 0,
    this.color = Colors.white,
  });
  final double size;
  final int count, delay;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!liveMotion(context)) return SizedBox.square(dimension: size);
    final total = delay + 900;
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: total),
          builder: (context, t, _) {
            final f = ((t * total - delay) / 900).clamp(0.0, 1.0);
            if (f <= 0 || f >= 1) return const SizedBox.shrink();
            final ease = Curves.easeOutCubic.transform(f);
            return Stack(
              children: [
                for (var k = 0; k < count; k++)
                  Positioned(
                    left:
                        size / 2 +
                        math.cos(k * 2 * math.pi / count) * size * .45 * ease -
                        12,
                    top:
                        size / 2 +
                        math.sin(k * 2 * math.pi / count) * size * .45 * ease -
                        12,
                    child: Opacity(
                      opacity: 1 - f,
                      child: Image.asset(
                        SkillCardArt.fx('sparkle'),
                        width: 24,
                        height: 24,
                        color: color,
                        colorBlendMode: BlendMode.modulate,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// v12.9 game title bar (user 2026-10-25: old plain app bars). Transparent
/// over the screen background: round kit buttons left and right, the title
/// in outlined gold game lettering. Still an [AppBar], so back navigation,
/// tooltips and semantics are unchanged.
class GameAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GameAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
  });
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  static const height = 60.0;

  @override
  Size get preferredSize =>
      Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final back =
        leading ??
        (automaticallyImplyLeading && (route?.impliesAppBarDismissal ?? false)
            ? const BackButton()
            : null);
    final heading = title;
    return AppBar(
      toolbarHeight: height,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leadingWidth: 60,
      leading: back == null ? null : Center(child: KitRound(child: back)),
      title: heading is Text && heading.data != null
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: GameLettering(
                heading.data!,
                size: 24,
                colors: const [Colors.white, Color(0xFFFFE08A)],
              ),
            )
          : heading,
      actions: [
        for (final action in actions ?? const <Widget>[])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(child: KitRound(child: action)),
          ),
      ],
      // a soft shade keeps the title readable over any background
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xAA0B1426), Color(0x000B1426)],
          ),
        ),
      ),
      bottom: bottom,
    );
  }
}

/// A round navy kit plate (gold rim) behind a 48px icon control.
class KitRound extends StatelessWidget {
  const KitRound({super.key, required this.child, this.size = 46});
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _RoundPlatePainter(),
    child: SizedBox.square(
      dimension: math.max(size, 48),
      child: Center(child: child),
    ),
  );
}

class _RoundPlatePainter extends CustomPainter {
  const _RoundPlatePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height) - 2;
    UiKit.paint(
      canvas,
      'plate',
      Rect.fromCenter(center: size.center(Offset.zero), width: d, height: d),
    );
  }

  @override
  bool shouldRepaint(_RoundPlatePainter old) => false;
}

/// A kit progress track filled with a yellow pill up to [value] (0..1),
/// growing in when it first appears.
class KitGauge extends StatelessWidget {
  const KitGauge(this.value, {super.key, this.height = 16});
  final double value, height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: Duration(milliseconds: liveMotion(context) ? 500 : 0),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) =>
          CustomPaint(size: Size.infinite, painter: _GaugePainter(t)),
    ),
  );
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    UiKit.paint(canvas, 'track', Offset.zero & size);
    if (value <= 0) return;
    final inner = size.height - 4;
    UiKit.paint(
      canvas,
      'btn_yellow',
      Rect.fromLTWH(2, 2, math.max(inner, (size.width - 4) * value), inner),
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}
