import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// v12 projectiles are light, not pictures (user decision 2026-10-24):
/// glowing beans, diamonds, ovals, crescents, beams, electric arcs and
/// lightning. Still shapes are baked once per (shape, colour, size) into a
/// bitmap and blitted, so hundreds of bullets stay cheap on the web renderer.
enum GlowShape { bean, diamond, oval, orb, crescent, star }

abstract final class GlowShots {
  // Player family: warm gold / cyan. Enemy family: hot pink / violet.
  static const gold = Color(0xFFFFD84A);
  static const cyan = Color(0xFF5BE9FF);
  static const pink = Color(0xFFFF4FA3);
  static const violet = Color(0xFFB45BFF);
  static const orange = Color(0xFFFF8A3D);
  static const green = Color(0xFF7DFF8A);

  /// v12.14 (user 2026-10-26: the web build stalled under heavy fire): each
  /// (shape, colour, size) glow is baked once into a bitmap and every bullet
  /// is a plain image blit. Replaying a recorded picture re-ran its blur for
  /// every bullet, and faded bullets each opened a saveLayer.
  static final _cache = <(GlowShape, int, int), ui.Image>{};
  static int get cachedPictures => _cache.length;

  /// The glow reaches past the shape: wide stroke plus blur on each side.
  static const _extent = 2.6;

  /// Bitmaps are baked at this many pixels per logical pixel (phones are
  /// 2–3x); large sizes are baked coarser to bound memory.
  static double _rasterScale(double s) => s > 80 ? 1.5 : 2.5;

  static final _blit = Paint()..filterQuality = FilterQuality.low;

  /// Draws [shape] centred at [at], [size] px long, pointing along [angle]
  /// (radians, 0 = up the screen).
  static void paint(
    Canvas canvas,
    GlowShape shape,
    Offset at,
    double size,
    Color color, {
    double angle = 0,
    double opacity = 1,
  }) {
    if (opacity <= 0) return;
    final bucket = (size.clamp(4, 160) / 2).round();
    final key = (shape, color.toARGB32(), bucket);
    final image = _cache[key] ?? _bake(key, shape, bucket * 2.0, color);
    final box = bucket * 2.0 * _extent;
    final paint = opacity >= 1
        ? _blit
        : (Paint()
            ..filterQuality = FilterQuality.low
            ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0)));
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    if (angle == 0) {
      canvas.drawImageRect(
        image,
        src,
        Rect.fromCenter(center: at, width: box, height: box),
        paint,
      );
      return;
    }
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawImageRect(
      image,
      src,
      Rect.fromCenter(center: Offset.zero, width: box, height: box),
      paint,
    );
    canvas.restore();
  }

  static ui.Image _bake(
    (GlowShape, int, int) key,
    GlowShape shape,
    double s,
    Color color,
  ) {
    if (_cache.length > 160) _cache.remove(_cache.keys.first)!.dispose();
    final scale = _rasterScale(s);
    final side = (s * _extent * scale).ceil();
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder)
      ..scale(scale)
      ..translate(s * _extent / 2, s * _extent / 2);
    _record(c, shape, s, color);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(side, side);
    picture.dispose();
    return _cache[key] = image;
  }

  static Path _shapePath(GlowShape shape, double s) {
    final h = s / 2;
    switch (shape) {
      case GlowShape.bean:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s * .42, height: s),
            Radius.circular(s * .21),
          ),
        );
      case GlowShape.diamond:
        return Path()
          ..moveTo(0, -h)
          ..lineTo(h * .55, 0)
          ..lineTo(0, h)
          ..lineTo(-h * .55, 0)
          ..close();
      case GlowShape.oval:
        return Path()..addOval(
          Rect.fromCenter(center: Offset.zero, width: s * .62, height: s),
        );
      case GlowShape.orb:
        return Path()
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: h * .8));
      case GlowShape.crescent:
        final outer = Path()
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: h));
        final bite = Path()
          ..addOval(
            Rect.fromCircle(center: Offset(0, h * .42), radius: h * .86),
          );
        return Path.combine(PathOperation.difference, outer, bite);
      case GlowShape.star:
        final p = Path();
        for (var i = 0; i < 8; i++) {
          final r = i.isEven ? h : h * .38;
          final a = i * math.pi / 4;
          final pt = Offset(math.sin(a) * r, -math.cos(a) * r);
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        return p..close();
    }
  }

  static void _record(Canvas c, GlowShape shape, double s, Color color) {
    final path = _shapePath(shape, s);
    // soft outer glow (two widened passes, cheaper than a blur per bullet)
    c.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .42
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .16),
    );
    c.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .16
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawPath(path, Paint()..color = color);
    // hot white core
    c.save();
    c.scale(.5);
    c.drawPath(path, Paint()..color = Colors.white.withValues(alpha: .92));
    c.restore();
  }

  /// A straight glowing beam (lasers): wide soft halo, bright core.
  static void beam(
    Canvas canvas,
    Offset from,
    Offset to,
    double width,
    Color color, {
    double opacity = 1,
  }) {
    // soft halo as two faint widened strokes: a per-call blur stalls the web
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: .12 * opacity)
        ..strokeWidth = width * 3.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: .22 * opacity)
        ..strokeWidth = width * 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: .85 * opacity)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = Colors.white.withValues(alpha: .9 * opacity)
        ..strokeWidth = width * .36
        ..strokeCap = StrokeCap.round,
    );
  }

  /// A jagged lightning / electric arc between two points. [seed] keeps the
  /// zig-zag stable for a frame or two, then it re-strikes.
  static void lightning(
    Canvas canvas,
    Offset from,
    Offset to,
    double width,
    Color color,
    int seed, {
    double opacity = 1,
  }) {
    final rng = math.Random(seed);
    final d = to - from;
    final len = d.distance;
    if (len < 1) return;
    final n = Offset(-d.dy, d.dx) / len;
    final steps = math.max(3, (len / 18).round());
    final path = Path()..moveTo(from.dx, from.dy);
    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      final jitter = (rng.nextDouble() - .5) * math.min(26, len * .22);
      final p = from + d * t + n * jitter;
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .22 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 3.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * .4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// A soft expanding ring (impacts, area weapons, telegraphs).
  static void ring(
    Canvas canvas,
    Offset at,
    double radius,
    Color color, {
    double width = 4,
    double opacity = 1,
  }) {
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..color = color.withValues(alpha: .14 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 3.4,
    );
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..color = color.withValues(alpha: .24 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 2,
    );
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  /// A filled glowing disc (area weapon bodies, bombs, yarn balls).
  static void disc(
    Canvas canvas,
    Offset at,
    double radius,
    Color color, {
    double opacity = 1,
  }) {
    canvas.drawCircle(
      at,
      radius * 1.45,
      Paint()..color = color.withValues(alpha: .1 * opacity),
    );
    canvas.drawCircle(
      at,
      radius * 1.2,
      Paint()..color = color.withValues(alpha: .16 * opacity),
    );
    canvas.drawCircle(
      at,
      radius,
      Paint()..color = color.withValues(alpha: .85 * opacity),
    );
    canvas.drawCircle(
      at,
      radius * .55,
      Paint()..color = Colors.white.withValues(alpha: .85 * opacity),
    );
  }
}
