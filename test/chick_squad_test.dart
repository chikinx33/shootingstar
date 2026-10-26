import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/content_catalog.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';

/// v12.17 chick tail squad (user 2026-10-27).
GameEngine field(List<ChickLoadout> roster) => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: -1,
  chickRoster: roster,
  seed: 5,
)..xpNeeded = 1e9;

/// Steps the field with no enemies so only the squad acts.
void step(GameEngine g, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    g.enemies.clear();
    g.update(1 / 60);
  }
}

Chick released(GameEngine g) {
  g.squad.clock = ChickSquad.firstAt;
  step(g, 1 / 60);
  return g.squad.chicks.single;
}

void main() {
  test(
    'the run starts with no chicks; deployed cards appear to be rescued',
    () {
      final g = field(const [ChickLoadout(0), ChickLoadout(4)]);
      step(g, 2);
      expect(g.squad.chicks, isEmpty);
      final c = released(g);
      expect(c.state, ChickState.waiting);
      expect(g.squad.tail, isEmpty);
    },
  );

  test('the rescue gauge fills near, pauses far, and the chick joins', () {
    final g = field(const [ChickLoadout(0)]);
    final c = released(g);
    g.position = c.position + const Offset(40, 0);
    step(g, .75);
    expect(c.inReach, isTrue);
    expect(c.rescue, closeTo(.5, .05));
    g.position = c.position + const Offset(0, 300);
    step(g, .5);
    expect(c.inReach, isFalse, reason: 'the tether drops when too far');
    final kept = c.rescue;
    expect(kept, closeTo(.5, .05), reason: 'the gauge pauses, not resets');
    g.position = c.position + const Offset(30, 0);
    step(g, .9);
    expect(c.state, ChickState.tail);
    expect(g.squad.tail, [c]);
    expect(c.hp, c.maxHp);
  });

  test('the tail follows the path flown: circling makes a ring', () {
    final g = field(const [ChickLoadout(0), ChickLoadout(1), ChickLoadout(2)]);
    for (var i = 0; i < 3; i++) {
      final c = released(g);
      g.squad.chicks.remove(c);
      g.squad.chicks.add(c);
      c.state = ChickState.tail;
      g.squad.tail.add(c);
      g.squad.clock = ChickSquad.firstAt + (i + 1) * ChickSquad.every - .01;
    }
    final center = g.position;
    for (var i = 0; i < 240; i++) {
      final a = i / 240 * math.pi * 4;
      g.position = center + Offset(math.cos(a), math.sin(a)) * 70;
      g.enemies.clear();
      g.update(1 / 60);
    }
    for (final c in g.squad.tail) {
      expect((c.position - center).distance, closeTo(70, 14));
    }
  });

  test('bodies block bullets, then the chick falls off and waits; a second '
      'rescue brings it back at half HP', () {
    final g = field(const [ChickLoadout(0), ChickLoadout(1)]);
    final c = released(g);
    g.position = c.position;
    step(g, 1.6);
    expect(c.state, ChickState.tail);
    var shots = 0;
    while (c.state == ChickState.tail && shots < 40) {
      g.shots.add(Shot(c.position, Offset.zero, 1, 4, life: 2));
      shots++;
      g.enemies.clear();
      g.update(1 / 60);
    }
    expect(c.state, ChickState.falling);
    expect(g.squad.blocked, greaterThanOrEqualTo(5));
    expect(g.squad.tail, isEmpty);
    step(g, 1.3);
    expect(c.state, ChickState.waiting);
    expect(c.rescuedBefore, isTrue);
    g.position = c.position;
    step(g, 1.6);
    expect(c.state, ChickState.tail);
    expect(c.hp, closeTo(c.maxHp * .5, .01));
  });

  test('the mirror chick sends blocked bullets back', () {
    final g = field(const [ChickLoadout(8)]);
    final c = released(g);
    g.position = c.position;
    step(g, 1.6);
    g.shots.add(Shot(c.position, Offset.zero, 1, 4, life: 2));
    g.enemies.clear();
    g.update(1 / 60);
    expect(g.squad.reflected, 1);
    expect(g.shots.any((s) => s.weapon == 'chick-mirror'), isTrue);
  });

  test('a starlight chick in the tail adds 15% experience', () {
    final g = field(const [ChickLoadout(7)]);
    expect(g.squad.xpFactor, 1);
    final c = released(g);
    g.position = c.position;
    step(g, 1.6);
    expect(g.squad.xpFactor, closeTo(1.15, .001));
  });

  test(
    'deploy cards: at most six, and old saves move their pets onto cards',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      for (var i = 0; i < petNames.length; i++) {
        p.petLevels[i] = 1;
      }
      p.deployedChicks
        ..clear()
        ..addAll([0, 1, 2, 3, 4, 5]);
      expect(p.toggleDeployChick(6), isFalse);
      expect(p.toggleDeployChick(2), isTrue);
      expect(p.deployedChicks, isNot(contains(2)));
      expect(p.toggleDeployChick(6), isTrue);
      expect(p.deployedChicks.length, maxDeployedChicks);
      // an older save: active pet 1 with helper 2, three kinds only
      await p.save();
      final prefs = await SharedPreferences.getInstance();
      final old = jsonDecode(
        prefs.getString(Profile.storageKey)!,
      ) as Map<String, dynamic>;
      (old['content'] as Map<String, dynamic>)
        ..remove('deployedChicks')
        ..['petLevels'] = [1, 3, 2]
        ..['activePet'] = 1
        ..['assistingPets'] = [2];
      await prefs.setString(Profile.storageKey, jsonEncode(old));
      final back = await Profile.load();
      expect(back.petLevels.length, petNames.length);
      expect(back.deployedChicks.take(2), [1, 2]);
      p.dispose();
      back.dispose();
    },
  );

  test('a rescue ticket brings home the next missing chick kind', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.petEggs = 2;
    final before = p.petLevels.where((l) => l > 0).length;
    expect(p.rescuePet(), isTrue);
    expect(p.petLevels.where((l) => l > 0).length, before + 1);
    p.dispose();
  });
}
