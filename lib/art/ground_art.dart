import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aircraft_assembly_art.dart';
import 'menu_art.dart';

abstract final class GroundArt {
  static ui.Image? image;
  static final cells = <Rect>[];
  static Future<void> load() async {
    if (image != null) return;
    final bytes = await rootBundle.load('assets/art/airframe_v51/ground.webp');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      targetWidth: 1024,
    );
    final art = (await codec.getNextFrame()).image;
    codec.dispose();
    final meta = jsonDecode(
      await rootBundle.loadString('assets/art/airframe_v51/manifest.json'),
    ) as Map;
    final sx = art.width / (meta['width'] as num),
        sy = art.height / (meta['height'] as num);
    cells.addAll([
      for (final r in meta['cells'])
        Rect.fromLTRB(r[0] * sx, r[1] * sy, r[2] * sx, r[3] * sy),
    ]);
    image = art;
  }

  static void paint(Canvas canvas, int kind, Rect target) {
    final art = image;
    if (art == null) return;
    final src = cells[kind.clamp(0, 2)];
    final fit = applyBoxFit(BoxFit.contain, src.size, target.size);
    final dst = Alignment.center.inscribe(fit.destination, target);
    canvas.drawImageRect(
      art,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  static Rect _normalizedCell(int index) {
    final r = AircraftAssemblyArt.cells[index],
        art = AircraftAssemblyArt.modules!;
    return Rect.fromLTRB(
      r.left / art.width,
      r.top / art.height,
      r.right / art.width,
      r.bottom / art.height,
    );
  }

  static void installAircraftAliases() {
    final hulls = AircraftAssemblyArt.hulls;
    if (hulls.length != 3) return;
    for (var i = 0; i < 3; i++) {
      final art = hulls[i];
      for (final name in [
        const ['hero', 'hero-vector', 'hero-monolith'][i],
        'lobby/${const ['hero', 'vector', 'monolith'][i]}',
      ]) {
        MenuArt.images[name] = art;
        MenuArt.bounds[name] = const Rect.fromLTWH(0, 0, 1, 1);
      }
      // v11: pets are the chick companions again (game_v10/pet-*.webp);
      // the v51 support-device override is retired.
    }
    const parts = {
      'gear-gun': 0,
      'gear-sensor': 1,
      'gear-core': 9,
      'gear-hull': 5,
      'gear-belt': 6,
      'gear-engine': 7,
      'armament-pulse': 0,
      'armament-kunai': 0,
      'armament-katana': 0,
      'armament-bat': 0,
      'armament-shotgun': 0,
      'armament-revolver': 0,
      'armament-lightchaser': 0,
      'armament-void': 0,
      'armament-disorder': 0,
      'armament-lance': 0,
    };
    for (final e in parts.entries) {
      MenuArt.images['game/${e.key}'] = AircraftAssemblyArt.modules!;
      MenuArt.bounds['game/${e.key}'] = _normalizedCell(e.value);
    }
    for (final alias in MenuArt.aliases.entries) {
      if (MenuArt.images.containsKey(alias.value)) {
        MenuArt.images[alias.key] = MenuArt.images[alias.value]!;
        MenuArt.bounds[alias.key] = MenuArt.bounds[alias.value]!;
      }
    }
  }
}
