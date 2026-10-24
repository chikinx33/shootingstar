import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/raster_assets.dart';
import '../art/experience_gem_art.dart';
import 'engine.dart';
import 'world_art.dart';
import 'combat_vfx.dart';

abstract final class ResolutionVfx {
  static void absorption(
    Canvas c,
    GameEngine g,
    bool reduced, {
    void Function(Canvas, Offset, double)? crystal,
  }) {
    // Every XP-bearing crystal remains visible; only duplicate trails are reduced.
    var index = 0;
    for (final mote in g.absorbingCrystals) {
      final p = (mote.age / mote.duration).clamp(0.0, 1.0);
      if (!reduced && index++ % 3 == 0) {
        final direction = g.position - mote.position;
        final tail =
            direction / math.max(1, direction.distance) * (12 + p * 18);
        c.drawLine(
          mote.position - tail,
          mote.position,
          CombatVfx.ink(CombatVfx.cyan, .55, 3),
        );
      }
      if (crystal == null) {
        ExperienceGemArt.paint(c, mote.position, mote.value);
      } else {
        crystal(c, ExperienceCrystal.at(mote.position, mote.value), 0);
      }
    }
    if (g.collectingMagnet) {
      CombatVfx.ring(
        c,
        g.position,
        26 + math.sin(g.atmosphereTime * 12) * 4,
        CombatVfx.cyan,
        .8,
        width: 3,
      );
    }
  }

  static void boss(Canvas c, GameEngine g, bool reduced) {
    final scene = g.bossResolution;
    if (scene == null) return;
    final t = scene.time, foe = scene.foe;
    for (var n = 0; n < scene.bursts; n++) {
      final phase = (t - (n + 1) * .145) / .55;
      if (phase < 0 || phase > 1) continue;
      final angle = n * 2.39996;
      final at =
          foe.position +
          Offset(math.cos(angle), math.sin(angle)) *
              foe.radius *
              (.2 + (n % 4) * .23);
      RasterAssets.sprite(
        c,
        'effects',
        (phase * 4).floor().clamp(0, 3),
        at,
        (42 + n % 4 * 22) * (.6 + .4 * math.sin(phase * math.pi)),
        opacity: 1 - phase * .65,
      );
    }
    if (t < BossResolution.breakupAt) {
      final strength = reduced ? 0.0 : 2 + t * 2;
      final shake = Offset(
        math.sin(t * 87) * strength,
        math.cos(t * 63) * strength,
      );
      c.save();
      c.translate(foe.position.dx + shake.dx, foe.position.dy + shake.dy);
      c.rotate(scene.rotation + (reduced ? 0 : math.sin(t * 27) * .035));
      WorldArt.boss(c, foe, g.worldIndex, g.atmosphereTime);
      c.restore();
      CombatVfx.ring(
        c,
        foe.position,
        foe.radius * (1.1 + t * .3),
        CombatVfx.gold,
        .65,
        width: 3,
      );
    } else {
      final age = t - BossResolution.breakupAt;
      if (age < .65) {
        RasterAssets.sprite(
          c,
          'effects',
          (age / .65 * 4).floor().clamp(0, 3),
          foe.position,
          160 + age * 100,
          opacity: 1 - age,
        );
      }
      final fade = (1 - age / 1.7).clamp(0.0, 1.0);
      if (fade <= 0) return;
      final diameter = foe.radius * 2.7;
      // The boss's own raster artwork breaks into twelve independent pieces.
      // Each clip paints the same source at native aspect, never generic debris.
      for (var i = 0; i < 12; i++) {
        final tile = Rect.fromLTWH(
          -diameter / 2 + i % 4 * diameter / 4,
          -diameter / 2 + i ~/ 4 * diameter / 3,
          diameter / 4,
          diameter / 3,
        );
        final direction = tile.center / math.max(1, tile.center.distance);
        final distance = age * (85 + i % 4 * 28);
        c.save();
        c.translate(
          foe.position.dx + direction.dx * distance,
          foe.position.dy + direction.dy * distance + age * age * 35,
        );
        c.rotate(scene.rotation);
        c.translate(tile.center.dx, tile.center.dy);
        c.rotate((i.isEven ? 1 : -1) * age * (reduced ? .2 : 1.8));
        c.scale(.6 + fade * .4);
        c.translate(-tile.center.dx, -tile.center.dy);
        c.clipRect(tile);
        WorldArt.boss(c, foe, g.worldIndex, g.atmosphereTime);
        c.restore();
        if (!reduced) {
          c.drawLine(
            foe.position + direction * distance,
            foe.position + direction * math.max(0, distance - 28),
            CombatVfx.ink(CombatVfx.gold, fade * .4, 3),
          );
        }
      }
    }
  }

  static Offset heroPosition(GameEngine g) {
    final progress = g.bossResolution?.departure ?? 0;
    final distance = g.position.dy - g.camera.dy + 100;
    return g.position - Offset(0, distance * progress * progress);
  }

  static void flash(Canvas c, GameEngine g, bool reduced) {
    final t = g.bossResolution?.time;
    if (t == null || reduced) return;
    final p = t - BossResolution.breakupAt;
    if (p >= 0 && p < .26) {
      c.drawRect(
        Rect.fromLTWH(g.camera.dx, g.camera.dy, 420, g.viewportHeight),
        Paint()
          ..color = const Color(0xFFFFF6D8)
              .withValues(alpha: (1 - p / .26) * .6),
      );
    }
  }
}
