import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine createGame(int seed) => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: seed,
);

void main() {
  test('normal and evolved gun fire straight upward regardless of input or targets', () {
    for (final evolved in [false, true]) {
      for (final input in [
        const Offset(1, 0),
        const Offset(-1, 0),
        const Offset(0, 1),
        const Offset(1, 1),
        Offset.zero,
      ]) {
        final g = createGame(4)..input = input;
        if (evolved) {
          g.upgrades['gun'] = 5;
          g.evolved.add('gun');
        }
        g.enemies.add(Foe(g.position + const Offset(80, 80), 100, 0, 10, 0));
        g.update(.05);
        final bullets = g.shots.where((s) => s.kind == 0).toList();
        expect(bullets.length, evolved ? 3 : 1);
        expect(g.angle, -math.pi / 2);
        for (final bullet in bullets) {
          expect(bullet.velocity, const Offset(0, -420));
        }
        if (evolved) {
          expect(bullets.map((s) => s.position.dx - g.position.dx).toSet(), {
            0.0,
            -12.0,
            12.0,
          });
        }
      }
    }
  });
  test('auxiliary drone still targets behind the ship', () {
    final g = createGame(8);
    g.upgrades.clear();
    g.upgrades['drone'] = 1;
    g.enemies.add(Foe(g.position + const Offset(0, 100), 100, 0, 10, 0));
    g.update(.01);
    final droneShots = g.shots.where((s) => s.weapon == 'drone');
    expect(droneShots, isNotEmpty);
    expect(droneShots.first.velocity.dy, greaterThan(0));
  });
  test(
    'random crowds and grouped waves use front-biased spawn distribution',
    () {
      for (final time in [1.0, 80.0, 120.0, 160.0]) {
        final counts = [0, 0, 0, 0];
        for (int seed = 0; seed < 600; seed++) {
          final g = createGame(seed)..elapsed = time;
          g.update(.001);
          for (final e in g.enemies) {
            final p = e.position - g.camera;
            final side = p.dy < 0
                ? 0
                : p.dx > 420
                ? 1
                : p.dy > g.viewportHeight
                ? 2
                : 3;
            counts[side]++;
          }
        }
        final total = counts.reduce((a, b) => a + b);
        expect(counts[0] / total, inInclusiveRange(.74, .86));
        expect(counts[1] / total, inInclusiveRange(.03, .13));
        expect(counts[3] / total, inInclusiveRange(.03, .13));
        expect(counts[2] / total, inInclusiveRange(.01, .08));
      }
    },
  );
}
