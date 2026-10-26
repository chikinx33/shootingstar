import 'package:flutter/material.dart';

import '../art/menu_art.dart';
import '../art/flight_scene_art.dart';
import '../data/campaign.dart';
import 'engine.dart';

class WorldArt {
  /// v12.15: Vacuum Empire fortress bodies (enemies_v14/boss_N).
  static void boss(Canvas canvas, Foe e, int world, double time) =>
      bossSprite(canvas, world, e.radius * 2.7);

  static void bossSprite(Canvas canvas, int world, double size) {
    if (size <= 0) return;
    MenuArt.paint(
      canvas,
      'boss-${world.clamp(0, 9)}',
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
    );
  }

  static void background(
    Canvas canvas,
    Size size,
    int world,
    double time,
    Offset camera,
  ) {
    FlightSceneArt.paint(
      canvas,
      size,
      world: world,
      time: time,
      camera: camera,
    );
  }

  static void enemy(
    Canvas canvas,
    Foe e,
    Color faction,
    int world, {
    double scale = 2.7,
  }) {
    // v12.15: Vacuum Empire minions, one silhouette per role (enemies_v14)
    final size = e.radius * scale;
    MenuArt.paint(
      canvas,
      'enemy-${e.role.index.clamp(0, 10)}',
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
    );
    if (e.vulnerable > 0 || e.statusTime > 0) {
      canvas.drawCircle(
        Offset.zero,
        e.radius + 7,
        Paint()
          ..color =
              (e.vulnerable > 0
                      ? const Color(0xFFFFD96F)
                      : const Color(0xFF90DAF4))
                  .withValues(alpha: .75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (e.role == EnemyRole.bulwark && e.phase % 6 < 4) {
      canvas.drawCircle(
        Offset.zero,
        e.radius + 5,
        Paint()..color = const Color(0xFF9DCAEF).withValues(alpha: .15),
      );
      canvas.drawCircle(
        Offset.zero,
        e.radius + 5,
        Paint()
          ..color = const Color(0xFF9DCAEF).withValues(alpha: .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}
