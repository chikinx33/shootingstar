import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/art/aircraft_assembly_art.dart';
import 'package:shootingstar/art/gear_art.dart';
import 'package:shootingstar/data/aircraft_geometry.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/content_catalog.dart';
import 'package:shootingstar/data/gear_traits.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/combat_cues.dart';

// v12.6: the lobby no longer shows an aircraft or armament buttons, and the
// old LobbyAircraft eye/slot overlay now only wraps ModuleAircraftPreview,
// whose sockets are covered by ship_modules_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'comparison matches actual equipped stat changes, not unrelated perks',
    () async {
      final p = await Profile.load();
      final candidate = GearItem(100, 1, rank: 2, level: 3);
      p.inventory.add(candidate);
      final before = p.gearDamage,
          expected =
              gearBaseContribution(candidate) -
              gearBaseContribution(p.gearAt(0));
      p.equipItem(100);
      expect(p.gearDamage - before, closeTo(expected, 1e-10));
      expect(
        gearBaseContribution(GearItem(1, 0)),
        gearBaseContribution(GearItem(2, 1)),
      );
      p.dispose();
    },
  );
  test(
    'parts follow at different delays, settle and never enter combat state',
    () {
      GameEngine game() => GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        aircraft: AircraftAssembly.initial(0),
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 63,
      );
      final shown = game(), hidden = game()..visuals.enabled = false;
      for (var i = 0; i < 20; i++) {
        shown.input = hidden.input = const Offset(1, 0);
        shown.update(.025);
        hidden.update(.025);
      }
      expect(shown.visuals.followOffset('main').dx, lessThan(0));
      expect(
        shown.visuals.followOffset('supportRear').distance,
        greaterThan(shown.visuals.followOffset('main').distance),
      );
      expect(jsonEncode(shown.checkpoint()), jsonEncode(hidden.checkpoint()));
      final cues = CombatCues();
      for (var i = 0; i < 10; i++)
        cues.followMovement(const Offset(5, 0), .025);
      for (final key in CombatCues.followTimes.keys)
        expect(cues.followOffset(key).distance, lessThan(3.7));
      for (var i = 0; i < 50; i++) cues.followMovement(Offset.zero, .025);
      expect(cues.followOffset('supportRear').distance, lessThan(.001));
    },
  );
  test('every hull and equipment variant uses physical painted rectangles', () async {
    await AircraftAssemblyArt.load();
    for (var hull = 0; hull < 3; hull++) {
      for (var spec = 0; spec < gearCatalog.length; spec++) {
        final gear = [0, 2, 4, 6, 8, 10];
        gear[gearCatalog[spec].slot] = spec;
        final assembly = AircraftAssembly.demo(hull).withGear(gear);
        final sockets = AircraftAssemblyArt.sockets(assembly);
        for (final placement in AircraftAssemblyArt.placements(assembly)) {
          final slot = placement.mount == AircraftMount.main
              ? 0
              : placement.mount == AircraftMount.armor
              ? 3
              : -1;
          final src = slot >= 0
              ? GearArt.cells[gear[slot]]
              : AircraftAssemblyArt.partRect(aircraftPart(placement.part));
          final physical = AircraftGeometry.mountedRect(
            placement.anchor,
            placement.width,
            src,
            pivot: placement.pivot,
            mirror: placement.mirror,
          );
          expect(
            sockets.any(
              (s) => s.mount == placement.mount && s.rect == physical,
            ),
            isTrue,
          );
        }
        expect(sockets.where((s) => s.gearSlot == 5), hasLength(2));
        for (final size in [const Size(160, 220), const Size(248, 440)]) {
          final view = AssemblyViewport.layout(size, assembly, targetSize: 48);
          for (final socket in sockets) {
            final rect = view.project(socket.rect);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
          }
          // The fuselage now spans most of the preview width, not a tiny core.
          expect(view.extent / size.width, greaterThan(.7));
        }
      }
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(const Color(0xFF243C51), BlendMode.src);
    for (var hull = 0; hull < 3; hull++) {
      final assembly = AircraftAssembly.demo(hull)
          .withGear(const [0, 2, 4, 6, 8, 10]);
      final view = AssemblyViewport.layout(const Size(320, 460), assembly);
      canvas.save();
      canvas.translate(hull * 320.0, 0);
      AircraftAssemblyArt.paintAssembly(
        canvas,
        view.center,
        view.extent,
        assembly,
      );
      for (final socket in AircraftAssemblyArt.sockets(
        assembly,
      ).where((s) => s.gearSlot != null)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            view.project(socket.rect),
            const Radius.circular(6),
          ),
          Paint()
            ..color = const Color(0xFF92D5E8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(960, 460);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    File('.local/lobby-v65/physical-layout.png')
        .writeAsBytesSync(bytes.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
