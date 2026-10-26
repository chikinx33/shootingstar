import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/survival_skills.dart';
import 'package:shootingstar/ui/battle_statistics.dart';

GameEngine arena({String armament = 'pulse', bool ready = true}) {
  final g =
      GameEngine(
          stageIndex: 0,
          shipIndex: 0,
          attackLevel: 0,
          hullLevel: 0,
          magnetLevel: 0,
          equipmentIndex: 0,
          armament: armament,
          seed: 17,
        )
        ..hp = 100000
        ..maxHp = 100000
        ..xpNeeded = 1e9;
  g.upgrades.clear();
  if (ready && armament == 'pulse') {
    g.upgrades['laser'] = 1;
  } else if (ready && armament == 'shotgun') {
    g.upgrades['missile'] = 1;
    g.passives['area'] = 1;
  }
  return g;
}

Foe target(
  GameEngine g, {
  Offset offset = const Offset(0, -100),
  double hp = 10000,
}) {
  final e = Foe(g.position + offset, hp, 0, 12, 0);
  g.enemies.add(e);
  return e;
}

void hit(GameEngine g, Foe e, {double damage = 1, bool secondary = false}) {
  g.shots.add(
    Shot(e.position, Offset.zero, damage, 0, weapon: 'gun')
      ..triggersSynergies = !secondary,
  );
  g.update(.02);
  g.enemies.removeWhere((v) => !identical(v, e));
}

void advance(GameEngine g, double seconds) {
  for (int i = 0; i < (seconds / .02).ceil(); i++) g.update(.02);
}

void main() {
  test('a primary hit outside slow breaks the front chain', () {
    final g = arena();
    final e = target(g)
      ..status = 2
      ..statusTime = 10;
    hit(g, e);
    hit(g, e);
    e.statusTime = 0;
    hit(g, e);
    e.status = 2;
    e.statusTime = 10;
    hit(g, e);
    expect(g.synergyTriggers('front-break'), 0);
    hit(g, e);
    hit(g, e);
    expect(g.synergyTriggers('front-break'), 1);
  });
  test('front per-target cooldown survives the shorter global cooldown', () {
    final g = arena();
    final e = target(g)
      ..status = 2
      ..statusTime = 20;
    hit(g, e);
    hit(g, e);
    hit(g, e);
    advance(g, 3.05);
    hit(g, e);
    hit(g, e);
    hit(g, e);
    expect(g.synergyTriggers('front-break'), 1);
    advance(g, 1.05);
    hit(g, e);
    hit(g, e);
    hit(g, e);
    expect(g.synergyTriggers('front-break'), 2);
  });
  test('a single piercing bullet cannot count the same target three times', () {
    final g = arena();
    final e = target(g)
      ..status = 2
      ..statusTime = 10;
    g.shots.add(
      Shot(e.position, Offset.zero, 1, 0, weapon: 'gun', pierce: 10, life: 1),
    );
    advance(g, .5);
    expect(e.frontBreakHits, 1);
    expect(g.synergyTriggers('front-break'), 0);
  });
  test('all auxiliaries and fusion results have immutable roles; tags follow evolution', () {
    final auxiliaries = survivalSkills.where(
      (s) => !s.passive && s.id != 'gun' && s.id != 'pilot',
    );
    expect(auxiliaries.length, 18);
    for (final s in auxiliaries)
      expect(weaponRoleFor(s.id), isNotNull, reason: s.id);
    expect(weaponRoleFor('drone')!.tags.contains(WeaponTag.pierce), false);
    expect(
      weaponRoleFor('drone', evolved: true)!.tags.contains(WeaponTag.pierce),
      true,
    );
    expect(weaponRoleFor('droneB')!.tags, {
      WeaponTag.direct,
    }); // no fabricated AoE
    expect(weaponRoleFor('armor'), isNull);
    final g = arena(ready: false)..upgrades['infernoMine'] = 5;
    expect(g.auxiliaryTags, {WeaponTag.explosive, WeaponTag.burn});
    g.upgrades
      ..clear()
      ..['thunderMine'] = 5;
    expect(g.auxiliaryTags, {WeaponTag.explosive, WeaponTag.chain});
  });

  test('recipes require exact weapon and passive without consuming or occupying slots', () {
    final front = arena();
    expect(front.synergyReady('front-break'), true);
    front.upgrades.remove('laser');
    expect(front.synergyReady('front-break'), false);
    final blast = arena(armament: 'shotgun');
    expect(blast.synergyReady('explosive-spread'), true);
    blast.passives.remove('area');
    expect(blast.synergyReady('explosive-spread'), false);
    blast.passives['area'] = 1;
    blast.upgrades.addAll({
      'drone': 1,
      'side': 1,
      'mine': 1,
      'trail': 1,
      'guardian': 1,
    });
    blast.passives.addAll({
      'attack': 1,
      'hull': 1,
      'speed': 1,
      'magnet': 1,
      'armor': 1,
    });
    final weapons = Map.of(blast.upgrades), passives = Map.of(blast.passives);
    expect(blast.synergyReady('explosive-spread'), true);
    expect(blast.weaponCount, 6);
    expect(blast.passives.length, 6);
    expect(blast.upgrades, weapons);
    expect(blast.passives, passives);
  });

  test(
    'laser applies build-specific slow only on actual hits, excluding bosses',
    () {
      for (final ready in [false, true]) {
        // v12.17: front-break needs the 치즈 pulse gun plus the laser.
        final g = arena(armament: ready ? 'pulse' : 'revolver', ready: ready)
          ..upgrades['laser'] = 1;
        final along = target(g, offset: const Offset(110, 0));
        final away = target(g, offset: const Offset(-110, -70));
        g.update(.001);
        expect(along.hp, lessThan(along.maxHp));
        expect(along.statusTime > 0, ready);
        expect(away.statusTime, 0);
      }
    },
  );

  test('front requires 3 actual slowed hits; window, per-target/global cooldown and next-shot buff are bounded', () {
    final g = arena();
    final e = target(g)
      ..status = 2
      ..statusTime = 10;
    hit(g, e);
    hit(g, e);
    expect(g.synergyTriggers('front-break'), 0);
    hit(g, e);
    expect(g.synergyTriggers('front-break'), 1);
    expect(g.frontBreakRemaining, inInclusiveRange(1.2, 1.25));
    g.upgrades['gun'] = 1;
    g.shots.clear();
    g.update(.001);
    expect(g.shots.firstWhere((s) => s.kind == 0).pierce, 1);
    g.upgrades.remove('gun');
    for (int i = 0; i < 10; i++) hit(g, e);
    expect(g.synergyTriggers('front-break'), 1);
    advance(g, 1.3);
    expect(g.frontBreakRemaining, 0);
    g.upgrades['gun'] = 1;
    g.shots.clear();
    g.update(.001);
    expect(g.shots.firstWhere((s) => s.kind == 0).pierce, 0);
    expect(g.synergyTriggers('front-break'), 1);
  });

  test('front resets a broken chain and never counts a secondary projectile, beam, boss or invulnerable hit', () {
    final g = arena();
    final e = target(g)
      ..status = 2
      ..statusTime = 10;
    hit(g, e);
    advance(g, 1.12);
    hit(g, e);
    hit(g, e);
    expect(g.synergyTriggers('front-break'), 0);
    hit(g, e, secondary: true);
    expect(g.synergyTriggers('front-break'), 0);
    hit(g, e, damage: 0);
    expect(g.synergyTriggers('front-break'), 0);
    hit(g, e);
    expect(g.synergyTriggers('front-break'), 1);
    final bossGame = arena();
    final boss = Foe(bossGame.position + const Offset(0, -100), 10000, 0, 30, 3)
      ..status = 2
      ..statusTime = 10;
    bossGame.enemies.add(boss);
    for (int i = 0; i < 5; i++) hit(bossGame, boss);
    expect(bossGame.synergyTriggers('front-break'), 0);
  });

  test('pause and choice clocks freeze buffs; missing equipment disables stale eligibility', () {
    final g = arena();
    final e = target(g)
      ..status = 2
      ..statusTime = 10;
    hit(g, e);
    hit(g, e);
    hit(g, e);
    final remaining = g.frontBreakRemaining;
    g.setPaused(true);
    advance(g, 2);
    g.setPaused(false);
    g.choices = [GameEngine.catalog.first];
    advance(g, 2);
    g.choices.clear();
    expect(g.frontBreakRemaining, remaining);
    g.upgrades.remove('laser');
    expect(g.frontBreakRemaining, 0);
    expect(g.synergyHudText, isEmpty);
    expect(arena().synergyTriggers('front-break'), 0);
  });

  test('shotgun kills launch exactly two nonrecursive rockets and respect global cooldown', () {
    final g = arena(armament: 'shotgun');
    final dead = target(g, hp: 1);
    target(g, offset: const Offset(55, -100));
    g.shots.add(Shot(dead.position, Offset.zero, 10, 0, weapon: 'gun'));
    g.update(.001);
    final shards = g.shots
        .where((s) => s.weapon == 'synergy-explosive')
        .toList();
    expect(shards.length, 2);
    expect(shards.every((s) => !s.triggersSynergies && s.life == 1.2), true);
    expect(g.synergyTriggers('explosive-spread'), 1);
    final second = target(g, offset: const Offset(-50, -100), hp: 1);
    g.shots.add(Shot(second.position, Offset.zero, 10, 0, weapon: 'gun'));
    g.update(.001);
    expect(g.synergyTriggers('explosive-spread'), 1);
    expect(g.shots.where((s) => s.weapon == 'synergy-explosive').length, 2);
  });

  test('secondary shell fragments and unsupported builds cannot trigger kill chains', () {
    for (final ready in [false, true]) {
      final g = arena(armament: 'shotgun', ready: ready);
      final e = target(g, hp: 1);
      target(g, offset: const Offset(55, -100));
      g.shots.add(
        Shot(e.position, Offset.zero, 10, 0, weapon: 'gun')
          ..triggersSynergies = !ready,
      );
      g.update(.001);
      expect(g.synergyTriggers('explosive-spread'), 0);
    }
  });

  test('explosive damage and splash keep attribution and cannot generate further procs', () {
    final g = arena(armament: 'shotgun');
    final a = target(g, hp: 1),
        b = target(g, offset: const Offset(55, -100), hp: 20);
    g.shots.add(Shot(a.position, Offset.zero, 100, 0, weapon: 'gun'));
    g.update(.001);
    final generated = g.shots.firstWhere(
      (s) => s.weapon == 'synergy-explosive',
    );
    generated
      ..position = b.position
      ..velocity = Offset.zero;
    final c = target(g, offset: const Offset(65, -100), hp: 100);
    g.update(.001);
    expect(g.damageByWeapon['synergy-explosive'], greaterThan(0));
    expect(c.hp, lessThan(c.maxHp));
    expect(g.synergyTriggers('explosive-spread'), 1);
    expect(
      damageSourceLabel('synergy-explosive', armament: '산탄', pilot: '기본'),
      contains('폭발 확산'),
    );
  });

  test('dense same-frame kills create at most one proc; ordinary reward accounting remains intact', () {
    final g = arena(armament: 'shotgun');
    target(g, offset: const Offset(170, -150), hp: 100000);
    for (int i = 0; i < 35; i++) {
      final e = target(
        g,
        offset: Offset((i % 7) * 17.0 - 60, -150 - (i ~/ 7) * 20.0),
        hp: 1,
      );
      g.shots.add(Shot(e.position, Offset.zero, 100, 0, weapon: 'gun'));
    }
    g.update(.001);
    expect(g.synergyTriggers('explosive-spread'), 1);
    expect(g.shots.where((s) => s.weapon == 'synergy-explosive').length, 2);
    expect(g.kills, 35);
    expect(g.crystals.length, inInclusiveRange(1, 34));
    expect(g.crystals.every((c) => ExperienceCrystal.valueOf(c) == 4), isTrue);
  });

  test('statistics freeze roles, requirements and proc counts without changing recipes', () {
    final g = arena();
    final e = target(g)
      ..status = 2
      ..statusTime = 10;
    hit(g, e);
    hit(g, e);
    hit(g, e);
    final snapshot = BattleStatisticsSnapshot.fromGame(g);
    expect(snapshot.synergies.single, contains('정면 돌파 · 활성 · 1회'));
    expect(snapshot.weapons.single.recipe, contains('제어·지원 · 관통'));
    g.upgrades.clear();
    expect(snapshot.synergies.single, contains('활성'));
    final hint = arena().choiceDetail(
      const UpgradeChoice('laser', '레이저', '', 'laser'),
    );
    expect(hint, contains('제어·지원'));
    expect(hint, contains('정면 돌파'));
  });
}
