import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/game/engine.dart';

import 'module_balance_test.dart' as bench;

void advance(GameEngine g, int frames) {
  for (var i = 0; i < frames; i++) g.update(1 / 60);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'create isolated current-balance boss fixtures for production web play',
    () async {
      final folder = Directory('.local/module-v68/browser-fixtures')
        ..createSync(recursive: true);
      for (final entry in {'gun_vulcan': 'W2', 'drone_wasp': 'W4'}.entries) {
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        final fleet = p.shipModules;
        fleet.owned.clear();
        fleet.loadouts.clear();
        fleet.airframeLevels.clear();
        for (final id in bench.weapons)
          fleet.add(id, level: 10, id: 'review-$id');
        fleet.loadouts[0] = {'W1': 'review-${entry.key}'};
        fleet.airframeLevels[0] = 1;
        p.onboarded = true;
        final g = bench.arena(
          entry.key,
          entry.value,
          10,
          42,
          'boss-front',
          parts: {
            entry.value: OwnedModulePart('review-${entry.key}', entry.key, 10),
          },
        );
        g.developerInvincible = false;
        g.position = g.boss!.position + const Offset(0, 180);
        expect(await p.checkpointBattle('v68-boss-${entry.key}', g), isTrue);
        final prefs = await SharedPreferences.getInstance();
        File('${folder.path}/${entry.key}-${entry.value}.json')
            .writeAsStringSync(prefs.getString(Profile.storageKey)!);
        p.dispose();
      }
    },
  );
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
      expect(
        g.damageByWeapon['part:W2:missile_hawk'],
        closeTo(g.partStats('W2').damage * 2, .001),
      );
      final copy = BattleCheckpoint.restore(
        jsonDecode(jsonEncode(g.checkpoint())),
      );
      advance(g, 60);
      advance(copy, 60);
      expect(
        g.damageByWeapon['part:W2:missile_hawk'],
        closeTo(g.partStats('W2').damage * 2, .001),
      );
      expect(copy.damageByWeapon, g.damageByWeapon);
    },
  );

  test('wing missiles spread their locks but keep both launchers against a solo boss', () {
    for (final count in [1, 2]) {
      final g = bench.arena('missile_hawk', 'W1', 1, 42, 'front');
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
      final g = bench.arena('gun_vulcan', 'W2', 40, 42, 'boss-front');
      final phases = <int>{};
      for (var i = 0; i < 1200 && g.boss != null && !g.resolvingBoss; i++) {
        phases.add(g.bossPhase);
        g.shots.add(
          Shot(
            g.boss!.position,
            Offset.zero,
            1000000,
            0,
            weapon: 'part:W2:gun_vulcan',
          ),
        );
        g.update(.01);
      }
      expect(phases, {0, 1, 2});
      expect(g.bossesDefeated, 1);
      expect(g.combatTime, greaterThanOrEqualTo(9.6));
    },
  );

  test('drone interception protects its chosen approach with real hull damage enabled', () {
    final rows = <Map<String, dynamic>>[];
    for (final seed in [1, 42, 667]) {
      for (final mount in bench.mounts) {
        final approach = switch (mount) {
          'W1' => const Offset(-1, 0),
          'W2' => const Offset(0, -1),
          'W3' => const Offset(0, 1),
          _ => const Offset(1, 0),
        };
        final damage = <String, double>{};
        for (final weapon in ['gun_vulcan', 'drone_wasp']) {
          final g = bench.arena(weapon, mount, 1, seed, 'front');
          g.developerInvincible = false;
          final initialHp = g.hp;
          for (var frame = 0; frame < 12 * 60; frame++) {
            if (frame % 54 == 0)
              g.shots.add(
                Shot(
                  g.position + approach * 220,
                  -approach * 160,
                  8,
                  4,
                  life: 2,
                ),
              );
            g.update(1 / 60);
          }
          damage[weapon] = initialHp - g.hp;
        }
        rows.add({'seed': seed, 'mount': mount, 'damageTaken': damage});
        expect(damage['gun_vulcan'], greaterThan(0));
        expect(
          damage['drone_wasp'],
          lessThan(damage['gun_vulcan']!),
          reason: '$mount/$seed',
        );
      }
    }
    Directory('.local/module-v68').createSync(recursive: true);
    File('.local/module-v68/interception.json')
        .writeAsStringSync(jsonEncode(rows));
    print('Interception damage: ${jsonEncode(rows)}');
  });

  test('equal-investment four-slot builds have encounter-dependent advantages', () {
    final builds = {
      'all-guns': List.filled(4, 'gun_vulcan'),
      'all-missiles': List.filled(4, 'missile_hawk'),
      'all-drones': List.filled(4, 'drone_wasp'),
      'mixed': ['missile_hawk', 'gun_vulcan', 'missile_hawk', 'drone_wasp'],
    };
    final rows = <Map<String, dynamic>>[];
    final averages = <String, Map<String, double>>{};
    for (final scene in bench.scenes) {
      final scores = averages[scene] = {};
      for (final build in builds.entries) {
        final parts = {
          for (var i = 0; i < 4; i++)
            bench.mounts[i]: OwnedModulePart('owned-$i', build.value[i], 10),
        };
        var sum = 0.0;
        for (final seed in [1, 42, 667]) {
          final row = bench.measure(
            build.value[0],
            'W1',
            10,
            seed,
            scene,
            parts: parts,
          );
          row['build'] = build.key;
          rows.add(row);
          sum += row['dps'] / 3;
        }
        scores[build.key] = sum;
      }
      print('$scene four-slot DPS: $scores');
    }
    final winners = averages.values
        .map(
          (scores) =>
              (scores.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .first
                  .key,
        )
        .toSet();
    expect(
      winners.length,
      greaterThan(1),
      reason: 'One build must not win every encounter',
    );
    expect(
      averages['boss-front']!['mixed'],
      greaterThan(averages['boss-front']!['all-missiles']! * 1.05),
    );
    // Boss blast resistance intentionally removes the old all-missile flank advantage.
    // Crowd specialization remains covered by ground and encounter-dependent winners.
    expect(
      averages['ground']!['all-missiles'],
      greaterThan(averages['ground']!['all-guns']!),
    );
    File(
      '${Platform.environment['MODULE_BALANCE_OUTPUT'] ?? '.local/module-v68'}/builds.json',
    ).writeAsStringSync(jsonEncode({'rows': rows, 'averages': averages}));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('growth milestones and in-run upgrades preserve all twelve roles', () {
    for (final weapon in bench.weapons) {
      for (final mount in bench.mounts) {
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
