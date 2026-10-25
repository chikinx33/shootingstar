import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/game/engine.dart';

import 'module_balance_test.dart' as bench;

void advance(GameEngine g, int frames) {
  for (var i = 0; i < frames; i++) g.update(1 / 60);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'piercing blast damages overlapping enemies once, including after resume',
    () {
      final g = bench.arena('missile_hawk', 'W2', 1, 42, 'ground');
      final targets = [
        for (final y in [-90.0, -110.0])
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
      for (var i = 0; i < 60 && g.damageByWeapon.isEmpty; i++) g.update(1 / 60);
      // v12.11: the pair fires two missiles; each blast hits both once
      final blast = g.partStats('W2').damage * 2;
      double total() => g.damageByWeapon['part:W2:missile_hawk']!;
      expect(targets[0].hp, closeTo(targets[1].hp, .001));
      expect(total() / blast, closeTo((total() / blast).roundToDouble(), 1e-6));
      final copy = BattleCheckpoint.restore(
        jsonDecode(jsonEncode(g.checkpoint())),
      );
      advance(g, 60);
      advance(copy, 60);
      expect(
        total(),
        lessThanOrEqualTo(blast * g.partStats('W2').count + .001),
      );
      expect(copy.damageByWeapon, g.damageByWeapon);
    },
  );

  test('wing missiles spread their locks but keep both launchers against a solo boss', () {
    for (final count in [1, 2]) {
      final g = bench.arena('missile_hawk', 'W2', 1, 42, 'front');
      for (var i = 0; i < count; i++)
        g.enemies.add(
          Foe(g.position + Offset((i - .5) * 80, -180), 10000, 0, 12, 0),
        );
      g.update(.001);
      final targets = g.shots
          .where((s) => s.weapon.startsWith('part:'))
          .map((s) => s.target)
          .toList();
      expect(targets, hasLength(2));
      expect(targets.toSet(), hasLength(count));
      expect(targets, everyElement(isNotNull));
    }
  });

  test(
    'native gun bonus cannot bypass three boss openings even at extreme burst',
    () {
      final g = bench.arena('gun_vulcan', 'W1', 40, 42, 'boss-front');
      final phases = <int>{};
      for (var i = 0; i < 1200 && g.boss != null && !g.resolvingBoss; i++) {
        phases.add(g.bossPhase);
        g.shots.add(
          Shot(
            g.boss!.position,
            Offset.zero,
            1000000,
            0,
            weapon: 'part:W1:gun_vulcan',
          ),
        );
        g.update(.01);
      }
      expect(phases, {0, 1, 2});
      expect(g.bossesDefeated, 1);
      expect(g.combatTime, greaterThanOrEqualTo(9.6));
    },
  );

  test('growth milestones and in-run upgrades preserve every slot role', () {
    for (final (weapon, mount) in bench.fits) {
      {
        var previousDamage = 0.0;
        for (final level in [1, 5, 10, 30, 40]) {
          final part = OwnedModulePart('growth', weapon, level);
          final base = resolvePartStats(part, mountProfile(mount));
          final upgraded = resolvePartStats(
            part,
            mountProfile(mount),
            damageBonus: 1,
          );
          expect(base.damage, greaterThan(previousDamage));
          expect(upgraded.damage, closeTo(base.damage * 2, .001));
          expect(upgraded.bossDamage, closeTo(base.bossDamage * 2, .001));
          previousDamage = base.damage;
        }
      }
    }
  });
}
