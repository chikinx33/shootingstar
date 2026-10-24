import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// Generated cartoon PNG skins, with a loading-only painted fallback.
abstract final class ArcadeStyle {
  static const ink = Color(0xFF14263B);
  static const panel = Color(0xFF293F56);
  static const outline = Color(0xFF111722);
  static const gold = Color(0xFFFFD447);
  static const blue = Color(0xFF347DC8);
  static const muted = Color(0xFFCBD5E2);

  static const panelColors = [
    panel,
    blue,
    gold,
    Color(0xFF5B6D87),
    Color(0xFF273449),
    Color(0xFF448F66),
  ];

  static void paintPanel(
    Canvas canvas,
    int skin,
    Rect target, {
    double border = 12,
    Color? color,
  }) {
    if (target.isEmpty) return;
    // v12.8: the generated game UI kit when it is loaded.
    final piece = UiKit.pieceFor(skin, target, color);
    if (piece != null &&
        UiKit.paint(canvas, piece, target, corner: math.max(18, border * 2))) {
      return;
    }
    const colors = [
      Color(0xFF2C425A),
      Color(0xFF246C96),
      Color(0xFFFFCF4B),
      Color(0xFF3C5872),
      Color(0xFF1C3048),
      Color(0xFF247D72),
      Color(0xFFF0B337),
      Color(0xFF5A589F),
    ];
    final fill = color ?? colors[skin.clamp(0, 7)];
    final small = target.height < 20;
    final inset = small ? 0.5 : 1.5;
    final r = target.deflate(inset);
    final cut = math.min(small ? 2.0 : 8.0, r.shortestSide / 4);
    Path shape(Rect b) => Path()
      ..moveTo(b.left + cut, b.top)
      ..lineTo(b.right - cut, b.top)
      ..lineTo(b.right, b.top + cut)
      ..lineTo(b.right, b.bottom - cut)
      ..lineTo(b.right - cut, b.bottom)
      ..lineTo(b.left + cut, b.bottom)
      ..lineTo(b.left, b.bottom - cut)
      ..lineTo(b.left, b.top + cut)
      ..close();
    final path = shape(r);
    canvas.drawPath(
      path.shift(Offset(0, small ? 0 : 2)),
      Paint()..color = const Color(0x80091524),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(fill, Colors.white, .10)!,
            fill,
            Color.lerp(fill, const Color(0xFF142139), .18)!,
          ],
          stops: const [0, .48, 1],
        ).createShader(r),
    );
    canvas.save();
    canvas.clipPath(path);
    final edge = small ? 1.0 : 4.0;
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, edge),
      Paint()..color = Colors.white.withValues(alpha: .24),
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.bottom - edge, r.width, edge),
      Paint()..color = Colors.black.withValues(alpha: .27),
    );
    canvas.restore();
    if (!small) {
      canvas.drawPath(
        shape(r.deflate(3)),
        Paint()
          ..color = const Color(0x337CB9D4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = small ? 1 : 3,
    );
  }
}
