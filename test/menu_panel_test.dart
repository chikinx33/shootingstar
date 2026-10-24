import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/art/arcade_style.dart';

void main() {
  test(
    'panel interiors have no slice seams at different aspect ratios',
    () async {
      for (final size in [
        const Size(160, 72),
        const Size(264, 72),
        const Size(320, 64),
        const Size(244, 120),
      ]) {
        final recorder = ui.PictureRecorder();
        ArcadeStyle.paintPanel(Canvas(recorder), 2, Offset.zero & size);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final w = size.width.toInt(), h = size.height.toInt();
        int pixel(int x, int y) => bytes.getUint32((y * w + x) * 4);
        for (int x = 17; x < w - 16; x++) {
          final previous = pixel(x - 1, h ~/ 2), current = pixel(x, h ~/ 2);
          for (final shift in [8, 16, 24]) {
            expect(
              (((current >> shift) & 255) - ((previous >> shift) & 255)).abs(),
              lessThanOrEqualTo(3),
              reason: 'horizontal seam at $size / $x',
            );
          }
        }
        // A continuous bevel gradient is allowed; a spliced bitmap seam is not.
        for (int y = 17; y < h - 16; y++) {
          final previous = pixel(w ~/ 2, y - 1), current = pixel(w ~/ 2, y);
          for (final shift in [8, 16, 24]) {
            expect(
              (((current >> shift) & 255) - ((previous >> shift) & 255)).abs(),
              lessThanOrEqualTo(3),
              reason: 'vertical seam at $size / $y',
            );
          }
        }
        image.dispose();
        picture.dispose();
      }
    },
  );
}
