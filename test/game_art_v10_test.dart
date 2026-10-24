import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/art/arcade_aircraft.dart';
import 'package:shootingstar/art/game_art.dart';
import 'package:shootingstar/art/gear_art.dart';
import 'package:shootingstar/art/menu_art.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/art/toon_assets.dart';

void main() {
  test('all gameplay and UI image addresses have a separate picture or control glyph', () {
    final game = jsonDecode(
      File('assets/art/game_v10/manifest.json').readAsStringSync(),
    ) as Map;
    // refit_v16 replaces most v9 lobby pictures; v9 keeps the other icons.
    final lobby = {
      ...jsonDecode(
        File('assets/art/lobby_v9/manifest.json').readAsStringSync(),
      ) as Map,
      ...jsonDecode(
        File('assets/art/refit_v16/manifest.json').readAsStringSync(),
      ) as Map,
    };
    expect(game.length, 51);
    for (final group in {
      'ships': 6,
      'enemies': 12,
      'bosses': 12,
      'equipment': 32,
      'icons': 64,
      'projectiles': 24,
      'effects': 16,
    }.entries) {
      for (var id = 0; id < group.value; id++) {
        final address = GameArt.address(group.key, id);
        if (address == null) {
          expect(group.key, 'icons');
          expect(GameArt.glyphs.containsKey(id), isTrue, reason: 'missing $id');
        } else {
          if (group.key == 'equipment') {
            expect(address, GearArt.address(id));
            continue;
          }
          final parts = address.split('/');
          expect(
            (parts[0] == 'game' ? game : lobby).containsKey(parts[1]),
            isTrue,
            reason: '${group.key}/$id -> $address',
          );
        }
      }
    }
  });

  testWidgets(
    'lobby, hangar and live combat draw identical craft pixels without legacy atlases',
    (tester) async {
      await tester.runAsync(() async {
        await RasterAssets.load();
        expect(GameArt.ready, isTrue);
        expect(RasterAssets.images, isEmpty);
        expect(ToonAssets.images, isEmpty);
        for (var ship = 0; ship < 3; ship++) {
          final key = const ['hero', 'hero-vector', 'hero-monolith'][ship];
          expect(
            MenuArt.images[key],
            same(MenuArt.images[GameArt.address('ships', ship)]),
          );
          Future<List<int>> pixels(bool combat) async {
            final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
            if (combat) {
              ArcadeAircraft.paintShip(canvas, const Offset(64, 64), 128, ship);
            } else {
              // Use the same local origin to avoid subpixel sampling noise.
              canvas.translate(64, 64);
              GameArt.paint(
                canvas,
                'ships',
                ship,
                const Rect.fromLTWH(-64, -64, 128, 128),
              );
            }
            final picture = recorder.endRecording();
            final image = await picture.toImage(128, 128);
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final bytes = data!.buffer.asUint8List().toList();
            image.dispose();
            picture.dispose();
            return bytes;
          }

          expect(
            await pixels(true),
            await pixels(false),
            reason: 'ship $ship changed after launch',
          );
        }
        for (var world = 0; world < 10; world++) {
          final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
          GameArt.paintWorld(
            canvas,
            world,
            const Rect.fromLTWH(0, 0, 540, 540),
          );
          final picture = recorder.endRecording(),
              image = await picture.toImage(540, 540);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          for (final x in [10, 270, 530]) {
            final top = data.sublist(x * 4, x * 4 + 4),
                bottom = data.sublist(
                  (539 * 540 + x) * 4,
                  (539 * 540 + x) * 4 + 4,
                );
            expect(top, bottom, reason: 'world $world has a border/seam at $x');
          }
          if (world == 0) {
            final flippedRecorder = ui.PictureRecorder();
            final flippedCanvas = Canvas(flippedRecorder)
              ..translate(540, 540)
              ..scale(-1.0, -1.0);
            GameArt.paintWorld(
              flippedCanvas,
              0,
              const Rect.fromLTWH(0, 0, 540, 540),
            );
            final flippedPicture = flippedRecorder.endRecording();
            final flippedImage = await flippedPicture.toImage(540, 540);
            final flipped = (await flippedImage.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            var difference = 0;
            for (var y = 0; y < 90; y++) {
              for (var x = 0; x < 90; x++) {
                for (var channel = 0; channel < 4; channel++) {
                  final normalIndex = ((60 + y) * 540 + 43 + x) * 4 + channel;
                  final flippedIndex =
                      ((390 + y) * 540 + 407 + x) * 4 + channel;
                  difference += (data[normalIndex] - flipped[flippedIndex])
                      .abs();
                }
              }
            }
            expect(
              difference / (90 * 90 * 4),
              lessThan(.5),
              reason: 'Mirrored floors must not turn AI scenery upside down',
            );
            flippedImage.dispose();
            flippedPicture.dispose();
          }
          image.dispose();
          picture.dispose();
        }
      });
    },
  );
}
