import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/survival_skills.dart';

GameEngine game({
  int stage = 0,
  int cycle = 0,
  String pilot = 'common',
  String weapon = 'pulse',
}) => GameEngine(
  stageIndex: stage,
  campaignLoop: cycle,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  pilot: pilot,
  armament: weapon,
  seed: 17,
);
void run(GameEngine g, double seconds) {
  for (int i = 0; i < (seconds / .05).round(); i++) {
    g.choices.clear();
    g.update(.05);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('every stage completes its required boss chain with all phases and bounded actors', () {
    final rows = <Map<String, dynamic>>[];
    for (int stage = 0; stage < 100; stage++) {
      final g = game(stage: stage)..upgrades.clear();
      g.hp = g.maxHp = 100000;
      g.xpNeeded = 1e9;
      final phases = <int>{};
      for (int wave = 0; wave < g.requiredBosses; wave++) {
        if (g.resolvingBoss) run(g, 3.5);
        g.choices.clear();
        g.elapsed = g.nextBossAt;
        g.update(.01);
        final before = g.bossesDefeated;
        for (
          int frame = 0;
          frame < 200 && g.bossesDefeated == before;
          frame++
        ) {
          expect(g.boss, isNotNull, reason: 'stage $stage boss $wave');
          phases.add(g.bossPhase);
          g.shots.add(Shot(g.boss!.position, Offset.zero, 1000000, 0));
          g.update(.05);
          expect(g.enemies.length, lessThanOrEqualTo(g.enemyLimit));
          expect(g.shots.length, lessThan(1000));
        }
        expect(
          g.bossesDefeated,
          before + 1,
          reason:
              'stage $stage boss $wave cycle ${g.bossCycle} choices ${g.choices.length}',
        );
      }
      // Victory is committed after destruction and hero departure, not at kill.
      run(g, 5.5);
      expect(g.victory, true, reason: 'stage $stage');
      expect(phases, {0, 1, 2});
      expect(g.bossAttacks, greaterThanOrEqualTo(g.requiredBosses * 3));
      rows.add({
        'stage': stage,
        'world': stage ~/ 10,
        'bosses': g.bossesDefeated,
        'attacks': g.bossAttacks,
        'threat': g.threat,
        'phases': phases.toList(),
      });
    }
    Directory('tools/qa/evidence/campaign-v5').createSync(recursive: true);
    File('tools/qa/evidence/campaign-v5/stages.json')
        .writeAsStringSync(jsonEncode(rows));
  });
  test('number pickups add attacks to every primary family', () {
    for (final spec in armaments) {
      final counts = <int>[], damages = <double>[];
      for (final extra in [false, true]) {
        final g = game(weapon: spec.id);
        g.enemies.add(
          Foe(g.position + const Offset(0, -150), 100000, 0, 20, 0),
        );
        if (extra) g.supplies.add(Supply(g.position, 6));
        g.update(.01);
        counts.add(g.shots.length);
        damages.add(g.damageByWeapon.values.fold(0.0, (a, b) => a + b));
      }
      expect(
        counts[1] > counts[0] || damages[1] > damages[0],
        true,
        reason: spec.id,
      );
    }
  });
  test('medical drone fusion consumes the healing module as well as the attack drone', () {
    final g = game(pilot: 'cat');
    g.upgrades['drone'] = 5;
    g.upgrades['pilot'] = 5;
    g.evolved.add('drone');
    g.choices = [
      const UpgradeChoice(
        'medicDrone',
        'medical fusion',
        '',
        'medicDrone',
        evolution: true,
      ),
    ];
    g.chooseUpgrade('medicDrone');
    expect(g.upgrades.containsKey('drone'), false);
    expect(g.upgrades.containsKey('pilot'), false);
    expect(g.upgrades['medicDrone'], 5);
    expect(g.weaponCount, 1);
  });
  test(
    '100 distinct stage IDs form 10 worlds and increasing repeat threat',
    () {
      expect(worlds.length, 10);
      expect(stages.length, 100);
      // v12: the ten houses repeat per neighbourhood; the label stays unique
      expect(stages.map((s) => '${s.name} ${s.subtitle}').toSet().length, 100);
      for (int i = 0; i < 100; i++) {
        expect(stages[i].worldIndex, i ~/ 10);
        expect(stages[i].sector, i % 10);
        expect(stages[i].threat(1), greaterThan(stages[i].threat(0)));
        if (i > 0) {
          expect(stages[i].threat(0), greaterThan(stages[i - 1].threat(0)));
        }
      }
    },
  );
  test(
    'legacy whole chapters migrate once with inventory and balances intact',
    () async {
      final original = Profile.freshProgress();
      original.remove('campaignVersion');
      original.remove('cycleClears');
      original['clearedStages'] = [0, 1];
      original['selectedStage'] = 2;
      original['onboarded'] = true;
      original['credits'] = 9123;
      original['blueprints'] = 87;
      final qaDir = Directory('tools/qa/evidence/campaign-v5')
        ..createSync(recursive: true);
      File('${qaDir.path}/legacy-profile.json')
          .writeAsStringSync(jsonEncode(original));
      SharedPreferences.setMockInitialValues({
        Profile.storageKey: jsonEncode(original),
      });
      final p = await Profile.load();
      expect(p.clearedStages, {for (int i = 0; i < 20; i++) i});
      expect(p.selectedStage, 20);
      expect(p.canStage(20), true);
      expect(p.canStage(21), false);
      final stored = await SharedPreferences.getInstance();
      expect(
        stored.getString('${Profile.storageKey}.beforeCampaign'),
        jsonEncode(original),
      );
      expect(p.credits, 9123);
      expect(p.blueprints, 87);
      expect(
        (p.exportProgress()['content'] as Map)['inventory'],
        (original['content'] as Map)['inventory'],
      );
      await p.save();
      final restored = await Profile.load();
      expect(restored.clearedStages, p.clearedStages);
      final fixture = p.exportProgress();
      fixture['clearedStages'] = List.generate(100, (i) => i);
      fixture['cycleClears'] = List.generate(100, (i) => i);
      fixture['selectedStage'] = 90;
      fixture['onboarded'] = true;
      File('${qaDir.path}/unlocked-profile.json')
          .writeAsStringSync(jsonEncode(fixture));
    },
  );
  test(
    '100th clear advances cycle without deleting lifetime progress or gear',
    () async {
      final p = await Profile.load();
      p.clearedStages.addAll(List.generate(99, (i) => i));
      final inventory = jsonEncode(p.inventory.map((g) => g.toJson()).toList());
      p.completeRun(
        victory: true,
        stageIndex: 99,
        kills: 200,
        level: 20,
        seconds: 240,
        bossesDefeated: 3,
        training: false,
        runId: 'cycle-end',
      );
      expect(p.campaignLoop, 1);
      expect(p.selectedStage, 0);
      expect(p.canStage(1), false);
      expect(p.clearedStages.length, 100);
      expect(p.pilotLevel, greaterThan(0));
      expect(
        jsonEncode(p.inventory.take(6).map((g) => g.toJson()).toList()),
        inventory,
      );
      final before = jsonEncode(p.exportProgress());
      p.completeRun(
        victory: true,
        stageIndex: 99,
        kills: 200,
        level: 20,
        seconds: 240,
        bossesDefeated: 3,
        training: false,
        runId: 'cycle-end',
      );
      expect(jsonEncode(p.exportProgress()), before);
      p.completeRun(
        victory: true,
        stageIndex: 0,
        kills: 50,
        level: 5,
        seconds: 180,
        training: false,
        runId: 'cycle-two',
      );
      expect(p.canStage(1), true);
      await p.save();
      expect((await Profile.load()).campaignLoop, 1);
    },
  );
  test('main gun pickups are independent, capped, visibly wider and reset per sortie', () {
    final g = game();
    for (int n = 0; n < 6; n++) {
      for (int type = 4; type <= 6; type++) {
        g.supplies.add(Supply(g.position, type));
      }
    }
    g.update(.01);
    expect(g.mainRate, 5);
    expect(g.mainPower, 5);
    expect(g.mainCount, 4);
    expect(g.mainWidth, greaterThan(3));
    expect(g.mainInterval, lessThan(1));
    expect(g.mainProjectiles, 5);
    expect(g.weaponCount, 0);
    expect(g.evolved, contains('gun'));
    expect(g.shots.where((s) => s.kind == 0).length, greaterThanOrEqualTo(5));
    expect(game().mainPower, 0);
  });
  test('sparse guaranteed magnet survives crowded supplies and only collects nearby crystals', () {
    final g = game()..upgrades.clear();
    g.hp = g.maxHp = 100000;
    g.supplies.addAll(
      List.generate(
        12,
        (i) => Supply(g.position + Offset(200 + i * 3.0, 100), 0),
      ),
    );
    run(g, 46);
    expect(g.supplies.any((s) => s.kind == 1), true);
    g.crystals
      ..clear()
      ..addAll([
        g.position + const Offset(150, 100),
        g.position + const Offset(600, 500),
        g.position + const Offset(-150, -100),
      ]);
    g.supplies.removeWhere((s) => s.kind == 1);
    g.supplies.add(Supply(g.position, 1));
    g.xp = 0;
    g.update(.01);
    expect(g.crystals.length, 1);
    expect(g.xp, 0);
    expect(g.absorbingCrystals.length, 2);
    expect(g.magnetPulse, greaterThan(0));
    // Value is awarded exactly once on arrival; the full stream then settles.
    run(g, 2);
    expect(g.collectingMagnet, false);
    expect(g.xp, 4);
    g.update(.01);
    expect(g.xp, 4);
  });
  test('A+B drone fusion and both mine branches release one slot and restore elemental pool', () {
    for (final branch in ['infernoMine', 'thunderMine']) {
      final g = game();
      final element = branch == 'infernoMine' ? 'trail' : 'lightning';
      g.upgrades.addAll({'mine': 5, element: 5});
      g.xp = 18;
      g.update(.01);
      // Rerolls may exclude the branch, so directly exercise a legal offered recipe.
      g.choices = [
        UpgradeChoice(branch, branch, 'fusion', branch, evolution: true),
      ];
      g.chooseUpgrade(branch);
      expect(g.upgrades[branch], 5);
      expect(g.upgrades.containsKey('mine'), false);
      expect(g.upgrades.containsKey(element), false);
      expect(g.weaponCount, 1);
    }
    final g = game()..upgrades.addAll({'drone': 5, 'droneB': 5});
    expect(g.canEvolve('drone'), true);
    g.choices = [
      const UpgradeChoice('drone', 'fusion', '', 'drone', evolution: true),
    ];
    g.chooseUpgrade('drone');
    expect(g.upgrades.containsKey('droneB'), false);
    expect(g.evolved, contains('drone'));
    expect(g.weaponCount, 1);
  });
  test('every primary family fires and every pilot executes safely with paused cooldowns', () {
    final rows = <Map<String, dynamic>>[];
    for (final spec in armaments) {
      final g = game(weapon: spec.id);
      g.enemies.add(Foe(g.position + const Offset(0, -80), 100000, 0, 30, 0));
      for (int n = 0; n < 3; n++) {
        for (int type = 4; type <= 6; type++) {
          g.supplies.add(Supply(g.position, type));
        }
      }
      run(g, 5);
      expect(
        g.damageByWeapon.values.fold(0.0, (a, b) => a + b),
        greaterThan(0),
        reason: spec.id,
      );
      expect(g.shots.length, lessThan(1000));
    }
    for (final spec in pilots) {
      final g = game(pilot: spec.id);
      g.hp = g.maxHp = 100000;
      g.enemies.add(Foe(g.position + const Offset(0, -60), 100000, 0, 20, 0));
      if (g.pilotUsesPassive) {
        g.passives['pilot'] = 5;
      } else {
        g.upgrades['pilot'] = 5;
      }
      g.evolved.add('pilot');
      g.pilotSync = 210;
      if (g.pilotHasActive) expect(g.activatePilotAbility(), true);
      run(g, 6);
      expect(g.hp.isFinite, true);
      expect(g.shots.length, lessThan(1000));
      final cooldown = g.pilotAbilityCooldown, sync = g.pilotSync;
      g.setPaused(true);
      g.update(.05);
      expect(g.pilotAbilityCooldown, cooldown);
      expect(g.pilotSync, sync);
      rows.add({
        'pilot': spec.id,
        'damage': g.damageByWeapon,
        'shield': g.pilotShield,
        'hp': g.hp,
      });
    }
    Directory('tools/qa/evidence/campaign-v5').createSync(recursive: true);
    File('tools/qa/evidence/campaign-v5/loadouts.json')
        .writeAsStringSync(jsonEncode(rows));
  });
  test('all enemy roles are executable and telegraphed ranged attacks remain bounded', () {
    for (final role in EnemyRole.values) {
      final g = game(stage: 50)
        ..viewportHeight = 1000
        ..upgrades.clear();
      g.hp = g.maxHp = 100000;
      final foe = Foe(
        g.position + const Offset(0, -180),
        10000,
        60,
        15,
        0,
        role: role,
      );
      g.enemies.add(foe);
      final observed = <int>{};
      for (int i = 0; i < 200; i++) {
        g.choices.clear();
        g.update(.05);
        observed.addAll(g.shots.where((s) => s.hostile).map((s) => s.kind));
      }
      expect(foe.position.dx.isFinite, true);
      expect(g.shots.where((s) => s.kind == 4).length, lessThanOrEqualTo(160));
      if ([
        EnemyRole.spitter,
        EnemyRole.sniper,
        EnemyRole.orbiter,
      ].contains(role)) {
        expect(
          observed,
          contains(
            {
              EnemyRole.spitter: 22,
              EnemyRole.sniper: 23,
              EnemyRole.orbiter: 19,
            }[role],
          ),
          reason: role.name,
        );
      }
      if (role == EnemyRole.carrier) expect(g.enemies.length, greaterThan(1));
    }
  });
  test('all active weapon families resolve real hits without unbounded projectiles', () {
    for (final skill in survivalSkills.where(
      (s) => !s.passive && !['gun', 'pilot'].contains(s.id),
    )) {
      final g = game()..upgrades.clear();
      g.hp = g.maxHp = 100000;
      g.upgrades[skill.id] = 5;
      g.evolved.add(skill.id);
      for (int i = 0; i < 12; i++) {
        g.enemies.add(
          Foe(
            g.position +
                Offset(
                  math.cos(i % 4 * math.pi / 2) * (45 + i ~/ 4 * 85),
                  math.sin(i % 4 * math.pi / 2) * (45 + i ~/ 4 * 85),
                ),
            100000,
            0,
            20,
            0,
          ),
        );
      }
      run(g, 7);
      expect(
        g.damageByWeapon.values.fold(0.0, (a, b) => a + b),
        greaterThan(0),
        reason: skill.id,
      );
      expect(g.shots.length, lessThan(1000), reason: skill.id);
    }
  });
}
