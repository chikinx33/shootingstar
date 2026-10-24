import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/art/game_art.dart';
import 'package:shootingstar/art/raster_assets.dart';

void main() {
  testWidgets(
    'world thumbnails paint the actual shared orbital art and distinct landmark combinations',
    (tester) async {
      final signatures = <int>{};
      await tester.runAsync(() async {
        await RasterAssets.load();
        for (var world = 0; world < 10; world++) {
          final recorder = ui.PictureRecorder();
          // A separate recorder per thumbnail avoids sharing mutable paint state.
          final c = ui.Canvas(recorder);
          expect(
            GameArt.paint(
              c,
              'worlds',
              world,
              const ui.Rect.fromLTWH(0, 0, 72, 72),
            ),
            true,
          );
          final pic = recorder.endRecording(),
              image = await pic.toImage(72, 72),
              bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
          var signature = 0;
          for (final b in bytes!.buffer.asUint8List()) {
            signature = ((signature << 5) + signature + b) & 0x7fffffff;
          }
          signatures.add(signature);
          image.dispose();
          pic.dispose();
        }
      });
      expect(signatures.length, 10);
    },
  );
}
