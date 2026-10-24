import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'unique ship and enemy PNG sprites decode with real transparency',
    () async {
      expect(ships.map((ship) => ship.asset).toSet().length, 3);
      final paths = [
        ...ships.map((ship) => ship.asset),
        'assets/art/survival_enemy.png',
        'assets/art/survival_boss.png',
        'assets/art/content_equipment.png',
        'assets/art/content_tech.png',
        'assets/art/content_pet.png',
        'assets/art/cloud_layer.png',
      ];
      for (final path in paths) {
        final source = await rootBundle.load(path);
        expect(source.getUint32(0), 0x89504e47, reason: '$path PNG signature');
        expect(source.getUint32(16), greaterThanOrEqualTo(512));
        expect(source.getUint32(20), greaterThanOrEqualTo(512));
        final codec = await ui.instantiateImageCodec(
          source.buffer.asUint8List(),
          targetWidth: 128,
        );
        final frame = await codec.getNextFrame();
        final rgba = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        expect(
          rgba.getUint8(3),
          0,
          reason: '$path top-left background is transparent',
        );
        expect(
          rgba.getUint8(rgba.lengthInBytes - 1),
          0,
          reason: '$path bottom-right background is transparent',
        );
        var solidPixels = 0;
        for (var i = 3; i < rgba.lengthInBytes; i += 4) {
          if (rgba.getUint8(i) > 200) solidPixels++;
        }
        expect(
          solidPixels,
          greaterThan(500),
          reason: '$path contains a visible spacecraft',
        );
        frame.image.dispose();
        codec.dispose();
      }
    },
  );
}
