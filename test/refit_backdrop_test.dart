import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/art/game_backdrop.dart';

void main() {
  test('nested backdrop does not erase the header painted before it', () async {
    for (final launch in [false, true]) {
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 200, 80),
        Paint()..color = const Color(0xFFCC2233),
      );
      canvas.save();
      canvas.translate(0, 80);
      GameBackdropPainter(launch).paint(canvas, const Size(200, 220));
      canvas.restore();
      final picture = recorder.endRecording(),
          image = await picture.toImage(200, 300);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final index = (20 * 200 + 32) * 4;
      expect(pixels.sublist(index, index + 4), [204, 34, 51, 255]);
      image.dispose();
      picture.dispose();
    }
  });
}
