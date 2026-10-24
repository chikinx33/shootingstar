import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/aircraft_geometry.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/data/hangar_preset.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine arena({
  AircraftAssembly? assembly,
  String weapon = 'pulse',
  int hull = 0,
  bool legacy = false,
}) => GameEngine(
  stageIndex: 0,
  shipIndex: hull,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  armament: weapon,
  aircraft: legacy
      ? null
      : assembly ?? AircraftAssembly.initial(hull, pets: []),
  seed: 71,
  supportLevels: const {'repair': 10, 'capacitor': 10, 'ward': 10},
)..xpNeeded = 1e8;
Foe foe(GameEngine g, Offset delta, {bool ground = false}) => Foe(
  g.position + delta,
  10000,
  0,
  10,
  0,
  plane: ground ? AircraftTarget.ground : AircraftTarget.air,
);
void frames(GameEngine g, int count) {
  for (var i = 0; i < count; i++) {
    g.update(.025);
  }
}

GameEngine restore(GameEngine g) =>
    BattleCheckpoint.restore(jsonDecode(jsonEncode(g.checkpoint())));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('all hulls and primary firing modes use the real forward muzzle', () {
    for (var hull = 0; hull < 3; hull++) {
      for (final weapon in armaments) {
        final g = arena(
          hull: hull,
          weapon: weapon.id,
          assembly: AircraftAssembly(
            hull: hull,
            parts: const {AircraftMount.main: 'cannon'},
          ),
        );
        g.enemies.add(foe(g, const Offset(0, 120)));
        g.update(.001);
        final shots = g.shots.where((s) => s.weapon == 'module-main').toList();
        expect(shots, isNotEmpty, reason: weapon.id);
        final origin =
            g.position +
            AircraftGeometry.offset(hull, AircraftMount.main) +
            const Offset(0, -10);
        for (final shot in shots) {
          expect(shot.velocity.dy, lessThan(0));
          expect((shot.position - origin).distance, lessThan(20));
        }
      }
    }
  });
  test(
    'air and ground masks hold for direct shots, blast and the ultimate',
    () {
      final g = arena(
        assembly: AircraftAssembly(parts: const {AircraftMount.main: 'cannon'}),
      );
      final air = foe(g, const Offset(0, -100)),
          ground = foe(g, const Offset(0, -100), ground: true);
      g.enemies.addAll([air, ground]);
      for (final source in [
        'module-main',
        'module-auxiliary',
        'module-wings',
        'module-rear',
        'common-ultimate',
        'status',
      ]) {
        expect(g.modularSourceCanHit(source, air), true);
        expect(g.modularSourceCanHit(source, ground), false);
      }
      expect(g.modularSourceCanHit('module-ground', air), false);
      expect(g.modularSourceCanHit('module-ground', ground), true);
      g.shots.add(
        Shot(
          g.position,
          Offset.zero,
          100,
          26,
          weapon: 'module-ground',
          anchor: ground.position,
          life: .7,
          radius: 60,
        )..age = .44,
      );
      g.update(.025);
      expect(ground.hp, lessThan(ground.maxHp));
      expect(air.hp, air.maxHp);
      final groundHp = ground.hp;
      frames(g, 30);
      expect(air.hp, lessThan(air.maxHp));
      expect(ground.hp, groundHp);
    },
  );
  test(
    'wing pair, rear direction and optional slot removal change actual attacks',
    () {
      final g = arena();
      g.enemies.addAll([
        foe(g, const Offset(-160, 0)),
        foe(g, const Offset(160, 0)),
        foe(g, const Offset(0, 180)),
      ]);
      g.update(.001);
      final wings = g.shots.where((s) => s.weapon == 'module-wings').toList();
      expect(wings, hasLength(2));
      expect(wings.first.velocity.dx, lessThan(0));
      expect(wings.last.velocity.dx, greaterThan(0));
      final rear = g.shots.where((s) => s.weapon == 'module-rear');
      expect(rear, hasLength(2));
      expect(rear.every((s) => s.velocity.dy > 0 && s.velocity.dx == 0), true);
      final minimal = arena(
        assembly: AircraftAssembly(parts: const {AircraftMount.main: 'cannon'}),
      );
      minimal.enemies.addAll([
        foe(minimal, const Offset(-120, 0)),
        foe(minimal, const Offset(0, 150)),
      ]);
      frames(minimal, 200);
      expect(
        minimal.shots.every((s) => s.hostile || s.weapon == 'module-main'),
        true,
      );
    },
  );
  test('utility pods never attack and shield and recovery remain bounded', () {
    final g = arena(
      assembly: AircraftAssembly.demo().equip(
        AircraftMount.auxiliary,
        'auxShield',
      ),
    );
    g.developerInvincible = true;
    g.hp = g.maxHp * .5;
    g.enemies.add(foe(g, const Offset(120, 0)));
    frames(g, 500);
    expect(g.hp, greaterThan(g.maxHp * .5));
    expect(g.hp, lessThanOrEqualTo(g.maxHp));
    expect(g.moduleShield, greaterThan(0));
    expect(g.moduleShield, lessThanOrEqualTo(g.maxHp * .22));
    expect(
      g.shots.where((s) => s.weapon == 'pet' || s.weapon == 'module-auxiliary'),
      isEmpty,
    );
    expect(
      g.damageByWeapon.keys.any(
        (id) => id.contains('pet') || id.contains('support'),
      ),
      false,
    );
    expect(g.ultimateCharge, greaterThan(60));
  });
  test('ground units spawn with warning and do not collide as aircraft', () {
    final g = arena(
      assembly: AircraftAssembly(parts: const {AircraftMount.main: 'cannon'}),
    );
    frames(g, 330);
    final ground = g.enemies
        .where((e) => e.plane == AircraftTarget.ground)
        .first;
    g.enemies.removeWhere((e) => e != ground);
    g.shots.clear(); // Isolate the ground actor from prior air combat.
    ground.position = g.position;
    ground.attackClock = .7;
    final hp = g.hp;
    g.update(.025);
    expect(ground.tell, greaterThan(0));
    expect(g.hp, hp);
    // A shell fired exactly on the hero is consumed by its same-frame hit.
    // Move the gun away and start a fresh tell to observe its flight separately.
    ground.position = g.position + const Offset(0, -120);
    ground.tell = 0;
    ground.attackClock = .7;
    frames(g, 30);
    expect(g.shots.any((s) => s.weapon == 'ground-shell'), true);
  });
  test(
    'modular checkpoint resumes exact timers, target planes and bomb state',
    () {
      final g = arena(assembly: AircraftAssembly.demo());
      g.enemies.add(foe(g, const Offset(100, -150), ground: true));
      frames(g, 5);
      final saved = g.checkpoint();
      final copy = restore(g)..setPaused(false);
      expect(copy.aircraft!.toJson(), g.aircraft!.toJson());
      expect(copy.checkpoint()['state'], saved['state']);
      expect(copy.enemies.map((e) => e.plane), g.enemies.map((e) => e.plane));
      expect(copy.shots.any((s) => s.kind == 26), true);
      for (var i = 0; i < 100; i++) {
        g.update(.025);
        copy.update(.025);
      }
      expect(jsonEncode(copy.checkpoint()), jsonEncode(g.checkpoint()));
      final old = arena(legacy: true);
      final oldCopy = restore(old);
      expect(oldCopy.aircraft, isNull);
      final bad = jsonDecode(jsonEncode(saved)) as Map;
      bad['config']['aircraft']['parts']['main'] = 'bomb';
      expect(() => BattleCheckpoint.restore(bad), throwsFormatException);
    },
  );
  test('profile migration, ownership, support positions, presets and cloud replacement persist', () async {
    final legacy = Profile.freshProgress()..remove('aircraft');
    legacy['credits'] = 876;
    legacy['unlockedShips'] = [0, 1];
    (legacy['content'] as Map)['petLevels'] = [3, 2, 0];
    (legacy['content'] as Map)['assistingPets'] = [1];
    SharedPreferences.setMockInitialValues({
      Profile.storageKey: jsonEncode(legacy),
    });
    final p = await Profile.load();
    expect(p.credits, 876);
    expect(
      p.aircraftAssembly.parts.values,
      containsAll(['capacitor', 'repair']),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey('${Profile.storageKey}.beforeModularAircraft'),
      true,
    );
    final next = p.aircraftAssembly
        .withHull(1)
        .equip(AircraftMount.supportLeft, null)
        .equip(AircraftMount.supportRear, 'capacitor')
        .equip(AircraftMount.auxiliary, 'auxShield');
    expect(p.setAircraftAssembly(next), true);
    expect(p.setAircraftAssembly(next.withHull(2)), false);
    expect(
      p.setAircraftAssembly(next.equip(AircraftMount.supportLeft, 'ward')),
      false,
    );
    expect(p.setAircraftAssembly(next.equip(AircraftMount.main, null)), false);
    p.hangarPresets[0] = HangarPreset.capture(p, 'assembly');
    await p.save();
    final reload = await Profile.load();
    expect(reload.aircraftAssembly.toJson(), next.toJson());
    reload.setAircraftAssembly(AircraftAssembly.initial(0));
    expect(reload.hangarPresets[0]!.apply(reload), true);
    expect(reload.aircraftAssembly.toJson(), next.toJson());
    await reload.replaceProgress(p.exportProgress());
    expect(reload.aircraftAssembly.toJson(), next.toJson());
    expect(reload.petLevels, [3, 2, 0]);
    expect(reload.credits, 876);
  });
  test('new modular combat stays bounded through eight minutes in early middle and final worlds', () {
    for (final world in [0, 5, 9]) {
      final g = GameEngine(
        stageIndex: world * 10,
        shipIndex: world % 3,
        attackLevel: 4,
        hullLevel: 4,
        magnetLevel: 2,
        equipmentIndex: 0,
        aircraft: AircraftAssembly.demo(world % 3),
        seed: 201 + world,
        supportLevels: const {'repair': 8, 'capacitor': 8, 'ward': 8},
      )..developerInvincible = true;
      var maxShots = 0, maxEnemies = 0;
      for (var i = 0; i < 19200 && !g.finished; i++) {
        if (g.choices.isNotEmpty) g.chooseUpgrade(g.choices.first.id);
        g.input = Offset(math.sin(i / 200), math.cos(i / 170)) * .7;
        g.update(.025);
        maxShots = math.max(maxShots, g.shots.length);
        maxEnemies = math.max(maxEnemies, g.enemies.length);
        if (i % 2400 == 0) {
          expect(g.hp.isFinite, true);
          expect(g.position.dx.isFinite, true);
        }
      }
      expect(maxShots, lessThan(1000));
      expect(maxEnemies, lessThanOrEqualTo(240));
      expect(
        g.damageByWeapon.values.fold<double>(0, (a, b) => a + b),
        greaterThan(0),
      );
      expect(g.damageByWeapon.keys.any((k) => k == 'pet'), false);
      print(
        'MODULAR_ENDURANCE world=$world frames=19200 maxShots=$maxShots maxEnemies=$maxEnemies combat=${g.combatTime}',
      );
    }
  });
  test(
    'a lower-cap shield recharge cannot consume an existing stronger shield',
    () {
      final g = arena(
        assembly: AircraftAssembly.demo().equip(
          AircraftMount.auxiliary,
          'auxShield',
        ),
      );
      g.moduleShield = g.maxHp * .22;
      g.update(.025);
      expect(g.moduleShield, g.maxHp * .22);
    },
  );
}
