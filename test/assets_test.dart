import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('bundled art is WebP only: no heavy PNG ships with the game', () {
    final pngs = Directory('assets/art')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .map((f) => f.path)
        .toList();
    expect(pngs, isEmpty);
  });

  test('cut-out WebP sprites decode with real transparency', () async {
    const paths = [
      'assets/art/cats_v11/cheese_side.webp',
      'assets/art/ship_parts/sunshine/base.webp',
      'assets/art/game_v10/pet-0.webp',
      'assets/art/icons_v12/paw.webp',
      'assets/art/lobby_v9/guild.webp',
    ];
    for (final path in paths) {
      final source = await rootBundle.load(path);
      // RIFF....WEBP
      expect(source.getUint32(0), 0x52494646, reason: '$path RIFF header');
      expect(source.getUint32(8), 0x57454250, reason: '$path WEBP header');
      final codec = await ui.instantiateImageCodec(
        source.buffer.asUint8List(),
        targetWidth: 128,
      );
      final frame = await codec.getNextFrame();
      final rgba = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(rgba.getUint8(3), 0, reason: '$path top-left is transparent');
      var solidPixels = 0;
      for (var i = 3; i < rgba.lengthInBytes; i += 4) {
        if (rgba.getUint8(i) > 200) solidPixels++;
      }
      expect(solidPixels, greaterThan(500), reason: '$path has visible art');
      frame.image.dispose();
      codec.dispose();
    }
  });
}
