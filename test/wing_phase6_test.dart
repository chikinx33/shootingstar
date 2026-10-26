import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/data/enemy_doctrine.dart' show EnemyFlight;

GameEngine arena({Offset? at, double viewport = 720, int stage = 0}) =>
    GameEngine(
        stageIndex: stage,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 73,
      )
      ..position = at ?? const Offset(900, 1680)
      ..viewportHeight = viewport
      ..hp = 100000
      ..maxHp = 100000
      ..xpNeeded = 1e9
      ..upgrades.clear();
List<Foe> spawn(GameEngine g, FlightFormation pattern) {
  for (var i = 0; i < 1100; i++) {
    g.update(.05);
    g.enemies.removeWhere((e) => e.formationPattern != pattern);
    final group = g.enemies
        .where((e) => e.formationPattern == pattern)
        .toList();
    if (group.isNotEmpty) {
      g.shots.clear();
      return group;
    }
  }
  throw StateError('Formation never spawned: $pattern');
}

void advance(GameEngine g, double seconds) {
  for (var t = 0.0; t < seconds; t += .02) {
    g.update(.02);
    g.enemies.removeWhere((e) => e.formationPattern == null);
  }
}

void strike(
  GameEngine g,
  Foe target, {
  String source = 'gun',
  double damage = 100,
}) {
  g.shots.add(Shot(target.position, Offset.zero, damage, 0, weapon: source));
  g.update(.001);
}

void main() {
  test('natural schedule includes four readable formation types without overlapping groups or free rewards', () {
    final g = arena();
    final seen = <FlightFormation>{};
    var shield = false,
        vent = false,
        tell = false,
        charge = false,
        fire = false;
    for (var i = 0; i < 1150; i++) {
      g.update(.05);
      g.enemies.removeWhere((e) => e.formationPattern == null);
      final groups = g.enemies.map((e) => e.formationId).toSet();
      expect(groups.length, lessThanOrEqualTo(1));
      for (final e in g.enemies) {
        seen.add(e.formationPattern!);
        shield |= g.formationShieldActive(e);
        vent |=
            e.formationPattern == FlightFormation.bulwark &&
            e.phase > 2.7 &&
            e.phase < 3.3;
        tell |= e.formationPattern == FlightFormation.assault && e.tell > 0;
        charge |=
            e.formationPattern == FlightFormation.assault &&
            e.flight == EnemyFlight.attackRun;
      }
      fire |= g.shots.any((s) => s.hostile);
      expect(g.enemies.length, lessThanOrEqualTo(g.enemyLimit));
      expect(
        g.shots.where((s) => s.hostile).length,
        lessThanOrEqualTo(g.hostileShotLimit),
      );
    }
    expect(seen, FlightFormation.values.toSet());
    expect(shield && vent && tell && charge && fire, true);
    expect(g.kills, 0);
    expect(g.crystals, isEmpty);
  });
  for (final pattern in [FlightFormation.bulwark, FlightFormation.assault]) {
    test(
      '$pattern spawns with reachable destinations, minimum clearance and fixed route at every world edge',
      () {
        for (final viewport in [360.0, 720.0])
          for (final at in [
            const Offset(32, 32),
            const Offset(1768, 32),
            const Offset(32, 2368),
            const Offset(1768, 2368),
          ]) {
            final g = arena(at: at, viewport: viewport);
            final group = spawn(g, pattern);
            expect(group.length, pattern == FlightFormation.bulwark ? 3 : 4);
            for (final e in group) {
              final destination = e.formationDestination!;
              expect(
                destination.dx,
                inInclusiveRange(32, GameEngine.worldWidth - 32),
              );
              expect(
                destination.dy,
                inInclusiveRange(32, GameEngine.worldHeight - 32),
              );
              expect((destination - at).distance, greaterThanOrEqualTo(130));
              expect(e.phase, lessThan(1.25));
              expect(g.formationContactActive(e), false);
            }
          }
      },
    );
    test(
      '$pattern freezes phase, warnings, movement and formation timers during pause and choices',
      () {
        final g = arena();
        final e = spawn(g, pattern).first;
        advance(g, 1.4);
        final phase = e.phase,
            at = e.position,
            tell = e.tell,
            time = g.combatTime;
        g.setPaused(true);
        advance(g, 3);
        g.setPaused(false);
        g.choices = [GameEngine.catalog.first];
        advance(g, 3);
        g.choices.clear();
        expect(e.phase, phase);
        expect(e.position, at);
        expect(e.tell, tell);
        expect(g.combatTime, time);
        g.update(.02);
        expect(e.phase, greaterThan(phase));
      },
    );
    test(
      '$pattern retires without kills, XP or rewards and boss transition removes it',
      () {
        final g = arena();
        spawn(g, pattern);
        advance(g, pattern == FlightFormation.bulwark ? 9 : 7);
        expect(g.enemies.where((e) => e.formationPattern == pattern), isEmpty);
        expect(g.kills, 0);
        expect(g.crystals, isEmpty);
        final boss = arena();
        spawn(boss, pattern);
        boss.elapsed = boss.nextBossAt - .01;
        boss.update(.02);
        expect(boss.boss, isNotNull);
        expect(boss.enemies.any((e) => e.formationPattern != null), false);
        expect(boss.shots.any((s) => s.hostile), false);
      },
    );
  }
  test('frontal guards reduce actual main damage, side and auxiliary fire bypass, vent removes both guard and leader protection', () {
    final g = arena();
    final group = spawn(g, FlightFormation.bulwark);
    final leader = group.firstWhere((e) => e.formationOrder == 0),
        guard = group.firstWhere((e) => e.formationOrder == 1);
    for (final e in group) {
      e.phase = 1.5;
      e.position = e.formationDestination!;
      e.hp = e.maxHp = 10000;
    }
    var hp = guard.hp;
    strike(g, guard);
    expect(hp - guard.hp, closeTo(45, .001));
    hp = leader.hp;
    strike(g, leader);
    expect(hp - leader.hp, closeTo(70, .001));
    hp = guard.hp;
    strike(g, guard, source: 'missile');
    expect(hp - guard.hp, closeTo(100, .001));
    hp = guard.hp;
    strike(g, guard, source: 'common-ultimate');
    expect(hp - guard.hp, closeTo(100, .001));
    final original = g.position;
    g.position = guard.position + const Offset(-220, 0);
    hp = guard.hp;
    strike(g, guard);
    expect(hp - guard.hp, closeTo(100, .001));
    g.position = original;
    for (final e in group) e.phase = 2.9;
    expect(g.formationCue, contains('방패 재정비'));
    hp = guard.hp;
    strike(g, guard);
    expect(hp - guard.hp, closeTo(100, .001));
    hp = leader.hp;
    strike(g, leader);
    expect(hp - leader.hp, closeTo(100, .001));
  });
  test('destroying or separating live guards removes cover without stacking armor and awards only actual kills', () {
    final g = arena();
    final group = spawn(g, FlightFormation.bulwark);
    for (final e in group) {
      e.phase = 1.5;
      e.position = e.formationDestination!;
    }
    final leader = group.first, guards = group.skip(1).toList();
    expect(g.formationCovered(leader), true);
    guards[0].position += const Offset(-160, 0);
    guards[1].position += const Offset(160, 0);
    expect(g.formationCovered(leader), false);
    for (final e in guards) e.position = e.formationDestination!;
    strike(g, guards[0], source: 'missile', damage: 1000);
    expect(g.kills, 1);
    expect(g.formationCovered(leader), true);
    strike(g, guards[1], source: 'missile', damage: 1000);
    expect(g.kills, 2);
    expect(g.formationCovered(leader), false);
    expect(g.formationCue, contains('호위 해제'));
    expect(g.crystals.length, lessThanOrEqualTo(2));
  });
  test('assault route is parallel and frozen, leaves a central passage and never fires extra hostile projectiles', () {
    final g = arena();
    final origin = g.position;
    final group = spawn(g, FlightFormation.assault);
    final aims = group.map((e) => e.aim).toList(),
        points = group.map((e) => e.targetPoint).toList();
    final xs = group.map((e) => e.formationDestination!.dx).toSet().toList()
      ..sort();
    expect(xs.length, 2);
    expect(xs.last - xs.first, 140);
    expect((xs.first + xs.last) / 2, origin.dx);
    g.position += const Offset(170, 0);
    advance(g, 2.4);
    for (var i = 0; i < group.length; i++) {
      expect(group[i].aim, aims[i]);
      expect(group[i].targetPoint, points[i]);
      expect(group[i].flight, EnemyFlight.attackRun);
      expect(group[i].tell, 0);
    }
    expect(g.shots.where((s) => s.hostile), isEmpty);
  });
  test('assault warns before contact damage, hits once on collision, then retires without rewards', () {
    final g = arena();
    final group = spawn(g, FlightFormation.assault);
    final e = group.first;
    for (final foe in group) {
      foe.phase = 1.5;
      foe.position = foe.formationDestination!;
    }
    g.position = e.position;
    final hp = g.hp;
    g.update(.001);
    expect(g.hp, hp);
    expect(e.retired, false);
    expect(e.tell, greaterThan(0));
    e.phase = 2.3;
    g.update(.001);
    expect(g.hp, lessThan(hp));
    expect(e.retired, true);
    expect(g.enemies.contains(e), false);
    expect(g.kills, 0);
    expect(g.crystals, isEmpty);
  });
  test('assault slowing affects movement and later worlds remain bounded at six hulls', () {
    final distances = <double>[];
    for (final slow in [false, true]) {
      final g = arena();
      final group = spawn(g, FlightFormation.assault);
      final e = group.first;
      e.phase = 2.3;
      e.position = e.formationDestination!;
      final at = e.position;
      if (slow) {
        e.status = 2;
        e.statusTime = 1;
      }
      g.update(.02);
      distances.add((e.position - at).distance);
    }
    expect(distances.last, closeTo(distances.first * .55, .001));
    final g = arena(stage: 90);
    expect(spawn(g, FlightFormation.assault).length, 6);
  });
  test('full capacity and imminent bosses defer both new formations without partial groups', () {
    final g = arena();
    g.enemies.addAll([
      for (var i = 0; i < g.enemyLimit; i++)
        Foe(g.position + const Offset(0, -250), 100000, 0, 1, 0),
    ]);
    for (var i = 0; i < 400; i++) g.update(.05);
    expect(g.enemies.length, g.enemyLimit);
    expect(g.enemies.any((e) => e.formationPattern != null), false);
    final boss = arena()..elapsed = 55;
    advance(boss, 1);
    expect(boss.enemies.any((e) => e.formationPattern != null), false);
  });
}
