import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

import 'module_campaign_run_test.dart' as run;

void main() {
  test('R P N pickups preserve drafted main levels and independent growth after resume', () {
    final g = run.campaignGame(0, 1, 'guns', 11);
    g.upgrades['gun'] = 4;
    for (final kind in [4, 5, 6]) {
      g.supplies.add(Supply(g.position, kind));
      g.update(.01);
      expect(g.upgrades['gun'], 4);
    }
    expect([g.mainRate, g.mainPower, g.mainCount], [1, 1, 1]);
    final copy = BattleCheckpoint.restore(
      jsonDecode(jsonEncode(g.checkpoint())),
    );
    copy.supplies.add(Supply(copy.position, 4));
    copy.update(.01);
    expect(copy.upgrades['gun'], 4);
    expect(copy.mainRate, 2);
  });

  test('shield hits including absorbed hits postpone recharge for six combat seconds across resume', () {
    var g = run.campaignGame(0, 30, 'guns', 11, defense: true)
      ..legacyArena = true;
    g.update(.001);
    g.enemies.clear();
    g.shots.clear();
    final data = g.checkpoint();
    for (final key in ['_spawn', '_formationClock', '_flightFormationClock']) {
      (data['state'] as Map)[key] = 10000.0;
    }
    g = BattleCheckpoint.restore(data);
    g.moduleShield = 50;
    g.shots.add(Shot(g.position, Offset.zero, 5, 4));
    g.update(.025);
    expect(g.moduleShield, closeTo(45, .001));
    expect(g.hp, g.maxHp);
    final copy = BattleCheckpoint.restore(
      jsonDecode(jsonEncode(g.checkpoint())),
    );
    for (final game in [g, copy]) {
      for (var i = 0; i < 118; i++) game.update(.05);
      expect(game.moduleShield, lessThanOrEqualTo(45));
      for (var i = 0; i < 4; i++) game.update(.05);
      expect(game.moduleShield, greaterThan(45));
    }
    expect(copy.moduleShield, closeTo(g.moduleShield, .001));
  });

  test(
    'support recovery uses base hull instead of multiplying frame HP growth',
    () {
      final g = run.campaignGame(
        0,
        30,
        'guns',
        11,
        defense: true,
        support: 'repair',
      )..legacyArena = true;
      g.hp -= 100;
      final before = g.hp;
      g.update(.001);
      final power = g.moduleLoadout!.supportPower('repair');
      expect(g.hp - before, closeTo(g.ship.health * .018 * power, .001));
      expect(g.maxHp, greaterThan(g.ship.health * 2));
      final s = run.campaignGame(0, 30, 'guns', 11, defense: true)
        ..legacyArena = true;
      s.update(.001);
      expect(
        s.moduleShield,
        closeTo(
          s.ship.health * .025 * s.moduleLoadout!.supportPower('shield'),
          .001,
        ),
      );
    },
  );

  test('first draft waits eight real combat seconds and pause does not advance growth', () {
    final g = run.campaignGame(0, 1, 'starter', 11)..xp = 100;
    g.setPaused(true);
    for (var i = 0; i < 200; i++) g.update(.05);
    expect(g.combatTime, 0);
    g.setPaused(false);
    for (var i = 0; i < 159; i++) g.update(.05);
    expect(g.choices, isEmpty);
    g.update(.05);
    g.update(.001);
    expect(g.level, 2);
    expect(g.choices, isNotEmpty);
  });
}
