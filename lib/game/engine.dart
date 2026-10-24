import 'dart:math' as math;
import 'dart:ui';

import 'seeded_random.dart';
import 'experience_crystals.dart';
export 'experience_crystals.dart';
import '../data/aircraft_assembly.dart';
import '../data/aircraft_geometry.dart';
import '../data/ship_modules.dart';
import 'world_fields.dart';
export 'world_fields.dart';

import '../data/content.dart' as content;
import '../data/daily_challenge.dart';
import '../data/armament_collection.dart';
import '../data/content_catalog.dart' as boss_catalog;
import 'survival_skills.dart';
import 'waves.dart';
import 'combat_cues.dart';
export 'waves.dart' show FlightFormation;
import 'weapon_roles.dart';
import '../art/ship_sprite_art.dart';
export 'weapon_roles.dart';

part 'enemy_behaviors.dart';
part 'expanded_weapons.dart';
part 'pilot_abilities.dart';
part 'hostile_ordnance.dart';
part 'main_specializations.dart';
part 'flight_formations.dart';
part 'armored_assault_formations.dart';
part 'weapon_synergies.dart';
part 'common_ultimate.dart';
part 'expanded_main_branches.dart';
part 'main_loadout_links.dart';
part 'world_bosses.dart';
part 'boss_gear_combat.dart';
part 'developer_tools.dart';
part 'battle_resolution.dart';
part 'battle_checkpoint.dart';
part 'modular_combat.dart';
part 'ship_module_combat.dart';
part 'house_waves.dart';
part 'paw_weapons.dart';
part 'house_bosses.dart';
part 'weapon_growth.dart';
part 'growth_arms.dart';
part 'gear_combat.dart';

class UpgradeChoice {
  final String id, title, description, iconKey;
  final bool evolution;
  final bool specialization;

  /// v12 weapon growth card kind: '', 'enh', 'evo', 'ult' or 'new'.
  final String growth;
  const UpgradeChoice(
    this.id,
    this.title,
    this.description,
    this.iconKey, {
    this.evolution = false,
    this.specialization = false,
    this.growth = '',
  });
}

class Foe {
  Offset position;
  double hp, maxHp, speed, radius, phase = 0;
  String lastSource = '';
  int frontBreakHits = 0;
  double frontBreakLastHit = -10, frontBreakReadyAt = 0;
  AircraftTarget plane;
  int groundKind;
  content.EnemyRole role;
  content.EnemyFlight flight = content.EnemyFlight.approach;
  Offset velocity = Offset.zero;
  Offset? targetPoint;
  double heading = math.pi / 2, orbitSign = 1;
  bool retired = false;
  // v12 formation waves: which wave it flies in and its scripted path.
  int waveId = -1;
  WavePath? path;
  double pathTime = 0;
  // v12.4 mid-boss: an elite of a hover wave with its own attack cycle.
  bool elite = false;
  int elitePattern = 0, eliteVolley = 0;
  double eliteTimer = 0, eliteSpin = 0;
  // v12 fortress boss parts ride on [anchor] at [mount]; 1 turret, 2 shield.
  Foe? anchor;
  Offset mount = Offset.zero;
  int partKind = 0;
  int formationId = -1, formationOrder = -1;
  FlightFormation? formationPattern;
  Offset? formationOrigin, formationDestination;
  Offset formationFacing = const Offset(0, 1);
  double attackClock = 2.5,
      tell = 0,
      statusTime = 0,
      vulnerable = 0,
      statusTick = 0;
  Offset aim = const Offset(0, 1);
  int status = 0, generation = 0;
  final int kind;
  Foe(
    this.position,
    this.hp,
    this.speed,
    this.radius,
    this.kind, {
    content.EnemyRole? role,
    this.plane = AircraftTarget.air,
    this.groundKind = 0,
  }) : maxHp = hp,
       role =
           role ??
           (kind == 1
               ? content.EnemyRole.weaver
               : kind == 2
               ? content.EnemyRole.bulwark
               : content.EnemyRole.scout);
}

class Shot {
  Offset position, velocity;
  double life, damage, radius, hitCooldown = 0;
  final int kind;
  final String weapon;
  int pierce;
  Foe? target;
  double age = 0;
  double distanceTravelled = 0;
  bool closeRange = false, splitOnHit = false;
  bool triggersSynergies = true;
  double fuse = 0;
  bool get hostile => kind == 4 || kind == 17 || (kind >= 19 && kind <= 24);
  bool get interceptable => kind == 4 || kind == 19 || kind == 20 || kind == 21;
  Offset? anchor;
  final Set<Foe> hitTargets = {};
  Shot(
    this.position,
    this.velocity,
    this.damage,
    this.kind, {
    this.weapon = '',
    this.target,
    this.anchor,
    this.pierce = 0,
    this.life = 2,
    this.radius = 3,
  });
}

class Spark {
  Offset position, velocity;
  double life;
  final int kind;
  Spark(this.position, this.velocity, this.life, this.kind);
}

class Supply {
  Supply(this.position, this.kind);
  Offset position;
  final int kind; // 0 repair, 1 magnet, 2 bomb, 3 boss chest
}

class GameEngine {
  final List<AbsorbingCrystal> absorbingCrystals = [];
  double _absorptionSettle = 0;
  BossResolution? bossResolution;
  bool get resolvingBoss => bossResolution != null;
  bool get collectingMagnet =>
      absorbingCrystals.isNotEmpty || _absorptionSettle > 0;
  final visuals = CombatCues();
  bool developerInvincible = false;
  final int bossSetWorld;
  double _bossSetHealClock = 10;
  final int stageIndex,
      shipIndex,
      attackLevel,
      hullLevel,
      magnetLevel,
      equipmentIndex;
  final AircraftAssembly? aircraft;
  final Map<String, int> supportLevels;
  final Map<String, double> _moduleTimers = {};
  double moduleShield = 0, moduleGroundClock = 8;
  int moduleGroundSerial = 0;
  int gearVolleys = 0, gearSalvage = 0;
  final int campaignLoop, armamentLevel;
  final String armament, pilot;
  final bool mainPrecisionLink, mainCycleLink;
  int _mainLinkVolleys = 0, _mainLinkBlocks = 0;
  double _mainLinkBlockReadyAt = 0;
  final bool training;
  final bool challenge;
  final DailyChallengeEntry? dailyEntry;
  final double petAwakePower, petAwakeCooldown;
  final double gearDamage,
      gearHull,
      bonusSpeed,
      bonusPickup,
      bonusCooldown,
      damageReduction;
  final bool regeneration;
  final Map<String, int> techRanks;
  final int petKind, petLevel, petRank;
  Offset petPosition = const Offset(860, 1240);
  double petHp = 100,
      petRevive = 0,
      _petAttack = 0,
      _petHurt = 0,
      _regenClock = 30;
  bool techSpecial(String id) => (techRanks[id] ?? -1) >= 2;
  double techDamage(String id) => 1 + ((techRanks[id] ?? -1) + 1) * .05;

  final Map<String, int> passives = {};
  final Set<String> evolved = {};
  final Map<Foe, double> _plasmaCooldown = {};
  final List<Supply> supplies = [];
  int bossesDefeated = 0, _bossWave = 0, chests = 0;

  /// Counts commander arrivals so the screen can show its intro card once.
  int bossArrivals = 0;

  /// Counts commander defeats (the Vacuum King's transmission replays).
  int bossDefeats = 0;
  final Map<String, double> _extraTimers = {};
  final List<Shot> _deferredShots = [];
  int _primaryStrikes = 0;
  int soulStacks = 0;
  int revolverAmmo = 6, pilotStance = 0;
  MainBranch? mainBranch;
  bool _revolverCharged = false;
  final Map<String, int> _synergyTriggers = {};
  double _ultimateCharge = 0, _ultimateUntil = 0, _ultimateNextPulse = 0;
  int _ultimateUses = 0, _shieldCounterAttacks = 0;
  bool _shieldCounterArmed = false, _mainAttackDidDamage = false;
  bool _mainAttackInProgress = false;
  double _shieldCounterUntil = 0,
      _shieldCounterReadyAt = 0,
      _mainAttackMultiplier = 1;
  double _frontBreakUntil = 0,
      _frontBreakReadyAt = 0,
      _explosiveSpreadReadyAt = 0;
  double pilotShield = 0,
      pilotSync = 0,
      pilotBuff = 0,
      pilotAbilityCooldown = 0;
  bool pilotMech = false;
  int mainRate = 0, mainPower = 0, mainCount = 0, _mainDrop = 0;
  double magnetPulse = 0, _magnetClock = 45, _mainClock = 24;
  double get permanentMainFactor =>
      unifiedModules ? 1 : 1 + ArmamentCollection.damageBonus(armamentLevel);
  double get mainDamage => (1 + mainPower * .25) * permanentMainFactor;
  double get mainInterval => 1 / (1 + mainRate * .22);
  int get mainProjectiles => 1 + mainCount;
  double get mainWidth => 3 + mainPower * 1.25;
  double get skillSpeed => 1 + (passives['projectile'] ?? 0) * .1;
  double get critChance =>
      ((passives['crit'] ?? 0) * .08 +
              (armament == 'revolver' && unifiedModules
                  ? gUp('gun', 3, 1.15) - 1
                  : 0) +
              (pilot == 'king' ? (upgrades['pilot'] ?? 1) * .05 : 0) +
              bossSetCrit)
          .clamp(0, .65);
  double _supplyClock = 27, _guardian = 0, _lightning = 0;
  final List<PawFx> pawFx = [];
  // v12 weapon growth: enhance / evolve steps and finished ultimates
  final Map<String, int> growthEnhance = {}, growthEvolve = {};
  final Set<String> growthUltimates = {};
  final Map<String, Offset> droneRoam = {};
  String ultimateBanner = '';
  double ultimateShow = 0, mainHeat = 0;
  final Map<String, double> _pawTimers = {};

  /// Keeps the pre-v12 free-roam arena (benchmarks of the old rules).
  bool legacyArena = false;
  int _waveId = 0;
  double _hbFire = 0, _hbSpin = 0, _hbDodge = 0, _hbAim = 1.2;
  final Set<int> _leakedWaves = {};
  double _waveGap = 1.2, _waveTimer = 0;
  // v12.4 house stages: follow-touch steering target (field coordinates),
  // which map is under the cat and the cloud veil that swaps them.
  Offset? steerTarget;
  bool houseMapShown = false;
  double _cloudOut = 0;
  String pickupNotice = '';
  double noticeTime = 0;
  static const worldWidth = 1800.0, worldHeight = 2400.0;
  double viewportHeight = 720;
  double atmosphereTime = 0;
  Offset get camera => screenMode
      ? screenOrigin + Offset(screenPan, 0)
      : Offset(position.dx - 210, position.dy - viewportHeight / 2);
  int get weaponCount => upgrades.keys
      .where(
        (id) =>
            id != 'gun' && survivalSkills.any((s) => s.id == id && !s.passive),
      )
      .length;
  double get cooldownFactor =>
      (1 - (passives['cooldown'] ?? 0) * .07 - bonusCooldown).clamp(.35, 1);
  double get areaFactor => 1 + (passives['area'] ?? 0) * .12;
  double get durationFactor => 1 + (passives['duration'] ?? 0) * .2;
  int get wave => 1 + elapsed ~/ 30;
  double get nextBossAt =>
      training ? 29 : duration * (_bossWave + 1) / requiredBosses;
  bool get bossIncoming =>
      boss == null &&
      _bossWave < requiredBosses &&
      nextBossAt - elapsed <= 3 &&
      nextBossAt > elapsed;
  int get encounterIndex =>
      encounterPhase(elapsed, training ? 29 : duration / requiredBosses);
  RouteWavePlan get routePlan => routeWavePlans[stage.sector];
  WaveSpec get encounter => routeWave(stage.sector, encounterIndex);
  double get routeFormationInterval =>
      routePlan.interval - math.min(2, worldIndex * .2);
  double _formationRestUntil = 0;
  bool get formationWindowOpen =>
      boss == null &&
      !bossIncoming &&
      elapsed < duration &&
      nextBossAt - elapsed >= 9 &&
      encounterIndex != 5 &&
      combatTime >= _formationRestUntil;
  double get formationPopulationFactor =>
      enemies.any((e) => e.hp > 0 && !e.retired && e.formationPattern != null)
      ? .7
      : 1;
  int get waveEnemyBudget =>
      ((const [60, 92, 112, 120, 148, 80][routePlan.phases[encounterIndex]] +
                  worldIndex * 4 +
                  stage.sector * 2 +
                  (challenge ? 12 : 0)) *
              (dailyEntry?.densityMultiplier ?? 1))
          .floor()
          .clamp(24, enemyLimit - 6);
  String get waveLabel => boss != null
      ? '보스 결전'
      : bossIncoming
      ? '보스 접근 · ${(nextBossAt - elapsed).ceil()}초'
      : formationCue.isNotEmpty
      ? formationCue
      : encounter.name;
  int _lastEncounter = -1;
  double _dailySpawnRemainder = 0;
  double _formationClock = 18;
  int _formationSerial = 0;
  double _flightFormationClock = 8;
  int _flightFormationSerial = 0;
  double waveNoticeTime = 0;
  int get enemyLimit => 260;

  int get requiredBosses =>
      training ? 1 : dailyEntry?.requiredBosses ?? stage.bossCount;
  content.StageSpec get stage => content.stages[stageIndex.clamp(0, 99)];
  int get worldIndex => stage.worldIndex;
  double get threat => stage.threat(campaignLoop);
  final CombatRandom random;
  void Function(String)? onEvent;
  Offset position = const Offset(900, 1200), input = Offset.zero;
  // Movement heading remains available to the existing auxiliary weapons.
  double get angle => -math.pi / 2;
  double movementAngle = -math.pi / 2,
      elapsed = 0,
      hp = 100,
      maxHp = 100,
      xp = 0,
      xpNeeded = firstGrowthCost;

  /// Gems needed per level (v12.9, user 2026-10-25: one or two gems opened
  /// the cards and broke up the fight). An ordinary house gem is 7.2 and a
  /// wiped formation drops 12, so the first draft takes about five gems and
  /// later ones roughly half again as many as before.
  static const firstGrowthCost = 45.0;
  static double growthCost(int level) =>
      45 + level * 14 + math.pow(math.max(0, level - 8), 2) * 1.5;
  int level = 1, kills = 0;
  double combatTime = 0, laserLife = 0, _laser = 0;
  double? firstEvolutionAt;
  Offset laserOrigin = Offset.zero;
  final Map<String, double> damageByWeapon = {};
  int rerolls = 3, passiveReplacements = 1;
  bool chestSelection = false;
  int _lastBossPhase = 0;
  double bossCycle = 0;
  Offset bossAim = const Offset(0, 1);
  Offset bossOrigin = Offset.zero, bossTarget = Offset.zero;
  int bossRound = 0;
  int bossAttacks = 0;
  // Fixed encounter rules, independent of player gear or measured DPS.
  bool get bossExposed =>
      boss != null && (screenMode ? !houseBossShielded : bossCycle >= 3.2);
  double get bossSegmentFloor => switch (_lastBossPhase) {
    0 => .65,
    1 => .30,
    _ => 0,
  };
  String get bossCue => screenMode
      ? houseBossCue
      : bossExposed
      ? '코어 개방 · 집중 공격'
      : bossRecovering
      ? '재정렬 · 코어 개방 준비'
      : bossWarning
      ? switch (bossPattern) {
          0 => '방사 예고 · 초록 통로로',
          1 => '조준 고정 · 옆으로 회피',
          2 => '돌진 예고 · 경로 이탈',
          3 => '쌍열 예고 · 빛나는 통로',
          4 => '포격 예고 · 표식 이탈',
          _ => '압축 기뢰 · 열린 출구',
        }
      : '격벽 잠김 · 공격 후 개방';
  int get bossPhase => boss == null
      ? 0
      : boss!.hp > boss!.maxHp * .65 + .000001
      ? 0
      : boss!.hp > boss!.maxHp * .3 + .000001
      ? 1
      : 2;
  bool get guardianShieldActive =>
      (upgrades['guardian'] ?? 0) >= 3 &&
      combatTime % 3 < math.min(3, 1.8 * durationFactor);
  void _hit(Foe target, double amount, String source) {
    if (target.hp <= 0) return;
    if (aircraft != null && !modularSourceCanHit(source, target)) return;
    var dealt =
        amount * bossSetHitFactor(target, source) * _gearHitFactor(source);
    if (unifiedModules && target.kind == 3 && source.startsWith('part:')) {
      final mount = source.split(':')[1];
      final stats = partStats(mount);
      if (stats.damage > 0) dealt *= stats.bossDamage / stats.damage;
    }
    if (critChance > 0 && random.nextDouble() < critChance) {
      dealt *= evolved.contains('pilot') && pilot == 'king' ? 2.5 : 1.8;
    }
    if (target.vulnerable > 0) dealt *= 1.2;
    if (target.formationPattern == FlightFormation.bulwark) {
      dealt *= formationDamageFactor(target, source);
    } else if (target.kind != 3 &&
        target.role == content.EnemyRole.bulwark &&
        target.phase % 6 < 4) {
      dealt *= .65;
    }
    if (target.kind == 3 && screenMode) {
      dealt *= houseBossDamage(target);
    } else if (target.kind == 3 && !training) {
      dealt *= bossExposed ? 1.15 : .12;
      // One hull section per opening. Closed bulkheads cannot be bypassed
      // by burst, splash, or supplies; the remaining section is visible in HUD.
      final floor = target.maxHp * bossSegmentFloor + (bossExposed ? 0 : .01);
      dealt = math.min(dealt, math.max(0, target.hp - floor));
    }
    final actual = math.min(target.hp, dealt);
    if (_mainAttackInProgress && actual > 0) _mainAttackDidDamage = true;
    target.hp -= dealt;
    if (actual > 0) target.lastSource = source;
    if (actual > 0) {
      visuals.emit(
        source == 'lightning' ? CombatCueKind.lightning : CombatCueKind.impact,
        target.position,
        from: position,
        source: source,
        amount: actual,
        radius: target.radius,
        throttle: 'hit-${identityHashCode(target)}',
        interval: .08,
      );
    }
    damageByWeapon[source] = (damageByWeapon[source] ?? 0) + actual;
  }

  void _evolve(String id) {
    visuals.emit(CombatCueKind.evolution, position, source: id, radius: 100);
    evolved.add(id);
    if (id == 'drone' || id == 'droneB') {
      upgrades.remove('droneB');
      upgrades['drone'] = 5;
      evolved.add('drone');
    }
    _completeFusion(id);
    firstEvolutionAt ??= combatTime;
  }

  List<String> get missingPartners => unifiedModules
      ? const []
      : upgrades.keys
            .where(
              (id) =>
                  id != 'gun' &&
                  !evolved.contains(id) &&
                  skillFor(id).partner != null,
            )
            .map((id) => skillFor(id).partner!)
            .where((id) => !passives.containsKey(id))
            .toSet()
            .toList();
  String evolutionHint(String id) {
    if (unifiedModules) return combatSkill(id).description;
    if (id == 'repair') return '';
    final skill = skillFor(id);
    if (skill.passive) {
      final owners = survivalSkills
          .where((w) => w.partner == id)
          .map((w) => w.name)
          .join(' / ');
      if (owners.isEmpty) return '보조 시스템 강화';
      final blocked =
          passives.length == 5 &&
          !passives.containsKey(id) &&
          missingPartners.any((p) => p != id);
      return '$owners 진화 재료${blocked ? ' · 마지막 보조 슬롯: 다른 진화 재료는 교체 필요' : ''}';
    }
    if (skill.partner == null) {
      return '진화: ${skill.recipeHint ?? '동일 계열 모듈 5단계 합성'}';
    }
    final partner = skill.partner!;
    return '진화: ${skillFor(partner).name} · ${passives.containsKey(partner)
        ? '보유'
        : passives.length >= 6
        ? '슬롯 가득 참 · 보조 교체 필요'
        : '미보유'}';
  }

  bool rerollChoices() {
    if (rerolls <= 0 || choices.isEmpty || finished || chestSelection) {
      return false;
    }
    final old = choices.map((c) => c.id).toSet();
    rerolls--;
    _offerChoices(exclude: old);
    return true;
  }

  bool replacePassive(String oldId, String newId) {
    if (finished ||
        chestSelection ||
        choices.isEmpty ||
        passiveReplacements <= 0 ||
        passives.length != 6 ||
        !passives.containsKey(oldId) ||
        !missingPartners.contains(newId)) {
      return false;
    }
    final removed = passives.remove(oldId)!;
    if (oldId == 'hull') {
      maxHp -= ship.health * .2 * removed;
      hp = math.min(hp, maxHp);
    }
    passives[newId] = 1;
    if (newId == 'hull') {
      maxHp += ship.health * .2;
      hp += ship.health * .2;
    }
    passiveReplacements--;
    choices = [];
    input = Offset.zero;
    _decisionGrace();
    return true;
  }

  bool paused = false, finished = false, victory = false;
  List<UpgradeChoice> choices = [];
  final Map<String, int> upgrades = {'gun': 1};
  final List<Foe> enemies = [];
  final List<Shot> shots = [];
  final List<Offset> crystals = [];
  late final ExperienceDrops experienceDrops;
  static const crystalLimit = 1400;
  final List<Spark> sparks = [];
  double _spawn = 0,
      _gun = 0,
      _missile = 0,
      _drone = 0,
      _side = 0,
      _mine = 0,
      _trail = 0,
      _hurt = 0,
      _damageFlash = 0,
      _audio = 0;
  bool _bossSpawned = false;
  GameEngine({
    required this.stageIndex,
    required this.shipIndex,
    required this.attackLevel,
    required this.hullLevel,
    required this.magnetLevel,
    required this.equipmentIndex,
    int? seed,
    this.campaignLoop = 0,
    this.armament = 'pulse',
    AircraftAssembly? aircraft,
    this.supportLevels = const {},
    this.mainPrecisionLink = false,
    this.mainCycleLink = false,
    int bossSetWorld = -1,
    int armamentLevel = 0,
    this.pilot = 'common',
    this.training = false,
    this.challenge = false,
    this.dailyEntry,
    this.petAwakePower = 0,
    this.petAwakeCooldown = 0,
    this.gearDamage = 0,
    this.gearHull = 0,
    String startingWeapon = 'gun',
    this.bonusSpeed = 0,
    this.bonusPickup = 0,
    this.bonusCooldown = 0,
    this.damageReduction = 0,
    this.regeneration = false,
    this.techRanks = const {},
    this.petKind = -1,
    this.petLevel = 0,
    this.petRank = 0,
  }) : aircraft = aircraft?.withHull(shipIndex),
       bossSetWorld = bossSetWorld >= 0 && bossSetWorld < 10
           ? bossSetWorld
           : -1,
       armamentLevel = armamentLevel.clamp(0, ArmamentCollection.maxLevel),
       random = CombatRandom(dailyEntry?.seed ?? seed) {
    experienceDrops = ExperienceDrops(
      CombatRandom((random.state ^ 0x58f361a9) & 0xffffffff),
    );
    _formationClock = routePlan.assaultFirst;
    maxHp =
        ship.health *
        (1 + gearHull) *
        (1 + hullLevel * .12) *
        (equipmentIndex == 0
            ? 1.2
            : equipmentIndex == 1
            ? .9
            : 1);
    if (moduleLoadout != null)
      maxHp *= 1 + (moduleLoadout!.airframeLevel - 1) * .06;
    hp = maxHp;
    upgrades.clear();
    upgrades['gun'] = 1;
    if (moduleLoadout == null &&
        startingWeapon != 'gun' &&
        !(this.aircraft?.gearSpecs.isNotEmpty ?? false))
      upgrades[startingWeapon] = 1;
    if (pilot == 'common') {
      // Common has an innate bonus and does not occupy a skill slot.
    } else if (pilotUsesPassive) {
      passives['pilot'] = 1;
    } else {
      upgrades['pilot'] = 1;
    }
  }
  content.ShipSpec get ship =>
      content.ships[shipIndex.clamp(0, content.ships.length - 1)];
  double get duration => training
      ? 45
      : dailyEntry != null
      ? DailyChallengeEntry.duration
      : content.stages[stageIndex.clamp(0, content.stages.length - 1)].duration
            .toDouble();
  double get damageFactor =>
      (1 + ((moduleLoadout?.airframeLevel ?? 1) - 1) * .04) *
      (1 + attackLevel * .08 + gearDamage) *
      (pilot == 'common' ? 1 + pilotSkillLevel * .03 : 1) *
      (pilotBuff > 0 && pilot == 'venato' ? 1 + pilotSkillLevel * .06 : 1) *
      (1 + (passives['attack'] ?? 0) * .1) *
      ship.damage *
      (equipmentIndex == 1 ? 1.2 : 1);
  double get moveSpeed =>
      ship.speed *
      (moduleLoadout?.hasSupport('thruster') == true
          ? 1 +
                .08 * moduleLoadout!.supportPower('thruster') +
                (input.distance > 0 && combatTime % 12 < 1 ? .12 : 0)
          : 1) *
      (equipmentIndex == 2 ? 1.05 : 1) *
      (1 + (passives['speed'] ?? 0) * .08 + bonusSpeed) *
      bossSetSpeed *
      gearThrustFactor;
  double get collectionRadius => math.min(
    112,
    (42 + math.min(magnetLevel, 12) * 3 + (passives['magnet'] ?? 0) * 9) *
        (equipmentIndex == 2 ? 1.25 : 1) *
        math.sqrt(1 + bonusPickup) *
        (1 + .2 * (moduleLoadout?.supportPower('magnet') ?? 0)) *
        (dailyEntry?.pickupMultiplier ?? 1),
  );
  double get hitRadius => moduleLoadout?.hitRadius ?? 12;
  Foe? get boss {
    for (final e in enemies) {
      if (e.kind == 3) return e;
    }
    return null;
  }

  double get bossHealth => boss == null ? 0 : boss!.hp / boss!.maxHp;
  bool get bossSpawned => _bossSpawned;
  int get bossPattern {
    final waveOffset = _bossWave > 0 ? _bossWave - 1 : 0;
    final phase = (bossPhase + stage.sector + waveOffset) % 3;
    final index = (phase + bossRound) % 3;
    return worldBossPatterns[worldIndex][index];
  }

  double get bossChargeSpeed => worldIndex == 6 ? 240 : 210;
  bool get bossCharging =>
      boss != null && bossPattern == 2 && bossCycle >= 1.1 && bossCycle < 2.3;
  bool get bossWarning => boss != null && !screenMode && bossCycle < 1.1;
  bool get bossRecovering =>
      boss != null && bossCycle >= 2.3 && bossCycle < 3.2;
  double get hurtFlash => _damageFlash;
  void _decisionGrace() {
    _hurt = math.max(_hurt, .75);
    _damageFlash = 0;
    visuals.clearRecoil();
  }

  String get worldTactic => worldTactics[worldIndex];
  String get statusText => boss != null ? bossCue : worldTactic;
  double get hazardPhase => elapsed % 18;
  int _hazardCycle = -1;
  Offset hazardCenter = const Offset(900, 1200);
  bool get hazardVisible =>
      !screenMode &&
      !training &&
      dailyEntry == null &&
      boss == null &&
      !bossIncoming &&
      !resolvingBoss &&
      _hazardCycle == elapsed ~/ 18 &&
      hazardPhase >= 10 &&
      hazardPhase < 15;
  bool get hazardActive => hazardVisible && hazardPhase >= 13;
  List<WorldField> get fields =>
      worldFields(worldIndex, hazardCenter, hazardPhase, _hazardCycle);
  bool hazardHits(Offset at) => fields.any((field) => field.hits(at));
  void setPaused(bool value) {
    if (!finished) {
      paused = value;
      input = Offset.zero;
    }
  }

  void abandon() {
    finished = true;
    victory = false;
    input = Offset.zero;
  }

  void _event(String event) {
    final cue = switch (event) {
      'shoot' => CombatCueKind.muzzle,
      'hit' => CombatCueKind.impact,
      'level' => CombatCueKind.level,
      'boss' => CombatCueKind.bossPhase,
      'victory' => CombatCueKind.victory,
      'defeat' => CombatCueKind.defeat,
      _ => null,
    };
    if (cue != null)
      visuals.emit(
        cue,
        event == 'boss' ? (boss?.position ?? position) : position,
        source: event == 'shoot' ? armament : event,
        throttle: event,
        interval: .08,
        radius: event == 'boss' ? 90 : 36,
      );
    if (event != 'shoot' || _audio <= 0) {
      onEvent?.call(event);
      if (event == 'shoot') _audio = .18;
    }
  }

  Offset _unit(Offset v) =>
      v.distance < .001 ? const Offset(0, -1) : v / v.distance;
  Offset _direction(double a) => Offset(math.cos(a), math.sin(a));
  void update(double delta, {double? presentationDelta}) {
    if (finished ||
        paused ||
        choices.isNotEmpty ||
        !delta.isFinite ||
        delta <= 0) {
      return;
    }
    final real = delta.clamp(0.0, .05);
    // an ultimate's transformation plays out in slow motion
    if (ultimateShow > 0) ultimateShow = math.max(0, ultimateShow - real);
    final dt = ultimateShow > 0 ? real * .3 : real;
    final presentation =
        presentationDelta != null &&
            presentationDelta.isFinite &&
            presentationDelta > 0
        ? presentationDelta.clamp(0.0, .05)
        : dt;
    visuals.advance(resolvingBoss || collectingMagnet ? presentation : dt);
    atmosphereTime += resolvingBoss ? presentation : dt;
    if (resolvingBoss) {
      _advanceBossResolution(presentation);
      return;
    }
    _advanceAbsorption(presentation);
    if (choices.isNotEmpty) return;
    combatTime += dt;
    laserLife = math.max(0, laserLife - dt);
    magnetPulse = math.max(0, magnetPulse - dt);
    _laser -= dt;
    if (boss == null) elapsed += dt;
    waveNoticeTime = math.max(0, waveNoticeTime - dt);
    if (hazardPhase >= 10 && _hazardCycle != elapsed ~/ 18) {
      _hazardCycle = elapsed ~/ 18;
      hazardCenter = position;
      onEvent?.call('warning');
    }
    noticeTime = math.max(0, noticeTime - dt);
    _updateSupplies(dt);
    if (choices.isNotEmpty) return;
    // Chick companions fly with every airframe (v11 guardian cats).
    _updatePet(dt);
    _regenClock -= dt;
    if (regeneration && _regenClock <= 0) {
      hp = math.min(maxHp, hp + maxHp * .02);
      if (_gear(3, 7))
        visuals.emit(
          CombatCueKind.heal,
          position,
          source: 'gear-regeneration',
          radius: 32,
        );
      _regenClock = 30;
    }
    _audio -= dt;
    _hurt -= dt;
    _damageFlash = math.max(0, _damageFlash - dt);
    var movement = input.distance > 1 ? _unit(input) : input;
    final previousPosition = position;
    final steer = screenMode ? steerTarget : null;
    if (steer != null) {
      // Follow-touch steering: glide straight to the finger point without
      // overshoot (fast, but capped so it never teleports).
      final to = steer - position;
      final reach = moveSpeed * 2.6 * dt;
      position += to.distance <= reach ? to : _unit(to) * reach;
      movement = to.distance > 2
          ? _unit(to) * math.min(1, to.distance / 40)
          : Offset.zero;
    } else {
      position += movement * moveSpeed * dt;
    }
    position = Offset(
      position.dx.clamp(32.0, worldWidth - 32),
      position.dy.clamp(32.0, worldHeight - 32),
    );
    if (screenMode) keepOnScreen();
    visuals.followMovement(position - previousPosition, dt);
    if (movement.distance > .05) {
      final target = math.atan2(movement.dy, movement.dx);
      final diff = math.atan2(
        math.sin(target - movementAngle),
        math.cos(target - movementAngle),
      );
      movementAngle += diff * math.min(1, dt * 9);
    }
    if (screenMode) {
      updateHouseMap(dt);
      driftHouseLoot(dt);
    }
    if (boss == null && screenMode) {
      directWaves(dt);
    } else if (boss == null) {
      _updateFlightFormations(dt);
      _formationClock -= dt;
      if (formationWindowOpen && _formationClock <= 0) {
        if (enemies
                .where(
                  (e) => e.role == content.EnemyRole.kamikaze && !e.retired,
                )
                .length <
            8) {
          final spawned = _spawnKamikazeFormation();
          _formationClock = spawned
              ? math.min(
                  routePlan.assaultInterval,
                  encounterIndex == 2 ? 22 : 40,
                )
              : 1;
        } else {
          _formationClock = 1;
        }
      }
      final encounterId =
          (elapsed / (training ? 29 : duration / requiredBosses)).floor() * 6 +
          encounterIndex;
      if (_lastEncounter != encounterId) {
        _lastEncounter = encounterId;
        waveNoticeTime = 2.5;
        _spawn = math.min(_spawn, .2);
      }
      _spawn -= dt;
      if (!bossIncoming &&
          _spawn <= 0 &&
          elapsed < duration &&
          enemies.length < waveEnemyBudget) {
        final spec = encounter;
        _spawn =
            spec.interval *
            (dailyEntry?.waveIntervalMultiplier ?? 1) /
            (1 +
                _bossWave * .12 +
                math.min(.6, stageIndex * .004 + campaignLoop * .03));
        final baseCount =
            spec.count + worldIndex ~/ 3 + _bossWave + (challenge ? 2 : 0);
        final desiredCount =
            baseCount *
                (dailyEntry?.densityMultiplier ?? 1) *
                formationPopulationFactor +
            _dailySpawnRemainder;
        final roundedCount = desiredCount.floor();
        _dailySpawnRemainder = desiredCount - roundedCount;
        final count = roundedCount.clamp(1, 16);
        final edge = _spawnEdge();
        final lane = .15 + random.nextDouble() * .70;
        for (int i = 0; i < count && enemies.length < waveEnemyBudget; i++) {
          _spawnEnemy(
            at: spec.grouped
                ? _spawnPosition(
                    edge: edge,
                    lane: lane,
                    spread: (i - (count - 1) / 2) * 25,
                  )
                : _spawnPosition(),
          );
        }
      }
    }
    if (_bossWave < requiredBosses && boss == null && elapsed >= nextBossAt) {
      _bossWave++;
      _bossSpawned = true;
      // A clear transition from crowd survival to a single boss duel.
      enemies.clear();
      shots.removeWhere((s) => s.hostile);
      enemies.add(
        Foe(
          _bossSpawnPosition(),
          (training
                  ? 170
                  : (650 +
                            worldIndex * 120 +
                            stage.sector * 35 +
                            _bossWave * 300) *
                        1.8 *
                        threat) *
              (challenge ? 1.4 : 1) *
              (dailyEntry?.healthMultiplier ?? 1),
          30 + _bossWave * 3,
          34,
          3,
        ),
      );
      if (screenMode) spawnHouseBoss(enemies.first);
      _lastBossPhase = 0;
      bossCycle = 0;
      bossRound = 0;
      _lockBossAttack();
      pickupNotice = 'WARNING · 보스 $_bossWave / $requiredBosses';
      noticeTime = 4;
      bossArrivals++;
      _event('boss');
    }
    if (boss != null && bossPhase != _lastBossPhase) {
      _lastBossPhase = bossPhase;
      boss!.phase = 0;
      bossCycle = 0;
      bossRound = 0;
      _lockBossAttack();
      shots.removeWhere((s) => s.hostile);
      enemies.removeWhere((e) => e.kind != 3 && e.anchor == null);
      visuals.emit(CombatCueKind.bossPhase, boss!.position, radius: 140);
      pickupNotice = '보스 ${bossPhase + 1}단계 · 공격 패턴 전환';
      noticeTime = 2;
    }
    if (screenMode) {
      updateHouseBoss(dt);
    } else {
      _updateBossCycle(dt);
    }
    _updateCommonUltimate(dt);
    _updateBossGearSet(dt);
    if (aircraft == null) {
      _weapons(dt);
      _expandedWeapons(dt);
    } else {
      _modularWeapons(dt);
    }
    updatePawWeapons(dt);
    final crowd = <(int, int), List<Foe>>{};
    for (final e in enemies) {
      final cell = ((e.position.dx / 40).floor(), (e.position.dy / 40).floor());
      crowd.putIfAbsent(cell, () => []).add(e);
    }
    for (final e in enemies.toList()) {
      if (e.hp <= 0 || e.retired) continue;
      e.phase += dt;
      e.statusTime = math.max(0, e.statusTime - dt);
      e.vulnerable = math.max(0, e.vulnerable - dt);
      e.statusTick -= dt;
      if (e.statusTime > 0 && e.status != 2 && e.statusTick <= 0) {
        _hit(e, 2 * damageFactor, 'status');
        e.statusTick = .5;
      }
      if (!screenMode &&
          e.plane == AircraftTarget.air &&
          e.kind != 3 &&
          e.formationPattern == null &&
          e.role != content.EnemyRole.kamikaze &&
          (e.position - position).distance >
              math.max(650, viewportHeight / 2 + 160)) {
        e.position = _spawnPosition();
      }
      final toward = _unit(position - e.position);
      if (e.kind == 3) {
        if (screenMode) {
          moveHouseBoss(e, dt);
        } else if (bossCharging) {
          e.position += bossAim * bossChargeSpeed * dt;
        } else if (bossRecovering) {
          // Recover into a shootable position before opening the core. Repeated
          // charges must not pin the boss below the pilot at the world's edge.
          final staging = Offset(
            position.dx,
            (position.dy - 180).clamp(70.0, worldHeight - 220),
          );
          final delta = staging - e.position;
          e.position += _unit(delta) * math.min(delta.distance, 200 * dt);
        } else if (!bossWarning && !bossExposed && bossPattern < 3) {
          // Hold a firing distance instead of homing through the pilot.
          final distance = (position - e.position).distance;
          e.position +=
              toward *
              e.speed *
              dt *
              (distance > 230
                  ? 1
                  : distance < 140
                  ? -1
                  : 0);
        }
        e.position = Offset(
          e.position.dx.clamp(34.0, worldWidth - 34),
          e.position.dy.clamp(34.0, worldHeight - 34),
        );
        if (screenMode) {
          // the boss stays on the one screen, in the upper part
          final r = screenRect.deflate(e.radius * .6);
          e.position = Offset(
            e.position.dx.clamp(r.left, r.right),
            e.position.dy.clamp(r.top, r.top + viewportHeight * .55),
          );
        }
      } else if (e.anchor != null) {
        followAnchor(e, dt);
        if (e.retired) continue;
      } else if (e.path != null) {
        followPath(e, dt);
        if (e.retired) continue;
      } else if (e.plane == AircraftTarget.ground) {
        _moveGroundEnemy(e, dt, toward);
      } else {
        _moveEnemy(e, dt, toward);
        if (screenMode &&
            e.kind != 3 &&
            !screenRect.inflate(220).contains(e.position)) {
          e.retired = true;
          continue;
        }
      }
      if (e.kind != 3 &&
          e.path == null &&
          e.anchor == null &&
          e.role != content.EnemyRole.kamikaze &&
          e.formationPattern == null) {
        final cx = (e.position.dx / 40).floor(),
            cy = (e.position.dy / 40).floor();
        var separation = Offset.zero;
        for (int x = cx - 1; x <= cx + 1; x++) {
          for (int y = cy - 1; y <= cy + 1; y++) {
            for (final other in crowd[(x, y)] ?? const <Foe>[]) {
              if (identical(e, other) || e.plane != other.plane) continue;
              final away = e.position - other.position;
              final spacing = (e.radius + other.radius) * .75;
              if (away.distance > .01 && away.distance < spacing) {
                separation += away / away.distance * (spacing - away.distance);
              }
            }
          }
        }
        if (separation.distance > 40) separation = _unit(separation) * 40;
        e.position += separation * dt * 3;
      }
      if (e.plane == AircraftTarget.air &&
          (e.position - position).distance < e.radius + hitRadius &&
          formationContactActive(e) &&
          !(e.kind == 3 && bossRecovering)) {
        if (_hurt <= 0) {
          _damage(
            e.kind == 3
                ? 20
                : e.kind == 2
                ? 15
                : 9,
            source: e.kind == 3 ? '보스 접촉' : '적기 접촉',
          );
        }
        if (e.role == content.EnemyRole.kamikaze) {
          e.retired = true;
          _burst(e.position, 0, 6);
        } else if (e.kind != 3) {
          e.position -= toward * 24;
        }
      }
    }
    _plasmaCooldown.removeWhere((e, time) => e.hp <= 0 || !enemies.contains(e));
    _plasmaCooldown.updateAll((e, time) => time - dt);
    final plasmaHits = <Foe>{};
    for (final s in shots) {
      s.life -= dt;
      s.age += dt;
      if (unifiedModules && s.life <= 0) continue;
      s.hitCooldown -= dt;
      if (_stepModularShot(s, dt)) continue;
      if (_stepHostileShot(s, dt)) continue;
      if (_stepExpandedShot(s, dt)) continue;
      if ((s.kind == 1 || (s.weapon == 'drone' && techSpecial('drone'))) &&
          enemies.isNotEmpty) {
        Foe target =
            s.target != null && s.target!.hp > 0 && enemies.contains(s.target)
            ? s.target!
            : enemies.first;
        if (s.target == null ||
            s.target!.hp <= 0 ||
            !enemies.contains(s.target)) {
          for (final e in enemies) {
            if (e.hp > 0 && (target.hp <= 0 || e.maxHp > target.maxHp)) {
              target = e;
            }
          }
        }
        if (s.weapon == 'missile-evo') s.target = target;
        s.velocity = Offset.lerp(
          s.velocity,
          _unit(target.position - s.position) * 275,
          math.min(1, dt * 7),
        )!;
      }
      s.position += s.velocity * dt;
      s.distanceTravelled += s.velocity.distance * dt;
      if (s.kind == 4) {
        if ((position - s.position).distance < hitRadius + s.radius &&
            _hurt <= 0) {
          _damage(s.damage, source: '적탄');
          s.life = 0;
        }
      } else {
        if (s.kind == 5 && s.hitCooldown > 0) continue;
        bool areaHit = false;
        for (final e in enemies) {
          if (e.hp <= 0 ||
              (aircraft != null && !modularSourceCanHit(s.weapon, e)) ||
              s.hitTargets.contains(e) ||
              (s.kind == 5 &&
                  (plasmaHits.contains(e) || (_plasmaCooldown[e] ?? 0) > 0))) {
            continue;
          }
          if ((e.position - s.position).distance < e.radius + s.radius) {
            final previousHp = e.hp;
            _hit(
              e,
              _primaryHitDamage(s),
              s.weapon.isNotEmpty
                  ? s.weapon
                  : switch (s.kind) {
                      0 => 'gun',
                      1 => 'missile',
                      3 => 'mine',
                      5 => 'trail',
                      _ => 'side',
                    },
            );
            if (modular) {
              _modularHit(s, e, previousHp);
            } else {
              _resolveSynergyHit(s, e, previousHp);
            }
            _splitShell(s, e);
            if (s.kind == 1 || s.kind == 3) {
              final blast =
                  (s.kind == 1
                      ? (s.weapon == 'synergy-explosive'
                            ? 28.0
                            : 44.0 * (techSpecial('missile') ? 1.6 : 1))
                      : 55.0 * (techSpecial('mine') ? 1.5 : 1)) *
                  areaFactor;
              for (final other in enemies) {
                if (other != e &&
                    (other.position - s.position).distance < blast) {
                  _hit(
                    other,
                    s.damage * .7,
                    s.weapon == 'synergy-explosive'
                        ? s.weapon
                        : s.kind == 1
                        ? 'missile'
                        : 'mine',
                  );
                }
              }
              _burst(s.position, 1, 9);
            }
            if (s.kind == 5) {
              areaHit = true;
              plasmaHits.add(e);
              _plasmaCooldown[e] = .4;
            } else if (s.pierce > 0) {
              s.pierce--;
              s.hitTargets.add(e);
            } else {
              s.life = 0;
              break;
            }
          }
        }
        if (areaHit) s.hitCooldown = .4;
      }
    }
    shots.addAll(_deferredShots);
    _deferredShots.clear();
    shots.removeWhere(
      (s) => s.life <= 0 || (s.position - position).distance > 1000,
    );
    for (final e in enemies.where((e) => e.hp <= 0 && !e.retired).toList()) {
      kills++;
      visuals.emit(
        e.kind == 3 ? CombatCueKind.bossExplosion : CombatCueKind.explosion,
        e.position,
        radius: e.kind == 3 ? 125 : e.radius * 2,
      );
      _enemyDeath(e);
      if (armament == 'disorder') soulStacks = (soulStacks + 1).clamp(0, 100);
      _burst(e.position, e.kind == 3 ? 2 : 0, e.kind == 3 ? 30 : 6);
      final wiped = screenMode && e.kind != 3 && waveWiped(e);
      final rewards = e.kind == 3
          ? const <double>[16, 16, 8]
          : <double>[
              experienceDrops.ordinary(
                    elapsed / duration,
                    armored: e.kind == 2,
                  ) *
                  (screenMode ? 1.8 : 1),
              if (wiped) 12,
              if (e.elite) ...[10, 10, 10],
            ];
      if (screenMode && e.kind != 3) houseDrop(e, wiped);
      for (final value in rewards) {
        if (value <= 0) continue;
        crystals.add(
          ExperienceCrystal.at(
            e.position +
                Offset(
                  experienceDrops.random.nextDouble() * 20 - 10,
                  experienceDrops.random.nextDouble() * 20 - 10,
                ),
            value,
          ),
        );
      }
      if (e.kind == 3) {
        bossesDefeated++;
        bossDefeats++;
        supplies.add(Supply(e.position, 3));
        _bossDefeated = bossesDefeated >= requiredBosses;
        _beginBossResolution(e, _bossDefeated);
        shots.removeWhere((s) => s.hostile);
        for (final add in enemies.where((e) => e.kind != 3)) {
          add.retired = true;
        }
        _spawn = 2;
        _formationRestUntil = combatTime + 5;
        pickupNotice = '보스 격파 · 보급 상자를 회수하세요';
        noticeTime = 3;
      }
    }
    enemies.removeWhere((e) => e.hp <= 0 || e.retired);
    _consolidateCrystals();
    if (resolvingBoss) return;
    // House stages: gems are no longer pulled in from anywhere, so the
    // pickup circle around the cat is a little wider.
    final reach = collectionRadius * (screenMode ? 1.5 : 1);
    var gemPicked = false;
    for (int i = crystals.length - 1; i >= 0; i--) {
      final dist = (crystals[i] - position).distance;
      if (dist < reach) {
        crystals[i] += _unit(position - crystals[i]) * 260 * dt;
      } else if (screenMode) {
        // House stages (user 2026-10-24): gems drift slowly down with the
        // street and are only drawn in once the cat flies near them.
        crystals[i] += Offset(0, 40 * dt);
      }
      if ((crystals[i] - position).distance < (screenMode ? 26 : 18)) {
        visuals.emit(
          CombatCueKind.pickup,
          position,
          throttle: 'xp',
          interval: .15,
          radius: 20,
        );
        final value = ExperienceCrystal.valueOf(crystals.removeAt(i));
        _gearCollectedCrystal(value);
        xp += value * (1 + (passives['xp'] ?? 0) * .08);
        gemPicked = true;
      }
    }
    if (gemPicked) _checkLevel();
    if (hazardActive && _hurt <= 0) {
      final danger = hazardHits(position);
      if (danger) _damage(worldIndex == 0 ? 4 : 7, source: '환경 위험');
    }
    for (final p in sparks) {
      p.position += p.velocity * dt;
      p.life -= dt;
    }
    sparks.removeWhere((p) => p.life <= 0);
    if (elapsed >= duration && _bossDefeated && !finished) {
      // The final boss resolution owns the transition into the result screen.
      // Never replace a missing presentation with a same-frame result.
      if (bossResolution == null) _finishVictory();
    }
  }

  void _updatePet(double dt) {
    if (petKind < 0 || petLevel <= 0) return;
    if (petHp <= 0) {
      if ((petPosition - position).distance < 80) petRevive += dt;
      if (petRevive >= 8) {
        petHp = 100;
        petRevive = 0;
      }
      return;
    }
    petPosition = Offset.lerp(
      petPosition,
      position + const Offset(-60, 40),
      math.min(1, dt * 5),
    )!;
    _petHurt -= dt;
    if (_petHurt <= 0 &&
        enemies.any(
          (e) => (e.position - petPosition).distance < e.radius + 12,
        )) {
      petHp = math.max(0, petHp - 12);
      _petHurt = 1;
    }
    _petAttack -= dt;
    if (_petAttack > 0) return;
    final power =
        ((1 + petLevel * .08 + petRank * .2) *
                (1 +
                    (petAwakePower.isFinite ? petAwakePower.clamp(0, .18) : 0)))
            .toDouble();
    final interval =
        (1 - (petAwakeCooldown.isFinite ? petAwakeCooldown.clamp(0, .12) : 0))
            .toDouble();
    if (petKind == 0) {
      _petAttack = .9 * interval;
      final target = _nearest();
      if (target != null) {
        onEvent?.call('pet');
        for (int i = 0; i < (petLevel >= 5 ? 2 : 1); i++) {
          shots.add(
            Shot(
              petPosition + Offset(i * 8.0, 0),
              _unit(target.position - petPosition) * 330,
              12 * power * damageFactor,
              6,
              weapon: 'pet',
            ),
          );
        }
      }
    } else if (petKind == 1) {
      _petAttack = 12 * interval;
      hp = math.min(maxHp, hp + maxHp * .025 * power);
      onEvent?.call('pet');
      _burst(petPosition, 1, 6);
    } else {
      _petAttack = 3 * interval;
      final before = shots.length;
      shots.removeWhere(
        (s) =>
            s.interceptable && (s.position - petPosition).distance < 85 * power,
      );
      if (shots.length < before) onEvent?.call('pet');
      _burst(petPosition, 1, 6);
    }
  }

  bool _bossDefeated = false;
  final Map<String, double> damageTakenBySource = {};
  String lastDamageSource = '';
  String get damageAdvice => switch (lastDamageSource) {
    '적기 접촉' || '보스 접촉' => '접근하는 적과 간격을 유지하세요. 선체 연구·방호 장비도 확인하세요.',
    '레이저' => '충전 예고 중 사선 밖으로 이동하세요. 코어가 열리면 다시 공격하세요.',
    '환경 위험' => '$worldTactic. 예고 중 회피 경로를 확보하세요.',
    '기뢰' => '기뢰가 활성화되기 전에 원 밖으로 이동하세요. 보스 기뢰 고리는 열린 출구로 빠져나가세요.',
    _ => '탄막이 겹치면 손을 떼어 판단하세요. 옆으로 이동하거나 방호·항성포를 활용하세요.',
  };

  /// Opens the level-up cards the moment the gauge is full (user
  /// 2026-10-25: a full bar that still asked for more gems felt broken).
  /// Runs when a gem reaches the cat, when the magnet's gems land, when a
  /// boss scene ends and after a choice, so a bar left full by any of those
  /// opens the next draft at once instead of waiting for another gem.
  void _checkLevel() {
    if (xp >= xpNeeded &&
        !finished &&
        choices.isEmpty &&
        !collectingMagnet &&
        !resolvingBoss) {
      xp -= xpNeeded;
      level++;
      xpNeeded = growthCost(level);
      _offerChoices();
      _event('level');
    }
  }

  void _damage(double amount, {String source = '교전 피해'}) {
    if (developerInvincible) return;
    if (unifiedModules && amount > 0) {
      // Absorbed hits interrupt recharge too; evading earns a recovery window.
      _moduleTimers['support-shield'] = math.max(
        _moduleTimers['support-shield'] ?? 0,
        6,
      );
    }
    final beforeHp = hp;
    if (moduleShield > 0) {
      final absorbed = math.min(moduleShield, amount);
      moduleShield -= absorbed;
      amount -= absorbed;
      visuals.emit(CombatCueKind.shield, position, radius: 48);
    }
    if (pilotShield > 0) {
      final absorbed = math.min(pilotShield, amount);
      visuals.emit(CombatCueKind.shield, position, radius: 48);
      pilotShield -= absorbed;
      amount -= absorbed;
    }
    if (aircraft == null && armament == 'disorder' && soulStacks > 0) {
      _radialDamage(
        position,
        100,
        (25 + soulStacks * .8) * permanentMainFactor,
        'soul',
      );
      soulStacks = 0;
    }
    // All callers supply base damage. Apply the shared, capped threat factor
    // exactly once, including boss contact and the world's environmental field.
    hp = math.max(
      0,
      hp -
          amount *
              math.sqrt(threat).clamp(1, 3) *
              (1 -
                  (moduleArmorReduction +
                          damageReduction +
                          (passives['armor'] ?? 0) * .08 +
                          bossSetReduction)
                      .clamp(0, .7)),
    );
    if (hp < beforeHp) {
      _damageFlash = .7;
      _gearTookDamage(beforeHp - hp);
      lastDamageSource = source;
      damageTakenBySource[source] =
          (damageTakenBySource[source] ?? 0) + beforeHp - hp;
    }
    if (pilot == 'venato' && amount > 0) pilotBuff = 10;
    _hurt = .7;
    if (hp < beforeHp) _event('hit');
    if (hp > 0 && hp <= maxHp * .25 && beforeHp > maxHp * .25) {
      onEvent?.call('warning');
    }
    if (hp <= 0) {
      finished = true;
      victory = false;
      _event('defeat');
    }
  }

  void _burst(Offset at, int kind, int count) {
    for (int i = 0; i < count; i++) {
      if (sparks.length > 160) break;
      sparks.add(
        Spark(
          at,
          _direction(random.nextDouble() * math.pi * 2) *
              (30 + random.nextDouble() * 70),
          .3 + random.nextDouble() * .5,
          kind,
        ),
      );
    }
  }

  // Front 80%, left/right 8% each, rear 4%. Used by reinforcements and recycling.
  int _spawnEdge() {
    final roll = random.nextDouble();
    return roll < .80
        ? 0
        : roll < .88
        ? 1
        : roll < .96
        ? 3
        : 2;
  }

  Offset _spawnPosition({int? edge, double? lane, double spread = 0}) {
    final side = edge ?? _spawnEdge();
    final along = lane ?? random.nextDouble();
    return camera +
        switch (side) {
          0 => Offset((along * 420 + spread).clamp(0, 420), -38),
          1 => Offset(
            458,
            (along * viewportHeight + spread).clamp(0, viewportHeight),
          ),
          2 => Offset(
            (along * 420 + spread).clamp(0, 420),
            viewportHeight + 38,
          ),
          _ => Offset(
            -38,
            (along * viewportHeight + spread).clamp(0, viewportHeight),
          ),
        };
  }

  void _spawnEnemy({required Offset at}) {
    final roll = random.nextDouble();
    var role = roll < encounter.heavyChance
        ? content.EnemyRole.bulwark
        : roll < encounter.heavyChance + encounter.runnerChance
        ? content.EnemyRole.weaver
        : content.EnemyRole.scout;
    if (random.nextDouble() < .25 + stage.sector * .035) {
      final roles = stage.world.roles;
      role = roles[random.nextInt(roles.length)];
    }
    if (encounterIndex != 0 &&
        encounterIndex != 5 &&
        random.nextDouble() < routePlan.roleChance) {
      role = routePlan.role;
    }
    if (dailyEntry?.variant == 1 && random.nextDouble() < .35) {
      role = content.EnemyRole.spitter;
    }
    final ranged = {
      content.EnemyRole.spitter,
      content.EnemyRole.sniper,
      content.EnemyRole.miner,
      content.EnemyRole.carrier,
    };
    if (ranged.contains(role) &&
        enemies.where((e) => ranged.contains(e.role)).length >= 12) {
      role = content.EnemyRole.scout;
    }
    enemies.add(_createEnemy(at, role));
  }

  Foe? _nearest({bool front = false}) {
    Foe? result;
    double distance = double.infinity;
    for (final e in enemies) {
      if (e.hp <= 0 || (aircraft != null && e.plane != AircraftTarget.air))
        continue;
      final v = e.position - position;
      if (front &&
          (_unit(v).dx * math.cos(movementAngle) +
                  _unit(v).dy * math.sin(movementAngle)) <
              .15) {
        continue;
      }
      if (v.distance < distance) {
        distance = v.distance;
        result = e;
      }
    }
    return result;
  }

  Offset _bossSpawnPosition() {
    final distance = math.min(230.0, math.max(120.0, viewportHeight / 2 - 190));
    for (final offset in [
      Offset(0, -distance),
      Offset(distance, 0),
      Offset(-distance, 0),
      Offset(0, distance),
    ]) {
      final at = position + offset;
      if (at.dx >= 34 &&
          at.dx <= worldWidth - 34 &&
          at.dy >= 34 &&
          at.dy <= worldHeight - 34) {
        return at;
      }
    }
    // Near a corner the perpendicular coordinate may itself be 32px.
    final at =
        position +
        Offset(0, position.dy < worldHeight / 2 ? distance : -distance);
    return Offset(
      at.dx.clamp(34.0, worldWidth - 34),
      at.dy.clamp(34.0, worldHeight - 34),
    );
  }

  void _updateBossCycle(double dt) {
    final b = boss;
    if (b == null) return;
    final previous = bossCycle;
    bossCycle += dt;
    if (previous < 1.1 && bossCycle >= 1.1) {
      bossAttacks++;
      _event('boss');
      _bossSignature(b);
      _bossReinforcements(b);
    }
    if (previous < 1.9 &&
        bossCycle >= 1.9 &&
        bossPattern < 2 &&
        bossPhase > 0 &&
        [1, 2, 7, 8, 9].contains(worldIndex)) {
      _bossVolley(b);
    }
    if (previous < 3.2 && bossCycle >= 3.2) {
      visuals.emit(
        CombatCueKind.bossPhase,
        b.position,
        radius: 100,
        source: 'open',
      );
      pickupNotice = '코어 개방 · 지금 집중 공격';
      noticeTime = 1.4;
    }
    if (bossCycle >= 5.8) {
      bossCycle = 0;
      bossRound++;
      _lockBossAttack();
    }
  }

  void _bossVolley(Foe b) {
    if (bossPattern == 2) return;
    final aimed = math.atan2(bossAim.dy, bossAim.dx);
    final safeAngle = math.atan2(bossSafeDirection.dy, bossSafeDirection.dx);
    final count = bossPattern == 1 ? 7 : 16 + worldIndex ~/ 2;
    for (int i = 0; i < count; i++) {
      final angle = bossPattern == 1
          ? aimed + (i - 3) * .16
          : aimed + i * math.pi * 2 / count;
      final difference = math
          .atan2(math.sin(angle - safeAngle), math.cos(angle - safeAngle))
          .abs();
      if (bossPattern == 0 && difference < .42) continue;
      final speed = worldIndex == 3 || worldIndex == 7
          ? 85.0
          : bossPattern == 1
          ? 150.0
          : 105.0;
      shots.add(
        Shot(
          b.position,
          _direction(angle) * speed,
          17,
          4,
          weapon: 'boss-volley',
          life: 5,
          radius: worldIndex == 3 ? 6 : 5,
        ),
      );
    }
  }

  void _weapons(double dt) {
    _gun -= dt;
    _missile -= dt;
    _drone -= dt;
    _side -= dt;
    _mine -= dt;
    _trail -= dt;
    final gun = upgrades['gun'] ?? 0;
    if (gun > 0 && _gun <= 0) {
      final firstMainShot = shots.length;
      _mainAttackMultiplier = shieldCounterPending ? 1.5 : 1;
      _mainAttackDidDamage = false;
      _mainAttackInProgress = true;
      _gun = math.max(.12, .36 - gun * .025) * cooldownFactor * mainInterval;
      if (armament != 'pulse') {
        _fireArmament(gun);
      } else {
        final firstShot = shots.length;
        const direction = Offset(0, -1);
        shots.add(
          Shot(
            position + direction * 17,
            direction * 420,
            (13 + gun * 4) *
                damageFactor *
                mainDamage *
                techDamage('gun') *
                _mainAttackMultiplier,
            0,
            pierce: techSpecial('gun') ? 1 : 0,
            radius: mainWidth,
          ),
        );
        if (evolved.contains('gun')) {
          for (final lane in [-12.0, 12.0]) {
            shots.add(
              Shot(
                position + Offset(lane, -17),
                direction * 420,
                18 *
                    damageFactor *
                    mainDamage *
                    techDamage('gun') *
                    _mainAttackMultiplier,
                0,
                pierce: techSpecial('gun') ? 1 : 0,
              ),
            );
          }
        }
        for (int lane = 1; lane < mainProjectiles; lane++) {
          final offset = (lane.isOdd ? 1 : -1) * ((lane + 1) ~/ 2) * 10.0;
          shots.add(
            Shot(
              position + Offset(offset, -17),
              direction * 420 * skillSpeed,
              (13 + gun * 4) *
                  damageFactor *
                  mainDamage *
                  techDamage('gun') *
                  _mainAttackMultiplier,
              0,
              radius: mainWidth,
              pierce: techSpecial('gun') ? 1 : 0,
            ),
          );
        }
        _applyPulseBranch(firstShot);
      } // pulse armament
      final mainFired = _applyMainLoadout(firstMainShot);
      _mainAttackInProgress = false;
      if (_mainAttackMultiplier > 1 && mainFired) {
        _shieldCounterArmed = false;
        _shieldCounterAttacks++;
      }
      _mainAttackMultiplier = 1;
      _event('shoot');
    }
    if (armament == 'pulse' &&
        gun > 0 &&
        evolved.contains('gun') &&
        _laser <= 0) {
      _laser = .9 * cooldownFactor;
      laserLife = .13;
      laserOrigin = position + const Offset(0, -17);
      for (final e in enemies) {
        final v = e.position - laserOrigin;
        final spread = mainBranch == MainBranch.pulseSpread;
        if (v.dy < 0 &&
            v.dy > -520 * mainReachFactor &&
            v.dx.abs() < e.radius + (spread ? 18 : 8)) {
          _hit(
            e,
            70 *
                (spread ? .7 : 1) *
                damageFactor *
                mainDamage *
                techDamage('gun'),
            'gun',
          );
        }
      }
    }
    final missile = upgrades['missile'] ?? 0;
    if (missile > 0 && _missile <= 0 && enemies.isNotEmpty) {
      _missile = math.max(.7, 2.0 - missile * .18) * cooldownFactor;
      for (
        int i = 0;
        i < (evolved.contains('missile') ? 4 : 1 + missile ~/ 3);
        i++
      ) {
        shots.add(
          Shot(
            position,
            _direction(movementAngle + i * 2) * 160,
            (23 + missile * 9) * damageFactor * techDamage('missile'),
            1,
            weapon: evolved.contains('missile') ? 'missile-evo' : 'missile',
            life: 4,
            radius: 6,
          ),
        );
      }
    }
    final drone = upgrades['drone'] ?? 0;
    if (drone > 0 && _drone <= 0) {
      _drone =
          math.max(.12, .75 - drone * .08) *
          cooldownFactor *
          (evolved.contains('drone') ? .65 : 1);
      final target = _nearest();
      if (target != null &&
          (target.position - position).distance < 210 + drone * 18) {
        final origin = position + _direction(combatTime * 2) * 34;
        shots.add(
          Shot(
            origin,
            _unit(target.position - origin) * 360,
            (12 + drone * 5) * damageFactor * techDamage('drone'),
            2,
            weapon: 'drone',
            pierce: evolved.contains('drone') ? 1 : 0,
          ),
        );
      }
    }
    final side = upgrades['side'] ?? 0;
    if (side > 0 && _side <= 0) {
      _side = (.9 - side * .1) * cooldownFactor;
      for (
        int ray = 0;
        ray <
            ((evolved.contains('side') ? 12 : 4 + side) +
                (techSpecial('side') ? 2 : 0));
        ray++
      ) {
        shots.add(
          Shot(
            position,
            _direction(
                  ray *
                      math.pi *
                      2 /
                      ((evolved.contains('side') ? 12 : 4 + side) +
                          (techSpecial('side') ? 2 : 0)),
                ) *
                330,
            (22 + side * 10) * damageFactor * techDamage('side'),
            2,
            radius: 6,
          ),
        );
      }
    }
    final mine = upgrades['mine'] ?? 0;
    if (mine > 0 && _mine <= 0) {
      _mine = (evolved.contains('mine') ? .65 : 1.7) * cooldownFactor;
      shots.add(
        Shot(
          position - _direction(movementAngle) * 24,
          Offset.zero,
          (50 + mine * 20) * damageFactor * techDamage('mine'),
          3,
          life: 6 * durationFactor,
          radius: 20 * areaFactor,
        ),
      );
    }
    final trail = upgrades['trail'] ?? 0;
    if (trail > 0 && _trail <= 0) {
      // Duration extends route coverage, not damage stacked at one location.
      final patches = shots.where((s) => s.kind == 5).toList();
      if (patches.length >= 24) shots.remove(patches.first);
      _trail = .45 * cooldownFactor;
      shots.add(
        Shot(
          position - _direction(movementAngle) * 20,
          Offset.zero,
          (14 + trail * 8) * damageFactor * techDamage('trail'),
          5,
          life: 1.8 * durationFactor * (techSpecial('trail') ? 1.5 : 1),
          radius: (evolved.contains('trail') ? 65 : 28) * areaFactor,
        ),
      );
    }
    _guardian -= dt;
    final guardian = upgrades['guardian'] ?? 0;
    if (guardian > 0 && _guardian <= 0) {
      _guardian = .16 * cooldownFactor;
      final reach =
          (evolved.contains('guardian') ? 95 : 62) *
          areaFactor *
          (techSpecial('guardian') ? 1.2 : 1);
      for (final e in enemies) {
        if ((e.position - position).distance < reach + e.radius) {
          _hit(
            e,
            (5 + guardian * 3) * damageFactor * techDamage('guardian'),
            'guardian',
          );
          if (e.kind != 3) e.position += _unit(e.position - position) * 9;
        }
      }
      if (guardianShieldActive) {
        var blocked = 0;
        shots.removeWhere((s) {
          final intercepted =
              s.interceptable && (s.position - position).distance < reach;
          if (intercepted && s.life > 0 && s.damage > 0) blocked++;
          return intercepted;
        });
        if (blocked > 0) _onGuardianBlock();
      }
    }
    _lightning -= dt;
    final lightning = upgrades['lightning'] ?? 0;
    if (lightning > 0 && _lightning <= 0 && enemies.isNotEmpty) {
      _lightning = 2 * cooldownFactor;
      final hits = <Foe, int>{};
      for (
        int i = 0;
        i <
            ((evolved.contains('lightning') ? 12 : lightning + 1) +
                (techSpecial('lightning') ? 2 : 0));
        i++
      ) {
        final live = enemies
            .where(
              (e) =>
                  e.hp > 0 &&
                  (e.position - position).distance < 420 &&
                  (hits[e] ?? 0) < (evolved.contains('lightning') ? 3 : 2),
            )
            .toList();
        if (live.isEmpty) break;
        final fewest = live.map((e) => hits[e] ?? 0).reduce(math.min);
        final candidates = live.where((e) => (hits[e] ?? 0) == fewest).toList();
        final e = candidates[random.nextInt(candidates.length)];
        hits[e] = (hits[e] ?? 0) + 1;
        _hit(
          e,
          (28 + lightning * 9) * damageFactor * techDamage('lightning'),
          'lightning',
        );
        _burst(e.position, 1, 5);
      }
    }
  }

  static final catalog = [
    for (final s in survivalSkills)
      UpgradeChoice(s.id, s.name, s.description, s.id),
    const UpgradeChoice('repair', '응급 나노 수리', '최대 선체의 30% 회복', 'repair'),
  ];
  bool canEvolve(String id) {
    if (unifiedModules) return false;
    if (id == 'gun' ||
        (id == 'pilot' ? pilotSkillLevel : (upgrades[id] ?? 0)) != 5 ||
        evolved.contains(id)) {
      return false;
    }
    final skill = skillFor(id);
    if (skill.fusionWith != null) {
      return (upgrades[skill.fusionWith] ?? 0) == 5 &&
          !evolved.contains(skill.fusionWith);
    }
    if (id == 'pilot') return true;
    return (passives[skill.partner] ?? 0) > 0;
  }

  void _offerChoices({Set<String> exclude = const {}}) {
    if (unifiedModules) {
      _offerModuleChoices(exclude: exclude);
      return;
    }
    final pool = <UpgradeChoice>[];
    for (final s in survivalSkills) {
      if (s.id == 'gun' ||
          s.fusionOnly ||
          (s.id == 'pilot' && pilot == 'common')) {
        continue;
      }
      final passive = isPassiveSkill(s.id);
      final current = (passive ? passives : upgrades)[s.id] ?? 0;
      if ((!passive || s.id == 'pilot') && canEvolve(s.id)) {
        pool.add(
          UpgradeChoice(
            s.id,
            s.evolution!,
            'EVO · ${s.name} · ${s.recipeHint ?? (s.partner == null ? '고유 모듈 완성' : skillFor(s.partner!).name)}',
            s.id,
            evolution: true,
          ),
        );
      } else if (current < 5 &&
          (current > 0 || (passive ? passives.length < 6 : weaponCount < 6))) {
        pool.add(
          UpgradeChoice(
            s.id,
            s.id == 'pilot'
                ? content.pilots.firstWhere((p) => p.id == pilot).name
                : s.name,
            '${passive ? '보조' : '무기'} Lv.$current → ${current + 1} · ${s.description}',
            s.id,
          ),
        );
      }
    }
    _offerFusionChoices(pool);
    pool.addAll(availableMainBranches);
    if (aircraft != null) {
      pool.removeWhere(
        (c) =>
            !c.specialization &&
            c.id != 'repair' &&
            !isPassiveSkill(c.id) &&
            !moduleSkillAvailable(c.id),
      );
      for (var i = 0; i < pool.length; i++) {
        final c = pool[i];
        final mount = moduleSkillMount(c.id);
        if (mount != null && !c.specialization)
          pool[i] = UpgradeChoice(
            c.id,
            '${moduleMountLabel(mount)} · ${c.title}',
            c.evolution ? '부품 진화 · 관통·범위·효율 강화' : '장착 부품의 피해·효율 강화',
            c.iconKey,
            evolution: c.evolution,
          );
      }
    }
    pool.shuffle(random);
    final fresh = pool.where((c) => !exclude.contains(c.id)).toList();
    choices = [
      ...fresh,
      ...pool.where((c) => exclude.contains(c.id)),
    ].take(3).toList();
    // One owned weapon/recipe offer keeps early build progress legible without guaranteeing a build.
    if (level <= 12 &&
        exclude.isEmpty &&
        !choices.any((c) => upgrades.containsKey(c.id))) {
      final owned = pool.where((c) => upgrades.containsKey(c.id)).toList();
      if (owned.isNotEmpty && choices.isNotEmpty) {
        choices[choices.length - 1] = owned.first;
      }
    }
    // Early levels always offer a tangible attack upgrade alongside random choices.
    if (level <= 5 && choices.isNotEmpty && choices.every(_choiceIsPassive)) {
      final weapons = pool.where(
        (c) => !_choiceIsPassive(c) && !exclude.contains(c.id),
      );
      if (weapons.isNotEmpty) choices[choices.length - 1] = weapons.first;
    }
    if ((level == 6 || level == 9) && exclude.isEmpty) {
      final recipes = pool
          .where((c) => missingPartners.contains(c.id))
          .toList();
      if (recipes.isNotEmpty &&
          !choices.any((c) => missingPartners.contains(c.id))) {
        choices[0] = recipes.first;
      }
    }
    if (choices.length < 3) choices.add(catalog.last);
    if (level == 2 && exclude.isEmpty && availableMainBranches.isNotEmpty) {
      choices = [
        ...availableMainBranches,
        choices.firstWhere(
          (c) => !c.specialization,
          orElse: () => catalog.last,
        ),
      ];
    }
    input = Offset.zero;
  }

  void chooseUpgrade(String id) {
    if (finished || !choices.any((c) => c.id == id)) return;
    final choice = choices.firstWhere((c) => c.id == id);
    if (choice.specialization) {
      final matching = mainBranches.where(
        (s) => s.id == id && s.armament == armament,
      );
      if (mainBranch != null || matching.isEmpty) return;
      mainBranch = matching.single.branch;
      pickupNotice = '${matching.single.name} · 이번 출격 특화';
      noticeTime = 3;
    } else if (id == 'repair') {
      hp = math.min(maxHp, hp + maxHp * .3);
    } else if (applyGrowthChoice(id)) {
      // enhance / evolve / ultimate of a weapon (weapon_growth.dart)
    } else if (choice.evolution) {
      _evolve(id);
    } else if (isPassiveSkill(id)) {
      passives[id] = (passives[id] ?? 0) + 1;
      if (id == 'hull') {
        maxHp += ship.health * .2;
        hp = math.min(maxHp, hp + ship.health * .2);
      }
    } else {
      upgrades[id] = (upgrades[id] ?? 0) + 1;
    }
    choices = [];
    chestSelection = false;
    if (!choice.evolution) {
      visuals.emit(
        id == 'repair' ? CombatCueKind.heal : CombatCueKind.level,
        position,
        source: id,
        radius: 58,
      );
    }
    input = Offset.zero;
    // Allow a thumb to return to the battlefield after making a choice.
    _decisionGrace();
    // Experience banked beyond this level still shows a full gauge.
    _checkLevel();
  }

  void _updateSupplies(double dt) {
    // House stages drop items from destroyed formations instead of timers.
    if (!screenMode) _dropFieldSupplies(dt);
    _supplyClock -= dt;
    if (!screenMode && _supplyClock <= 0 && supplies.length < 4) {
      _supplyClock = 36;
      // A visible detour, never a random free pickup under the aircraft.
      final kind = random.nextDouble() < .7 ? 0 : 2;
      supplies.add(Supply(_safeDrop(), kind));
    }
    for (int i = supplies.length - 1; i >= 0; i--) {
      final item = supplies[i];
      if ((item.position - position).distance > 28) continue;
      if (item.kind == 3 &&
          (collectingMagnet ||
              (crystals.isNotEmpty &&
                  supplies.any(
                    (s) =>
                        s.kind == 1 && (s.position - position).distance <= 28,
                  )))) {
        // A chest cannot interrupt an XP stream already entering the aircraft,
        // including two pickups reached in the very same frame.
        continue;
      }
      visuals.emit(
        switch (item.kind) {
          0 => CombatCueKind.heal,
          1 => CombatCueKind.magnet,
          2 => CombatCueKind.bomb,
          7 || 8 => CombatCueKind.level,
          _ => CombatCueKind.pickup,
        },
        position,
        radius: item.kind == 2 ? 240 : 60,
        source: item.kind == 3 || item.kind == 9 ? 'chest' : '',
      );
      supplies.removeAt(i);
      noticeTime = 2.5;
      switch (item.kind) {
        case 0:
          hp = math.min(maxHp, hp + maxHp * .2);
          pickupNotice = '선체 20% 회복';
        case 1:
          _attractCrystals();
          pickupNotice = '자석 · 주변 경험치 회수';
          magnetPulse = 1.1;
        case 2:
          for (final e in enemies) {
            if ((e.position - position).distance <= 220 + e.radius) {
              _hit(e, e.kind == 3 ? e.maxHp * .025 : 240, 'bomb');
            }
          }
          pickupNotice = '충격파 · 군집 소탕';
        case 7:
          pickupNotice = dropGrowthStep('gun')
              ? '총알 강화 · ${growthPlans[planKey('gun')]!.name}'
              : '총알 최대 강화';
        case 8:
          final missile = nextMissileGrowth;
          pickupNotice = missile != null && dropGrowthStep(missile)
              ? '미사일 강화 · ${growthPlans[planKey(missile)]!.name}'
              : '미사일 최대 강화';
        case 9:
          // Mid-boss supply: both drop weapons grow, the hull is patched and
          // every gem on screen flies in.
          final gun = dropGrowthStep('gun');
          final missile = nextMissileGrowth;
          final fish = missile != null && dropGrowthStep(missile);
          hp = math.min(maxHp, hp + maxHp * .25);
          _attractCrystals();
          magnetPulse = 1.1;
          pickupNotice = gun || fish
              ? '중간 보스 보급 · ${[if (gun) '총알', if (fish) '미사일'].join('·')} 강화 · 회복'
              : '중간 보스 보급 · 선체 25% 회복';
          _event('level');
        case 4:
          _mainPickup(0);
        case 5:
          _mainPickup(1);
        case 6:
          _mainPickup(2);
        case 3:
          chests++;
          final ready = upgrades.keys.where(canEvolve).toList();
          if (ready.length > 1) {
            choices = [
              for (final id in ready)
                UpgradeChoice(
                  id,
                  skillFor(id).evolution!,
                  '보스 보급 · 원하는 진화를 선택하세요',
                  id,
                  evolution: true,
                ),
            ];
            chestSelection = true;
            input = Offset.zero;
            pickupNotice = '보스 보급 · 진화 선택';
            _event('level');
            return;
          } else if (ready.isNotEmpty) {
            _evolve(ready.first);
            pickupNotice = '보스 보급 · ${skillFor(ready.first).evolution}';
          } else {
            final available = upgrades.keys
                .where((id) => upgrades[id]! < 5)
                .toList();
            if (unifiedModules) {
              pickupNotice = freeGrowthStep()
                  ? '보스 보급 · 무기 성장 1단계'
                  : '보스 보급 · 선체 회복';
              if (pickupNotice.endsWith('회복')) {
                hp = math.min(maxHp, hp + maxHp * .3);
              }
            } else if (available.isNotEmpty) {
              final id = available[random.nextInt(available.length)];
              upgrades[id] = upgrades[id]! + 1;
              pickupNotice = '보스 보급 · ${combatSkill(id).name} 강화';
            } else {
              hp = math.min(maxHp, hp + maxHp * .3);
              pickupNotice = '보스 보급 · 선체 회복';
            }
          }
          _event('level');
      }
    }
    _consolidateCrystals();
  }

  void _consolidateCrystals() {
    // Actor pressure merges physical value; leaving gems behind never grants XP.
    if (crystals.length > crystalLimit) {
      final count = crystals.length - crystalLimit + 1;
      final at = crystals.first;
      var value = 0.0;
      for (var i = 0; i < count; i++) {
        value += ExperienceCrystal.valueOf(crystals[i]);
      }
      crystals.removeRange(0, count);
      crystals.insert(0, ExperienceCrystal.at(at, value));
    }
  }
}
