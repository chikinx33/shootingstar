import 'dart:math' as math;
import 'dart:ui';

import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/survival_skills.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';

// Deterministic driver: visible projectiles/contacts, nearby pickups and boss position.
// No invincibility, permanent-stat inflation or knowledge of future random rolls.
int choiceScore(GameEngine g, UpgradeChoice c) {
  if (c.id == 'repair') return g.hp < g.maxHp * .55 ? 110 : -1;
  if (c.evolution) return 100;
  if (c.specialization) return 90;
  if (c.id == 'gun') return 85;
  if (['guardian', 'missile', 'lightning', 'laser'].contains(c.id)) return 75;
  return skillFor(c.id).passive ? 40 : 50;
}

Offset steer(GameEngine g) {
  var goal = g.boss == null
      ? Offset(
          900 + 140 * math.sin(g.combatTime * .23),
          1200 + 150 * math.cos(g.combatTime * .23),
        )
      : g.boss!.position + Offset(90 * math.sin(g.combatTime * .6), 175);
  if (g.boss == null) {
    var nearest = 200.0;
    for (final item in [...g.crystals, ...g.supplies.map((s) => s.position)]) {
      final distance = (item - g.position).distance;
      if (distance < nearest) {
        nearest = distance;
        goal = item;
      }
    }
  }
  var best = goal, bestScore = -double.infinity;
  for (var i = 0; i < 16; i++) {
    final at =
        g.position +
        Offset(math.cos(i * math.pi / 8), math.sin(i * math.pi / 8)) * 65;
    if (at.dx < 40 || at.dx > 1760 || at.dy < 40 || at.dy > 2360) continue;
    var score = -(at - goal).distance * .03;
    for (final shot in g.shots.where((s) => s.hostile)) {
      for (final horizon in [0.0, .3, .6]) {
        final distance =
            (at - (shot.position + shot.velocity * horizon)).distance;
        score -= math.max(0, 42 + shot.radius - distance) * .7;
      }
    }
    for (final e in g.enemies.where((e) => e.plane == AircraftTarget.air)) {
      score -= math.max(0, e.radius + 40 - (at - e.position).distance) * .4;
    }
    if (g.hazardVisible && g.hazardHits(at)) score -= 60;
    if (score > bestScore) {
      bestScore = score;
      best = at;
    }
  }
  final direction = best - g.position;
  return direction.distance > 1 ? direction / direction.distance : Offset.zero;
}
