import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine arena(int stage, int loop, {double reduction = 0}) => GameEngine(
  stageIndex: stage,
  campaignLoop: loop,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 33,
  damageReduction: reduction,
)..upgrades.clear();

void main() {
  test('boss contact, environment and ordnance share one bounded threat factor', () {
    for (final stage in [0, 49, 99]) {
      for (final loop in [0, 3, 9999]) {
        for (final source in ['boss', 'field', 'bullet']) {
          for (final reduction in [0.0, .4]) {
            final g = arena(stage, loop, reduction: reduction);
            g.hp = g.maxHp = 10000;
            if (source == 'boss') {
              g.enemies.add(Foe(g.position, 1e9, 0, 34, 3));
            } else if (source == 'bullet') {
              g.shots.add(Shot(g.position, Offset.zero, 10, 4));
            } else {
              g.elapsed = 10;
              g.update(.01);
              g.enemies.clear();
              g.shots.clear();
              g.elapsed = 13.1;
              // Deliberately enter the locked geometry after its 3-second tell.
              g.position =
                  g.hazardCenter +
                  (stage ~/ 10 == 9 ? const Offset(250, 0) : Offset.zero);
              if (!g.hazardHits(g.position)) {
                g.position = g.fields.first.a;
              }
              expect(g.hazardHits(g.position), true);
            }
            final before = g.hp;
            g.update(.01);
            final base = source == 'boss'
                ? 20
                : source == 'bullet'
                ? 10
                : stage ~/ 10 == 0
                ? 4
                : 7;
            expect(
              before - g.hp,
              closeTo(
                base * math.sqrt(g.threat).clamp(1, 3) * (1 - reduction),
                .00001,
              ),
              reason: '$stage/$loop/$source/$reduction applies threat once',
            );
            final after = g.hp;
            g.update(.01);
            expect(
              g.hp,
              after,
              reason: 'normal hit invulnerability is preserved',
            );
          }
        }
      }
    }
  });
  test('hostile mine reports its cause and never damages an enemy', () {
    final g = arena(99, 0);
    final foe = Foe(g.position + const Offset(60, 0), 1000, 0, 12, 0);
    g.enemies.add(foe);
    g.shots.add(
      Shot(
        g.position,
        Offset.zero,
        9,
        17,
        weapon: 'boss-mine',
        life: 2,
        radius: 80,
      )..age = 1.1,
    );
    g.update(.01);
    expect(g.lastDamageSource, '기뢰');
    expect(foe.hp, 1000);
    expect(g.damageByWeapon, isEmpty);
  });
}
