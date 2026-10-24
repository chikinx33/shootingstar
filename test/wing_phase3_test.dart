import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/combat_loadout.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle_statistics.dart';

GameEngine arena({
  String pilot = 'common',
  String weapon = 'pulse',
  int pet = -1,
}) =>
    GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        pilot: pilot,
        armament: weapon,
        petKind: pet,
        petLevel: pet >= 0 ? 1 : 0,
        seed: 17,
      )
      ..upgrades.clear()
      ..hp = 100000
      ..maxHp = 100000
      ..xpNeeded = 1e9;

void advance(GameEngine g, double seconds, {bool quiet = false}) {
  for (int i = 0; i < (seconds / .02).ceil(); i++) {
    g.update(.02);
    if (quiet) {
      g.enemies.clear();
      g.shots.clear();
      g.supplies.clear();
      g.crystals.clear();
    }
  }
}

void charge(GameEngine g) => advance(g, 20.1, quiet: true);
void arm(GameEngine g) {
  g.upgrades['guardian'] = 3;
  g.passives['armor'] = 1;
  g.shots.add(Shot(g.position + const Offset(0, -35), Offset.zero, 9, 4));
  g.update(.001);
  g.enemies.clear();
}

void main() {
  test('common charges one capped resource in combat; other pilot abilities remain separate', () {
    final g = arena();
    expect(g.activateCommonUltimate(), false);
    charge(g);
    expect(g.ultimateCharge, 100);
    expect(g.ultimateReady, true);
    advance(g, 2, quiet: true);
    expect(g.ultimateCharge, 100);
    expect(g.activateCommonUltimate(), true);
    expect(g.ultimateCharge, 0);
    expect(g.activateCommonUltimate(), false);
    advance(g, 1.9, quiet: true);
    expect(g.ultimateCharge, 0);
    advance(g, .2, quiet: true);
    expect(g.ultimateCharge, lessThan(1));
    final other = arena(pilot: 'yang');
    charge(other);
    expect(other.hasCommonUltimate, false);
    expect(other.ultimateCharge, 0);
    expect(other.activateCommonUltimate(), false);
    expect(other.activatePilotAbility(), true);
    expect(g.activatePilotAbility(), false);
  });
  test('pause, choice and finish freeze charge and prevent spending', () {
    final g = arena();
    g.setPaused(true);
    charge(g);
    expect(g.ultimateCharge, 0);
    g.setPaused(false);
    g.choices = [mainBranches.first.choice];
    charge(g);
    expect(g.ultimateCharge, 0);
    g.choices.clear();
    charge(g);
    g.setPaused(true);
    expect(g.activateCommonUltimate(), false);
    g.setPaused(false);
    g.choices = [mainBranches.first.choice];
    expect(g.activateCommonUltimate(), false);
    g.choices.clear();
    g.finished = true;
    expect(g.activateCommonUltimate(), false);
    expect(g.ultimateCharge, 100);
  });
  test('four bounded forward pulses have distinct damage attribution and active time freezes', () {
    final g = arena();
    charge(g);
    final front = Foe(g.position + const Offset(0, -120), 10000, 0, 12, 0);
    final side = Foe(g.position + const Offset(150, -120), 10000, 0, 12, 0);
    final back = Foe(g.position + const Offset(0, 120), 10000, 0, 12, 0);
    g.enemies.addAll([front, side, back]);
    g.activateCommonUltimate();
    expect(front.maxHp - front.hp, closeTo(45 * g.damageFactor, .001));
    final remaining = g.ultimateRemaining;
    g.setPaused(true);
    advance(g, 2);
    g.setPaused(false);
    expect(g.ultimateRemaining, remaining);
    g.choices = [mainBranches.first.choice];
    advance(g, 2);
    g.choices.clear();
    expect(g.ultimateRemaining, remaining);
    advance(g, 2.1);
    expect(front.maxHp - front.hp, closeTo(180 * g.damageFactor, .001));
    expect(
      g.damageByWeapon['common-ultimate'],
      greaterThanOrEqualTo(front.maxHp - front.hp - .001),
    );
    expect(side.hp, side.maxHp);
    expect(back.hp, back.maxHp);
    expect(g.ultimateDescription, contains('사용 1회'));
  });
  test('ultimate clears only interceptable forward bullets, without invulnerability or guard procs', () {
    final g = arena();
    charge(g);
    g.upgrades['guardian'] = 3;
    g.passives['armor'] = 1;
    for (final kind in [4, 19, 20, 21, 22, 23, 24, 17, 0]) {
      g.shots.add(
        Shot(g.position + const Offset(0, -40), Offset.zero, 9, kind, life: 3),
      );
    }
    final back = Shot(g.position + const Offset(0, 30), Offset.zero, 9, 4);
    final side = Shot(g.position + const Offset(150, -40), Offset.zero, 9, 4);
    g.shots.addAll([back, side]);
    g.activateCommonUltimate();
    expect(g.shots.where((s) => [4, 19, 20, 21].contains(s.kind)).length, 2);
    for (final kind in [22, 23, 24, 17, 0])
      expect(g.shots.any((s) => s.kind == kind), true);
    expect(g.shieldCounterPending, false);
    expect(g.synergyTriggers('shield-counter'), 0);
    g.upgrades.clear();
    g.shots.clear();
    g.shots.add(Shot(g.position + const Offset(0, 1), Offset.zero, 9, 4));
    final before = g.hp;
    g.update(.001);
    expect(g.hp, lessThan(before));
  });
  test('ultimate respects closed boss gates and does not grant evolution, slots or persistent resources', () {
    final g = arena();
    charge(g);
    final boss = Foe(g.position + const Offset(0, -120), 1000, 0, 30, 3)
      ..hp = 650.01;
    g.enemies.add(boss);
    g.activateCommonUltimate();
    advance(g, 2);
    expect(boss.hp, greaterThanOrEqualTo(650));
    expect(g.upgrades, isEmpty);
    expect(g.passives, isEmpty);
    expect(g.evolved, isEmpty);
    expect(arena().ultimateCharge, 0);
    expect(
      damageSourceLabel('common-ultimate', armament: '펄스', pilot: '기본'),
      contains('항성포'),
    );
  });
  test('shield counter needs guardian level3 and armor and is pilot/weapon independent', () {
    final g = arena(pilot: 'king', weapon: 'revolver');
    g.upgrades['guardian'] = 2;
    g.passives['armor'] = 1;
    expect(g.synergyReady('shield-counter'), false);
    g.upgrades['guardian'] = 3;
    expect(g.synergyReady('shield-counter'), true);
    g.passives.remove('armor');
    expect(g.synergyReady('shield-counter'), false);
  });
  test('a live hostile guardian interception arms once, not friendly, expired, zero damage or excluded shots', () {
    for (final kind in [4, 19, 20, 21]) {
      final g = arena();
      g.upgrades['guardian'] = 3;
      g.passives['armor'] = 1;
      for (int i = 0; i < 10; i++)
        g.shots.add(
          Shot(g.position + const Offset(0, -35), Offset.zero, 9, kind),
        );
      g.update(.001);
      expect(g.synergyTriggers('shield-counter'), 1, reason: 'kind $kind');
      expect(g.shieldCounterPending, true);
    }
    for (final shot in [
      Shot(Offset.zero, Offset.zero, 9, 0),
      Shot(Offset.zero, Offset.zero, 9, 4, life: 0),
      Shot(Offset.zero, Offset.zero, 0, 4),
      Shot(Offset.zero, Offset.zero, 9, 22),
      Shot(Offset.zero, Offset.zero, 9, 23),
    ]) {
      final g = arena();
      g.upgrades['guardian'] = 3;
      g.passives['armor'] = 1;
      shot.position = g.position + const Offset(0, -35);
      g.shots.add(shot);
      g.update(.001);
      expect(g.shieldCounterPending, false);
    }
  });
  test(
    'pet interception and inactive guardian shield do not arm a counter',
    () {
      final pet = arena(pet: 2);
      arm(pet);
      expect(pet.shieldCounterPending, false);
      final g = arena()..combatTime = 2;
      arm(g);
      expect(g.shieldCounterPending, false);
    },
  );
  test('counter empowers one entire N volley, then expires and cannot stack within cooldown', () {
    final g = arena();
    arm(g);
    expect(g.shieldCounterPending, true);
    final frozen = g.combatTime;
    g.setPaused(true);
    advance(g, 4);
    g.setPaused(false);
    g.choices = [mainBranches.first.choice];
    advance(g, 4);
    g.choices.clear();
    expect(g.combatTime, frozen);
    g.upgrades['gun'] = 1;
    g.mainCount = 2;
    g.update(.001);
    final volley = g.shots.where((s) => s.kind == 0).toList();
    expect(volley.length, 3);
    expect(
      volley.every((s) => (s.damage - 17 * g.damageFactor * 1.5).abs() < .001),
      true,
    );
    expect(g.shieldCounterPending, false);
    g.shots.clear();
    advance(g, .4);
    expect(
      g.shots
          .where((s) => s.kind == 0)
          .every((s) => (s.damage - 17 * g.damageFactor).abs() < .001),
      true,
    );
    expect(g.synergyTriggers('shield-counter'), 1);
    final timeout = arena();
    arm(timeout);
    advance(timeout, 3.1, quiet: true);
    expect(timeout.shieldCounterPending, false);
    timeout.shots.add(
      Shot(timeout.position + const Offset(0, -35), Offset.zero, 9, 4),
    );
    advance(timeout, .2);
    expect(timeout.synergyTriggers('shield-counter'), 1);
  });
  test(
    'all ten armaments deliver the counter through their existing attack path',
    () {
      for (final spec in armaments) {
        final damages = <double>[];
        for (final counter in [false, true]) {
          final g = arena(weapon: spec.id);
          if (counter)
            arm(g);
          else {
            g.update(.001);
            g.enemies.clear();
          }
          g.upgrades['gun'] = 1;
          g.enemies.add(
            Foe(g.position + const Offset(0, -80), 100000, 0, 12, 0),
          );
          g.update(.001);
          final shots = g.shots
              .where((s) => !s.hostile && s.damage > 0)
              .toList();
          final score = shots.isNotEmpty
              ? shots.map((s) => s.damage).reduce((a, b) => a > b ? a : b)
              : g.damageByWeapon.values.fold(0.0, (a, b) => a + b);
          damages.add(score);
          if (counter) expect(g.shieldCounterPending, false, reason: spec.id);
        }
        expect(damages.first, greaterThan(0), reason: spec.id);
        expect(
          damages.last,
          closeTo(damages.first * 1.5, .001),
          reason: spec.id,
        );
      }
    },
  );
  test('counter does not consume on an empty target-only attack and snapshots freeze new details', () {
    final g = arena(weapon: 'kunai');
    arm(g);
    g.upgrades['gun'] = 1;
    g.update(.001);
    expect(g.shieldCounterPending, true);
    final snap = BattleStatisticsSnapshot.fromGame(g);
    expect(snap.synergies.any((s) => s.contains('방패 역습 · 활성')), true);
    expect(snap.ultimate, contains('항성포'));
    g.upgrades.clear();
    expect(snap.synergies.any((s) => s.contains('활성')), true);
  });
}
