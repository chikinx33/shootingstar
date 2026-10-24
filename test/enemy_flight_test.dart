import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine arena() =>
    GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 42,
      )
      ..viewportHeight = 1000
      ..upgrades.clear()
      ..xpNeeded = 1e9
      ..hp = 100000
      ..maxHp = 100000;
void tick(GameEngine g, {Foe? only, bool clearShots = false}) {
  g.choices.clear();
  g.update(.02);
  if (only != null) g.enemies.removeWhere((e) => !identical(e, only));
  if (clearShots) g.shots.clear();
}

void main() {
  test(
    'every conventional role holds firing range and flees close contact',
    () {
      final rows = <Map<String, dynamic>>[];
      for (final role in EnemyRole.values.where(
        (r) => r != EnemyRole.kamikaze,
      )) {
        final g = arena();
        final e = Foe(
          g.position + const Offset(0, -400),
          100000,
          70,
          12,
          0,
          role: role,
        );
        g.enemies.add(e);
        double minDistance = 1000, settled = 0;
        for (int i = 0; i < 750; i++) {
          tick(g, only: e, clearShots: true);
          final d = (e.position - g.position).distance;
          minDistance = math.min(minDistance, d);
          if (i >= 500) settled += d / 250;
        }
        final range = enemyDoctrines[role]!.range;
        expect(minDistance, greaterThan(95), reason: role.name);
        expect(settled, inInclusiveRange(130, range + 75), reason: role.name);
        final initial = e.position;
        g.position = e.position + const Offset(0, 55);
        for (int i = 0; i < 100; i++) {
          tick(g, only: e, clearShots: true);
        }
        expect(
          (e.position - g.position).distance,
          greaterThan(95),
          reason: role.name,
        );
        expect(e.heading.isFinite, true);
        expect((e.position - initial).distance, greaterThan(45));
        rows.add({
          'role': role.name,
          'minimumDistance': minDistance,
          'settledMean': settled,
          'desired': range,
        });
      }
      Directory('tools/qa/evidence/flight-v6.1').createSync(recursive: true);
      File('tools/qa/evidence/flight-v6.1/ranges.json')
          .writeAsStringSync(jsonEncode(rows));
    },
  );

  test(
    'hostile families cannot damage enemies or enter friendly hit logic',
    () {
      for (int kind = 19; kind <= 24; kind++) {
        final g = arena();
        final at = g.position + const Offset(110, -160);
        final e = Foe(at, 100000, 0, 15, 0);
        g.enemies.add(e);
        g.shots.add(
          Shot(
            at,
            const Offset(0, 100),
            50,
            kind,
            anchor: at,
            life: 2,
            radius: 10,
          ),
        );
        tick(g, only: e);
        expect(e.hp, e.maxHp, reason: 'hostile $kind');
        expect(g.damageByWeapon, isEmpty);
      }
    },
  );

  test('guidance has a turn limit and stops tracking before expiry', () {
    for (final kind in [19, 20]) {
      final g = arena();
      final s = Shot(
        g.position + const Offset(-120, -160),
        const Offset(0, 140),
        8,
        kind,
        life: 4,
      );
      g.shots.add(s);
      final before = math.atan2(s.velocity.dy, s.velocity.dx);
      tick(g);
      final after = math.atan2(s.velocity.dy, s.velocity.dx);
      expect(
        (after - before).abs(),
        lessThanOrEqualTo((kind == 19 ? 1.25 : .85) * .02 + .00001),
      );
      s.age = 2;
      final locked = s.velocity;
      g.position += const Offset(200, -100);
      for (int i = 0; i < 10; i++) {
        tick(g);
      }
      expect(s.velocity, locked);
    }
  });

  test('grenade target locks during warning and dodging avoids detonation', () {
    final g = arena();
    final original = g.position;
    final e = Foe(
      original + const Offset(0, -240),
      100000,
      0,
      15,
      0,
      role: EnemyRole.spitter,
    )..attackClock = .9;
    g.enemies.add(e);
    tick(g, only: e);
    expect(e.targetPoint, original);
    expect(e.tell, greaterThan(0));
    g.position += const Offset(130, 0);
    Shot? grenade;
    for (int i = 0; i < 60; i++) {
      tick(g, only: e);
      for (final s in g.shots.where((s) => s.kind == 22)) {
        grenade = s;
      }
    }
    expect(grenade, isNotNull);
    expect(grenade!.anchor, original);
    final hp = g.hp;
    for (int i = 0; i < 90; i++) {
      tick(g, only: e);
    }
    expect(g.hp, hp);
  });

  test(
    'laser warns, locks aim, fires once, then respects cooldown and pause',
    () {
      final g = arena();
      final e = Foe(
        g.position + const Offset(0, -280),
        100000,
        0,
        15,
        0,
        role: EnemyRole.sniper,
      )..attackClock = 1.2;
      g.enemies.add(e);
      tick(g, only: e);
      final aim = e.aim;
      g.setPaused(true);
      final timer = e.attackClock;
      g.update(.05);
      expect(e.attackClock, timer);
      g.setPaused(false);
      g.position += const Offset(95, 0);
      int beams = 0;
      for (int i = 0; i < 240; i++) {
        tick(g, only: e);
        if (g.shots.any((s) => s.kind == 23)) beams++;
        if (i < 45) expect(e.aim, aim);
      }
      expect(beams, greaterThan(0));
      expect(beams, lessThan(25));
      expect(g.hp, g.maxHp);
    },
  );

  test('assault holds two telegraphed lanes, heading and no free kills', () {
    final g = arena();
    for (int i = 0; i < 901; i++) {
      tick(g);
    }
    final line =
        g.enemies
            .where((e) => e.formationPattern == FlightFormation.assault)
            .toList()
          ..sort((a, b) => a.formationOrder.compareTo(b.formationOrder));
    expect(line.length, 4);
    expect(line.map((e) => e.formationId).toSet().length, 1);
    final aim = line.first.aim;
    final lanes = line.map((e) => e.formationDestination!.dx).toSet().toList()
      ..sort();
    expect(lanes.length, 2);
    expect(lanes.last - lanes.first, closeTo(140, .01));
    for (final x in lanes) {
      final lane = line.where((e) => e.formationDestination!.dx == x).toList();
      expect(lane.length, 2);
      expect(
        (lane[0].formationDestination!.dy - lane[1].formationDestination!.dy)
            .abs(),
        closeTo(32, .01),
      );
    }
    g.position += const Offset(200, 0);
    for (int i = 0; i < 50; i++) {
      tick(g);
    }
    for (final e in line) {
      expect(e.aim, aim);
    }
    final isolated = arena();
    final ram = Foe(
      isolated.position - const Offset(0, 20),
      10,
      0,
      11,
      0,
      role: EnemyRole.kamikaze,
    )..aim = const Offset(0, 1);
    isolated.enemies.add(ram);
    tick(isolated);
    expect(isolated.enemies.contains(ram), false);
    expect(isolated.hp, lessThan(isolated.maxHp));
    expect(isolated.kills, 0);
    expect(isolated.crystals, isEmpty);
  });

  test(
    'all hostile families clear on boss transition; shield intercepts missiles',
    () {
      final g = arena();
      for (final kind in [4, 17, 19, 20, 21, 22, 23, 24]) {
        g.shots.add(
          Shot(g.position + const Offset(100, 0), Offset.zero, 9, kind),
        );
      }
      g.elapsed = g.nextBossAt;
      tick(g);
      expect(g.shots.where((s) => s.hostile), isEmpty);
      final shield = arena()
        ..upgrades['guardian'] = 5
        ..evolved.add('guardian');
      shield.shots.add(
        Shot(shield.position + const Offset(35, 0), Offset.zero, 9, 20),
      );
      tick(shield);
      expect(shield.shots.where((s) => s.kind == 20), isEmpty);
    },
  );
}
