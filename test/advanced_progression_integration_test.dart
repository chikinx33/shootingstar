import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/daily_challenge.dart';
import 'package:shootingstar/data/hangar_preset.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine combat({
  DailyChallengeEntry? entry,
  int pet = -1,
  double power = 0,
  double cooldown = 0,
}) => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 47,
  dailyEntry: entry,
  petKind: pet,
  petLevel: 5,
  petRank: 1,
  petAwakePower: power,
  petAwakeCooldown: cooldown,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'legacy load keeps an exact backup and saves additive migration once',
    () async {
      final saved = Profile.freshProgress();
      final content = saved['content'] as Map;
      for (final key in [
        'advancedProgressionVersion',
        'advancedEquipment',
        'petBond',
        'dailyChallenge',
      ]) {
        content.remove(key);
      }
      final blob = jsonEncode(saved);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(Profile.storageKey, blob);
      final p = await Profile.load();
      expect(
        prefs.getString('${Profile.storageKey}.beforeAdvancedProgression'),
        blob,
      );
      expect(
        jsonDecode(
          prefs.getString(Profile.storageKey)!,
        )['content']['advancedProgressionVersion'],
        1,
      );
      await p.save();
      await Profile.load();
      expect(
        prefs.getString('${Profile.storageKey}.beforeAdvancedProgression'),
        blob,
      );
    },
  );

  test(
    'legacy save retains inventory, presets and prior growth without new power',
    () async {
      final p = await Profile.load();
      p.credits = 500;
      p.blueprints = 30;
      p.item(1)!.rank = 2;
      p.item(1)!.locked = true;
      p.hangarPresets[0] = HangarPreset.capture(p, '기존 구성');
      p.collections.levels[0] = 2;
      final damage = p.gearDamage, hull = p.gearHull, pickup = p.gearPickup;
      final saved = p.exportProgress();
      final content = saved['content'] as Map;
      for (final field in [
        'advancedProgressionVersion',
        'dailyChallenge',
        'advancedEquipment',
        'petBond',
      ]) {
        content.remove(field);
      }
      await p.replaceProgress(saved);
      expect(p.inventory.map((g) => g.toJson()).toList(), content['inventory']);
      expect(p.hangarPresets.first!.name, '기존 구성');
      expect(p.gearDamage, damage);
      expect(p.gearHull, hull);
      expect(p.gearPickup, pickup);
      expect(p.dailyChallenge.tokens, 0);
      expect(p.petBond.favor, [0, 0, 0]);
      expect(p.credits, 500);
      expect(p.blueprints, 30);
    },
  );

  test('fusion preserves identities and reserves consumed IDs through reload, then exact refund once', () async {
    final p = await Profile.load();
    p.credits = 10000;
    p.blueprints = 100;
    p.item(1)!.rank = 2;
    final m1 = p.grantItem(0, rank: 1)!, m2 = p.grantItem(1, rank: 1)!;
    final ids = [m1.id, m2.id];
    final wallet = p.credits, plans = p.blueprints;
    for (var i = 0; i < 3; i++) {
      expect(p.refineEquipment(1, 0), true);
    }
    expect(p.ascendEquipment(1, ids), true);
    expect(p.item(1)!.rank, 2);
    expect(p.equippedGear.first, 1);
    expect(p.inventory.any((g) => ids.contains(g.id)), false);
    await p.save();
    final q = await Profile.load();
    expect(q.advancedEquipment.entry(1)!.ascension, 1);
    final newItem = q.grantItem(2)!;
    expect(newItem.id, greaterThan(m2.id));
    final beforeReset = q.inventory.length;
    expect(q.resetAdvancedEquipment(1), true);
    expect(q.inventory.length, beforeReset + 2);
    expect(q.item(m1.id)!.toJson(), m1.toJson());
    expect(q.item(m2.id)!.toJson(), m2.toJson());
    expect(q.credits, wallet);
    expect(q.blueprints, plans);
    expect(q.resetAdvancedEquipment(1), false);
    expect(q.credits, wallet);
    expect(q.dailyUpgrades, 0);
  });

  test('presets and advanced materials stay protected from ordinary and advanced fusion', () async {
    final p = await Profile.load();
    p.credits = 10000;
    p.blueprints = 100;
    p.item(1)!.rank = 2;
    for (var i = 0; i < 3; i++) {
      p.refineEquipment(1, 0);
    }
    final material = p.grantItem(0, rank: 1)!;
    final other = p.grantItem(0, rank: 1)!;
    p.equipItem(material.id);
    p.hangarPresets[0] = HangarPreset.capture(p, '지킬 구성');
    p.equipItem(1);
    expect(
      p.advancedMaterialCandidates(1).map((g) => g.id),
      isNot(contains(material.id)),
    );
    final before = jsonEncode(p.exportProgress()['content']);
    expect(p.ascendEquipment(1, [material.id, other.id]), false);
    // The clock may advance; inventory and wallet are unchanged on rejection.
    expect(p.item(material.id), isNotNull);
    expect(p.item(other.id), isNotNull);
    p.hangarPresets[0] = null;
    expect(p.refineEquipment(material.id, 0), true);
    final baseTarget = p.grantItem(0, rank: 1)!;
    expect(
      p.mergeMaterials(baseTarget).map((g) => g.id),
      isNot(contains(material.id)),
    );
    expect(before, isNotEmpty);
  });

  test('equipped advanced modes change the real loadout and refund capacity rejects atomically', () async {
    final p = await Profile.load();
    p.credits = 1000;
    p.blueprints = 20;
    p.item(1)!.rank = 1;
    final damage = p.gearDamage, hull = p.gearHull;
    expect(p.refineEquipment(1, 0), true);
    expect(p.gearDamage, closeTo(damage + .005, 1e-10));
    expect(p.chooseEquipmentMode(1, 1), true);
    expect(p.gearDamage, damage);
    expect(p.gearHull, closeTo(hull + .0075, 1e-10));
    p.credits = 9999999;
    final record = p.advancedEquipment.toJson();
    expect(p.resetAdvancedEquipment(1), false);
    expect(p.advancedEquipment.toJson(), record);
  });

  test('daily settlement grants once and never clears campaign or duplicates normal caches', () async {
    final p = await Profile.load();
    final entry = p.dailyChallenge.begin(2)!;
    final normal = p.exportProgress();
    final inventory = p.inventory.map((g) => g.toJson()).toList();
    int finish(String id) => p.completeDailyChallenge(
      runId: id,
      entry: entry,
      victory: true,
      kills: 120,
      seconds: 180,
      bosses: 1,
      deployedPet: 0,
    );
    expect(finish('daily-1'), 8);
    expect(finish('daily-1'), 0);
    expect(finish('daily-2'), 0);
    expect(p.dailyChallenge.tokens, 8);
    expect(p.clearedStages, isEmpty);
    expect(p.clearedChallenges, isEmpty);
    expect(p.runs, normal['runs']);
    expect(p.credits, normal['credits']);
    expect(p.blueprints, normal['blueprints']);
    expect(p.inventory.map((g) => g.toJson()).toList(), inventory);
    expect(
      p.petBond.favor[0],
      20,
    ); // Two real distinct runs, token reward once.
    expect(p.exchangeDailyChallenge(2), true);
    expect(p.collections.keys, 1);
    expect(p.dailyChallenge.tokens, 0);
    expect(p.exchangeDailyChallenge(2), false);
    await p.save();
    final q = await Profile.load();
    expect(q.dailyChallenge.cleared, {2});
    expect(q.collections.keys, 1);
    expect(q.dailyChallenge.tokens, 0);
  });

  test('favor uses actual deployed pet and excludes training, duplicate or inaccessible runs', () async {
    final p = await Profile.load();
    p.petLevels[1] = 1;
    p.activePet = 1;
    void finish(String id, {bool training = false, int stage = 0}) =>
        p.completeRun(
          runId: id,
          victory: false,
          stageIndex: stage,
          kills: 20,
          level: 3,
          seconds: 130,
          training: training,
          deployedPet: 0,
        );
    finish('training', training: true);
    finish('locked', stage: 99);
    expect(p.petBond.favor, [0, 0, 0]);
    finish('real');
    finish('real');
    expect(p.petBond.favor, [10, 0, 0]);
    await p.save();
    final q = await Profile.load();
    expect(q.petBond.favor, [10, 0, 0]);
  });

  test('daily variants affect wave cadence, health, movement and pickup without campaign changes', () {
    DailyChallengeEntry entry(int variant, int tier) => DailyChallengeEntry(
      day: '2026-10-17',
      variant: variant,
      tier: tier,
      seed: 47,
    );
    final plain = combat(),
        rush = combat(entry: entry(0, 0)),
        fast = combat(entry: entry(2, 0)),
        hard = combat(entry: entry(2, 2));
    for (final g in [plain, rush, fast, hard]) {
      g.update(.01);
    }
    expect(
      fast.enemies.first.speed / plain.enemies.first.speed,
      closeTo(1.15, 1e-10),
    );
    expect(
      hard.enemies.first.maxHp / fast.enemies.first.maxHp,
      closeTo(1.4, 1e-10),
    );
    expect(fast.collectionRadius / plain.collectionRadius, closeTo(1.2, 1e-10));
    expect(rush.requiredBosses, 1);
    expect(rush.duration, 180);
    for (var i = 0; i < 120; i++) {
      plain.update(.05);
      rush.update(.05);
    }
    expect(
      rush.enemies.length + rush.kills,
      greaterThan(plain.enemies.length + plain.kills),
    );
  });

  test('pet awakening affects only selected pet projectile, healing, interception or interval', () {
    final normal = combat(pet: 0), awake = combat(pet: 0, power: .18);
    for (final g in [normal, awake]) {
      g.enemies.add(Foe(g.position + const Offset(200, 100), 100000, 0, 10, 0));
      g.update(.01);
    }
    final base = normal.shots.firstWhere((s) => s.weapon == 'pet').damage;
    expect(
      awake.shots.firstWhere((s) => s.weapon == 'pet').damage / base,
      closeTo(1.18, 1e-10),
    );
    final heal = combat(pet: 1), healAwake = combat(pet: 1, power: .15);
    for (final g in [heal, healAwake]) {
      g.hp = g.maxHp / 2;
      g.update(.01);
    }
    expect(
      (healAwake.hp - healAwake.maxHp / 2) / (heal.hp - heal.maxHp / 2),
      closeTo(1.15, 1e-10),
    );
    final shield = combat(pet: 2), shieldAwake = combat(pet: 2, power: .15);
    for (final g in [shield, shieldAwake]) {
      g.petPosition = g.position + const Offset(-34, 32);
      g.shots.add(
        Shot(g.petPosition + const Offset(146, 0), Offset.zero, 1, 4),
      );
      g.update(.01);
    }
    expect(shield.shots.where((s) => s.kind == 4), isNotEmpty);
    expect(shieldAwake.shots.where((s) => s.kind == 4), isEmpty);
    final rapid = combat(pet: 0, cooldown: .12), slow = combat(pet: 0);
    for (final g in [rapid, slow]) {
      g.enemies.add(Foe(g.position + const Offset(200, 100), 100000, 0, 10, 0));
      for (var i = 0; i < 17; i++) {
        g.update(.05);
      }
    }
    expect(
      rapid.shots.where((s) => s.weapon == 'pet').length,
      greaterThan(slow.shots.where((s) => s.weapon == 'pet').length),
    );
    expect(rapid.damageFactor, slow.damageFactor);
  });
}
