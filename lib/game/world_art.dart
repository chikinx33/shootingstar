import 'package:flutter/material.dart';

import '../art/arcade_world.dart';
import '../art/flight_scene_art.dart';
import '../data/campaign.dart';
import 'engine.dart';

class WorldArt {
  static void boss(Canvas canvas, Foe e, int world, double time) {
    ArcadeWorld.paintBoss(canvas, world, e.radius * 2.7);
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
    ArcadeWorld.paintEnemy(canvas, e.role.index, e.radius * scale, faction);
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

class WorldBackdropPainter extends CustomPainter {
  WorldBackdropPainter(this.world);
  final int world;
  @override
  void paint(Canvas canvas, Size size) =>
      WorldArt.background(canvas, size, world, 0, Offset.zero);
  @override
  bool shouldRepaint(covariant WorldBackdropPainter old) => old.world != world;
}
