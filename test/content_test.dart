import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/content_systems.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine game({
  String weapon = 'gun',
  Map<String, int> tech = const {},
  int pet = -1,
  int petLevel = 1,
}) => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 12,
  startingWeapon: weapon,
  techRanks: tech,
  petKind: pet,
  petLevel: petLevel,
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'v2 migration retains equipment power, copies and exact enhancement refund',
    () async {
      SharedPreferences.setMockInitialValues({
        Profile.storageKey: jsonEncode({
          'version': 2,
          'credits': 150,
          'gearRanks': [2, 1, 0, 0, 0, 0],
          'gearLevels': [3, 0, 0, 0, 0, 0],
          'gearCopies': [4, 0, 0, 0, 0, 0],
        }),
      });
      final p = await Profile.load();
      expect(p.gearAt(0).rank, 2);
      expect(p.gearAt(0).level, 3);
      expect(p.gearCopies[0], 4);
      expect(p.resetItem(1), true);
      expect(p.credits, 300);
      expect(p.blueprints, 3);
      expect(p.resetItem(1), false);
      expect(p.convertLegacyPart(0), true);
      expect(p.gearCopies[0], 3);
      await p.save();
      final q = await Profile.load();
      expect(q.inventory.length, 7);
      expect(q.gearAt(0).rank, 2);
    },
  );
  test(
    'merge protects locked, equipped and enhanced materials and is atomic',
    () async {
      final p = await Profile.load();
      final a = p.grantItem(0)!, b = p.grantItem(0)!;
      a.locked = true;
      expect(p.mergeItem(1), false);
      expect(p.inventory.length, 8);
      a.locked = false;
      b.level = 1;
      expect(p.mergeItem(1), false);
      b.level = 0;
      expect(p.mergeItem(1), true);
      expect(p.gearAt(0).rank, 1);
      expect(p.inventory.length, 6);
      expect(p.mergeItem(1), false);
    },
  );
  test(
    'equipped variant changes start weapon and exact upgrade cost refunds once',
    () async {
      final p = await Profile.load();
      final rocket = p.grantItem(1)!;
      p.equipItem(rocket.id);
      expect(p.startingWeapon, 'missile');
      p.blueprints = 2;
      final before = p.credits;
      expect(p.enhanceItem(rocket.id), true);
      expect(p.enhanceItem(rocket.id), true);
      expect(p.credits, before - 80);
      p.resetItem(rocket.id);
      expect(p.credits, before);
      expect(p.blueprints, 2);
    },
  );
  test('capacity does not consume a supply key', () async {
    final p = await Profile.load();
    while (p.inventory.length < 240) {
      p.grantItem(0);
    }
    final keys = p.gearKeys;
    expect(p.openGearSupply(), false);
    expect(p.gearKeys, keys);
  });
  test(
    'gear supplies and battle drops have independent guarantee counters',
    () async {
      final p = await Profile.load();
      p.gearKeys = 10;
      for (int i = 0; i < 9; i++) {
        p.openGearSupply();
      }
      p.recordContentRun(runId: 'x', kills: 10, seconds: 30, victory: false);
      expect(p.supplySerial, 9);
      p.openGearSupply();
      expect(p.inventory.last.rank, 3);
    },
  );
  test(
    'tech has three attack and three defense slots and merges preserve effects',
    () async {
      final p = await Profile.load();
      for (int i = 0; i < 8; i++) {
        p.techStock[i][0] = 9;
      }
      for (final i in [0, 1, 2, 4, 5, 6]) {
        expect(p.equipTech(i), true);
      }
      expect(p.equipTech(3), false);
      expect(p.equipTech(7), false);
      for (int i = 0; i < 3; i++) {
        expect(p.mergeTech(0, 0), true);
      }
      expect(p.mergeTech(0, 1), true);
      expect(p.battleTech['gun'], 2);
      expect(p.techStock[0][0], 0);
      expect(p.mergeTech(0, 0), false);
    },
  );
  test(
    'pet feeding, rescue, assistants and promotion consume correct resources',
    () async {
      final p = await Profile.load();
      expect(p.feedPet(0), true);
      expect(p.petFood, 20);
      expect(p.petLevels[0], 2);
      expect(p.rescuePet(), true);
      expect(p.petLevels[1], 1);
      expect(p.assistPet(1), true);
      expect(p.gearPickup, greaterThan(0));
      expect(p.deployPet(1), true);
      expect(p.assistingPets, isEmpty);
      expect(p.assistPet(1), false);
      expect(p.evolvePet(0), false);
      p.petShards[0] = 3;
      expect(p.evolvePet(0), true);
      expect(p.petShards[0], 0);
    },
  );
  test('Korean month boundary mails earned unclaimed tiers once and ignores rollback', () async {
    final p = await Profile.load();
    p.lastClock = 0;
    p.lastPatrol = 0;
    p.dayKey = '';
    p.seasonKey = '';
    p.refreshContentClock(DateTime.utc(2026, 10, 31, 14, 59));
    p.seasonXp = 350;
    p.seasonClaims = {1};
    p.dailyClaims = {0};
    p.refreshContentClock(DateTime.utc(2026, 10, 31, 15));
    expect(p.seasonKey, '2026-11');
    expect(p.mail.length, 2);
    expect(p.dailyClaims, isEmpty);
    expect(p.seasonXp, 0);
    final credits = p.credits;
    expect(p.claimMail(p.mail.first.id), true);
    expect(p.claimMail(p.mail.first.id), false);
    expect(p.credits, greaterThan(credits));
    p.refreshContentClock(DateTime.utc(2026, 10, 30));
    expect(p.seasonKey, '2026-11');
    expect(p.mail.length, 2);
    expect(ContentSystems.dayOf(DateTime.utc(2026, 10, 12, 15)), '2026-10-13');
  });
  test(
    'daily claims, season claims and duplicate battle settlement cannot repeat',
    () async {
      final p = await Profile.load();
      p.completeRun(
        victory: true,
        stageIndex: 0,
        kills: 120,
        level: 5,
        seconds: 600,
        training: false,
        runId: 'unique',
      );
      final before = jsonEncode(p.contentSnapshot());
      p.completeRun(
        victory: true,
        stageIndex: 0,
        kills: 120,
        level: 5,
        seconds: 600,
        training: false,
        runId: 'unique',
      );
      expect(jsonEncode(p.contentSnapshot()), before);
      expect(p.claimDaily(0), true);
      expect(p.claimDaily(0), false);
      expect(p.claimSeason(1), true);
      expect(p.claimSeason(1), false);
      await p.save();
      final q = await Profile.load();
      expect(q.seasonClaims, {1});
      expect(q.inventory.length, p.inventory.length);
    },
  );
  test('patrol caps eight hours and cannot collect twice', () async {
    final p = await Profile.load();
    final now = DateTime.now();
    p.lastPatrol = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    final before = p.credits;
    expect(p.claimPatrol(now), true);
    expect(p.credits - before, 320);
    expect(p.claimPatrol(now), false);
  });
  test('mail receipt deduplicates server retries', () async {
    final p = await Profile.load();
    final reward = {'id': 'server-1', 'title': 'test', 'food': 30};
    expect(p.acceptServerReward(reward), true);
    expect(p.acceptServerReward(reward), false);
    expect(p.claimMail('server-1'), true);
    expect(p.petFood, 60);
    expect(p.claimMail('server-1'), false);
  });
  test(
    'corrupt inventory recovers all six slots without duplicate IDs',
    () async {
      SharedPreferences.setMockInitialValues({
        Profile.storageKey: jsonEncode({
          'content': {
            'inventory': [
              {'id': 8, 'spec': 0},
              {'id': 8, 'spec': 0},
              {'id': 9, 'spec': 999},
            ],
            'equippedGear': [999, 8, 8, 8, 8, 8],
          },
        }),
      });
      final p = await Profile.load();
      expect(p.inventory.map((g) => g.id).toSet().length, p.inventory.length);
      for (int i = 0; i < 6; i++) {
        expect(p.gearAt(i).definition.slot, i);
      }
      expect(p.grantItem(0)!.id, greaterThan(8));
    },
  );
  test('legacy missile gear adds an auxiliary while independent primary still fires', () {
    final g = game(weapon: 'missile');
    g.enemies.add(Foe(g.position + const Offset(150, 0), 100, 0, 10, 0));
    g.update(.01);
    expect(g.upgrades, {'gun': 1, 'missile': 1});
    expect(g.shots.any((s) => s.kind == 0), true);
    expect(g.shots.any((s) => s.kind == 1), true);
  });
  test('rare gun tech fires piercing shot with higher damage', () {
    final g = game(tech: {'gun': 2});
    g.update(.01);
    final shot = g.shots.firstWhere((s) => s.kind == 0);
    expect(shot.pierce, 1);
    expect(shot.damage, closeTo(17 * g.damageFactor * 1.15, .001));
  });
  test('fire chick attacks and pause freezes its fall-off', () {
    final g = game(pet: 0, petLevel: 5)..seatChicks();
    g.enemies.add(Foe(g.position + const Offset(150, 0), 100, 0, 10, 0));
    g.update(.01);
    expect(g.shots.where((s) => s.weapon == 'pet').length, 2);
    final c = g.squad.tail.single..hp = .1;
    g.shots.add(Shot(c.position, Offset.zero, 1, 4, life: 2));
    g.enemies.clear();
    g.update(.01);
    expect(c.state, ChickState.falling);
    g.setPaused(true);
    g.update(.05);
    expect(c.fall, 0);
    g.setPaused(false);
    for (int i = 0; i < 30; i++) {
      g.enemies.clear();
      g.update(.05);
    }
    expect(c.state, ChickState.waiting);
  });
  test('medic heals and guardian removes hostile bullets', () {
    final medic = game(pet: 1)..seatChicks();
    medic.hp = 20;
    medic.update(.01);
    expect(medic.hp, greaterThan(20));
    final shield = game(pet: 2)..seatChicks();
    shield.shots.add(
      Shot(shield.squad.tail.single.position, Offset.zero, 10, 4),
    );
    shield.update(.01);
    expect(shield.shots.any((s) => s.kind == 4), false);
  });
}
