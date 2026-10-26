import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/art/flight_scene_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('depth planes scroll continuously in world space', () async {
    // Deliberately asymmetric image catches parity flips hidden by symmetric art.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var y = 0; y < 12; y++) {
      for (var x = 0; x < 8; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          Paint()..color = Color.fromARGB(255, x * 30, y * 20, (x + y) * 12),
        );
      }
    }
    final picture = recorder.endRecording();
    final pattern = await picture.toImage(8, 12);
    picture.dispose();
    Future<Uint8List> pixels(
      FlightSceneLayer layer,
      double time,
      Offset camera,
    ) async {
      final r = ui.PictureRecorder();
      FlightSceneArt.paintLayer(
        Canvas(r),
        const Size(80, 120),
        layer,
        pattern,
        time: time,
        camera: camera,
      );
      final p = r.endRecording(), image = await p.toImage(80, 120);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      image.dispose();
      p.dispose();
      return bytes;
    }

    double difference(Uint8List a, Uint8List b) {
      var sum = 0;
      for (var i = 0; i < a.length; i++) {
        sum += (a[i] - b[i]).abs();
      }
      return sum / a.length;
    }

    try {
      var previousCameraTravel = 0.0, previousDrift = 0.0;
      for (final layer in FlightSceneArt.layers) {
        final travel = layer.displacement(0, const Offset(100, -200));
        expect(travel.dx, lessThan(0));
        expect(travel.dy, greaterThan(0));
        expect(-travel.dx, greaterThan(previousCameraTravel));
        expect(layer.drift, greaterThan(previousDrift));
        previousCameraTravel = -travel.dx;
        previousDrift = layer.drift;
        final base = await pixels(layer, 0, Offset.zero);
        final moved = await pixels(
          layer,
          0,
          Offset(10 / layer.cameraFactor, 20 / layer.cameraFactor),
        );
        // A 10px right /20px down camera pan samples that much farther in the
        // texture, rather than gluing scenery to a screen edge. Compare interiors.
        for (var y = 20; y < 80; y += 10) {
          for (var x = 20; x < 60; x += 10) {
            final a = (y * 80 + x) * 4, b = ((y + 20) * 80 + x + 10) * 4;
            for (var channel = 0; channel < 4; channel++) {
              expect(moved[a + channel], closeTo(base[b + channel], 1));
            }
          }
        }
        for (final boundary in [-240.0, -120.0, 120.0, 240.0]) {
          final before = await pixels(
            layer,
            (boundary - .0001) / layer.drift,
            Offset.zero,
          );
          final after = await pixels(
            layer,
            (boundary + .0001) / layer.drift,
            Offset.zero,
          );
          expect(
            difference(before, after),
            lessThan(1),
            reason: '${layer.depth} vertical wrap $boundary',
          );
        }
        for (final boundary in [-160.0, -80.0, 80.0, 160.0]) {
          final before = await pixels(
            layer,
            0,
            Offset((boundary - .0001) / layer.cameraFactor, 0),
          );
          final after = await pixels(
            layer,
            0,
            Offset((boundary + .0001) / layer.cameraFactor, 0),
          );
          expect(
            difference(before, after),
            lessThan(1),
            reason: '${layer.depth} horizontal wrap $boundary',
          );
        }
        final long = await pixels(layer, 3600, const Offset(12345, -67890));
        for (var n = 3; n < long.length; n += 4) {
          expect(long[n], 255);
        }
      }
    } finally {
      pattern.dispose();
    }
  });
}
