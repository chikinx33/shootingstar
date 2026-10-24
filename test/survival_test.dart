import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/survival_skills.dart';

GameEngine engine() => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 32,
);
void main() {
  test(
    'distant swarm is recycled outside the camera instead of blocking spawns',
    () {
      final g = engine();
      final distant = Foe(const Offset(-1000, -1000), 100, 0, 11, 0);
      g.enemies.add(distant);
      g.update(.01);
      expect((distant.position - g.position).distance, lessThan(650));
      final local = distant.position - g.camera;
      expect(
        local.dx < 0 || local.dx > 420 || local.dy < 0 || local.dy > 720,
        isTrue,
      );
    },
  );
  test('six weapon and six passive limits retain owned upgrades', () {
    final g = engine();
    g.upgrades.addAll({
      'missile': 1,
      'drone': 1,
      'side': 1,
      'mine': 1,
      'trail': 1,
      'ball': 1,
    });
    g.passives.addAll({
      'attack': 1,
      'area': 1,
      'cooldown': 1,
      'speed': 1,
      'hull': 1,
      'magnet': 1,
    });
    for (int i = 0; i < 25; i++) {
      g.choices = [];
      g.xp = g.xpNeeded;
      g.update(.01);
      expect(g.choices, isNotEmpty);
      for (final c in g.choices.where(
        (c) => c.id != 'repair' && !c.specialization,
      )) {
        expect(
          (skillFor(c.id).passive ? g.passives : g.upgrades).containsKey(c.id),
          isTrue,
        );
      }
      g.chooseUpgrade(g.choices.first.id);
    }
    expect(g.weaponCount, 6);
    expect(g.passives.length, 6);
  });
  test(
    'evolution requires five stars and matching passive, chest evolves once',
    () {
      final g = engine();
      g.upgrades['missile'] = 4;
      g.passives['area'] = 1;
      expect(g.canEvolve('missile'), isFalse);
      g.upgrades['missile'] = 5;
      g.passives.clear();
      expect(g.canEvolve('missile'), isFalse);
      g.passives['area'] = 1;
      expect(g.canEvolve('missile'), isTrue);
      g.supplies.add(Supply(g.position, 3));
      g.update(.01);
      expect(g.evolved, contains('missile'));
      expect(g.canEvolve('missile'), isFalse);
      expect(g.chests, 1);
    },
  );
  test(
    'magnet supply collects distant experience, repair respects max hull',
    () {
      final g = engine();
      g.crystals.add(g.position + const Offset(400, 400));
      g.supplies.add(Supply(g.position, 1));
      g.update(.01);
      expect(g.crystals, isEmpty);
      expect(g.absorbingCrystals.length, 1);
      expect(g.xp, 0);
      for (var i = 0; i < 60; i++) {
        g.update(.025);
      }
      expect(g.absorbingCrystals, isEmpty);
      expect(g.xp, 2);
      g.hp = g.maxHp - 1;
      g.supplies.add(Supply(g.position, 0));
      g.update(.01);
      expect(g.hp, g.maxHp);
    },
  );
  test('camera follows player, pausing freezes supplies and notices', () {
    final g = engine();
    final before = g.camera;
    g.input = const Offset(1, 0);
    g.update(.05);
    expect(g.camera.dx, greaterThan(before.dx));
    g.supplies.add(Supply(g.position, 0));
    g.noticeTime = 2;
    g.setPaused(true);
    g.update(.05);
    expect(g.supplies.length, 1);
    expect(g.noticeTime, 2);
  });
  test('plasma damages several enemies and remains on ground', () {
    final g = engine();
    final at = g.position + const Offset(100, 0);
    final a = Foe(at, 100, 0, 10, 0),
        b = Foe(at + const Offset(4, 0), 100, 0, 10, 0);
    g.enemies.addAll([a, b]);
    final patch = Shot(at, Offset.zero, 20, 5, life: 2, radius: 30);
    g.shots.add(patch);
    g.update(.01);
    expect(a.hp, 80);
    expect(b.hp, 80);
    expect(g.shots, contains(patch));
    g.update(.01);
    expect(a.hp, 80);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('instant return does not farm credits, missions or gear', () async {
    final p = await Profile.load();
    for (int i = 0; i < 10; i++) {
      expect(
        p.completeRun(
          victory: false,
          stageIndex: 0,
          kills: 0,
          level: 1,
          seconds: 0,
          training: false,
          runId: 'abort-$i',
        ),
        0,
      );
    }
    expect(p.credits, 150);
    expect(p.runs, 0);
    expect(p.blueprints, 0);
  });
  test('earned equipment, merge, upgrade, mission and reload form a persistent loop', () async {
    final p = await Profile.load();
    p.completeRun(
      victory: true,
      stageIndex: 0,
      kills: 120,
      level: 10,
      seconds: 600,
      training: false,
      runId: 'clear',
    );
    expect(p.inventory.length, 8);
    p.grantItem(0);
    p.grantItem(0);
    expect(p.mergeGear(0), isTrue);
    expect(p.mergeGear(0), isFalse);
    expect(p.enhanceGear(0), isTrue);
    expect(p.gearDamage, greaterThan(0));
    expect(p.claimMission(0), isTrue);
    expect(p.claimMission(0), isFalse);
    await p.save();
    final restored = await Profile.load();
    expect(restored.gearRanks, p.gearRanks);
    expect(restored.gearLevels, p.gearLevels);
    expect(restored.blueprints, p.blueprints);
    expect(restored.claimedMissions, {0});
  });
  test(
    'challenge must be unlocked and first-clear materials cannot repeat',
    () async {
      final p = await Profile.load();
      expect(
        p.completeRun(
          victory: true,
          stageIndex: 0,
          kills: 20,
          level: 3,
          seconds: 600,
          training: false,
          challenge: true,
          runId: 'locked',
        ),
        0,
      );
      p.clearedStages.add(0);
      p.completeRun(
        victory: true,
        stageIndex: 0,
        kills: 20,
        level: 3,
        seconds: 600,
        training: false,
        challenge: true,
        runId: 'first',
      );
      expect(p.blueprints, 7);
      p.completeRun(
        victory: true,
        stageIndex: 0,
        kills: 20,
        level: 3,
        seconds: 600,
        training: false,
        challenge: true,
        runId: 'second',
      );
      expect(p.blueprints, 10);
    },
  );
}
