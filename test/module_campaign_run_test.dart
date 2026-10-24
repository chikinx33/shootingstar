import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/survival_skills.dart';

import 'support/run_driver.dart' as driver;

const campaignBuilds = {
  'starter': ['gun_vulcan', 'missile_hawk', 'gun_vulcan', 'drone_wasp'],
  'guns': ['gun_vulcan', 'gun_vulcan', 'gun_vulcan', 'gun_vulcan'],
  'missiles': ['missile_hawk', 'missile_hawk', 'missile_hawk', 'missile_hawk'],
  'drones': ['drone_wasp', 'drone_wasp', 'drone_wasp', 'drone_wasp'],
  'mixed': ['missile_hawk', 'gun_vulcan', 'missile_hawk', 'drone_wasp'],
};

GameEngine campaignGame(
  int stage,
  int level,
  String build,
  int seed, {
  bool defense = false,
}) {
  final parts = {
    for (var i = 0; i < 4; i++)
      'W${i + 1}': OwnedModulePart(
        'owned-$i',
        campaignBuilds[build]![i],
        level,
      ),
    if (defense) ...{
      'S1': OwnedModulePart('shield', 'shield', level),
      'S2': OwnedModulePart('repair', 'repair', level),
      'S3': OwnedModulePart('armor', 'armor', level),
    },
  };
  return GameEngine(
    stageIndex: stage,
    shipIndex: 0,
    aircraft: AircraftAssembly(modules: ModuleSnapshot(0, level, parts)),
    attackLevel: 0,
    hullLevel: 0,
    magnetLevel: level > 1 ? 5 : 0,
    equipmentIndex: -1,
    armament: 'pulse',
    armamentLevel: level - 1,
    seed: seed,
  )..visuals.enabled = false;
}

int campaignChoice(GameEngine g, UpgradeChoice c) {
  if (c.id == 'repair') return g.hp < g.maxHp * .6 ? 130 : -1;
  if (c.id == 'hull' && g.hp < g.maxHp * .55) return 120;
  if (c.id.startsWith('part:')) return 95 - (g.upgrades[c.id] ?? 0) * 4;
  // v12 weapon growth: finish ultimates, then grow what is already strong
  if (c.growth == 'ult') return 140;
  if (c.growth == 'enh' || c.growth == 'evo') return 92;
  if (c.growth == 'new') return 86;
  if (c.id == 'attack') return 88;
  if (c.id == 'gun') return 85;
  if (c.id == 'cooldown') return 83;
  if (c.id == 'magnet') return 78;
  if (c.id == 'hull') return 70;
  return 60;
}

Map<String, dynamic> campaignRun(
  int stage,
  int level,
  String build,
  int seed,
  bool active, {
  bool defense = false,
  GameEngine? game,
}) {
  final g = game ?? campaignGame(stage, level, build, seed, defense: defense);
  final drafts = <Map<String, dynamic>>[], bosses = <Map<String, dynamic>>[];
  var peakEnemies = 0, peakShots = 0, peakCrystals = 0, ultimates = 0;
  var bossStart = 0.0, hpBeforeBoss = 0.0;
  Foe? currentBoss;
  var decisionFrames = 0;
  final mainRegressions = <Map<String, dynamic>>[];
  for (var frame = 0; frame < 24000 && !g.finished; frame++) {
    if (g.choices.isNotEmpty) {
      final choices = g.choices.toList()
        ..sort((a, b) => campaignChoice(g, b).compareTo(campaignChoice(g, a)));
      drafts.add({
        'time': g.combatTime,
        'elapsed': g.elapsed,
        'level': g.level,
        'id': choices.first.id,
        'chest': g.chestSelection,
        'offered': g.choices.map((c) => c.id).toList(),
      });
      g.chooseUpgrade(choices.first.id);
      decisionFrames = 0;
    }
    if (active && decisionFrames++ % 6 == 0) g.input = driver.steer(g);
    if (!active) g.input = Offset.zero;
    if (g.ultimateReady && g.activateCommonUltimate()) ultimates++;
    final beforeGun = g.upgrades['gun'] ?? 1;
    g.update(.025);
    if ((g.upgrades['gun'] ?? 1) < beforeGun)
      mainRegressions.add({
        'time': g.combatTime,
        'before': beforeGun,
        'after': g.upgrades['gun'],
      });
    if (g.boss != null && currentBoss == null) {
      currentBoss = g.boss;
      bossStart = g.combatTime;
      hpBeforeBoss = g.hp;
    }
    if (currentBoss != null && (currentBoss.hp <= 0 || g.finished)) {
      bosses.add({
        'start': bossStart,
        'seconds': g.combatTime - bossStart,
        'killed': currentBoss.hp <= 0,
        'hpLeft': currentBoss.hp,
        'pilotHpStart': hpBeforeBoss,
        'pilotHpEnd': g.hp,
      });
      currentBoss = null;
    }
    peakEnemies = math.max(peakEnemies, g.enemies.length);
    peakShots = math.max(peakShots, g.shots.length);
    peakCrystals = math.max(peakCrystals, g.crystals.length);
  }
  return {
    'stage': stage,
    'partLevel': level,
    'build': build,
    'seed': seed,
    'active': active,
    'defense': defense,
    'victory': g.victory,
    'finished': g.finished,
    'seconds': g.combatTime,
    'elapsed': g.elapsed,
    'level': g.level,
    'kills': g.kills,
    'hp': g.hp,
    'maxHp': g.maxHp,
    'drafts': drafts,
    'bosses': bosses,
    'mainRegressions': mainRegressions,
    'bossesDefeated': g.bossesDefeated,
    'ultimates': ultimates,
    'damageTaken': g.damageTakenBySource,
    'damage': g.damageByWeapon,
    'upgrades': g.upgrades,
    'passives': g.passives,
    'peakEnemies': peakEnemies,
    'peakShots': peakShots,
    'peakCrystals': peakCrystals,
  };
}

void main() {
  test('natural campaign runs compare active and stationary native-module builds', () {
    final rows = <Map<String, dynamic>>[];
    final label = Platform.environment['MODULE_RUN_CAPTURE'] ?? 'current';
    final focused = Platform.environment['MODULE_RUN_FOCUS'] == '1';
    final directory = Directory('.local/module-v69')
      ..createSync(recursive: true);
    void record(Map<String, dynamic> row) {
      rows.add(row);
      File('${directory.path}/$label.json')
          .writeAsStringSync(jsonEncode({'rows': rows}));
      print(
        'RUN ${row['stage']}/L${row['partLevel']}/${row['build']}/${row['active']}/${row['seed']} '
        'win=${row['victory']} time=${(row['seconds'] as double).toStringAsFixed(1)} level=${row['level']} '
        'bosses=${row['bossesDefeated']} hp=${row['hp']}',
      );
    }

    for (final tier in (focused ? [(49, 30)] : [(0, 1), (9, 10), (49, 30)])) {
      for (final build in (focused ? ['missiles'] : campaignBuilds.keys)) {
        for (final active in [false, true]) {
          for (final seed in [11, 31])
            record(
              campaignRun(
                tier.$1,
                tier.$2,
                build,
                seed,
                active,
                defense: tier.$2 > 1,
              ),
            );
        }
      }
    }
    for (final stage in (focused ? [99] : [0, 49, 99])) {
      for (final build
          in (focused ? ['missiles'] : ['guns', 'missiles', 'drones', 'mixed']))
        record(campaignRun(stage, 40, build, 11, false, defense: true));
    }
    expect(rows, hasLength(focused ? 5 : 72));
    expect(
      rows.every((r) => (r['hp'] as double).isFinite && r['finished'] == true),
      isTrue,
    );
    if (label != 'baseline') {
      expect(
        rows.where(
          (r) =>
              r['active'] == false &&
              r['victory'] == true &&
              (r['partLevel'] != 40 || r['stage'] == 99),
        ),
        isEmpty,
        reason: 'Stationary builds must still answer telegraphed threats',
      );
      expect(
        rows
            .where(
              (r) =>
                  r['active'] == true &&
                  r['stage'] == 0 &&
                  r['build'] == 'starter',
            )
            .every((r) => r['victory'] == true),
        isTrue,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
