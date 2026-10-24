import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/battle_painter.dart';
import 'package:shootingstar/game/resolution_vfx.dart';

GameEngine arena({int stage = 0}) => GameEngine(
  stageIndex: stage,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 623,
)..developerInvincible = true;
void tick(GameEngine g, double seconds) {
  for (var i = 0; i < (seconds / .025).ceil(); i++) {
    g.update(.025);
  }
}

void killBoss(GameEngine g) {
  g.elapsed = g.nextBossAt;
  g.update(.001);
  expect(g.boss, isNotNull);
  g.boss!.hp = 0;
  g.update(.001);
}

void main() {
  test('simultaneous magnet and evolution chest wait for the full absorption in either pickup order', () {
    for (final order in [
      [1, 3],
      [3, 1],
    ]) {
      final g = arena()..xpNeeded = 1e9;
      g.upgrades.addAll({'missile': 5, 'laser': 5});
      g.passives.addAll({'area': 1, 'armor': 1});
      g.crystals.addAll(
        List.generate(20, (i) => g.position + Offset(200, -150.0 - i)),
      );
      g.supplies.addAll([for (final kind in order) Supply(g.position, kind)]);
      g.update(.01);
      expect(g.collectingMagnet, true);
      expect(g.chests, 0);
      expect(g.choices, isEmpty);
      while (g.collectingMagnet) {
        expect(g.choices, isEmpty);
        g.update(.025);
      }
      expect(g.chests, 1);
      expect(g.chestSelection, true);
      expect(g.choices.length, 2);
      expect(g.xp, 40);
    }
  });
  test(
    'magnet awards exact XP on arrival and defers choices through final glow',
    () {
      final g = arena()..upgrades.clear();
      g.xpNeeded = 10;
      g.passives['xp'] = 2;
      g.crystals.addAll(
        List.generate(
          31,
          (i) => g.position + Offset(i * 12 - 180, -170.0 - i * 2),
        ),
      );
      g.supplies.add(Supply(g.position, 1));
      g.update(.01);
      expect(g.xp, 0);
      expect(g.absorbingCrystals.length, 31);
      expect(g.choices, isEmpty);
      final origin = g.absorbingCrystals.first.position;
      tick(g, .2);
      expect(g.absorbingCrystals.first.position, isNot(origin));
      expect(g.choices, isEmpty);
      while (g.absorbingCrystals.isNotEmpty) {
        g.update(.025);
        expect(
          g.choices,
          isEmpty,
          reason: 'last arrival must be visible before the overlay',
        );
      }
      expect(g.collectingMagnet, true);
      expect(g.xp, closeTo(31 * 2 * 1.16, 1e-8));
      tick(g, .25);
      expect(g.choices.length, 3);
      expect(g.level, 2);
      expect(g.xp, closeTo(31 * 2 * 1.16 - 10, 1e-8));
    },
  );
  test('repeated magnets and a large batch never lose or duplicate XP', () {
    final g = arena()..xpNeeded = 1e9;
    g.crystals.addAll(
      List.generate(
        2000,
        (i) => g.position + Offset(100 + i % 40 * 3.0, i % 51 * -3.0),
      ),
    );
    g.supplies.add(Supply(g.position, 1));
    g.update(.01);
    tick(g, .1);
    g.crystals.addAll(
      List.generate(5, (i) => g.position + Offset(100.0 + i, -100)),
    );
    g.supplies.add(Supply(g.position, 1));
    g.update(.01);
    g.setPaused(true);
    final age = g.absorbingCrystals.first.age;
    tick(g, 1);
    expect(g.absorbingCrystals.first.age, age);
    g.setPaused(false);
    tick(g, 1.8);
    expect(g.absorbingCrystals, isEmpty);
    expect(g.xp, 4010);
  });
  test('boss clear freezes threats, breaks up, announces, exits, then finishes once', () {
    final g = arena(stage: 9);
    var clears = 0;
    g.onEvent = (event) {
      if (event == 'victory') clears++;
    };
    for (var i = 0; i < g.requiredBosses; i++) {
      killBoss(g);
      final scene = g.bossResolution!;
      final hp = g.hp, time = g.elapsed;
      expect(g.finished, false);
      expect(g.shots, isEmpty);
      g.input = const Offset(0, -1);
      tick(g, 1);
      expect(scene.bursts, greaterThan(3));
      expect(g.elapsed, time);
      expect(g.hp, hp);
      g.setPaused(true);
      final pausedAt = scene.time;
      tick(g, .5);
      expect(scene.time, pausedAt);
      g.setPaused(false);
      tick(g, 1.8);
      expect(scene.time, greaterThan(BossResolution.clearAt));
      expect(g.finished, false);
      if (scene.finalBoss) {
        tick(g, 1.2);
        expect(scene.departure, greaterThan(0));
        expect(g.finished, false);
        tick(g, 1.6);
        expect(ResolutionVfx.heroPosition(g).dy, lessThan(g.camera.dy - 50));
        expect(g.finished, true);
        expect(g.victory, true);
      } else {
        tick(g, .7);
        expect(g.resolvingBoss, false);
        expect(g.finished, false);
        expect(g.supplies.any((s) => s.kind == 3), true);
      }
    }
    tick(g, 3);
    expect(g.bossesDefeated, g.requiredBosses);
    expect(clears, g.requiredBosses);
  });
  test(
    'boss fragments and reduced effects render without altering game or RNG',
    () async {
      final g = arena();
      killBoss(g);
      for (final time in [.7, 2.05, 2.8]) {
        g.bossResolution!.time = time;
        for (final reduced in [false, true]) {
          final recorder = PictureRecorder();
          final before = g.elapsed;
          BattlePainter(
            g,
            reducedEffects: reduced,
          ).paint(Canvas(recorder), const Size(420, 720));
          final picture = recorder.endRecording();
          final image = await picture.toImage(420, 720);
          expect(image.width, 420);
          expect(g.elapsed, before);
          image.dispose();
          picture.dispose();
        }
      }
    },
  );
  test('magnet arrivals continue during final destruction and count in result level', () {
    final g = arena();
    g.xpNeeded = 10;
    g.crystals.addAll(
      List.generate(30, (i) => g.position + Offset(200, -100.0 - i)),
    );
    g.supplies.add(Supply(g.position, 1));
    g.update(.001);
    expect(g.collectingMagnet, true);
    killBoss(g);
    tick(g, 5.5);
    expect(g.finished, true);
    expect(g.absorbingCrystals, isEmpty);
    expect(g.level, 3);
    expect(g.xp, 12);
    expect(g.choices, isEmpty);
  });
}
