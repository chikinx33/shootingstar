import 'dart:math' as math;
import 'dart:ui' as ui;

/// Animated light, with a soft cross-section rather than an outlined capsule.
/// Gradient passes avoid a large per-frame blur/saveLayer on mobile.
abstract final class LaserBeam {
  static double envelope(double age, double duration) {
    if (duration <= 0 || age < 0 || age >= duration) return 0;
    final attack = math.min(.12, duration * .28);
    final release = math.min(.075, duration * .20);
    if (age < attack) {
      final t = age / attack;
      return .015 + .985 * t * t * (3 - 2 * t);
    }
    if (duration - age < release) {
      final t = (duration - age) / release;
      return t * t;
    }
    return 1;
  }

  static void paint(
    ui.Canvas c,
    ui.Offset from,
    ui.Offset to,
    double width, {
    required double age,
    required double duration,
    bool hostile = false,
    bool reduced = false,
  }) {
    final power = envelope(age, duration), delta = to - from;
    if (power <= 0 || width <= 0 || delta.distance < .01) return;
    final normal = ui.Offset(-delta.dy, delta.dx) / delta.distance;
    final fullWidth = width * power;
    final release = math.min(.075, duration * .20);
    final fade = ((duration - age) / release).clamp(0.0, 1.0);
    final color = hostile
        ? const ui.Color(0xffff674b)
        : const ui.Color(0xff48dfff);
    void light(double span, List<ui.Color> colors, List<double> stops) {
      final side = normal * span * .5;
      final p = ui.Path()..moveTo(from.dx, from.dy);
      for (final at in [
        from + delta * .025 - side,
        to - delta * .02 - side * .65,
        to,
        to - delta * .02 + side * .65,
        from + delta * .025 + side,
      ]) {
        p.lineTo(at.dx, at.dy);
      }
      p.close();
      c.drawPath(
        p,
        ui.Paint()
          ..shader = ui.Gradient.linear(
            from - side,
            from + side,
            colors,
            stops,
          ),
      );
    }

    if (!reduced) {
      light(
        fullWidth * 1.45,
        [
          color.withValues(alpha: 0),
          color.withValues(alpha: .08 * fade),
          color.withValues(alpha: .32 * fade),
          color.withValues(alpha: .08 * fade),
          color.withValues(alpha: 0),
        ],
        const [0, .25, .5, .75, 1],
      );
    }
    light(
      fullWidth * .62,
      [
        color.withValues(alpha: 0),
        color.withValues(alpha: .65 * fade),
        color.withValues(alpha: .85 * fade),
        color.withValues(alpha: .65 * fade),
        color.withValues(alpha: 0),
      ],
      const [0, .32, .5, .68, 1],
    );
    const white = ui.Color(0xfff2fdff);
    light(
      math.max(.4, fullWidth * .16),
      [
        white.withValues(alpha: 0),
        white.withValues(alpha: .95 * fade),
        white.withValues(alpha: .95 * fade),
        white.withValues(alpha: 0),
      ],
      const [0, .32, .68, 1],
    );
    if (!reduced) {
      final radius = math.min(14.0, fullWidth * .30 + 1);
      c.drawCircle(
        from,
        radius,
        ui.Paint()
          ..shader = ui.Gradient.radial(
            from,
            radius,
            [
              white.withValues(alpha: .85 * fade),
              color.withValues(alpha: .3 * fade),
              color.withValues(alpha: 0),
            ],
            const [0, .25, 1],
          ),
      );
    }
  }
}
