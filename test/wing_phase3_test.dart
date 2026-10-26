import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/combat_loadout.dart';
import 'package:shootingstar/data/ship_modules.dart';
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

// v12.16: a full star cannon takes about ninety seconds of flight.
void charge(GameEngine g) =>
    advance(g, CommonUltimate.chargeSeconds + .1, quiet: true);

/// Runs until the active ultimate ends, checking it never recharges meanwhile.
void finishUltimate(GameEngine g) {
  for (var i = 0; i < 2000 && g.ultimateRemaining > 0; i++) {
    expect(
      g.ultimateCharge,
      0,
      reason: 'no charge while the ultimate is active',
    );
    g.update(.02);
    g.enemies.clear();
    g.shots.clear();
  }
  expect(g.ultimateRemaining, 0);
}

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
    // about 1.11% per second of flight: 20 s is far from full
    advance(g, 20.1, quiet: true);
    expect(g.ultimateCharge, closeTo(20.1 * 100 / 90, .05));
    expect(g.ultimateReady, false);
    expect(g.activateCommonUltimate(), false);
    advance(g, 70, quiet: true);
    expect(g.ultimateCharge, 100);
    expect(g.ultimateReady, true);
    advance(g, 2, quiet: true);
    expect(g.ultimateCharge, 100);
    expect(g.activateCommonUltimate(), true);
    expect(g.ultimateCharge, 0);
    expect(g.ultimateRemaining, greaterThan(0));
    expect(g.activateCommonUltimate(), false);
    finishUltimate(g);
    advance(g, .2, quiet: true);
    expect(g.ultimateCharge, closeTo(.2 * 100 / 90, .03));
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
    g.choices = [GameEngine.catalog.first];
    charge(g);
    expect(g.ultimateCharge, 0);
    g.choices.clear();
    advance(g, 45, quiet: true);
    expect(g.ultimateCharge, closeTo(50, .1));
    charge(g);
    expect(g.ultimateCharge, 100);
    g.setPaused(true);
    expect(g.ultimateReady, false);
    expect(g.activateCommonUltimate(), false);
    g.setPaused(false);
    g.choices = [GameEngine.catalog.first];
    expect(g.ultimateReady, false);
    expect(g.activateCommonUltimate(), false);
    g.choices.clear();
    g.finished = true;
    expect(g.ultimateReady, false);
    expect(g.activateCommonUltimate(), false);
    expect(g.ultimateCharge, 100);
  });
  test('fish missile storm hunts enemies in every direction, plays the cut-in and freezes with combat', () {
    final g = arena();
    charge(g);
    expect(g.ultimateKind, 0);
    final front = Foe(g.position + const Offset(0, -160), 1e6, 0, 12, 0);
    final side = Foe(g.position + const Offset(200, -60), 1e6, 0, 12, 0);
    final back = Foe(g.position + const Offset(-160, 120), 1e6, 0, 12, 0);
    g.enemies.addAll([front, side, back]);
    expect(g.activateCommonUltimate(), true);
    expect(g.ultimateBanner, CommonUltimate.ultimateNames[0]);
    expect(g.ultimateShow, closeTo(1.6, 1e-9));
    expect(g.pickupNotice, g.ultimateName);
    expect(g.invincibleActive, false);
    expect(g.clonesActive, false);
    g.update(.02);
    final missiles = <Shot>{...g.shots.where((s) => s.weapon == 'ult-missile')};
    expect(missiles, isNotEmpty);
    expect(
      missiles.every((s) => s.kind == 1 && !s.hostile && s.target != null),
      true,
    );
    final remaining = g.ultimateRemaining;
    final launched = missiles.length;
    g.setPaused(true);
    advance(g, 2);
    g.setPaused(false);
    expect(g.ultimateRemaining, remaining);
    g.choices = [GameEngine.catalog.first];
    advance(g, 2);
    g.choices.clear();
    expect(g.ultimateRemaining, remaining);
    expect(g.shots.where((s) => s.weapon == 'ult-missile').length, launched);
    for (var i = 0; i < 400; i++) {
      g.update(.02);
      missiles.addAll(g.shots.where((s) => s.weapon == 'ult-missile'));
    }
    // 18..48 missiles, every foe around the cat taken down to size
    expect(missiles.length, inInclusiveRange(18, 48));
    for (final foe in [front, side, back]) {
      expect(foe.hp, lessThan(foe.maxHp));
    }
    expect(g.damageByWeapon['ult-missile'], greaterThan(0));
    expect(g.ultimateRemaining, 0);
    expect(g.ultimateCharge, greaterThan(0));
    expect(g.ultimateDescription, contains('사용 1회'));
  });
  test('ultimate clears interceptable bullets around the cat, without invulnerability or guard procs', () {
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
    final far = Shot(g.position + const Offset(0, -300), Offset.zero, 9, 4);
    g.shots.addAll([back, side, far]);
    g.activateCommonUltimate();
    // everything interceptable inside 260 is gone, in any direction
    expect(g.shots.where((s) => s.interceptable).toList(), [far]);
    for (final kind in [22, 23, 24, 17, 0])
      expect(g.shots.any((s) => s.kind == kind), true);
    expect(g.shieldCounterPending, false);
    expect(g.synergyTriggers('shield-counter'), 0);
    // the missile storm (ship 0) grants no invulnerability
    expect(g.invincibleActive, false);
    g.upgrades.clear();
    g.shots.clear();
    g.shots.add(Shot(g.position + const Offset(0, 1), Offset.zero, 9, 4));
    final before = g.hp;
    g.update(.001);
    expect(g.hp, lessThan(before));
  });
  test('each unified craft fires its own signature; only ship 2 is invincible and rams', () {
    for (var ship = 0; ship < 3; ship++) {
      final g = GameEngine(
        stageIndex: 0,
        shipIndex: ship,
        aircraft: AircraftAssembly(
          hull: ship,
          modules: ModuleSnapshot(ship, 1, {
            'W1': OwnedModulePart('w1', 'gun_vulcan', 1),
          }),
        ),
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: -1,
        seed: 7,
      )..xpNeeded = 1e9;
      expect(g.unifiedModules, true);
      expect(g.ultimateKind, ship);
      g.developerPrepare(scene: 0, ultimateReady: true);
      g.enemies.clear();
      g.shots.clear();
      final rammed = Foe(g.position + const Offset(0, -20), 1e6, 0, 12, 0);
      g.enemies.add(rammed);
      g.shots.add(Shot(g.position + const Offset(80, 0), Offset.zero, 9, 4));
      expect(g.activateCommonUltimate(), true, reason: 'ship $ship');
      expect(g.ultimateBanner, CommonUltimate.ultimateNames[ship]);
      expect(g.pickupNotice, CommonUltimate.ultimateNames[ship]);
      expect(g.shots.where((s) => s.interceptable), isEmpty);
      expect(g.clonesActive, ship == 1, reason: 'ship $ship');
      expect(g.invincibleActive, ship == 2, reason: 'ship $ship');
      expect(g.ultimateRemaining, closeTo(const [2.4, 10.0, 8.0][ship], 1e-9));
      g.update(.02);
      expect(
        (g.damageByWeapon['common-ultimate'] ?? 0) > 0,
        ship == 2,
        reason: 'only 까미 rams (ship $ship)',
      );
      expect(g.clonePositions.length, ship == 1 ? 2 : 0);
    }
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
      final pet = arena(pet: 2)..seatChicks();
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
    g.choices = [GameEngine.catalog.first];
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
  // v12.17: the target-only main guns are gone; every cat gun fires forward.
  test('armed counter snapshots freeze new details', () {
    final g = arena();
    arm(g);
    expect(g.shieldCounterPending, true);
    final snap = BattleStatisticsSnapshot.fromGame(g);
    expect(snap.synergies.any((s) => s.contains('방패 역습 · 활성')), true);
    expect(snap.ultimate, contains(g.ultimateName));
    expect(snap.ultimate, contains('생선 미사일 폭풍'));
    g.upgrades.clear();
    expect(snap.synergies.any((s) => s.contains('활성')), true);
  });
}
