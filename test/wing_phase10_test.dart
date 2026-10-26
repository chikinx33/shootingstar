import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/boss_gear.dart';
import 'package:shootingstar/data/content_catalog.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine arena(int set, {double health = 100}) =>
    GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        bossSetWorld: set,
        seed: 73,
      )
      ..hp = health
      ..maxHp = 100
      ..xpNeeded = 1e9
      ..upgrades.clear();
Foe target(GameEngine g, {bool boss = false}) {
  final e = Foe(
    g.position + const Offset(0, -200),
    100000,
    0,
    12,
    boss ? 3 : 0,
  );
  g.enemies.add(e);
  return e;
}

double hit(GameEngine g, Foe e, {String source = 'gun'}) {
  g.shots.add(Shot(e.position, Offset.zero, 100, 0, weapon: source));
  final before = e.hp;
  g.update(.001);
  return before - e.hp;
}

void step(GameEngine g, double seconds) {
  for (var i = 0; i < (seconds / .01).round(); i++) {
    g.update(.01);
    g.enemies.clear();
    g.shots.clear();
  }
}

double incoming(GameEngine g) {
  final before = g.hp;
  g.shots.add(Shot(g.position, Offset.zero, 10, 4));
  g.update(.001);
  return before - g.hp;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'twenty stable boss definitions fit the two existing slots and roundtrip',
    () {
      expect(gearCatalog.length, 32);
      for (var w = 0; w < 10; w++)
        for (var p = 0; p < 2; p++) {
          final index = 12 + w * 2 + p;
          final item = GearItem(100 + index, index, rank: 2, locked: true);
          expect(item.definition.slot, p == 0 ? 3 : 5);
          expect(item.definition.bossWorld, w);
          expect(GearItem.restore(item.toJson())!.toJson(), item.toJson());
        }
    },
  );
  test('eligible bosses earn alternating milestones, duplicate runs and reload do not mint equipment', () async {
    final p = await Profile.load();
    void run(
      String id, {
      bool training = false,
      int seconds = 30,
      int bosses = 1,
    }) => p.completeRun(
      runId: id,
      victory: false,
      stageIndex: 0,
      kills: 10,
      level: 1,
      seconds: seconds,
      training: training,
      bossesDefeated: bosses,
    );
    run('first');
    expect(p.bossGear.defeats[0], 1);
    expect(p.bossGear.pending(0), 1);
    run('first');
    expect(p.bossGear.defeats[0], 1);
    expect(p.claimBossGear(0), true);
    final hull = p.inventory.last;
    expect(hull.spec, 12);
    expect(hull.rank, 2);
    expect(hull.locked, true);
    expect(p.claimBossGear(0), false);
    run('second');
    expect(p.bossGear.pending(0), 0);
    run('third');
    expect(p.claimBossGear(0), true);
    expect(p.inventory.last.spec, 13);
    run('training', training: true);
    run('short', seconds: 29);
    expect(p.bossGear.defeats[0], 3);
    await p.save();
    final loaded = await Profile.load();
    expect(loaded.bossGear.toJson(), p.bossGear.toJson());
    expect(loaded.inventory.any((i) => i.id == hull.id && i.spec == 12), true);
    loaded.dispose();
    p.dispose();
  });
  test('all worlds record their own rewards without consuming previous first bonuses', () async {
    final p = await Profile.load();
    for (var w = 0; w < 10; w++) {
      if (w > 0) p.clearedStages.add(w * 10 - 1);
      p.completeRun(
        runId: 'world-$w',
        victory: false,
        stageIndex: w * 10,
        kills: 10,
        level: 1,
        seconds: 30,
        training: false,
        bossesDefeated: 1,
      );
      expect(p.bossGear.pending(w), 1);
      expect(p.claimBossGear(w), true);
      expect(p.inventory.last.definition.bossWorld, w);
    }
    expect(p.campaignRewards.bossWorlds.length, 10);
    await p.save();
    p.dispose();
  });
  test('inventory-full rewards remain pending across reload and failed claim is atomic', () async {
    final p = await Profile.load();
    p.bossGear.record(2, 3);
    while (p.inventory.length < 240) {
      p.grantItem(0);
    }
    final book = p.bossGear.toJson();
    expect(p.claimBossGear(2), false);
    expect(p.bossGear.toJson(), book);
    await p.save();
    final loaded = await Profile.load();
    expect(loaded.bossGear.pending(2), 2);
    loaded.inventory.removeLast();
    expect(loaded.claimBossGear(2), true);
    expect(loaded.inventory.last.spec, 16);
    expect(loaded.bossGear.pending(2), 1);
    await loaded.save();
    loaded.dispose();
    p.dispose();
  });
  test('only equipped matching rare pieces activate; mixed, low rank and duplicate IDs do not', () async {
    final p = await Profile.load();
    p.bossGear.record(0, 3);
    p.claimBossGear(0);
    final a = p.inventory.last;
    p.claimBossGear(0);
    final b = p.inventory.last;
    expect(p.activeBossSetWorld, -1);
    p.equipItem(a.id);
    expect(p.activeBossSetWorld, -1);
    p.equipItem(b.id);
    expect(p.activeBossSetWorld, 0);
    final g = arena(p.activeBossSetWorld);
    b.rank = 1;
    expect(p.activeBossSetWorld, -1);
    b.rank = 2;
    p.equippedGear[5] = a.id;
    expect(p.activeBossSetWorld, -1);
    p.equipItem(b.id);
    final other = p.grantItem(15, rank: 2)!;
    p.equipItem(other.id);
    expect(p.activeBossSetWorld, -1);
    expect(g.bossSetWorld, 0);
    await p.save();
    p.dispose();
  });
  test('legacy precision and cycle links coexist with a boss set', () async {
    final p = await Profile.load();
    p.gearAt(1).rank = 1;
    final core = p.grantItem(5, rank: 1)!;
    p.equipItem(core.id);
    p.equippedTech.add(0);
    p.techStock[0][2] = 1;
    p.bossGear.record(0, 3);
    p.claimBossGear(0);
    p.equipItem(p.inventory.last.id);
    p.claimBossGear(0);
    p.equipItem(p.inventory.last.id);
    expect(p.activeBossSetWorld, 0);
    expect(p.mainPrecisionLink, true);
    expect(p.mainCycleLink, true);
    final g = arena(p.activeBossSetWorld);
    expect(g.mainLoadoutDescription, contains('잔광'));
    await p.save();
    p.dispose();
  });
  test('high hull, exposed boss, formation, slow and mixed set damage apply through real hits', () {
    var g = arena(0);
    expect(hit(g, target(g)), closeTo(108, .001));
    g = arena(0, health: 79);
    expect(hit(g, target(g)), closeTo(100, .001));
    g = arena(1);
    final boss = target(g, boss: true);
    g.bossCycle = 3.3;
    expect(hit(g, boss), closeTo(126.5, .001));
    g = arena(2);
    final formation = target(g)
      ..formationPattern = FlightFormation.column
      ..formationId = 1
      ..formationOrigin = const Offset(900, 1000)
      ..formationDestination = const Offset(900, 1000);
    expect(hit(g, formation), closeTo(110, .001));
    g = arena(3);
    final slow = target(g)
      ..status = 2
      ..statusTime = 1;
    expect(hit(g, slow), closeTo(110, .001));
    g = arena(9);
    expect(hit(g, target(g), source: 'missile'), closeTo(106, .001));
    g = arena(9);
    expect(hit(g, target(g)), closeTo(100, .001));
    g = arena(9);
    final b = target(g, boss: true);
    g.bossCycle = 3.3;
    expect(hit(g, b), closeTo(121.9, .001));
  });
  test('set damage never bypasses closed boss hull floors and does not buff excluded sources', () {
    for (final set in [0, 1, 2, 3, 9]) {
      final g = arena(set);
      final b = target(g, boss: true);
      g.shots.add(Shot(b.position, Offset.zero, 1e9, 0));
      g.update(.001);
      expect(b.hp, closeTo(b.maxHp * .65 + .01, .001));
    }
    final g = arena(0);
    expect(hit(g, target(g), source: 'missile'), closeTo(100, .001));
  });
  test(
    'regeneration uses combat clock and freezes on pause and growth choices',
    () {
      final g = arena(4, health: 40);
      step(g, 9.95);
      expect(g.hp, 40);
      g.setPaused(true);
      step(g, 2);
      g.setPaused(false);
      expect(g.hp, 40);
      g.choices = [const UpgradeChoice('x', 'x', 'x', 'x')];
      step(g, 2);
      g.choices.clear();
      expect(g.hp, 40);
      step(g, .1);
      expect(g.hp, 41);
      final healthy = arena(4, health: 60);
      step(healthy, 10.1);
      expect(healthy.hp, 60);
    },
  );
  test('defensive sets obey thresholds and existing damage reduction cap, speed stays fixed', () {
    expect(incoming(arena(5, health: 40)), closeTo(9.4, .001));
    expect(incoming(arena(5, health: 60)), closeTo(10, .001));
    final b = arena(7);
    target(b, boss: true);
    expect(incoming(b), closeTo(9.5, .001));
    expect(incoming(arena(7)), closeTo(10, .001));
    final cap =
        GameEngine(
            stageIndex: 0,
            shipIndex: 0,
            attackLevel: 0,
            hullLevel: 0,
            magnetLevel: 0,
            equipmentIndex: 0,
            bossSetWorld: 5,
            damageReduction: .69,
          )
          ..maxHp = 100
          ..hp = 40
          ..upgrades.clear();
    expect(incoming(cap), closeTo(3, .001));
    // v12.17: movement speed is not a stat; the sun set's old +8% speed at
    // high hull no longer changes the fixed follow pace.
    expect(arena(-1).moveSpeed, GameEngine.followSpeed);
    expect(arena(6).moveSpeed, GameEngine.followSpeed);
    expect(arena(6, health: 79).moveSpeed, GameEngine.followSpeed);
  });
  test('critical set increases actual critical hits while preserving the 65 percent cap', () {
    final g = arena(8);
    expect(g.critChance, .04);
    final e = target(g);
    e.hp = e.maxHp = 1000000;
    var total = 0.0;
    for (var i = 0; i < 1000; i++) {
      total += hit(g, e);
    }
    expect(total, inInclusiveRange(101000, 108000));
    g.passives['crit'] = 20;
    expect(g.critChance, .65);
    expect(arena(999).bossSetWorld, -1);
  });
  test(
    'boss gear enhancement and refunds retain equipped IDs after reload',
    () async {
      final p = await Profile.load();
      p.credits = 10000;
      p.blueprints = 100;
      p.bossGear.record(0, 1);
      p.claimBossGear(0);
      final g = p.inventory.last;
      expect(p.enhanceItem(g.id), true);
      expect(g.level, 1);
      expect(p.resetItem(g.id), true);
      expect(g.level, 0);
      p.equipItem(g.id);
      await p.save();
      final loaded = await Profile.load();
      expect(loaded.gearAt(3).id, g.id);
      expect(loaded.gearAt(3).definition.bossWorld, 0);
      loaded.dispose();
      p.dispose();
    },
  );
  test(
    'advanced fusion stores and refunds exact boss material definitions',
    () async {
      final p = await Profile.load();
      p.credits = 100000;
      p.blueprints = 1000;
      final main = p.grantItem(12, rank: 2)!,
          a = p.grantItem(14, rank: 2)!,
          b = p.grantItem(16, rank: 2)!;
      p.equipItem(main.id);
      for (var i = 0; i < 3; i++) {
        expect(p.refineEquipment(main.id, 1), true);
      }
      expect(p.ascendEquipment(main.id, [a.id, b.id]), true);
      await p.save();
      final restored = await Profile.load();
      expect(
        restored.advancedEquipment
            .entry(main.id)!
            .materials
            .map((g) => g.spec)
            .toList(),
        [14, 16],
      );
      expect(restored.resetAdvancedEquipment(main.id), true);
      expect(restored.item(a.id)!.spec, 14);
      expect(restored.item(b.id)!.spec, 16);
      await restored.save();
      restored.dispose();
      p.dispose();
    },
  );
  test('older snapshots normalize to empty equipment records without granting anything', () async {
    final p = await Profile.load();
    final old = p.exportProgress();
    old.remove('bossGear');
    old.remove('bossGearVersion');
    final size = p.inventory.length;
    await p.replaceProgress(old);
    expect(p.inventory.length, size);
    expect(p.bossGear.pending(0), 0);
    expect(p.exportProgress()['bossGearVersion'], 1);
    final bad = BossGearBook.restore({
      'defeats': [-5, 100000, 'x'],
      'claimed': [99, 99999, 2],
    });
    expect(bad.defeats[0], 0);
    expect(bad.claimed[0], 0);
    expect(bad.claimed[1], 5000);
    p.dispose();
  });
}
