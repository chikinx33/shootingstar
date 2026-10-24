import 'dart:math' as math;

import 'content_catalog.dart';
import 'gear_traits.dart';
import 'collection_book.dart';
import 'fleet_journal.dart';
import 'run_rewards.dart';
import 'daily_challenge.dart';
import 'advanced_equipment.dart';
import 'pet_bond.dart';

mixin ContentSystems {
  bool get developerMode => false;
  int get credits;
  set credits(int value);
  int get blueprints;
  set blueprints(int value);
  void contentChanged();
  CollectionBook collections = CollectionBook();
  FleetJournal journal = FleetJournal();
  DailyChallengeBook dailyChallenge = DailyChallengeBook();
  AdvancedEquipment advancedEquipment = AdvancedEquipment();
  PetBond petBond = PetBond();
  Set<int> get presetProtectedGearIds;
  Set<int> get protectedGearIds => {
    ...presetProtectedGearIds,
    for (final g in inventory)
      if (advancedEquipment.isProtected(g.id)) g.id,
  };
  AdvancedBonuses get advancedBonuses => advancedEquipment.bonuses(
    equippedGear.map((id) => item(id)).whereType<GearItem>(),
  );
  List<GearItem> inventory = List.generate(6, (i) => GearItem(i + 1, i * 2));
  List<int> equippedGear = List.generate(6, (i) => i + 1);
  List<int> gearCopies = List.filled(
    6,
    0,
  ); // Unspent v2 parts, converted explicitly.
  int nextItemId = 7, gearKeys = 1, techKeys = 1, petEggs = 1, petFood = 30;
  int supplySerial = 0, petSerial = 1, techSerial = 0, dropSerial = 0;
  List<int> petLevels = [1, 0, 0], petRanks = [0, 0, 0], petShards = [0, 0, 0];
  int activePet = 0;
  Set<int> assistingPets = {};
  List<List<int>> techStock = List.generate(8, (_) => List.filled(6, 0));
  Set<int> equippedTech = {};
  String dayKey = '', seasonKey = '';
  int lastClock = 0,
      lastPatrol = 0,
      seasonXp = 0,
      dailyRuns = 0,
      dailyKills = 0,
      dailyUpgrades = 0;
  Set<int> dailyClaims = {}, seasonClaims = {};
  Map<String, int> shopCounts = {};
  List<RewardMail> mail = [];
  Set<String> receivedServerRewards = {};
  String guildToken = '', guildNickname = '';
  List<Map<String, dynamic>> guildReports = [];
  String lastLoot = '';
  int salvageSeconds = 0;
  bool starterTechUnlocked = false, starterTechClaimed = false;
  bool claimStarterTech(int id) {
    if (!starterTechUnlocked || starterTechClaimed || id < 0 || id >= 8) {
      return false;
    }
    techStock[id][2]++;
    starterTechClaimed = true;
    if (equippedTech.where((t) => (t < 4) == (id < 4)).length < 3) {
      equippedTech.add(id);
    }
    contentChanged();
    return true;
  }

  GearItem? item(int id) {
    for (final value in inventory) {
      if (value.id == id) return value;
    }
    return null;
  }

  GearItem gearAt(int slot) => item(equippedGear[slot])!;
  List<int> get gearSpecs => List.generate(6, (slot) {
    final g = slot < equippedGear.length ? item(equippedGear[slot]) : null;
    return g != null && g.definition.slot == slot ? g.spec : slot * 2;
  });
  List<int> get gearRanks => List.generate(6, (i) => gearAt(i).rank);
  List<int> get gearLevels => List.generate(6, (i) => gearAt(i).level);
  double get gearDamage =>
      List.generate(
        3,
        (i) => gearBaseContribution(gearAt(i)),
      ).fold(0.0, (a, b) => a + b) +
      collections.damageBonus +
      advancedBonuses.damage;
  double get gearHull =>
      List.generate(
        3,
        (i) => gearBaseContribution(gearAt(i + 3)),
      ).fold(0.0, (a, b) => a + b) +
      collections.hullBonus +
      advancedBonuses.hull;
  String get startingWeapon => gearAt(0).definition.weapon;
  double get gearSpeed => gearAt(5).spec == 10 ? .03 * (gearAt(5).rank + 1) : 0;
  double get gearPickup =>
      (gearAt(1).spec == 3 ? .1 * (gearAt(1).rank + 1) : 0) +
      (gearAt(5).spec == 11 ? .08 * (gearAt(5).rank + 1) : 0) +
      (assistingPets.contains(1) ? .1 : 0) +
      collections.pickupBonus +
      advancedBonuses.pickup;
  double get gearCooldown =>
      (gearAt(2).spec == 5 ? .02 * (gearAt(2).rank + 1) : 0) +
      (assistingPets.contains(0) ? .04 : 0) +
      collections.cooldownBonus;
  double get gearReduction =>
      (gearAt(4).spec == 8 ? .02 * (gearAt(4).rank + 1) : 0) +
      (assistingPets.contains(2) ? .05 : 0);
  bool get gearRegeneration => gearAt(3).spec == 7;
  int get equippedPetLevel => activePet < 0 ? 0 : petLevels[activePet];
  int get equippedPetRank => activePet < 0 ? 0 : petRanks[activePet];
  Map<String, int> get battleTech => {
    for (final t in equippedTech) techWeapons[t]: techRank(t),
  };
  bool get mainPrecisionLink =>
      equippedTech.contains(0) &&
      techRank(0) >= 2 &&
      gearAt(1).spec == 2 &&
      gearAt(1).rank >= 1;
  bool get mainCycleLink =>
      equippedTech.contains(0) &&
      techRank(0) >= 2 &&
      gearAt(2).spec == 5 &&
      gearAt(2).rank >= 1;
  int get activeBossSetWorld {
    final hull = gearAt(3), thruster = gearAt(5);
    final world = hull.definition.bossWorld;
    return world >= 0 &&
            hull.id != thruster.id &&
            hull.definition.slot == 3 &&
            thruster.definition.slot == 5 &&
            hull.rank >= 2 &&
            thruster.rank >= 2 &&
            thruster.definition.bossWorld == world
        ? world
        : -1;
  }

  bool equipItem(int id) {
    final g = item(id);
    if (g == null) return false;
    equippedGear[g.definition.slot] = id;
    contentChanged();
    return true;
  }

  bool lockItem(int id) {
    final g = item(id);
    if (g == null) return false;
    g.locked = !g.locked;
    contentChanged();
    return true;
  }

  bool _commitAdvanced(AdvancedChange? change) {
    if (change == null) return false;
    credits -= change.creditsCost;
    blueprints -= change.plansCost;
    inventory.removeWhere((g) => change.consumedIds.contains(g.id));
    inventory.addAll(change.returnedItems);
    nextItemId = math.max(nextItemId, advancedEquipment.highestReservedId + 1);
    lastLoot = change.creditsCost < 0
        ? '고급 성장 초기화 · 사용 재화와 재료 반환'
        : '고급 장비 성장 완료';
    contentChanged();
    return true;
  }

  bool refineEquipment(int id, int mode) {
    refreshContentClock(DateTime.now());
    final g = item(id);
    return g != null &&
        _commitAdvanced(
          advancedEquipment.refine(
            target: g,
            credits: credits,
            plans: blueprints,
            mode: mode,
          ),
        );
  }

  bool chooseEquipmentMode(int id, int mode) {
    if (item(id) == null || !advancedEquipment.chooseMode(id, mode)) {
      return false;
    }
    lastLoot = '정밀 조정 성향 · ${AdvancedEquipment.modeNames[mode]}';
    contentChanged();
    return true;
  }

  List<GearItem> advancedMaterialCandidates(int id) {
    final g = item(id);
    return g == null
        ? []
        : advancedEquipment.candidates(
            target: g,
            inventory: inventory,
            equipped: equippedGear,
            protectedIds: presetProtectedGearIds,
          );
  }

  bool ascendEquipment(int id, List<int> materialIds) {
    refreshContentClock(DateTime.now());
    final g = item(id);
    return g != null &&
        _commitAdvanced(
          advancedEquipment.ascend(
            target: g,
            inventory: inventory,
            equipped: equippedGear,
            protectedIds: presetProtectedGearIds,
            materialIds: materialIds,
            credits: credits,
            plans: blueprints,
          ),
        );
  }

  bool resetAdvancedEquipment(int id) {
    final record = advancedEquipment.entry(id);
    if (record == null ||
        credits + record.spentCredits > 9999999 ||
        blueprints + record.spentPlans > 999999) {
      return false;
    }
    return _commitAdvanced(
      advancedEquipment.reset(targetId: id, inventory: inventory),
    );
  }

  bool giftPet(int id, {DateTime? now}) {
    refreshContentClock(now ?? DateTime.now());
    if (id < 0 ||
        id >= 3 ||
        !petBond.gift(
          id,
          unlocked: petLevels[id] > 0,
          food: petFood,
          now: DateTime.fromMillisecondsSinceEpoch(lastClock, isUtc: true),
        )) {
      return false;
    }
    petFood -= 10;
    lastLoot = '${petNames[id]} · 호감도 +10';
    contentChanged();
    return true;
  }

  bool awakenPet(int id) {
    refreshContentClock(DateTime.now());
    if (id < 0 || id >= 3) return false;
    final cost = petBond.awaken(
      id,
      petLevel: petLevels[id],
      petRank: petRanks[id],
      credits: credits,
      food: petFood,
      shards: petShards[id],
    );
    if (cost == null) return false;
    credits -= cost.credits;
    petFood -= cost.food;
    petShards[id] -= cost.shards;
    lastLoot = '${petNames[id]} · 각성 ${petBond.awakening[id]}단계';
    contentChanged();
    return true;
  }

  bool selectPetAwakeSkill(int id, int skill) {
    if (id < 0 ||
        id >= 3 ||
        petLevels[id] <= 0 ||
        !petBond.selectSkill(id, skill)) {
      return false;
    }
    lastLoot = '${petNames[id]} · 각성 기술 변경';
    contentChanged();
    return true;
  }

  bool resetPetAwakening(int id) {
    if (id < 0 || id >= 3) return false;
    final refund = petBond.resetRefund(id);
    if (refund == null ||
        credits + refund.credits > 9999999 ||
        petFood + refund.food > 999999 ||
        petShards[id] + refund.shards > 9999) {
      return false;
    }
    petBond.reset(id);
    credits += refund.credits;
    petFood += refund.food;
    petShards[id] += refund.shards;
    lastLoot = '${petNames[id]} · 각성 초기화 및 사용 재료 반환';
    contentChanged();
    return true;
  }

  int itemUpgradeCost(GearItem g) => 30 + g.level * 20;
  bool enhanceItem(int id) {
    refreshContentClock(DateTime.now());
    final g = item(id);
    if (g == null ||
        g.level >= 20 + g.rank * 10 ||
        blueprints < 1 ||
        credits < itemUpgradeCost(g)) {
      return false;
    }
    final cost = itemUpgradeCost(g);
    credits -= cost;
    blueprints--;
    g.spentCredits += cost;
    g.spentPlans++;
    g.level++;
    dailyUpgrades++;
    contentChanged();
    return true;
  }

  bool enhanceGear(int slot) =>
      slot >= 0 && slot < 6 && enhanceItem(equippedGear[slot]);
  List<GearItem> mergeMaterials(GearItem g) => inventory
      .where(
        (m) =>
            m.id != g.id &&
            m.spec == g.spec &&
            m.rank == g.rank &&
            !m.locked &&
            !equippedGear.contains(m.id) &&
            m.level == 0 &&
            !protectedGearIds.contains(m.id),
      )
      .take(2)
      .toList();
  bool mergeItem(int id) {
    refreshContentClock(DateTime.now());
    final g = item(id);
    if (g == null || g.rank >= 5) return false;
    final materials = mergeMaterials(g);
    if (materials.length != 2) return false;
    final ids = materials.map((m) => m.id).toSet();
    inventory.removeWhere((m) => ids.contains(m.id));
    g.rank++;
    dailyUpgrades++;
    contentChanged();
    return true;
  }

  bool mergeGear(int slot) =>
      slot >= 0 && slot < 6 && mergeItem(equippedGear[slot]);
  bool resetItem(int id) {
    final g = item(id);
    if (g == null || g.level == 0) return false;
    credits += g.spentCredits;
    blueprints += g.spentPlans;
    g.level = 0;
    g.spentCredits = 0;
    g.spentPlans = 0;
    contentChanged();
    return true;
  }

  GearItem? grantItem(int spec, {int rank = 0}) {
    if (inventory.length >= 240 || spec < 0 || spec >= gearCatalog.length) {
      return null;
    }
    final g = GearItem(nextItemId++, spec, rank: rank.clamp(0, 5));
    inventory.add(g);
    return g;
  }

  bool convertLegacyPart(int slot) {
    if (slot < 0 ||
        slot >= 6 ||
        gearCopies[slot] == 0 ||
        inventory.length >= 240) {
      return false;
    }
    gearCopies[slot]--;
    grantItem(slot * 2);
    contentChanged();
    return true;
  }

  bool openGearSupply() {
    if (gearKeys < 1 || inventory.length >= 240) return false;
    final serial = supplySerial++;
    final rank = (serial + 1) % 10 == 0
        ? 3
        : (serial + 1) % 3 == 0
        ? 1
        : 0;
    final g = grantItem(serial % 12, rank: rank)!;
    gearKeys--;
    lastLoot = '${qualityNames[g.rank]} ${g.definition.name} 획득';
    contentChanged();
    return true;
  }

  int techRank(int id) {
    if (id < 0 || id >= 8) return -1;
    for (int r = 5; r >= 0; r--) {
      if (techStock[id][r] > 0) return r;
    }
    return -1;
  }

  bool openTechSupply() {
    if (techKeys < 1) return false;
    final id = techSerial++ % 8;
    techKeys--;
    techStock[id][0]++;
    lastLoot = '${techNames[id]} 획득';
    contentChanged();
    return true;
  }

  bool equipTech(int id) {
    if (techRank(id) < 0) return false;
    if (equippedTech.contains(id)) {
      equippedTech.remove(id);
    } else {
      if (equippedTech.where((t) => (t < 4) == (id < 4)).length >= 3) {
        return false;
      }
      equippedTech.add(id);
    }
    contentChanged();
    return true;
  }

  bool mergeTech(int id, int rank) {
    refreshContentClock(DateTime.now());
    if (id < 0 || id >= 8 || rank < 0 || rank >= 5 || techStock[id][rank] < 3) {
      return false;
    }
    techStock[id][rank] -= 3;
    techStock[id][rank + 1]++;
    dailyUpgrades++;
    contentChanged();
    return true;
  }

  bool rescuePet() {
    if (petEggs < 1) return false;
    final id = petSerial++ % 3;
    petEggs--;
    if (petLevels[id] == 0) {
      petLevels[id] = 1;
      lastLoot = '${petNames[id]} 구조 완료';
    } else {
      petShards[id]++;
      lastLoot = '${petNames[id]} 유전자 +1';
    }
    contentChanged();
    return true;
  }

  bool deployPet(int id) {
    if (id < 0 || id >= 3 || petLevels[id] == 0) return false;
    activePet = id;
    assistingPets.remove(id);
    contentChanged();
    return true;
  }

  bool assistPet(int id) {
    if (id < 0 || id >= 3 || petLevels[id] == 0 || id == activePet) {
      return false;
    }
    if (!assistingPets.remove(id)) {
      if (assistingPets.length >= 2) return false;
      assistingPets.add(id);
    }
    contentChanged();
    return true;
  }

  bool feedPet(int id) {
    refreshContentClock(DateTime.now());
    if (id < 0 ||
        id >= 3 ||
        petLevels[id] == 0 ||
        petLevels[id] >= 20 + petRanks[id] * 10 ||
        petFood < petLevels[id] * 10) {
      return false;
    }
    petFood -= petLevels[id] * 10;
    petLevels[id]++;
    dailyUpgrades++;
    contentChanged();
    return true;
  }

  bool evolvePet(int id) {
    refreshContentClock(DateTime.now());
    if (id < 0 ||
        id >= 3 ||
        petLevels[id] == 0 ||
        petRanks[id] >= 5 ||
        petShards[id] < 3 * (petRanks[id] + 1)) {
      return false;
    }
    petShards[id] -= 3 * (petRanks[id] + 1);
    petRanks[id]++;
    dailyUpgrades++;
    contentChanged();
    return true;
  }

  static DateTime seoul(DateTime date) =>
      date.toUtc().add(const Duration(hours: 9));
  static String dayOf(DateTime date) =>
      seoul(date).toIso8601String().substring(0, 10);
  bool refreshContentClock(DateTime now) {
    final millis = math.max(lastClock, now.toUtc().millisecondsSinceEpoch);
    final safe = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    final day = dayOf(safe), season = day.substring(0, 7);
    bool changed = false;
    if (lastPatrol == 0) {
      lastPatrol = millis;
      changed = true;
    }
    if (seasonKey != season) {
      if (seasonKey.isNotEmpty) {
        for (int t = 1; t <= math.min(20, seasonXp ~/ 100); t++) {
          if (!seasonClaims.contains(t)) {
            mail.add(seasonReward(seasonKey, t));
          }
        }
      }
      seasonKey = season;
      seasonXp = 0;
      seasonClaims.clear();
      changed = true;
    }
    if (dayKey != day) {
      dayKey = day;
      dailyRuns = 0;
      dailyKills = 0;
      dailyUpgrades = 0;
      dailyClaims.clear();
      shopCounts.clear();
      changed = true;
    }
    if (journal.advance(safe)) changed = true;
    if (dailyChallenge.advance(safe)) changed = true;
    if (petBond.advance(safe)) changed = true;
    lastClock = millis;
    return changed;
  }

  /// Apply only a claim already accepted by the bounded journal ledger.
  bool _deliverFleet(FleetReward? reward) {
    if (reward == null) return false;
    credits = (credits + reward.credits).clamp(0, 9999999);
    blueprints = (blueprints + reward.plans).clamp(0, 999999);
    petFood = (petFood + reward.food).clamp(0, 999999);
    gearKeys = (gearKeys + reward.gearKeys).clamp(0, 99999);
    techKeys = (techKeys + reward.techKeys).clamp(0, 99999);
    petEggs = (petEggs + reward.eggs).clamp(0, 99999);
    collections.keys = (collections.keys + reward.collectionKeys).clamp(
      0,
      99999,
    );
    lastLoot = reward.summary;
    contentChanged();
    return true;
  }

  bool exchangeDailyChallenge(int id) {
    refreshContentClock(DateTime.now());
    return _deliverFleet(dailyChallenge.exchange(id));
  }

  bool claimSignIn({DateTime? now}) {
    refreshContentClock(now ?? DateTime.now());
    return _deliverFleet(journal.claimSignIn());
  }

  bool claimSignInChest(int id, {DateTime? now}) {
    refreshContentClock(now ?? DateTime.now());
    return _deliverFleet(journal.claimSignInChest(id));
  }

  bool claimDailyActivity(int id, {DateTime? now}) {
    refreshContentClock(now ?? DateTime.now());
    return _deliverFleet(journal.claimDailyChest(id, dailyClaims.length));
  }

  bool claimWeeklyMission(int id, {DateTime? now}) {
    refreshContentClock(now ?? DateTime.now());
    return _deliverFleet(journal.claimWeekly(id));
  }

  bool claimWeeklyActivity(int id, {DateTime? now}) {
    refreshContentClock(now ?? DateTime.now());
    return _deliverFleet(journal.claimWeeklyChest(id));
  }

  bool claimQuickPatrol({DateTime? now}) {
    refreshContentClock(now ?? DateTime.now());
    return _deliverFleet(journal.claimQuickPatrol(dailyRuns));
  }

  bool claimChapterMilestone(
    int stage,
    int milestone,
    int duration,
    Set<int> legacyClears,
  ) {
    return _deliverFleet(
      journal.claimChapter(stage, milestone, duration, legacyClears),
    );
  }

  int seasonDaysLeft(DateTime now) {
    final date = seoul(now);
    return DateTime.utc(
      date.year,
      date.month + 1,
    ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
  }

  RewardMail seasonReward(String season, int tier) => RewardMail(
    'season-$season-$tier',
    '시즌 $season · $tier 단계',
    credits: 50 + tier * 10,
    plans: 1,
    food: 10,
    gearKeys: tier % 2 == 0 ? 1 : 0,
    techKeys: tier % 3 == 0 ? 1 : 0,
    eggs: tier % 5 == 0 ? 1 : 0,
  );
  void _deliver(RewardMail r) {
    credits += r.credits;
    blueprints += r.plans;
    petFood += r.food;
    gearKeys += r.gearKeys;
    techKeys += r.techKeys;
    petEggs += r.eggs;
    r.claimed = true;
  }

  bool claimSeason(int tier) {
    refreshContentClock(DateTime.now());
    if (tier < 1 ||
        tier > 20 ||
        seasonXp < tier * 100 ||
        seasonClaims.contains(tier)) {
      return false;
    }
    seasonClaims.add(tier);
    final r = seasonReward(seasonKey, tier);
    _deliver(r);
    lastLoot = r.summary;
    contentChanged();
    return true;
  }

  bool claimMail(String id) {
    final list = mail.where((m) => m.id == id && !m.claimed);
    if (list.isEmpty) return false;
    final r = list.first;
    _deliver(r);
    lastLoot = r.summary;
    contentChanged();
    return true;
  }

  int dailyProgress(int id) => switch (id) {
    0 => dailyRuns,
    1 => dailyKills,
    2 => dailyUpgrades,
    _ => 0,
  };
  static const dailyTargets = [1, 100, 1],
      dailyNames = ['출격 1회 완수', '군집 100기 격파', '장비·펫·테크 성장 1회'];
  bool claimDaily(int id) {
    refreshContentClock(DateTime.now());
    if (id < 0 ||
        id >= 3 ||
        dailyClaims.contains(id) ||
        dailyProgress(id) < dailyTargets[id]) {
      return false;
    }
    dailyClaims.add(id);
    seasonXp += 50;
    credits += 50;
    petFood += 10;
    if (id == 0) gearKeys++;
    if (id == 1) techKeys++;
    if (id == 2) petEggs++;
    contentChanged();
    return true;
  }

  int patrolMinutes(DateTime now) =>
      ((math.max(lastClock, now.toUtc().millisecondsSinceEpoch) - lastPatrol) ~/
              60000)
          .clamp(0, 480);
  bool claimPatrol(DateTime now) {
    refreshContentClock(now);
    final minutes = patrolMinutes(now);
    if (minutes < 30) return false;
    credits += minutes ~/ 30 * 20;
    blueprints += minutes ~/ 60;
    petFood += minutes ~/ 60 * 5;
    lastPatrol = math.max(lastClock, now.toUtc().millisecondsSinceEpoch);
    lastLoot = '순찰 ${minutes ~/ 60}시간 ${minutes % 60}분 보상 회수';
    contentChanged();
    return true;
  }

  bool buyMaterial(String kind) {
    refreshContentClock(DateTime.now());
    final cost = switch (kind) {
      'food' => 60,
      'plans' => 100,
      'gear' => 180,
      'tech' => 180,
      'egg' => 200,
      _ => 0,
    };
    if (cost == 0 ||
        credits < cost ||
        (!developerMode && (shopCounts[kind] ?? 0) >= 3) ||
        (kind == 'gear' && inventory.length >= 240)) {
      return false;
    }
    credits -= cost;
    shopCounts[kind] = (shopCounts[kind] ?? 0) + 1;
    switch (kind) {
      case 'food':
        petFood += 30;
      case 'plans':
        blueprints += 3;
      case 'gear':
        gearKeys++;
      case 'tech':
        techKeys++;
      case 'egg':
        petEggs++;
    }
    contentChanged();
    return true;
  }

  void recordContentRun({
    required String runId,
    required int kills,
    required int seconds,
    required bool victory,
    int bossesDefeated = 0,
    int? stageIndex,
    bool challenge = false,
  }) {
    refreshContentClock(DateTime.now());
    if (seconds < 30 || kills < 10) return;
    if (stageIndex != null) {
      journal.recordRun(
        stage: stageIndex,
        seconds: seconds,
        kills: kills,
        bosses: bossesDefeated,
        victory: victory,
        challenge: challenge,
      );
    }
    final payout = RunRewards(
      seconds: seconds,
      kills: kills,
      bosses: bossesDefeated.clamp(0, 3),
      victory: victory,
    );
    salvageSeconds += seconds;
    final caches = salvageSeconds ~/ 120 + payout.bonusCaches;
    salvageSeconds %= 120;
    if (seconds >= 120 || bossesDefeated > 0 || victory) dailyRuns++;
    dailyKills += kills;
    seasonXp +=
        seconds ~/ 6 +
        math.min<int>(80, kills ~/ 20) +
        bossesDefeated.clamp(0, 3) * 20 +
        (victory ? 50 : 0);
    petFood += caches * 10;
    blueprints += caches;
    for (int n = 0; n < caches; n++) {
      final dropped = grantItem((dropSerial++) % 12);
      if (dropped == null) gearKeys++;
      techStock[(techSerial++) % 8][0]++;
    }
    if (victory) {
      gearKeys++;
      petEggs++;
    }
    lastLoot = caches > 0
        ? '회수 보급 $caches개 · 장비/테크 각 $caches · 별가루 $caches · 먹이 ${caches * 10}'
        : '회수 진행 $salvageSeconds / 120초 · 다음 출격으로 이어집니다';
    if (victory) lastLoot += ' · 장비권 1 · 펫권 1';
    if (guildToken.isNotEmpty && guildReports.length < 30) {
      guildReports.add({'runId': runId, 'kills': kills, 'seconds': seconds});
    }
  }

  bool acceptServerReward(Map<String, dynamic> data) {
    final id = data['id'];
    if (id is! String ||
        id.length > 160 ||
        receivedServerRewards.contains(id)) {
      return false;
    }
    final reward = RewardMail.restore({
      ...data,
      'title': data['title'] ?? '길드 보상',
    });
    if (reward == null) return false;
    receivedServerRewards.add(id);
    mail.add(reward);
    contentChanged();
    return true;
  }

  Map<String, dynamic> contentSnapshot() => {
    'progressionVersion': 1,
    'advancedProgressionVersion': 1,
    'dailyChallenge': dailyChallenge.toJson(),
    'advancedEquipment': advancedEquipment.toJson(),
    'petBond': petBond.toJson(),
    'collections': collections.toJson(),
    'journal': journal.toJson(),
    'salvageSeconds': salvageSeconds,
    'starterTechUnlocked': starterTechUnlocked,
    'starterTechClaimed': starterTechClaimed,
    'inventory': inventory.map((g) => g.toJson()).toList(),
    'equippedGear': equippedGear,
    'nextItemId': nextItemId,
    'legacyParts': gearCopies,
    'gearKeys': gearKeys,
    'techKeys': techKeys,
    'petEggs': petEggs,
    'petFood': petFood,
    'dropSerial': dropSerial,
    'supplySerial': supplySerial,
    'techSerial': techSerial,
    'petSerial': petSerial,
    'petLevels': petLevels,
    'petRanks': petRanks,
    'petShards': petShards,
    'activePet': activePet,
    'assistingPets': assistingPets.toList(),
    'techStock': techStock,
    'equippedTech': equippedTech.toList(),
    'dayKey': dayKey,
    'seasonKey': seasonKey,
    'lastClock': lastClock,
    'lastPatrol': lastPatrol,
    'seasonXp': seasonXp,
    'dailyRuns': dailyRuns,
    'dailyKills': dailyKills,
    'dailyUpgrades': dailyUpgrades,
    'dailyClaims': dailyClaims.toList(),
    'seasonClaims': seasonClaims.toList(),
    'shopCounts': shopCounts,
    'mail': mail.map((m) => m.toJson()).toList(),
    'receivedServerRewards': receivedServerRewards.toList(),
    'guildToken': guildToken,
    'guildNickname': guildNickname,
    'guildReports': guildReports,
  };
  void restoreContent(Map<String, dynamic> root) {
    salvageSeconds = 0;
    starterTechUnlocked = false;
    starterTechClaimed = false;
    final raw = root['content'];
    dailyChallenge = DailyChallengeBook.restore(
      raw is Map ? raw['dailyChallenge'] : null,
    );
    petBond = PetBond.restore(raw is Map ? raw['petBond'] : null);
    advancedEquipment = AdvancedEquipment();
    collections = CollectionBook.restore(
      raw is Map ? raw['collections'] : null,
    );
    journal = FleetJournal.restore(raw is Map ? raw['journal'] : null);
    if (raw is! Map) {
      final ranks = root['gearRanks'],
          levels = root['gearLevels'],
          copies = root['gearCopies'];
      for (int i = 0; i < 6; i++) {
        final g = inventory[i];
        g.rank = ranks is List && i < ranks.length
            ? boundedInt(ranks[i], 0, 5)
            : 0;
        g.level = levels is List && i < levels.length
            ? boundedInt(levels[i], 0, 70)
            : 0;
        g.spentPlans = g.level;
        g.spentCredits = g.level * 30 + 10 * g.level * (g.level - 1);
        gearCopies[i] = copies is List && i < copies.length
            ? boundedInt(copies[i], 0, 9999)
            : 0;
      }
      return;
    }
    final v = raw;
    salvageSeconds = boundedInt(v['salvageSeconds'], 0, 119);
    starterTechUnlocked = v['starterTechUnlocked'] == true;
    starterTechClaimed = v['starterTechClaimed'] == true;
    List<int> ints(String key, int n, int max, List<int> defaults) {
      final a = v[key];
      return List.generate(
        n,
        (i) => a is List && i < a.length
            ? boundedInt(a[i], defaults[i], max)
            : defaults[i],
      );
    }

    if (v['inventory'] is List) {
      final ids = <int>{};
      final restored = <GearItem>[];
      for (final row in (v['inventory'] as List).take(
        developerMode ? 2400 : 240,
      )) {
        final g = GearItem.restore(row);
        if (g != null && ids.add(g.id)) restored.add(g);
      }
      if (restored.isNotEmpty) inventory = restored;
    }
    advancedEquipment = AdvancedEquipment.restore(
      v['advancedEquipment'],
      inventory: inventory,
    );
    nextItemId =
        math.max(
          inventory.map((g) => g.id).fold(0, math.max),
          advancedEquipment.highestReservedId,
        ) +
        1;
    final equip = ints('equippedGear', 6, 100000000, List.filled(6, 0));
    for (int slot = 0; slot < 6; slot++) {
      var candidate = item(equip[slot]);
      if (candidate == null || candidate.definition.slot != slot) {
        final options = inventory.where((g) => g.definition.slot == slot);
        candidate = options.isNotEmpty
            ? options.first
            : GearItem(nextItemId++, slot * 2);
        if (!inventory.contains(candidate)) inventory.add(candidate);
      }
      equippedGear[slot] = candidate.id;
    }
    gearCopies = ints('legacyParts', 6, 9999, List.filled(6, 0));
    gearKeys = boundedInt(v['gearKeys'], 1, 99999);
    techKeys = boundedInt(v['techKeys'], 1, 99999);
    petEggs = boundedInt(v['petEggs'], 1, 99999);
    petFood = boundedInt(v['petFood'], 30, 999999);
    supplySerial = boundedInt(v['supplySerial'], 0, 9999999);
    techSerial = boundedInt(v['techSerial'], 0, 9999999);
    petSerial = boundedInt(v['petSerial'], 1, 9999999);
    dropSerial = boundedInt(v['dropSerial'], 0, 9999999);
    petLevels = ints('petLevels', 3, 70, [1, 0, 0]);
    petRanks = ints('petRanks', 3, 5, [0, 0, 0]);
    petShards = ints('petShards', 3, 9999, [0, 0, 0]);
    activePet = boundedInt(v['activePet'], 0, 2);
    if (petLevels[activePet] == 0) {
      activePet = petLevels.indexWhere((l) => l > 0);
    }
    if (v['assistingPets'] is List) {
      assistingPets = (v['assistingPets'] as List)
          .whereType<int>()
          .where((i) => i >= 0 && i < 3 && i != activePet && petLevels[i] > 0)
          .take(2)
          .toSet();
    }
    final tech = v['techStock'];
    techStock = List.generate(
      8,
      (i) => List.generate(
        6,
        (r) =>
            tech is List &&
                i < tech.length &&
                tech[i] is List &&
                r < (tech[i] as List).length
            ? boundedInt(tech[i][r], 0, 9999)
            : 0,
      ),
    );
    if (v['equippedTech'] is List) {
      for (final id in (v['equippedTech'] as List).whereType<int>()) {
        if (techRank(id) >= 0 &&
            equippedTech.where((t) => (t < 4) == (id < 4)).length < 3) {
          equippedTech.add(id);
        }
      }
    }
    dayKey = v['dayKey'] is String ? v['dayKey'] : '';
    seasonKey = v['seasonKey'] is String ? v['seasonKey'] : '';
    // Reject far-future corrupted clocks while still preventing ordinary rollback farming.
    final ceiling = DateTime.now()
        .toUtc()
        .add(const Duration(days: 2))
        .millisecondsSinceEpoch;
    lastClock = boundedInt(v['lastClock'], 0, ceiling);
    lastPatrol = boundedInt(v['lastPatrol'], 0, ceiling);
    seasonXp = boundedInt(v['seasonXp'], 0, 999999);
    dailyRuns = boundedInt(v['dailyRuns'], 0, 9999);
    dailyKills = boundedInt(v['dailyKills'], 0, 999999);
    dailyUpgrades = boundedInt(v['dailyUpgrades'], 0, 99999);
    if (v['dailyClaims'] is List) {
      dailyClaims = (v['dailyClaims'] as List)
          .whereType<int>()
          .where((i) => i >= 0 && i < 3)
          .toSet();
    }
    if (v['seasonClaims'] is List) {
      seasonClaims = (v['seasonClaims'] as List)
          .whereType<int>()
          .where((i) => i >= 1 && i <= 20)
          .toSet();
    }
    if (v['shopCounts'] is Map) {
      for (final key in ['food', 'plans', 'gear', 'tech', 'egg']) {
        shopCounts[key] = boundedInt(v['shopCounts'][key], 0, 3);
      }
    }
    if (v['mail'] is List) {
      final ids = <String>{};
      mail = (v['mail'] as List)
          .map(RewardMail.restore)
          .whereType<RewardMail>()
          .where((m) => ids.add(m.id))
          .toList();
    }
    if (v['receivedServerRewards'] is List) {
      receivedServerRewards = (v['receivedServerRewards'] as List)
          .whereType<String>()
          .where((s) => s.length <= 160)
          .toSet();
    }
    guildToken =
        v['guildToken'] is String && (v['guildToken'] as String).length < 200
        ? v['guildToken']
        : '';
    guildNickname = v['guildNickname'] is String ? v['guildNickname'] : '';
    if (v['guildReports'] is List) {
      guildReports = (v['guildReports'] as List)
          .whereType<Map>()
          .where(
            (r) =>
                r['runId'] is String &&
                r['kills'] is int &&
                r['seconds'] is int,
          )
          .take(30)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }
  }
}
