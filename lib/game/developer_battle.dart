import '../data/profile.dart';
import '../data/content.dart';
import 'engine.dart';
import 'survival_skills.dart';

class DeveloperBattleConfig {
  int seed = 623, level = 1, rate = 0, power = 0, count = 0;
  int scene = 0, phase = 0, startSeconds = 0;
  int enemyCount = 100, shotCount = 200, sparkCount = 80;
  double speed = 1, healthPercent = 100;
  bool invincible = false, showPerformance = true, autoChoose = false;
  bool ultimateReady = false;
  int supplyKind = -1;
  MainBranch? branch;
  final Map<String, int> skills = {};
  final Set<String> evolutions = {};

  Map<String, dynamic> toJson() => {
    'seed': seed,
    'level': level,
    'rate': rate,
    'power': power,
    'count': count,
    'scene': scene,
    'phase': phase,
    'startSeconds': startSeconds,
    'enemyCount': enemyCount,
    'shotCount': shotCount,
    'sparkCount': sparkCount,
    'speed': speed,
    'healthPercent': healthPercent,
    'invincible': invincible,
    'showPerformance': showPerformance,
    'autoChoose': autoChoose,
    'ultimateReady': ultimateReady,
    'supplyKind': supplyKind,
    'branch': branch?.name,
    'skills': {...skills},
    'evolutions': evolutions.toList(),
  };

  static DeveloperBattleConfig restore(dynamic value) {
    final c = DeveloperBattleConfig();
    if (value is! Map) return c;
    int n(String key, int fallback, int min, int max) =>
        value[key] is int ? (value[key] as int).clamp(min, max) : fallback;
    c.seed = n('seed', 623, 0, 2147483647);
    c.level = n('level', 1, 1, 100);
    c.rate = n('rate', 0, 0, 5);
    c.power = n('power', 0, 0, 5);
    c.count = n('count', 0, 0, 4);
    c.scene = n('scene', 0, 0, 6);
    c.phase = n('phase', 0, 0, 2);
    c.startSeconds = n('startSeconds', 0, 0, 150);
    c.enemyCount = n('enemyCount', 100, 0, 260);
    c.shotCount = n('shotCount', 200, 0, 1000);
    c.sparkCount = n('sparkCount', 80, 0, 160);
    if (const [.5, 1, 2, 4].contains(value['speed'])) {
      c.speed = (value['speed'] as num).toDouble();
    }
    if (const [100, 80, 49, 10].contains(value['healthPercent'])) {
      c.healthPercent = (value['healthPercent'] as num).toDouble();
    }
    c.invincible = value['invincible'] == true;
    c.showPerformance = value['showPerformance'] != false;
    c.autoChoose = value['autoChoose'] == true;
    c.ultimateReady = value['ultimateReady'] == true;
    c.supplyKind = n('supplyKind', -1, -1, 6);
    if (!const [623, 1, 42, 20261018].contains(c.seed)) c.seed = 623;
    if (!const [0, 30, 60, 90, 120, 150].contains(c.startSeconds))
      c.startSeconds = 0;
    if (!const [0, 50, 100, 200, 260].contains(c.enemyCount))
      c.enemyCount = 100;
    if (!const [0, 100, 200, 500, 1000].contains(c.shotCount))
      c.shotCount = 200;
    if (!const [0, 80, 160].contains(c.sparkCount)) c.sparkCount = 80;
    for (final b in MainBranch.values) {
      if (b.name == value['branch']) c.branch = b;
    }
    if (value['skills'] is Map) {
      for (final s in survivalSkills) {
        final rank = value['skills'][s.id];
        if (rank is int && rank > 0) c.skills[s.id] = rank.clamp(1, 5);
      }
    }
    if (value['evolutions'] is List) {
      c.evolutions.addAll(
        (value['evolutions'] as List).whereType<String>().where(
          (id) => c.skills.containsKey(id),
        ),
      );
    }
    return c;
  }

  void preset(int id) {
    skills.clear();
    evolutions.clear();
    branch = null;
    if (id == 1) {
      skills['laser'] = 3;
      branch = MainBranch.pulseFocus;
    }
    if (id == 2) {
      skills['missile'] = 3;
      skills['area'] = 1;
      branch = MainBranch.shellSplit;
    }
    if (id == 3) {
      skills['guardian'] = 3;
      skills['armor'] = 1;
    }
    if (id >= 4 && id <= 6) {
      final key = const ['infernoMine', 'thunderMine', 'medicDrone'][id - 4];
      skills[key] = 5;
      evolutions.add(key);
    }
  }

  GameEngine build(Profile p) {
    if (!p.developerMode) throw StateError('Developer profile required');
    final game = GameEngine(
      aircraft: p.aircraftAssembly,
      supportLevels: p.aircraftSupportLevels,
      stageIndex: p.selectedStage,
      shipIndex: p.selectedShip,
      attackLevel: p.attackLevel,
      hullLevel: p.hullLevel,
      magnetLevel: p.magnetLevel,
      equipmentIndex: p.equipment,
      seed: seed,
      campaignLoop: p.campaignLoop,
      armament: armaments[p.activeArmamentIndex].id,
      armamentLevel: p.activeArmamentLevel,
      pilot: pilots[p.selectedPilot].id,
      traitLevel: catTraitLevel(p.pilotLevel),
      gearDamage: p.gearDamage + p.pilotDamage,
      gearHull: p.gearHull + p.pilotHull,
      startingWeapon: p.startingWeapon,
      mainPrecisionLink: p.mainPrecisionLink,
      mainCycleLink: p.mainCycleLink,
      bossSetWorld: p.activeBossSetWorld,
      bonusSpeed: p.gearSpeed,
      bonusPickup: p.gearPickup,
      bonusCooldown: p.gearCooldown,
      damageReduction: p.gearReduction,
      regeneration: p.gearRegeneration,
      techRanks: p.battleTech,
      petKind: p.activePet,
      petLevel: p.equippedPetLevel,
      petRank: p.equippedPetRank,
      petAwakePower: p.petBond.powerBonus(p.activePet),
      petAwakeCooldown: p.petBond.cooldownReduction(p.activePet),
    );
    game.developerInvincible = invincible;
    game.level = level.clamp(1, 100);
    game.xpNeeded = game.level == 1
        ? 10
        : 12 +
              game.level * 8 +
              (game.level > 20 ? (game.level - 20) * game.level * .8 : 0);
    game.mainRate = rate.clamp(0, 5);
    game.mainPower = power.clamp(0, 5);
    game.mainCount = count.clamp(0, 4);
    if (mainBranches.any(
      (s) => s.armament == game.armament && s.branch == branch,
    )) {
      game.mainBranch = branch;
    }
    for (final entry in skills.entries) {
      if (entry.value <= 0) continue;
      final skill = skillFor(entry.key);
      if (skill.passive) {
        if (game.passives.length < 6 || game.passives.containsKey(skill.id)) {
          game.passives[skill.id] = entry.value.clamp(1, 5);
        }
      } else if (game.weaponCount < 6 || game.upgrades.containsKey(skill.id)) {
        game.upgrades[skill.id] = entry.value.clamp(1, 5);
      }
    }
    for (final id in evolutions) {
      if (!game.upgrades.containsKey(id)) continue;
      // Use the real evolution resolver, including drone/fusion cleanup.
      game.choices = [UpgradeChoice(id, '', '', id, evolution: true)];
      game.chooseUpgrade(id);
    }
    if ((game.passives['hull'] ?? 0) > 0) {
      game.maxHp += game.ship.health * .2 * game.passives['hull']!;
    }
    game.developerPrepare(
      scene: scene,
      phase: phase,
      startSeconds: startSeconds,
      enemyCount: enemyCount,
      shotCount: shotCount,
      sparkCount: sparkCount,
      healthPercent: healthPercent,
      ultimateReady: ultimateReady,
      supplyKind: supplyKind,
    );
    return game;
  }
}
