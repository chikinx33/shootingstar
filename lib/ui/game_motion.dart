import 'dart:math' as math;

import 'package:flutter/material.dart';

/// v12.8 shared screen motion (user 2026-10-25: pages felt like clicking
/// website buttons). Items arrive one after another, panels pop in, numbers
/// count up. Everything respects reduced motion and plays once.
bool liveMotion(BuildContext context) =>
    TickerMode.valuesOf(context).enabled &&
    !MediaQuery.disableAnimationsOf(context);

/// Slides [child] up into place with a small pop, [index] steps after the
/// first item of its group.
class StaggerIn extends StatelessWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.step = 55,
    this.distance = 26,
  });
  final int index;
  final Widget child;
  final int step;
  final double distance;

  @override
  Widget build(BuildContext context) {
    if (!liveMotion(context)) return child;
    final delay = math.min(index, 14) * step;
    final total = delay + 380;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) {
        final local = ((t * total - delay) / 380).clamp(0.0, 1.0);
        final ease = Curves.easeOutBack.transform(local);
        return Opacity(
          opacity: Curves.easeOut.transform(local),
          child: Transform.translate(
            offset: Offset(0, distance * (1 - ease)),
            child: Transform.scale(scale: .92 + .08 * ease, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

/// A panel that drops in with a bounce, for dialogs and overlays.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    if (!liveMotion(context)) return child;
    final total = delay + 420;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) {
        final local = ((t * total - delay) / 420).clamp(0.0, 1.0);
        return Opacity(
          opacity: (local * 2.5).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: .82 + .18 * Curves.easeOutBack.transform(local),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// A number that counts up from zero when it first appears.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = 900,
    this.delay = 0,
  });
  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final int duration, delay;

  @override
  Widget build(BuildContext context) {
    final finalText = Text(
      format(value),
      style: style,
      textAlign: TextAlign.center,
    );
    if (!liveMotion(context)) return finalText;
    final total = delay + duration;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, _) {
        if (t >= 1) return finalText;
        final local = ((t * total - delay) / duration).clamp(0.0, 1.0);
        // The final value is the real (laid-out, readable) text; the
        // running count is painted over it until it arrives.
        final base = DefaultTextStyle.of(context).style.merge(style);
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(opacity: 0, child: finalText),
            RichText(
              textAlign: TextAlign.center,
              textScaler: MediaQuery.textScalerOf(context),
              text: TextSpan(
                text: format(value * Curves.easeOutCubic.transform(local)),
                style: base,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A gentle endless bob (or [sway]) for mascots and displayed items.
class Bob extends StatefulWidget {
  const Bob({
    super.key,
    required this.child,
    this.height = 6,
    this.sway = 0,
    this.period = 2200,
  });
  final Widget child;
  final double height, sway;
  final int period;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.period),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A bounded loop: screens and tests can still settle.
    if (liveMotion(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true, count: 60);
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = Curves.easeInOut.transform(_c.value);
      return Transform.translate(
        offset: Offset(0, -widget.height * t),
        child: Transform.rotate(angle: widget.sway * (t - .5), child: child),
      );
    },
    child: widget.child,
  );
}
