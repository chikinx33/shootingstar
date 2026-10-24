import 'dart:convert';
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

  test('twelve mounts fire from the painted tip, with drone aiming and top vertical missile', () {
    for (final id in ['gun_vulcan', 'missile_hawk', 'drone_wasp']) {
      for (final mount in ['W1', 'W2', 'W3', 'W4']) {
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
        final expected = id == 'drone_wasp'
            ? ModuleGeometry.muzzle(
                g
                    .droneFormation(
                      mount,
                      g.moduleLoadout!.parts[mount]!,
                      g.partStats(mount).count,
                    )
                    .first,
                ModuleGeometry.droneExtent,
                PartCategory.drone,
                angle,
              )
            : g.moduleMuzzleAt(mount, 0, angle);
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
        if (id == 'missile_hawk' && mount == 'W4')
          expect(g.moduleVisualAngle(mount), 0);
        if (id == 'drone_wasp')
          expect(
            g.droneVisualAngle(
              mount,
              g.moduleLoadout!.parts[mount]!,
              0,
              g
                  .droneFormation(
                    mount,
                    g.moduleLoadout!.parts[mount]!,
                    g.partStats(mount).count,
                  )
                  .first,
            ),
            closeTo(angle, .01),
          );
      }
    }
  });

  test(
    'wing missiles launch on alternate sides from the current moving socket',
    () {
      final g = reviewGame('missile_hawk', 'W1');
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
        (launch - g.moduleMuzzleAt('W1', 1, angle)).distance,
        lessThan(g.moveSpeed * .02),
      );
      expect(launch.dx, greaterThan(old.dx + 10));
      expect(
        g.visuals.recoil(ModuleGeometry.recoilKey('W1', 1)).distance,
        greaterThan(0),
      );
    },
  );

  test('top missile has ascent, three falling projectiles and deterministic mid-fall resume', () {
    final g = reviewGame('missile_hawk', 'W4');
    ring(g);
    for (var i = 0; i < 25; i++) g.update(1 / 60);
    final drops = g.shots
        .where((s) => s.weapon.startsWith('part:') && s.closeRange)
        .toList();
    expect(drops, hasLength(3));
    expect(
      drops.every(
        (s) => s.position.dy < s.target!.position.dy && s.velocity.dy > 0,
      ),
      isTrue,
    );
    final copy = BattleCheckpoint.restore(
      jsonDecode(jsonEncode(g.checkpoint())),
    );
    for (var i = 0; i < 65; i++) {
      g.update(1 / 60);
      copy.update(1 / 60);
    }
    expect(g.damageByWeapon['part:W4:missile_hawk'], greaterThan(0));
    expect(copy.damageByWeapon, g.damageByWeapon);
  });

  test('belly missile consumes pierce and damages a second separated ground target', () {
    final g = reviewGame('missile_hawk', 'W2');
    final targets = [
      for (final y in [-90.0, -180.0])
        Foe(
          g.position + Offset(0, y),
          10000,
          0,
          10,
          0,
          plane: AircraftTarget.ground,
        ),
    ];
    g.enemies.addAll(targets);
    for (var i = 0; i < 90; i++) g.update(1 / 60);
    expect(targets.every((e) => e.hp < e.maxHp), isTrue);
    expect(
      g.damageByWeapon['part:W2:missile_hawk'],
      closeTo(g.partStats('W2').damage * 2, .001),
    );
  });
}
