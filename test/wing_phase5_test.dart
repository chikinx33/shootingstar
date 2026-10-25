import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/combat_loadout.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle_statistics.dart';

GameEngine arena(
  String weapon, {
  MainBranch? branch,
  bool tech = false,
  bool precision = false,
  bool cycle = false,
  int level = 0,
}) =>
    GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        armament: weapon,
        armamentLevel: level,
        techRanks: tech ? {'gun': 2} : const {},
        mainPrecisionLink: precision,
        mainCycleLink: cycle,
        seed: 57,
      )
      ..mainBranch = branch
      ..xpNeeded = 1e9
      ..hp = 100000
      ..maxHp = 100000;
Foe foe(GameEngine g, double x, double y, {double hp = 100000}) =>
    Foe(g.position + Offset(x, y), hp, 0, 10, 0);
void advance(GameEngine g, double time) {
  for (var t = 0.0; t < time; t += .02) g.update(.02);
}

List<Shot> fire(GameEngine g) {
  g.update(.001);
  return g.shots.where((s) => !s.hostile).toList();
}

void main() {
  test('shield counter scales the whole evolved soul volley including the additive stack burst', () {
    for (final branch in [
      null,
      MainBranch.soulPierce,
      MainBranch.soulRelease,
    ]) {
      final scores = <double>[];
      for (final armed in [false, true]) {
        final g = arena('disorder', branch: branch, level: 10);
        g.upgrades.clear();
        g.upgrades['guardian'] = 3;
        g.passives['armor'] = 1;
        if (armed)
          g.shots.add(
            Shot(g.position + const Offset(0, -35), Offset.zero, 10, 4),
          );
        g.update(.001);
        g.enemies.clear();
        g.shots.clear();
        g.upgrades['gun'] = 1;
        g.soulStacks = 20;
        g.mainCount = 2;
        g.evolved.add('gun');
        final target = foe(g, 0, -80);
        g.enemies.add(target);
        final shots = fire(g);
        scores.add(
          shots.fold(0.0, (n, s) => n + s.damage) + target.maxHp - target.hp,
        );
        if (armed) expect(g.shieldCounterPending, false);
      }
      expect(scores.last, closeTo(scores.first * 1.5, .001), reason: '$branch');
    }
  });
  test('all added branches evolve from real R/P/N pickups and N adds actual firepower', () {
    for (final spec in mainBranches.skip(6)) {
      final g = arena(spec.armament, branch: spec.branch);
      for (final kind in [4, 4, 4, 5, 5, 5, 6, 6]) {
        g.supplies.add(Supply(g.position, kind));
        g.update(.001);
      }
      expect(g.evolved, contains('gun'));
      expect(g.mainBranch, spec.branch);
      expect([g.mainRate, g.mainPower, g.mainCount], [3, 3, 2]);
      final values = <double>[];
      for (final count in [0, 2]) {
        final n = arena(spec.armament, branch: spec.branch)..mainCount = count;
        final target = foe(n, 0, -70);
        n.enemies.add(target);
        final shots = fire(n);
        values.add(
          shots.fold(0.0, (v, s) => v + s.damage) + target.maxHp - target.hp,
        );
      }
      expect(values.last, greaterThan(values.first), reason: spec.name);
    }
  });
  test('expanded maximum builds remain executable through crowd combat without uncontrolled actors', () {
    for (final spec in mainBranches.skip(6)) {
      final g =
          arena(
              spec.armament,
              branch: spec.branch,
              tech: true,
              precision: true,
              cycle: true,
              level: 10,
            )
            ..mainRate = 5
            ..mainPower = 5
            ..mainCount = 4;
      g.evolved.add('gun');
      g.passives['cooldown'] = 5;
      g.passives['area'] = 5;
      g.enemies.addAll([
        for (var i = 0; i < 30; i++)
          foe(g, (i % 6 - 2.5) * 45, -70 - (i ~/ 6) * 45),
      ]);
      var peak = 0;
      for (var i = 0; i < 800; i++) {
        g.update(.02);
        if (g.shots.length > peak) peak = g.shots.length;
      }
      expect(g.finished, false, reason: spec.name);
      expect(peak, lessThan(1000), reason: spec.name);
      expect(
        g.damageByWeapon.values.fold(0.0, (n, d) => n + d),
        greaterThan(0),
        reason: spec.name,
      );
    }
  });
  test('all ten armaments offer exactly two exclusive branches and no persistent or skill-slot state', () {
    expect(mainBranches.length, 20);
    for (final a in armaments) {
      final g = arena(a.id)
        ..xpNeeded = 8
        ..xp = 8;
      // v12.4.1: a level-up only opens when a gem reaches the cat.
      g.crystals.add(g.position);
      g.update(.001);
      final pair = g.choices.where((c) => c.specialization).toList();
      expect(pair.length, 2, reason: a.id);
      final before = Map.of(g.upgrades);
      g.chooseUpgrade(pair.first.id);
      expect(g.mainBranchSpec!.id, pair.first.id);
      expect(g.upgrades, before);
      expect(g.passives, isEmpty);
      g.choices = [pair.last];
      g.chooseUpgrade(pair.last.id);
      expect(g.mainBranchSpec!.id, pair.first.id);
      expect(arena(a.id).mainBranch, isNull);
    }
  });
  for (final spec in mainBranches.skip(6))
    for (final evo in [false, true]) {
      test(
        '${spec.id} evolved=$evo keeps permanent scaling, N count, freeze and actual main attacks',
        () {
          final scores = <double>[];
          for (final level in [0, 10]) {
            final g = arena(spec.armament, branch: spec.branch, level: level);
            g.mainCount = 2;
            g.mainPower = 2;
            g.soulStacks = 20;
            if (evo) g.evolved.add('gun');
            final target = foe(g, 0, -80);
            g.enemies.add(target);
            final shots = fire(g);
            scores.add(
              shots.fold(0.0, (n, s) => n + s.damage) +
                  target.maxHp -
                  target.hp,
            );
            expect(scores.last, greaterThan(0));
            final frozen = g.combatTime;
            g.setPaused(true);
            advance(g, 2);
            g.setPaused(false);
            expect(g.combatTime, frozen);
            g.choices = [mainBranches.first.choice];
            advance(g, 1);
            g.choices.clear();
            expect(g.combatTime, frozen);
            expect([g.mainRate, g.mainPower, g.mainCount], [0, 2, 2]);
            expect(g.weaponCount, 0);
            final snapshot = BattleStatisticsSnapshot.fromGame(g);
            expect(snapshot.mainLoadout, contains(spec.name));
          }
          expect(scores.last, closeTo(scores.first * 1.2, .001));
        },
      );
    }
  test('needle branches trade penetration for bounded independent target allocation', () {
    final pierce = arena('kunai', branch: MainBranch.needlePierce);
    pierce.enemies.add(foe(pierce, 0, -80));
    final p = fire(pierce).where((s) => s.kind == 9).toList();
    expect(p.single.pierce, 2);
    final swarm = arena('kunai', branch: MainBranch.needleSwarm);
    swarm.enemies.addAll([
      foe(swarm, -100, -100),
      foe(swarm, 0, -100),
      foe(swarm, 100, -100),
    ]);
    final s = fire(swarm).where((s) => s.weapon == 'primary').toList();
    expect(s.length, 3);
    expect(s.map((s) => s.target).toSet().length, 3);
    expect(s.every((s) => s.pierce == 0), true);
    expect(s.first.damage, lessThan(p.first.damage));
  });
  test('homing penetration hits distinct foes once and retargets instead of orbiting a hit target', () {
    final g = arena('kunai', branch: MainBranch.needlePierce, tech: true);
    final a = foe(g, 0, -40), b = foe(g, 0, -90);
    g.enemies.addAll([a, b]);
    fire(g);
    final bullet = g.shots.firstWhere((s) => s.weapon == 'primary');
    g.upgrades.clear();
    for (var i = 0; i < 18; i++) {
      g.update(.02);
      g.shots.removeWhere((s) => s != bullet);
    }
    expect(a.hp, lessThan(a.maxHp));
    expect(b.hp, lessThan(b.maxHp));
    final before = a.hp;
    advance(g, .18);
    expect(a.hp, before);
    expect(bullet.hitTargets.containsAll([a, b]), true);
  });
  test('melee variants have different real coverage, keep healing, ring and sword-array evolution', () {
    for (final pair in [
      ('katana', MainBranch.bladeLong, MainBranch.bladeFan),
      ('bat', MainBranch.batRam, MainBranch.batOrbit),
      ('lightchaser', MainBranch.lightLance, MainBranch.lightCross),
    ]) {
      final long = arena(pair.$1, branch: pair.$2),
          wide = arena(pair.$1, branch: pair.$3);
      final a = foe(long, 0, -220), b = foe(wide, 0, -220);
      long.enemies.add(a);
      wide.enemies.add(b);
      fire(long);
      fire(wide);
      if (pair.$1 != 'bat') expect(a.hp, lessThan(a.maxHp));
      expect(b.hp, b.maxHp);
    }
    final katana = arena('katana', branch: MainBranch.bladeFan)..hp = 50000;
    katana.evolved.add('gun');
    katana.enemies.add(foe(katana, 0, -60));
    fire(katana);
    expect(katana.hp, greaterThan(50000));
    final bat = arena('bat', branch: MainBranch.batRam);
    bat.evolved.add('gun');
    expect(fire(bat).any((s) => s.weapon == 'main-ring'), true);
    final light = arena('lightchaser', branch: MainBranch.lightCross);
    light.evolved.add('gun');
    expect(fire(light).any((s) => s.weapon == 'sword-array'), true);
  });
  test('void concentrated fields stay still, drift fields travel, both retain evolved detonation and shield', () {
    for (final branch in [MainBranch.voidWell, MainBranch.voidDrift]) {
      final g = arena('void', branch: branch);
      g.evolved.add('gun');
      g.enemies.add(foe(g, 0, -80));
      final zone = fire(g).firstWhere((s) => s.weapon == 'void');
      final before = zone.position;
      advance(g, .2);
      expect(zone.position == before, branch == MainBranch.voidWell);
      zone.life = 0;
      g.update(.001);
      expect(g.pilotShield, greaterThan(0));
    }
  });
  test('soul release spends at most ten once per N volley and retains ordinary kill stacks', () {
    final g = arena('disorder', branch: MainBranch.soulRelease)
      ..soulStacks = 25
      ..mainCount = 4;
    g.enemies.add(foe(g, 0, -100));
    final shots = fire(g).where((s) => s.weapon == 'soul').toList();
    expect(shots.length, 5);
    expect(g.soulStacks, 15);
    expect(shots.every((s) => s.kind == 0), true);
    final empty = arena('disorder', branch: MainBranch.soulRelease)
      ..soulStacks = 25;
    empty.upgrades.clear();
    fire(empty); // settle the initial spawn before testing a truly empty arena
    empty.enemies.clear();
    empty.upgrades['gun'] = 1;
    fire(empty);
    expect(empty.soulStacks, 25);
  });
  test('lance variants trade ring radius against actual thrust reach and preserve both evolved modules', () {
    for (final branch in [MainBranch.lanceRing, MainBranch.lanceThrust]) {
      final g = arena('lance', branch: branch);
      g.evolved.add('gun');
      final target = foe(g, 0, -340);
      g.enemies.add(target);
      final shots = fire(g);
      expect(target.hp < target.maxHp, branch == MainBranch.lanceThrust);
      expect(shots.any((s) => s.weapon == 'fissure'), true);
      expect(shots.any((s) => s.weapon == 'lance'), true);
    }
  });
  test('gun technical special reaches all families and gear precision selects a nearby heavy target', () {
    for (final w in ['pulse', 'kunai', 'shotgun', 'revolver', 'disorder']) {
      final g = arena(w, tech: true);
      g.enemies.add(foe(g, 0, -120));
      final shots = fire(g).where((s) => s.damage > 0).toList();
      expect(shots.any((s) => s.pierce >= 1), true, reason: w);
    }
    final ordinary = arena('void'), tech = arena('void', tech: true);
    ordinary.enemies.add(foe(ordinary, 0, -100));
    tech.enemies.add(foe(tech, 0, -100));
    expect(
      fire(tech).firstWhere((s) => s.weapon == 'void').life,
      closeTo(
        fire(ordinary).firstWhere((s) => s.weapon == 'void').life + .4,
        .001,
      ),
    );
    final g = arena('kunai', tech: true, precision: true);
    final close = foe(g, 0, -60, hp: 100),
        heavy = foe(g, 0, -260),
        far = foe(g, 0, -800, hp: 200000);
    g.enemies.addAll([close, heavy, far]);
    expect(fire(g).firstWhere((s) => s.weapon == 'primary').target, heavy);
  });
  test('cycle defense needs four real volleys, clears one valid shot, respects pause and never triggers guardian counter', () {
    final g = arena('kunai', tech: true, cycle: true);
    g.enemies.add(foe(g, 0, -120));
    g.upgrades['guardian'] = 3;
    g.passives['armor'] = 1;
    // Guardian is outside its own active interval, while link remains available.
    g.combatTime = 2;
    final bullets = [
      for (var i = 0; i < 4; i++)
        Shot(
          g.position + Offset(80.0, i.toDouble()),
          Offset.zero,
          10,
          4,
          life: 10,
        ),
    ];
    g.shots.addAll(bullets);
    advance(g, 1.05);
    expect(bullets.where((s) => g.shots.contains(s)).length, 3);
    expect(g.mainLoadoutDescription, contains('· 1회'));
    expect(g.synergyTriggers('shield-counter'), 0);
    expect(g.shieldCounterPending, false);
    g.setPaused(true);
    final frozen = g.combatTime;
    advance(g, 3);
    expect(g.combatTime, frozen);
  });
  test('link flags are derived from equipped rare tech and exact ranked gear; changing gear cannot alter a battle snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.techStock[0][2] = 1;
    p.equippedTech = {0};
    expect(p.mainPrecisionLink, false);
    p.gearAt(1).rank = 1;
    expect(p.mainPrecisionLink, true);
    expect(p.mainCycleLink, false);
    final id = p.grantItem(5)!.id;
    p.item(id)!.rank = 1;
    p.equipItem(id);
    expect(p.mainCycleLink, true);
    final g = arena(
      'kunai',
      tech: true,
      precision: p.mainPrecisionLink,
      cycle: p.mainCycleLink,
    );
    final snap = BattleStatisticsSnapshot.fromGame(g);
    p.equippedTech.clear();
    expect(p.mainPrecisionLink, false);
    expect(p.mainCycleLink, false);
    expect(g.precisionLinkActive, true);
    expect(snap.mainLoadout, contains('정밀 연계 · 활성'));
    await p.save();
    p.dispose();
  });
}
