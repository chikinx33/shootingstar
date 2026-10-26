import 'package:flutter_test/flutter_test.dart';

import 'package:shootingstar/data/aircraft_assembly.dart';

import 'support/run_driver.dart';

import 'dart:math' as math;

import 'package:shootingstar/game/engine.dart';

GameEngine makeGame({int stage = 0}) => GameEngine(
  stageIndex: stage,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 8,
);
void main() {
  test(
    'camera keeps player centered at every arena corner and aspect ratio',
    () {
      final game = makeGame();
      for (final height in [720.0, 909.0, 1100.0]) {
        game.viewportHeight = height;
        for (final position in [
          const Offset(32, 32),
          const Offset(1768, 32),
          const Offset(32, 2368),
          const Offset(1768, 2368),
          const Offset(900, 1200),
        ]) {
          game.position = position;
          expect(game.position - game.camera, Offset(210, height / 2));
          final previousCamera = game.camera;
          game.position += const Offset(17, -23);
          expect(game.camera - previousCamera, const Offset(17, -23));
        }
      }
    },
  );
  test('meta effects match hangar descriptions', () {
    final baseline = makeGame();
    final upgraded = GameEngine(
      stageIndex: 0,
      shipIndex: 0,
      attackLevel: 2,
      hullLevel: 2,
      magnetLevel: 2,
      equipmentIndex: 0,
    );
    expect(upgraded.damageFactor / baseline.damageFactor, closeTo(1.16, .0001));
    expect(upgraded.maxHp / baseline.maxHp, closeTo(1.24, .0001));
    expect(
      upgraded.collectionRadius / baseline.collectionRadius,
      closeTo(48 / 42, .0001),
    );
  });
  test('pause and upgrade choice freeze complete combat state', () {
    final game = makeGame(stage: 1)..elapsed = 12;
    game.position = const Offset(900, 1200);
    game.enemies.add(Foe(game.position, 500, 40, 30, 3));
    game.shots.add(Shot(game.position, const Offset(0, 50), 10, 4));
    game.sparks.add(Spark(game.position, const Offset(10, 0), 1, 0));
    game.crystals.add(game.position + const Offset(20, 0));
    void expectFrozen() {
      final elapsed = game.elapsed, hp = game.hp;
      final foePosition = game.enemies.first.position;
      final shotLife = game.shots.first.life;
      final sparkLife = game.sparks.first.life;
      final crystal = game.crystals.first;
      final count = game.enemies.length;
      for (int i = 0; i < 200; i++) {
        game.update(.05);
      }
      expect(game.elapsed, elapsed);
      expect(game.hp, hp);
      expect(game.enemies.first.position, foePosition);
      expect(game.shots.first.life, shotLife);
      expect(game.sparks.first.life, sparkLife);
      expect(game.crystals.first, crystal);
      expect(game.enemies.length, count);
    }

    game.setPaused(true);
    expectFrozen();
    game.setPaused(false);
    game.choices = [GameEngine.catalog.first];
    expectFrozen();
  });
  // v12.4.1: a draft opens only when a gem reaches the cat. v12.5.2: banked
  // experience that still fills the gauge after a choice opens the next draft
  // at once, so a large surplus chains drafts until it no longer fills a level.
  test('large XP chains drafts on a gem pickup and banks the remainder', () {
    final game = makeGame()..xp = 200;
    game.crystals.add(game.position);
    game.update(.05);
    final elapsed = game.elapsed;
    int selections = 0;
    while (game.choices.isNotEmpty) {
      expect(game.choices.length, 3);
      game.chooseUpgrade(game.choices.first.id);
      selections++;
      expect(game.elapsed, elapsed);
      expect(selections, lessThan(15));
    }
    // 202 XP: level 2 costs 60, level 3 costs 60 + 2 * 16 = 92, leaving 50
    // below the 108 needed for level 4.
    expect(selections, 2);
    expect(game.level, 3);
    expect(game.xp, closeTo(50, .001));
    expect(game.xp, lessThan(game.xpNeeded));
  });
  test('simultaneous player and boss death always awards defeat', () {
    for (int stage = 0; stage < 3; stage++) {
      final game = makeGame(stage: stage)..elapsed = 1000;
      game.update(.01);
      game.enemies.removeWhere((e) => e.kind != 3);
      game.boss!.hp = 1;
      game.bossesDefeated = 2;
      game.upgrades.clear();
      game.update(
        .01,
      ); // Enter the final hull section before the lethal exchange.
      game.bossCycle = 3.3;
      game.boss!.position = game.position;
      game.hp = 1;
      game.shots.add(Shot(game.position, Offset.zero, 100, 0));
      game.update(.01);
      expect(game.finished, isTrue);
      expect(game.victory, isFalse);
      expect(game.hp, 0);
      expect(game.boss, isNull);
    }
  });
  test('starter modular flight with projectile avoidance across three stages', () {
    for (int stage = 0; stage < 3; stage++) {
      int wins = 0;
      final summaries = <String>[];
      for (int seed = 0; seed < 3; seed++) {
        final game = GameEngine(
          stageIndex: stage,
          shipIndex: 0,
          aircraft: AircraftAssembly.initial(0),
          attackLevel: stage,
          hullLevel: stage,
          magnetLevel: 0,
          equipmentIndex: 0,
          gearDamage: stage * .03,
          gearHull: stage * .03,
          seed: seed,
        );
        for (
          int frame = 0;
          frame < (game.duration + 180) * 20 && !game.finished;
          frame++
        ) {
          if (game.choices.isNotEmpty) {
            final choices = [...game.choices];
            choices.sort((a, b) {
              return choiceScore(game, b).compareTo(choiceScore(game, a));
            });
            game.chooseUpgrade(choices.first.id);
          }
          game.input = steer(game);
          game.update(.05);
        }
        if (game.victory) wins++;
        summaries.add(
          'seed=$seed won=${game.victory} t=${game.elapsed.toStringAsFixed(1)} hp=${game.hp.toStringAsFixed(0)} level=${game.level} kills=${game.kills}',
        );
      }
      // Evidence, not a human-play certification; no HP or combat cheats used.
      // ignore: avoid_print
      print('STARTER stage=$stage wins=$wins/3 ${summaries.join('; ')}');
      expect(
        wins,
        greaterThan(0),
        reason:
            'A moving account with prior-stage upgrades must have a viable path through stage $stage',
      );
    }
  });
  test('pause, invalid delta and level choice freeze time', () {
    final game = makeGame();
    game.setPaused(true);
    game.update(.05);
    expect(game.elapsed, 0);
    game.setPaused(false);
    game.update(double.nan);
    expect(game.elapsed, 0);
    game.xp = game.xpNeeded;
    // Drafts open when a gem reaches the cat (v12.4.1).
    game.crystals.add(game.position);
    game.update(.05);
    expect(game.choices.length, 3);
    final time = game.elapsed;
    game.update(.05);
    expect(game.elapsed, time);
    game.chooseUpgrade('unknown');
    expect(game.choices.length, 3);
    game.chooseUpgrade(game.choices.first.id);
    expect(game.choices, isEmpty);
    game.update(.05);
    expect(game.elapsed, greaterThan(time));
  });
  test('movement remains in arena while ship faces forward', () {
    final game = makeGame()..input = const Offset(100, 100);
    for (int i = 0; i < 300; i++) {
      game.update(.05);
    }
    expect(game.position.dx, inInclusiveRange(32, GameEngine.worldWidth - 32));
    expect(game.position.dy, inInclusiveRange(32, GameEngine.worldHeight - 32));
    expect(game.angle, -math.pi / 2);
  });
  test(
    'main gun hits front, leaves rear target alone, and projectiles expire',
    () {
      final game = makeGame();
      final rear = Foe(game.position + const Offset(0, 70), 20, 0, 12, 0);
      game.enemies.add(rear);
      game.enemies.add(Foe(game.position + const Offset(0, -70), 20, 0, 12, 0));
      for (int i = 0; i < 45; i++) {
        game.update(.05);
      }
      expect(game.kills, greaterThan(0));
      expect(rear.hp, 20);
      expect(game.shots.length, lessThan(50));
    },
  );
  test('boss defeat and survival finish with victory exactly once', () {
    final game = makeGame();
    int wins = 0;
    game.onEvent = (event) {
      if (event == 'victory') wins++;
    };
    for (int wave = 1; wave <= game.requiredBosses; wave++) {
      game.choices = [];
      game.elapsed = game.duration * wave / game.requiredBosses;
      game.update(.05);
      expect(game.boss, isNotNull);
      game.boss!.hp = 0;
      game.update(.05);
      expect(game.finished, isFalse);
      while (game.resolvingBoss && !game.finished) {
        game.update(.05);
      }
    }
    game.choices = [];
    game.elapsed = game.duration;
    game.update(.05);
    expect(game.victory, isTrue);
    expect(game.finished, isTrue);
    game.update(.05);
    expect(wins, game.requiredBosses);
  });
  test('contact damage causes defeat, abandon is terminal', () {
    final game = makeGame()..hp = 1;
    game.enemies.add(Foe(game.position, 999, 0, 20, 2));
    game.update(.05);
    expect(game.finished, isTrue);
    expect(game.victory, isFalse);
    final another = makeGame()..abandon();
    another.update(.05);
    expect(another.elapsed, 0);
  });
  test('all stage timelines and evolved weapons stay bounded', () {
    for (int stage = 0; stage < 3; stage++) {
      final game = makeGame(stage: stage);
      game.upgrades.addAll({
        'gun': 5,
        'missile': 5,
        'drone': 5,
        'side': 5,
        'mine': 5,
        'trail': 5,
      });
      game.evolved.addAll(game.upgrades.keys);
      for (
        int frame = 0;
        frame < (game.duration + 180) * 20 && !game.finished;
        frame++
      ) {
        // Isolate resource lifetime and complete timelines from player survival.
        game.hp = game.maxHp;
        if (game.choices.isNotEmpty) game.chooseUpgrade(game.choices.first.id);
        game.input = game.crystals.isEmpty
            ? Offset.zero
            : game.crystals.first - game.position;
        game.update(.05);
        expect(game.enemies.length, lessThanOrEqualTo(game.enemyLimit));
        expect(game.shots.length, lessThan(500));
        expect(game.sparks.length, lessThanOrEqualTo(161));
        expect(game.position.dx.isFinite && game.position.dy.isFinite, isTrue);
      }
      expect(
        game.victory,
        isTrue,
        reason: 'stage $stage can finish after boss defeat',
      );
      expect(game.kills, greaterThan(30));
    }
  });
}
