import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Ground, atmosphere and cloud sprites live below combat entities.
class SkyBackground {
  static Offset groundOffset(Offset camera, double time) =>
      camera * .24 - Offset(0, time * 8);
  static Offset cloudOffset(Offset camera, double time) =>
      camera * .48 - Offset(time * 4, time * 2.5);

  static void paint(
    Canvas canvas,
    Size view, {
    required Offset camera,
    required double time,
    ui.Image? ground,
    ui.Image? clouds,
    bool reducedEffects = false,
  }) {
    final bounds = Offset.zero & view;
    if (ground != null) {
      const tileSize = 540.0;
      final offset = groundOffset(camera, reducedEffects ? 0 : time);
      final startX = (offset.dx / tileSize).floor();
      final startY = (offset.dy / tileSize).floor();
      for (int x = startX; x * tileSize - offset.dx < view.width; x++) {
        for (int y = startY; y * tileSize - offset.dy < view.height; y++) {
          canvas.save();
          canvas.translate(x * tileSize - offset.dx, y * tileSize - offset.dy);
          // Mirrored repetition joins identical image edges without hard seams.
          canvas.translate(x.isOdd ? tileSize : 0, y.isOdd ? tileSize : 0);
          canvas.scale(x.isOdd ? -1 : 1, y.isOdd ? -1 : 1);
          canvas.drawImageRect(
            ground,
            Rect.fromLTWH(
              0,
              0,
              ground.width.toDouble(),
              ground.height.toDouble(),
            ),
            const Rect.fromLTWH(0, 0, tileSize, tileSize),
            Paint()..filterQuality = FilterQuality.low,
          );
          canvas.restore();
        }
      }
    }
    // A cool haze separates the distant city from the flight plane.
    canvas.drawRect(bounds, Paint()..color = const Color(0x500D2033));
    if (clouds == null) return;
    final offset = cloudOffset(camera, reducedEffects ? 0 : time);
    const stepX = 590.0, stepY = 640.0;
    for (
      int row = ((offset.dy - 500) / stepY).floor();
      row * stepY - offset.dy < view.height;
      row++
    ) {
      final stagger = row.isOdd ? 270.0 : 0.0;
      for (
        int col = ((offset.dx - stagger - 500) / stepX).floor();
        col * stepX + stagger - offset.dx < view.width;
        col++
      ) {
        final width = row.isOdd ? 440.0 : 520.0;
        final rect = Rect.fromLTWH(
          col * stepX + stagger - offset.dx,
          row * stepY - offset.dy,
          width,
          width,
        );
        canvas.drawImageRect(
          clouds,
          Rect.fromLTWH(
            0,
            0,
            clouds.width.toDouble(),
            clouds.height.toDouble(),
          ),
          rect,
          Paint()
            ..filterQuality = FilterQuality.low
            ..color = Colors.white.withValues(alpha: row.isOdd ? .28 : .38),
        );
      }
    }
  }
}
