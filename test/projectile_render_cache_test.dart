import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/glow_shots.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/game/battle_painter.dart';
import 'package:shootingstar/game/engine.dart';

Future<Uint8List> pixels(GameEngine game, bool cached, bool reduced) async {
  final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
  BattlePainter(
    game,
    cacheProjectiles: cached,
    reducedEffects: reduced,
  ).paint(canvas, const ui.Size(420, 720));
  final picture = recorder.endRecording(),
      image = await picture.toImage(420, 720);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (Platform.environment['CACHE_CAPTURE'] == '1') {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('.local/complete-v27/render-$cached-$reduced.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  }
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets(
    'magnet crystal cache preserves every mote, pixels and gameplay state',
    (tester) async {
      await tester.runAsync(() async {
        await RasterAssets.load();
        final g = GameEngine(
          stageIndex: 0,
          shipIndex: 0,
          attackLevel: 0,
          hullLevel: 0,
          magnetLevel: 0,
          equipmentIndex: 0,
        );
        for (var i = 0; i < 1400; i++) {
          final at =
              g.position +
              ui.Offset((i % 35 - 17) * 11.5, (i ~/ 35 - 20) * 9.5);
          g.absorbingCrystals.add(AbsorbingCrystal(at, 1.2, 20, 2)..age = .3);
        }
        for (final reduced in [false, true]) {
          final before = jsonEncode(g.checkpoint());
          final a = await pixels(g, false, reduced),
              b = await pixels(g, true, reduced);
          var difference = 0, large = 0;
          for (var i = 0; i < a.length; i++) {
            final d = (a[i] - b[i]).abs();
            difference += d;
            if (d > 8) large++;
          }
          expect(difference / a.length, lessThan(.12));
          expect(large / a.length, lessThan(.001));
          expect(g.absorbingCrystals.length, 1400);
          expect(jsonEncode(g.checkpoint()), before);
        }
      });
    },
  );
  testWidgets(
    'reduced-effects field reuses unchanged gems and invalidates on pickup/drop, camera and art revision',
    (tester) async {
      await tester.runAsync(() async {
        await RasterAssets.load();
        final game = GameEngine(
          stageIndex: 0,
          shipIndex: 0,
          attackLevel: 0,
          hullLevel: 0,
          magnetLevel: 0,
          equipmentIndex: 0,
        );
        for (var i = 0; i < 168; i++) {
          game.crystals.add(
            game.position +
                ui.Offset((i % 14 - 7) * 25.0, (i ~/ 14 - 6) * 40.0),
          );
        }
        for (var step = 0; step < 6; step++) {
          if (step == 2) {
            game.crystals.removeAt(47);
            game.crystals.add(game.position + const ui.Offset(125.5, -80.5));
            game.position += const ui.Offset(33.25, 10.5);
          }
          if (step == 3) {
            game.crystals.add(game.position + const ui.Offset(-70.5, 50.5));
          }
          if (step == 4) RasterAssets.revision.value++;
          if (step == 5) {
            // Equal positions with a different tier must invalidate the cache.
            game.crystals[0] = ExperienceCrystal.at(game.crystals[0], 16);
            game.crystals[1] = ExperienceCrystal.at(game.crystals[1], 8);
          }
          final before = jsonEncode(game.checkpoint()),
              reference = await pixels(game, false, true),
              cached = await pixels(game, true, true);
          var difference = 0;
          for (var i = 0; i < reference.length; i++) {
            difference += (reference[i] - cached[i]).abs();
          }
          expect(difference / reference.length, lessThan(.12));
          expect(jsonEncode(game.checkpoint()), before);
          expect(BattlePainter.cachedCrystalFields, inInclusiveRange(1, 12));
        }
      });
    },
  );
  testWidgets(
    'cached pulse/hazard sprites preserve pixels, source state and the uncached animated fallback',
    (tester) async {
      await tester.runAsync(() async {
        await RasterAssets.load();
        for (final power in [0, 3])
          for (final reduced in [false, true]) {
            final game = GameEngine(
              stageIndex: 0,
              shipIndex: 0,
              attackLevel: 0,
              hullLevel: 0,
              magnetLevel: 0,
              equipmentIndex: 0,
            )..mainPower = power;
            for (var i = 0; i < 26; i++) {
              game.crystals.add(
                game.position +
                    ui.Offset((i % 6 - 3) * 61.0, (i ~/ 6 - 2) * 73.0),
              );
            }
            for (var i = 0; i < 42; i++) {
              final kind = [0, 4, 1, 19, 18, 23][i % 6];
              final angle = i * .47;
              game.shots.add(
                Shot(
                  game.position +
                      ui.Offset((i % 6 - 3) * 52.0, (i ~/ 6 - 3) * 64.0),
                  ui.Offset(math.cos(angle), math.sin(angle)) *
                      (i == 0 ? 0 : 85),
                  1,
                  kind,
                  radius: i % 3 + 3.0,
                  weapon: ['gun', 'soul', 'fire'][(i ~/ 6) % 3],
                )..age = .35,
              );
            }
            final before = jsonEncode(game.checkpoint());
            final legacy = await pixels(game, false, reduced),
                cached = await pixels(game, true, reduced);
            var differing = 0, difference = 0;
            for (var i = 0; i < legacy.length; i++) {
              final delta = (legacy[i] - cached[i]).abs();
              difference += delta;
              if (delta > 8) differing++;
            }
            // Rotating a recorded path vs transformed endpoints can change edge AA.
            expect(differing / legacy.length, lessThan(.001));
            expect(difference / legacy.length, lessThan(.12));
            expect(jsonEncode(game.checkpoint()), before);
          }
        // v12: most bullets are recorded glow pictures (GlowShots)
        expect(
          BattlePainter.cachedProjectilePictures + GlowShots.cachedPictures,
          greaterThan(0),
        );
        final crowded = GameEngine(
          stageIndex: 0,
          shipIndex: 0,
          attackLevel: 0,
          hullLevel: 0,
          magnetLevel: 0,
          equipmentIndex: 0,
        );
        for (var i = 0; i < 170; i++) {
          crowded.shots.add(
            Shot(
              crowded.position + const ui.Offset(0, -100),
              const ui.Offset(0, -100),
              1,
              4,
              radius: 2 + i / 100,
            ),
          );
        }
        await pixels(crowded, true, false);
        expect(BattlePainter.cachedProjectilePictures, lessThanOrEqualTo(128));
      });
    },
  );
}
