import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/combat_cues.dart';

GameEngine reviewGame(String id, String mount) => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  seed: 667,
  aircraft: AircraftAssembly(
    modules: ModuleSnapshot(0, 1, {
      mount: OwnedModulePart('review-$id', id, 1),
    }),
  ),
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: -1,
)..xpNeeded = 100000;

void ring(GameEngine g) {
  for (final point in const [
    Offset(-60, -130),
    Offset(60, -130),
    Offset(0, -130),
    Offset(130, 0),
    Offset(0, 130),
    Offset(-130, 0),
  ]) {
    g.enemies.add(Foe(g.position + point, 10000, 0, 16, 0));
  }
  g.enemies.add(
    Foe(
      g.position + const Offset(0, -210),
      10000,
      0,
      16,
      0,
      plane: AircraftTarget.ground,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // v12.11: each slot takes only the device drawn there
  test('every slot fires from the painted tip of its device', () {
    for (final (id, mount) in const [
      ('gun_vulcan', 'W1'),
      ('missile_hawk', 'W2'),
      ('gun_vulcan', 'W3'),
    ]) {
      {
        final g = reviewGame(id, mount);
        ring(g);
        g.visuals.followMovement(const Offset(4, -2), .016);
        g.update(.001);
        final shots = g.shots
            .where((s) => s.weapon == 'part:$mount:$id' && s.age >= 0)
            .toList();
        expect(shots, isNotEmpty, reason: '$id/$mount');
        final shot = shots.first;
        final flash = g.visuals.active.firstWhere(
          (v) => v.kind == CombatCueKind.muzzle && v.source == shot.weapon,
        );
        final direction = (flash.at - flash.from!) / 7;
        final angle = math.atan2(direction.dx, -direction.dy);
        final initial = shot.position - shot.velocity * .001;
        final expected = g.moduleMuzzleAt(mount, 0, angle);
        expect(
          (initial - expected).distance,
          lessThan(.01),
          reason: '$id/$mount muzzle',
        );
        expect((flash.at - (expected + shot.anchor!)).distance, lessThan(.01));
        expect(
          (direction - ModuleGeometry.direction(angle)).distance,
          lessThan(1e-8),
        );
      }
    }
  });

  test(
    'wing missiles launch on alternate sides from the current moving socket',
    () {
      final g = reviewGame('missile_hawk', 'W2');
      g.update(.001);
      final pending = g.shots.singleWhere(
        (s) => s.weapon.startsWith('part:') && s.age < 0,
      );
      expect(
        g.visuals.active.where(
          (c) => c.source == pending.weapon && c.kind == CombatCueKind.muzzle,
        ),
        hasLength(1),
      );
      final old = pending.position;
      g.input = const Offset(1, 0);
      for (var i = 0; i < 11; i++) g.update(.01);
      final launch = pending.position - pending.velocity * pending.age;
      final angle = math.atan2(pending.velocity.dx, -pending.velocity.dy);
      expect(
        (launch - g.moduleMuzzleAt('W2', 1, angle)).distance,
        lessThan(g.moveSpeed * .02),
      );
      expect(launch.dx, greaterThan(old.dx + 10));
      expect(
        g.visuals.recoil(ModuleGeometry.recoilKey('W2', 1)).distance,
        greaterThan(0),
      );
    },
  );

  // v12.11: the wing missile pair took over the old belly bay's ground strike
  test('wing missiles strike a ground target', () {
    final g = reviewGame('missile_hawk', 'W2');
    final target = Foe(
      g.position + const Offset(0, -140),
      10000,
      0,
      10,
      0,
      plane: AircraftTarget.ground,
    );
    g.enemies.add(target);
    for (var i = 0; i < 120; i++) g.update(1 / 60);
    expect(target.hp, lessThan(target.maxHp));
    expect(g.damageByWeapon['part:W2:missile_hawk'], greaterThan(0));
  });
}
