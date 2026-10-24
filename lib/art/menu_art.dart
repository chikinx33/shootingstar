import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shared registry of decoded lobby/game pictures, filled by the art loaders.
abstract final class MenuArt {
  static final images = <String, ui.Image>{};
  static final bounds = <String, Rect>{};
  static final aliases = <String, String>{};
  static const _opaqueCutout = ColorFilter.matrix([
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1.04,
    -8,
  ]);
  static bool paint(
    Canvas canvas,
    String name,
    Rect target, {
    bool cover = false,
    double opacity = 1,
    Color? tint,
  }) {
    name = aliases[name] ?? name;
    final im = images[name];
    if (im == null || target.isEmpty) return false;
    final b = bounds[name]!;
    final source = Rect.fromLTRB(
      b.left * im.width,
      b.top * im.height,
      b.right * im.width,
      b.bottom * im.height,
    );
    final fit = applyBoxFit(
      cover ? BoxFit.cover : BoxFit.contain,
      source.size,
      target.size,
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (!cover) {
      // Generated alpha can contain stray 1..7/255 pixels outside the ink.
      // Suppress those at render time; preserve the original PNG and AA edge.
      paint.colorFilter = tint == null && opacity == 1
          ? _opaqueCutout
          : ColorFilter.matrix([
              tint?.r ?? 1,
              0,
              0,
              0,
              0,
              0,
              tint?.g ?? 1,
              0,
              0,
              0,
              0,
              0,
              tint?.b ?? 1,
              0,
              0,
              0,
              0,
              0,
              1.04 * opacity,
              -8 * opacity,
            ]);
    }
    canvas.drawImageRect(
      im,
      Alignment.center.inscribe(fit.source, source),
      Alignment.center.inscribe(fit.destination, target),
      paint,
    );
    return true;
  }
}

class MenuImage extends StatelessWidget {
  const MenuImage(this.name, {super.key, this.size = 64});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _MenuPainter(name, false)),
  );
}

class MenuBackdrop extends StatelessWidget {
  const MenuBackdrop(this.name, {super.key, required this.child});
  final String name;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _MenuPainter(name, true), child: child);
}

class _MenuPainter extends CustomPainter {
  const _MenuPainter(this.name, this.cover);
  final String name;
  final bool cover;
  @override
  bool hitTest(Offset position) => false;
  @override
  void paint(Canvas canvas, Size size) {
    MenuArt.paint(canvas, name, Offset.zero & size, cover: cover);
  }

  @override
  bool shouldRepaint(_MenuPainter old) =>
      old.name != name || old.cover != cover;
}
