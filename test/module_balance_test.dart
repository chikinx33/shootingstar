import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/game/engine.dart';

const weapons = ['gun_vulcan', 'missile_hawk', 'drone_wasp'];
const mounts = ['W1', 'W2', 'W3', 'W4'];
const scenes = [
  'front',
  'front-wide',
  'surround',
  'rear',
  'ground',
  'boss-front',
  'boss-flank',
  'boss-adds',
];

GameEngine arena(
  String weapon,
  String mount,
  int level,
  int seed,
  String scene, {
  Map<String, OwnedModulePart>? parts,
}) {
  final g = GameEngine(
    stageIndex: scene == 'boss-flank' ? 49 : 0,
    shipIndex: 0,
    attackLevel: 0,
    hullLevel: 0,
    magnetLevel: 0,
    equipmentIndex: -1,
    seed: seed,
    aircraft: AircraftAssembly(
      modules: ModuleSnapshot(
        0,
        1,
        parts ?? {mount: OwnedModulePart('same', weapon, level)},
      ),
    ),
  )..xpNeeded = 1e9;
  if (scene.startsWith('boss')) g.developerPrepare(scene: 1);
  final data = g.checkpoint();
  final state = data['state'] as Map;
  for (final key in ['_spawn', '_formationClock', '_flightFormationClock'])
    state[key] = 10000.0;
  state['_lastEncounter'] = g.encounterIndex;
  final fixed = BattleCheckpoint.restore(data);
  fixed.developerInvincible =
      true; // Equal exposure, not a human win-rate test.
  fixed.visuals.enabled = false;
  fixed.legacyArena = true; // benchmarks of the pre-v12 arena rules
  return fixed;
}

Map<String, dynamic> measure(
  String weapon,
  String mount,
  int level,
  int seed,
  String scene, {
  Map<String, OwnedModulePart>? parts,
}) {
  final g = arena(weapon, mount, level, seed, scene, parts: parts);
  final boss = g.boss, initialBossHp = boss?.hp ?? 0;
  var aliveFrames = 0.0, frames = 0, peakShots = 0;
  final start = g.combatTime;
  for (var frame = 0; frame < 18 * 60; frame++) {
    if (scene.startsWith('boss') && (boss!.hp <= 0 || g.resolvingBoss)) break;
    if (!scene.startsWith('boss') &&
        frame % 120 == 0 &&
        g.enemies.length < 60) {
      final count = scene == 'surround'
          ? 12
          : scene == 'front-wide'
          ? 4
          : 6;
      for (var i = 0; i < count; i++) {
        final lane = i % 3 - 1.0, depth = 205.0 + (i ~/ 3) * 42;
        final point = scene == 'surround'
            ? Offset(
                math.cos(i * math.pi * 2 / count + seed * .17) * 230,
                math.sin(i * math.pi * 2 / count + seed * .17) * 230,
              )
            : scene == 'front-wide'
            ? Offset((i - 1.5) * 120, -220 - (i % 2) * 80)
            : Offset(
                lane * 64 + (seed % 3 - 1) * 7,
                scene == 'rear' ? depth : -depth,
              );
        final hp = (scene == 'ground' ? 50 : 24) * (1 + (level - 1) * .12);
        g.enemies.add(
          Foe(
            g.position + point,
            hp,
            scene == 'ground' ? 14 : 28,
            12,
            0,
            plane: scene == 'ground'
                ? AircraftTarget.ground
                : AircraftTarget.air,
          ),
        );
      }
    }
    if (scene == 'boss-adds' && frame % 180 == 0) {
      for (var i = 0; i < 3; i++) {
        g.enemies.add(
          Foe(
            g.position + Offset((i - 1) * 44, 210),
            24 * (1 + (level - 1) * .12),
            38,
            12,
            0,
          ),
        );
      }
    }
    final t = g.combatTime - start;
    final target = boss == null
        ? Offset(900 + 40 * math.sin(t * .7), 1200 + 28 * math.cos(t * .6))
        : boss.position +
              ((scene == 'boss-front' || scene == 'boss-adds')
                  ? Offset(45 * math.sin(t * .7), 180)
                  : Offset(math.sin(t * .35) * 180, math.cos(t * .35) * 180));
    final delta = target - g.position;
    g.input = delta.distance > 4
        ? delta / math.max(60, delta.distance)
        : Offset.zero;
    g.update(1 / 60);
    final part = g.moduleLoadout!.parts[mount]!;
    if (part.definition.category == PartCategory.drone) {
      final count = g.partStats(mount).count;
      aliveFrames +=
          List.generate(
            count,
            (i) => g.droneHealth(mount, i) > 0 ? 1 : 0,
          ).fold(0, (a, b) => a + b) /
          count;
    }
    peakShots = math.max(peakShots, g.shots.length);
    frames++;
  }
  final seconds = g.combatTime - start;
  final damage = parts == null
      ? g.damageByWeapon['part:$mount:$weapon'] ?? 0
      : g.damageByWeapon.entries
            .where((e) => e.key.startsWith('part:'))
            .fold(0.0, (sum, e) => sum + e.value);
  return {
    'weapon': weapon,
    'mount': mount,
    'level': level,
    'seed': seed,
    'scene': scene,
    'seconds': seconds,
    'partDamage': damage,
    'dps': damage / math.max(.001, seconds),
    'kills': g.kills,
    'bossDamage': boss == null ? null : initialBossHp - boss.hp,
    'bossKilled': boss != null && boss.hp <= 0,
    'droneUptime': frames > 0 ? aliveFrames / frames : 0,
    'peakShots': peakShots,
  };
}

void main() {
  test('module encounter matrix records comparable early mid and late performance', () {
    final rows = <Map<String, dynamic>>[];
    for (final level in [1, 10, 30]) {
      for (final scene in scenes) {
        for (final weapon in weapons) {
          for (final mount in mounts) {
            for (final seed in [1, 42, 667])
              rows.add(measure(weapon, mount, level, seed, scene));
          }
        }
      }
    }
    expect(rows, hasLength(864));
    expect(
      rows.every((r) => (r['dps'] as double).isFinite && r['dps'] >= 0),
      isTrue,
    );
    final dir = Directory('.local/module-v68')..createSync(recursive: true);
    final label = Platform.environment['MODULE_BALANCE_CAPTURE'] ?? 'current';
    File('${dir.path}/$label.json').writeAsStringSync(
      jsonEncode({
        'equalExposureInvincible': true,
        'durationSeconds': 18,
        'seeds': [1, 42, 667],
        'levels': [1, 10, 30],
        'rows': rows,
      }),
    );
    for (final level in [1, 10, 30]) {
      for (final scene in scenes) {
        final sums = <String, double>{};
        for (final r in rows.where(
          (r) => r['level'] == level && r['scene'] == scene,
        )) {
          final key = '${r['weapon']}/${r['mount']}';
          sums[key] = (sums[key] ?? 0) + r['dps'] / 3;
        }
        final sorted = sums.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        print(
          'Lv$level $scene: ${sorted.map((e) => '${e.key}=${e.value.toStringAsFixed(1)}').join(' ')}',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
