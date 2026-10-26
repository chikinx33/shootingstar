import 'dart:math' as math;
import 'dart:convert';

import '../game/engine.dart';
import 'flight_record.dart';

import 'package:flutter/foundation.dart';

import 'cat_gear.dart';
import 'guardian_quests.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';
import 'run_rewards.dart';
import 'cloud_sync.dart';
import '../services/commerce_controller.dart';
import 'content_systems.dart';
import 'hangar_preset.dart';
import 'daily_challenge.dart';
import 'armament_collection.dart';
import 'campaign_rewards.dart';
import 'fleet_journal.dart';
import 'shop_ledger.dart';
import 'boss_gear.dart';
import 'content_catalog.dart';
import 'control_preferences.dart';
import 'aircraft_assembly.dart';
import 'ship_modules.dart';

part 'module_profile.dart';
part 'developer_profile.dart';

class Profile extends ChangeNotifier with ContentSystems, ShopSystems {
  @override
  void contentChanged() {
    _syncAssemblyPets();
    _changed();
  }

  Profile._(this._prefs, {this.developerMode = false});
  @override
  final bool developerMode;
  static const developerStorageKey = 'shootingstar.developer.v1';
  Profile? developerSession, _developerOwner;
  bool _developerClosed = false;
  Map<String, dynamic> developerSettings = {};
  void _notifySessionChange() {
    if (!_disposed) notifyListeners();
  }

  /// Detached, memory-only copy. Never attach CloudSync to this profile.
  static Profile developerCopy(Profile source) {
    final copy = Profile._(null, developerMode: true)
      .._restore(jsonDecode(jsonEncode(source.exportProgress())));
    copy._unlockDeveloperContent();
    return copy;
  }

  /// Isolated animation rehearsal. No preferences, cloud client or developer
  /// owner is attached; successful demo transactions cannot persist anywhere.
  static Profile presentationCopy(Profile source) => Profile._(null)
    .._restore(jsonDecode(jsonEncode(source.exportProgress())))
    .._presentationOnly = true;

  bool _presentationOnly = false;
  final List<FlightRecord> _flightRecords = [];
  List<FlightRecord> get flightHistory => List.unmodifiable(_flightRecords);
  void recordFlight(String runId, GameEngine game) {
    if (developerMode ||
        _presentationOnly ||
        game.training ||
        !game.finished ||
        game.elapsed < 5 ||
        _processedRunIds.contains(runId) ||
        _flightRecords.any((r) => r.id == runId)) {
      return;
    }
    _flightRecords.insert(
      0,
      FlightRecord(
        id: runId,
        stage: game.stageIndex,
        loop: game.campaignLoop,
        armament: game.armament,
        level: game.level,
        kills: game.kills,
        seconds: game.elapsed.floor(),
        bosses: game.bossesDefeated,
        victory: game.victory,
        defeated: game.hp <= 0,
        cause: game.lastDamageSource,
        savedAt: DateTime.now().toUtc(),
        damage: game.damageByWeapon,
      ),
    );
    if (_flightRecords.length > 8) {
      _flightRecords.removeRange(8, _flightRecords.length);
    }
  }

  CloudSync? online;
  CommerceController? commerce;
  int _verifiedAdCredits = 0;
  ControlPreferences controls = const ControlPreferences();
  bool restoringBackup = false;
  bool get canExportProgressBackup => !developerMode && !_presentationOnly;
  static const manualBackupKey = '$storageKey.beforeManualRestore';

  static Map<String, dynamic> normalizeBackupProgress(
    Map<String, dynamic> value,
  ) {
    final copy = Profile._(null).._restore(value);
    copy.guildToken = '';
    copy.guildNickname = '';
    copy.guildReports.clear();
    copy._verifiedAdCredits = 0;
    return copy.exportProgress();
  }

  /// Normal play with device storage (not developer or presentation mode):
  /// runs are recorded and progress can be restored.
  bool get persistsProgress =>
      !developerMode && !_presentationOnly && _prefs != null;

  String? get backupRestoreBlock {
    if (!persistsProgress) return '일반 진행의 저장소를 사용할 수 있어야 복원할 수 있습니다.';
    if (online != null &&
        (!online!.ready ||
            online!.signedIn ||
            online!.boundId.isNotEmpty ||
            online!.busy ||
            online!.inBattle ||
            online!.conflict != null)) {
      return '계정 진행을 보호하기 위해 연결·동기화를 마치고 로그아웃한 게스트 상태에서 복원하세요.';
    }
    if (restoringBackup) return '진행 복원이 끝날 때까지 기다려 주세요.';
    return null;
  }

  Map<String, dynamic>? previousManualBackup() {
    final value = _prefs?.getString(manualBackupKey);
    try {
      final decoded = value == null ? null : jsonDecode(value);
      return decoded is Map<String, dynamic>
          ? normalizeBackupProgress(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Persist before changing live state. The previous snapshot is retained and
  /// a failed write leaves both the live profile and current saved game intact.
  Future<void> restoreGuestBackup(Map<String, dynamic> progress) async {
    final blocked = backupRestoreBlock;
    if (blocked != null) throw StateError(blocked);
    restoringBackup = true;
    String? previous;
    bool attemptedWrite = false;
    try {
      await _pendingSave;
      final original = jsonEncode(_snapshot(includeLocal: true));
      previous = original;
      final next = normalizeBackupProgress(progress);
      if (!await _prefs!.setString(manualBackupKey, original)) {
        throw StateError('현재 진행을 안전하게 보관하지 못해 복원을 중단했습니다.');
      }
      // Account/session changes or local edits during the first disk write
      // invalidate this operation. Never replace a moving target.
      restoringBackup = false;
      final moved =
          backupRestoreBlock != null ||
          original != jsonEncode(_snapshot(includeLocal: true));
      restoringBackup = true;
      if (moved) throw StateError('현재 진행이 바뀌었습니다. 다시 확인해 주세요.');
      attemptedWrite = true;
      if (!await _prefs.setString(storageKey, jsonEncode(next))) {
        throw StateError('기기 저장에 실패해 복원을 중단했습니다.');
      }
      _flightRecords.clear();
      claimedMissions.clear();
      clearedChallenges.clear();
      _processedRunIds.clear();
      equippedTech.clear();
      assistingPets.clear();
      _restore(next);
      saveError = null;
      _notifySessionChange();
    } catch (_) {
      if (attemptedWrite && previous != null) {
        // Legacy SharedPreferences updates its cache before the platform
        // result. Restore that cache and attempt the original disk write too.
        try {
          await _prefs!.setString(storageKey, previous);
        } catch (_) {
          /* previous snapshot remains separately stored */
        }
        saveError =
            '복원 저장에 실패했습니다. 현재 진행을 유지하며 복원 전 백업을 보관했습니다. 기기 저장 공간을 확인하세요.';
      }
      rethrow;
    } finally {
      restoringBackup = false;
    }
  }

  void updateControls(ControlPreferences value) {
    controls = ControlPreferences.restore(value.toJson());
    _changed();
  }

  void rebindVerifiedAdCredits() => _verifiedAdCredits = 0;

  /// Only CloudSync calls this after an authenticated server save. This is an
  /// application counter for free credits, never evidence of paid ownership.
  void acceptVerifiedAdCredits(int total) {
    if (developerMode || _presentationOnly || total <= _verifiedAdCredits) {
      return;
    }
    credits = (credits + total - _verifiedAdCredits).clamp(0, 9999999);
    _verifiedAdCredits = total;
  }

  List<HangarPreset?> hangarPresets = List.filled(6, null);
  @override
  Set<int> get presetProtectedGearIds => {
    for (final preset in hangarPresets)
      if (preset != null) ...preset.gearIds,
  };
  static Map<String, dynamic> freshProgress() => Profile._(null)._snapshot();
  Map<String, dynamic> exportProgress() {
    final value = _snapshot();
    (value['content'] as Map).remove('guildToken');
    return value;
  }

  Future<void> replaceProgress(
    Map<String, dynamic> value, {
    bool preserveFlightHistory = false,
  }) async {
    if (!preserveFlightHistory) _flightRecords.clear();
    claimedMissions.clear();
    clearedChallenges.clear();
    _processedRunIds.clear();
    equippedTech.clear();
    assistingPets.clear();
    final normalized = Profile._(null).._restore(value);
    _restore(normalized._snapshot());
    await save();
  }

  static const storageKey = 'shootingstar.profile.v1';
  final SharedPreferences? _prefs;
  final Set<String> _processedRunIds = {};
  Future<void> _pendingSave = Future<void>.value();
  bool _disposed = false;
  @override
  int get credits => developerMode ? 1000000 : _credits;
  @override
  set credits(int value) {
    if (!developerMode) _credits = value;
  }

  int _credits = 150;
  int selectedShip = 0, selectedStage = 0, equipment = 0;
  ModuleFleet? _moduleFleet;

  /// v11 story quests (Captain Momo) and endless achievements.
  GuardianQuestState quests = GuardianQuestState();

  int guardianStat(GuardianStat stat) => switch (stat) {
    GuardianStat.flights => runs,
    GuardianStat.kills => totalKills,
    GuardianStat.bosses => quests.bosses,
    GuardianStat.stagesCleared => clearedStages.length,
    GuardianStat.worldsCleared => List.generate(
      10,
      (w) => List.generate(10, (s) => w * 10 + s).every(clearedStages.contains),
    ).where((cleared) => cleared).length,
    GuardianStat.gearUpgrades => quests.gearUpgrades,
    GuardianStat.gearOwned => catGear.items.length,
    GuardianStat.pilotLevel => pilotLevel,
    GuardianStat.chickLevel => petLevels.fold(0, (a, b) => a + b),
  };

  bool get storyReady {
    final q = quests.currentStory;
    return q != null && guardianStat(q.stat) >= q.target;
  }

  bool achievementReady(GuardianStat stat) =>
      guardianStat(stat) >= quests.nextAchievement(stat).target;

  /// Claimable story step + achievements (lobby badge).
  int get questAttention =>
      (storyReady ? 1 : 0) + GuardianStat.values.where(achievementReady).length;

  /// Pays [reward]; a gear reward lands in the gear bag. Returns the line
  /// shown to the player.
  String _payQuest(QuestReward reward) {
    credits = (credits + reward.churu).clamp(0, 9999999);
    blueprints = (blueprints + reward.stardust).clamp(0, 999999);
    var line = reward.summary;
    if (reward.gearRarity != null &&
        catGear.items.length < CatGearState.capacity) {
      final item = catGear.rollDrop(
        math.Random(runs * 31 + quests.storyStep * 977 + totalKills),
        stage: 0,
      );
      final upgraded = CatGearItem(
        id: item.id,
        set: item.set,
        slot: item.slot,
        rarity: reward.gearRarity!,
      );
      catGear.items[catGear.items.indexOf(item)] = upgraded;
      line =
          '$line · ${upgraded.name} (${catGearRarityNames[upgraded.rarity]})';
    }
    return line;
  }

  String? claimStory() {
    final q = quests.currentStory;
    if (q == null || guardianStat(q.stat) < q.target) return null;
    final line = _payQuest(q.reward);
    quests.storyStep++;
    _changed();
    return line;
  }

  String? claimAchievement(GuardianStat stat) {
    if (!achievementReady(stat)) return null;
    final a = quests.nextAchievement(stat);
    final line = _payQuest(a.reward);
    quests.achievementTier[stat] = a.tier + 1;
    _changed();
    return line;
  }

  /// The guardian cats' prologue was shown (first launch only).
  bool prologueSeen = false;

  void markPrologueSeen() {
    if (prologueSeen) return;
    prologueSeen = true;
    _changed();
  }

  /// v11 cat airframe equipment (nose, armour, wings, engines, shield).
  CatGearState catGear = CatGearState.starter();

  /// One-time messages about save changes (v12.11 slot rework), shown once
  /// in the lobby and then dropped; never saved.
  final List<String> updateNotices = [];
  void addUpdateNotice(String text) => updateNotices.add(text);

  /// The gear piece the last won flight dropped (result screen), if any.
  CatGearItem? lastGearDrop;

  bool equipCatGear(int id) {
    final item = catGear.item(id);
    if (item == null || catGear.isEquipped(item)) return false;
    catGear.equipped[item.slot] = id;
    _changed();
    return true;
  }

  bool canUpgradeCatGear(CatGearItem item) =>
      !item.maxed &&
      credits >= item.upgradeChuru &&
      blueprints >= item.upgradeStardust;

  bool upgradeCatGear(int id) {
    final item = catGear.item(id);
    if (item == null || !canUpgradeCatGear(item)) return false;
    credits -= item.upgradeChuru;
    blueprints -= item.upgradeStardust;
    item.level++;
    quests.gearUpgrades++;
    _changed();
    return true;
  }

  bool dismantleCatGear(int id) {
    final item = catGear.item(id);
    if (item == null || item.locked || catGear.isEquipped(item)) return false;
    credits = (credits + item.dismantleChuru).clamp(0, 9999999);
    blueprints = (blueprints + item.dismantleStardust).clamp(0, 999999);
    catGear.items.remove(item);
    _changed();
    return true;
  }

  void toggleCatGearLock(int id) {
    final item = catGear.item(id);
    if (item == null) return;
    item.locked = !item.locked;
    _changed();
  }

  AircraftAssembly _assembly = AircraftAssembly.initial(0);
  AircraftAssembly get aircraftAssembly {
    return AircraftAssembly(
      hull: selectedShip,
      modules: shipModules.snapshot(selectedShip),
    );
  }

  Map<String, int> get aircraftSupportLevels => {
    for (final id in aircraftAssembly.parts.values.where(
      (id) => AircraftAssembly.petKind(id) >= 0,
    ))
      id: petLevels[AircraftAssembly.petKind(id)],
  };
  void _syncAssemblyPets() {
    final desired = {
      activePet,
      ...assistingPets,
    }.where((i) => i >= 0 && i < 3 && petLevels[i] > 0).toSet();
    final actual = _assembly.parts.entries
        .where((e) => supportMounts.contains(e.key))
        .map((e) => AircraftAssembly.petKind(e.value))
        .toSet();
    if (setEquals(desired, actual)) return;
    final next = Map<AircraftMount, String>.of(_assembly.parts);
    next.removeWhere(
      (m, id) =>
          supportMounts.contains(m) &&
          !desired.contains(AircraftAssembly.petKind(id)),
    );
    for (final id in desired) {
      if (next.values.contains(AircraftAssembly.petParts[id])) continue;
      final free = supportMounts.where((m) => !next.containsKey(m));
      if (free.isNotEmpty) next[free.first] = AircraftAssembly.petParts[id];
    }
    _assembly = AircraftAssembly(hull: selectedShip, parts: next);
  }

  bool setAircraftAssembly(AircraftAssembly value) {
    if (value.modules != null) {
      if (!unlockedShips.contains(value.hull)) return false;
      final fleet = shipModules, parts = <String, OwnedModulePart>{};
      for (final e in value.modules!.parts.entries) {
        final owned = fleet.owned[e.value.instanceId];
        if (owned == null || owned.partId != e.value.partId) return false;
        parts[e.key] = owned;
      }
      try {
        ModuleSnapshot(
          value.hull,
          fleet.airframeLevels[value.hull] ?? 1,
          parts,
        );
      } catch (_) {
        return false;
      }
      fleet.loadouts[value.hull] = parts.map(
        (k, v) => MapEntry(k, v.instanceId),
      );
      selectedShip = value.hull;
      _changed();
      return true;
    }
    if (!unlockedShips.contains(value.hull) ||
        !value.parts.containsKey(AircraftMount.main))
      return false;
    final pets = value.parts.entries
        .where((e) => supportMounts.contains(e.key))
        .map((e) => AircraftAssembly.petKind(e.value))
        .toList();
    if (pets.any((i) => i < 0 || i >= 3 || petLevels[i] <= 0)) return false;
    selectedShip = value.hull;
    _assembly = value;
    activePet = pets.contains(activePet)
        ? activePet
        : pets.isEmpty
        ? -1
        : pets.first;
    assistingPets = pets.where((i) => i != activePet).toSet();
    _changed();
    return true;
  }

  int attackLevel = 0, hullLevel = 0, magnetLevel = 0;
  Set<int> unlockedShips = {0}, clearedStages = {};
  int campaignLoop = 0, pilotLevel = 0, pilotXp = 0;
  int selectedArmament = 0, selectedPilot = 0;
  ArmamentCollection armamentCollection = ArmamentCollection.fresh();
  CampaignRewardBook campaignRewards = CampaignRewardBook();
  CampaignRewardReceipt? lastCampaignReward;
  BossGearBook bossGear = BossGearBook();
  int get activeArmamentIndex =>
      selectedArmament >= 0 &&
          selectedArmament < armaments.length &&
          armamentCollection.owns(armaments[selectedArmament].id)
      ? selectedArmament
      : 0;
  int get activeArmamentLevel =>
      armamentCollection.level(armaments[activeArmamentIndex].id);
  Set<int> cycleClears = {};
  Set<int> get activeClears => campaignLoop == 0 ? clearedStages : cycleClears;
  double get pilotDamage => pilotLevel * .015;
  double get pilotHull => pilotLevel * .01;
  int get pilotXpNeeded => 120 + pilotLevel * 40;
  void selectArmament(int id) {
    if (id >= 0 &&
        id < armaments.length &&
        armamentCollection.owns(armaments[id].id)) {
      selectedArmament = id;
      _changed();
    }
  }

  bool unlockArmament(String id) {
    if (!ArmamentCollection.valid(id) ||
        armamentCollection.owns(id) ||
        credits < ArmamentCollection.unlockCredits ||
        blueprints < ArmamentCollection.unlockBlueprints) {
      return false;
    }
    armamentCollection.unlock(id);
    credits -= ArmamentCollection.unlockCredits;
    blueprints -= ArmamentCollection.unlockBlueprints;
    _changed();
    return true;
  }

  bool upgradeArmament(String id, {required int expectedLevel}) {
    final level = armamentCollection.level(id);
    if (!armamentCollection.owns(id) ||
        level != expectedLevel ||
        level >= ArmamentCollection.maxLevel ||
        credits < ArmamentCollection.upgradeCredits(level) ||
        blueprints < ArmamentCollection.upgradeBlueprints(level)) {
      return false;
    }
    credits -= ArmamentCollection.upgradeCredits(level);
    blueprints -= ArmamentCollection.upgradeBlueprints(level);
    armamentCollection.upgrade(id);
    _changed();
    return true;
  }

  bool resetArmament(String id, {required int expectedLevel}) {
    final level = armamentCollection.level(id);
    final refund = armamentCollection.refundCredits(id);
    final plans = armamentCollection.refundBlueprints(id);
    if (!armamentCollection.owns(id) ||
        level <= 0 ||
        level != expectedLevel ||
        credits + refund > 9999999 ||
        blueprints + plans > 999999) {
      return false;
    }
    credits += refund;
    blueprints += plans;
    armamentCollection.reset(id);
    _changed();
    return true;
  }

  void selectPilot(int id) {
    if (id >= 0 && id < pilots.length) {
      selectedPilot = id;
      _changed();
    }
  }

  /// [soundEnabled]/[volume] are the sound effects; background music has
  /// its own switch and level (v12.8).
  bool onboarded = false, reducedEffects = false, soundEnabled = true;
  bool musicEnabled = true;
  double volume = .5, musicVolume = .5;
  int runs = 0, bestKills = 0;
  int totalKills = 0;
  @override
  int get blueprints => developerMode ? 100000 : _blueprints;
  @override
  set blueprints(int value) {
    if (!developerMode) _blueprints = value;
  }

  int _blueprints = 0;
  Set<int> claimedMissions = {}, clearedChallenges = {};
  static const gearNames = ['주무장', '조준 센서', '출력 코어', '선체 장갑', '보호 벨트', '추진 장치'];
  static const rankNames = ['일반', '우수', '희귀', '엘리트', '에픽', '전설'];
  int missionProgress(int id) => switch (id) {
    0 => totalKills,
    1 => runs,
    2 => clearedStages.length,
    3 => gearLevels.fold(0, (a, b) => a + b),
    _ => 0,
  };
  static const missionTargets = [100, 3, 1, 5];
  static const missionNames = ['군집 100기 처치', '출격 3회 완료', '첫 챕터 정복', '장비 강화 5회'];
  bool claimMission(int id) {
    if (id < 0 ||
        id >= 4 ||
        claimedMissions.contains(id) ||
        missionProgress(id) < missionTargets[id]) {
      return false;
    }
    claimedMissions.add(id);
    credits += 100;
    blueprints += 3;
    _changed();
    return true;
  }

  String? saveError;

  static Future<Profile> load({
    @visibleForTesting Future<SharedPreferences> Function()? preferencesLoader,
  }) async {
    SharedPreferences? prefs;
    try {
      prefs = await (preferencesLoader ?? SharedPreferences.getInstance)();
    } catch (_) {
      return Profile._(null)
        ..saveError = '저장소를 사용할 수 없습니다. 이번 진행은 앱을 종료하면 사라집니다.';
    }
    final profile = Profile._(prefs);
    bool migrated = false;
    try {
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid profile');
        }
        profile._restore(decoded);
        // Saves write 'legacyAircraft' + 'moduleFleet'; only a save with
        // neither is from before the modular aircraft. One-time slot
        // refunds (updateNotices) are written back too.
        if (profile.updateNotices.isNotEmpty) migrated = true;
        if (decoded['aircraft'] == null && decoded['moduleFleet'] == null) {
          final backupKey = '$storageKey.beforeModularAircraft';
          if (!prefs.containsKey(backupKey))
            await prefs.setString(backupKey, raw);
          migrated = true;
        }
        if (decoded['_flights'] is List) {
          for (final raw in (decoded['_flights'] as List).take(8)) {
            final entry = FlightRecord.restore(raw);
            if (entry != null &&
                !profile._flightRecords.any((r) => r.id == entry.id)) {
              profile._flightRecords.add(entry);
            }
          }
        }
        if (decoded['armamentProgressionVersion'] != 1) {
          final backupKey = '$storageKey.beforeArmamentProgression';
          if (!prefs.containsKey(backupKey)) {
            await prefs.setString(backupKey, raw);
          }
          migrated = true;
        }
        final content = decoded['content'];
        if (content is! Map || content['advancedProgressionVersion'] != 1) {
          final backupKey = '$storageKey.beforeAdvancedProgression';
          if (!prefs.containsKey(backupKey)) {
            await prefs.setString(backupKey, raw);
          }
          migrated = true;
        }
        if (decoded['campaignVersion'] != 1) {
          final backupKey = '$storageKey.beforeCampaign';
          if (!prefs.containsKey(backupKey)) {
            await prefs.setString(backupKey, raw);
          }
          migrated = true;
        }
      }
    } catch (_) {
      profile.saveError = '저장 데이터를 읽지 못해 기본 상태로 시작합니다.';
    }
    profile.refreshContentClock(DateTime.now());
    if (migrated) await profile.save();
    return profile;
  }

  static int _integer(dynamic value, int fallback, int maximum) =>
      value is num && value.isFinite
      ? value.toInt().clamp(0, maximum)
      : fallback;
  void _restore(Map<String, dynamic> data) {
    restoreContent(data);
    final presets = data['hangarPresets'];
    hangarPresets = List.generate(
      6,
      (i) => presets is List && i < presets.length
          ? HangarPreset.restore(presets[i])
          : null,
    );
    totalKills = _integer(data['totalKills'], 0, 9999999);
    blueprints = _integer(data['blueprints'], 0, 999999);
    for (final id
        in (data['claimedMissions'] is List
            ? data['claimedMissions'] as List
            : [])) {
      if (id is int && id >= 0 && id < 4) claimedMissions.add(id);
    }
    for (final id
        in (data['clearedChallenges'] is List
            ? data['clearedChallenges'] as List
            : [])) {
      if (id is int && id >= 0 && id < stages.length) clearedChallenges.add(id);
    }
    final processedIds = data['processedRunIds'];
    if (processedIds is List) {
      final validIds = processedIds
          .whereType<String>()
          .where((id) => id.isNotEmpty && id.length <= 200)
          .toSet()
          .toList();
      _processedRunIds.addAll(
        validIds.skip(validIds.length > 100 ? validIds.length - 100 : 0),
      );
    }
    credits = _integer(data['credits'], 150, 9999999);
    _verifiedAdCredits = _integer(data['verifiedAdCredits'], 0, 1000000000);
    attackLevel = _integer(data['attackLevel'], 0, maxUpgradeLevel);
    hullLevel = _integer(data['hullLevel'], 0, maxUpgradeLevel);
    magnetLevel = _integer(data['magnetLevel'], 0, maxUpgradeLevel);
    runs = _integer(data['runs'], 0, 9999999);
    bestKills = _integer(data['bestKills'], 0, 9999999);
    Set<int> validSet(dynamic value, int length) => value is List
        ? value.whereType<int>().where((v) => v >= 0 && v < length).toSet()
        : <int>{};
    unlockedShips = validSet(data['unlockedShips'], ships.length)..add(0);
    clearedStages = validSet(data['clearedStages'], stages.length);
    if (clearedStages.contains(0)) starterTechUnlocked = true;
    selectedShip = _integer(data['selectedShip'], 0, ships.length - 1);
    if (!unlockedShips.contains(selectedShip)) selectedShip = 0;
    try {
      _assembly = AircraftAssembly.decode(
        data['legacyAircraft'] ?? data['aircraft'],
        hull: selectedShip,
      );
      final sanitized = Map<AircraftMount, String>.of(_assembly.parts);
      sanitized[AircraftMount.main] = 'cannon';
      sanitized.removeWhere(
        (m, id) =>
            supportMounts.contains(m) &&
            petLevels[AircraftAssembly.petKind(id)] <= 0,
      );
      _assembly = AircraftAssembly(hull: selectedShip, parts: sanitized);
      final pets = sanitized.entries
          .where((e) => supportMounts.contains(e.key))
          .map((e) => AircraftAssembly.petKind(e.value))
          .toList();
      activePet = pets.contains(activePet)
          ? activePet
          : pets.isEmpty
          ? -1
          : pets.first;
      assistingPets = pets.where((i) => i != activePet).toSet();
    } catch (_) {
      _assembly = AircraftAssembly.initial(
        selectedShip,
        pets: {
          activePet,
          ...assistingPets,
        }.where((i) => i >= 0 && i < 3 && petLevels[i] > 0),
      );
    }
    selectedStage = _integer(data['selectedStage'], 0, stages.length - 1);
    campaignLoop = _integer(data['campaignLoop'], 0, 9999);
    pilotLevel = _integer(data['pilotLevel'], 0, 200);
    pilotXp = _integer(data['pilotXp'], 0, 100000);
    selectedArmament = _integer(
      data['selectedArmament'],
      0,
      armaments.length - 1,
    );
    armamentCollection = ArmamentCollection.restore(
      data['armamentCollection'],
      legacy: data['armamentProgressionVersion'] != 1,
    );
    selectedArmament = activeArmamentIndex;
    selectedPilot = _integer(data['selectedPilot'], 0, pilots.length - 1);
    campaignRewards = CampaignRewardBook.restore(data['campaignRewards']);
    bossGear = BossGearBook.restore(data['bossGear']);
    lastCampaignReward = null;
    if (data['campaignVersion'] != 1) {
      // Old IDs 0/1/2 were whole worlds; preserve their completed content.
      final legacy = clearedStages.where((i) => i < 3).toList();
      clearedStages = {
        for (final world in legacy)
          for (int n = 0; n < 10; n++) world * 10 + n,
      };
      selectedStage = (selectedStage.clamp(0, 2)) * 10;
      final oldChallenges = clearedChallenges.where((i) => i < 3).toList();
      clearedChallenges.clear();
      clearedChallenges.addAll(oldChallenges.map((i) => i * 10 + 9));
    }
    cycleClears = data['cycleClears'] is List
        ? validSet(data['cycleClears'], 100)
        : {...clearedStages};
    if (!canStage(selectedStage)) selectedStage = 0;
    equipment = _integer(data['equipment'], 0, equipmentOptions.length - 1);
    onboarded = data['onboarded'] == true;
    reducedEffects = data['reducedEffects'] == true;
    soundEnabled = data['soundEnabled'] is bool
        ? data['soundEnabled'] as bool
        : true;
    final savedVolume = data['volume'];
    volume = savedVolume is num && savedVolume.isFinite
        ? savedVolume.toDouble().clamp(0, 1)
        : .5;
    // saves from before v12.8 had one switch: music starts the same
    musicEnabled = data['musicEnabled'] is bool
        ? data['musicEnabled'] as bool
        : soundEnabled;
    final savedMusic = data['musicVolume'];
    musicVolume = savedMusic is num && savedMusic.isFinite
        ? savedMusic.toDouble().clamp(0, 1)
        : volume;
    controls = ControlPreferences.restore(data['controls']);
    catGear = CatGearState.restore(data['catGear']);
    if (catGear.retiredShields > 0) {
      credits = (credits + catGear.retiredChuru).clamp(0, 9999999);
      blueprints = (blueprints + catGear.retiredStardust).clamp(0, 999999);
      addUpdateNotice(
        '보호막 장치가 무기의 보조 장치로 옮겨져, 가지고 있던 보호막 장치 ${catGear.retiredShields}개를 전액 환급했습니다. 츄르 ${catGear.retiredChuru} · 별가루 ${catGear.retiredStardust}',
      );
    }
    prologueSeen = data['prologueSeen'] == true;
    quests = GuardianQuestState.restore(data['quests']);
    _moduleFleet = null;
    if (data['moduleFleet'] != null) {
      try {
        _moduleFleet = ModuleFleet.restore(data['moduleFleet']);
      } catch (_) {
        _moduleFleet = _migrateModules()
          ..legacyArchive['invalidFleet'] = data['moduleFleet'];
      }
    }
  }

  Map<String, dynamic> _snapshot({bool includeLocal = false}) => {
    if (includeLocal && _flightRecords.isNotEmpty)
      '_flights': _flightRecords.map((r) => r.toJson()).toList(),
    'version': 4,
    'campaignVersion': 1,
    'campaignLoop': campaignLoop,
    'cycleClears': cycleClears.toList()..sort(),
    'pilotLevel': pilotLevel,
    'pilotXp': pilotXp,
    'selectedArmament': activeArmamentIndex,
    'armamentProgressionVersion': 1,
    'armamentCollection': armamentCollection.toJson(),
    'campaignRewardsVersion': 1,
    'campaignRewards': campaignRewards.toJson(),
    'bossGearVersion': 1,
    'bossGear': bossGear.toJson(),
    'selectedPilot': selectedPilot,
    'content': contentSnapshot(),
    'hangarPresets': hangarPresets.map((p) => p?.toJson()).toList(),
    'gearRanks': gearRanks,
    'gearLevels': gearLevels,
    'gearCopies': gearCopies,
    'totalKills': totalKills,
    'blueprints': blueprints,
    'claimedMissions': claimedMissions.toList(),
    'clearedChallenges': clearedChallenges.toList(),
    'credits': credits,
    'verifiedAdCredits': _verifiedAdCredits,
    'selectedShip': selectedShip,
    'legacyAircraft': _assembly.toJson(),
    'moduleFleet': shipModules.toJson(),
    'catGearVersion': 1,
    'prologueSeen': prologueSeen,
    'quests': quests.toJson(),
    'catGear': catGear.toJson(),
    'selectedStage': selectedStage,
    'equipment': equipment,
    'attackLevel': attackLevel,
    'hullLevel': hullLevel,
    'magnetLevel': magnetLevel,
    'unlockedShips': unlockedShips.toList()..sort(),
    'clearedStages': clearedStages.toList()..sort(),
    'onboarded': onboarded,
    'reducedEffects': reducedEffects,
    'soundEnabled': soundEnabled,
    'volume': volume,
    'musicEnabled': musicEnabled,
    'musicVolume': musicVolume,
    'controls': controls.toJson(),
    'runs': runs,
    'bestKills': bestKills,
    'processedRunIds': _processedRunIds.toList(),
  };

  Future<void> save() {
    if (_presentationOnly) return Future<void>.value();
    if (developerMode) return _saveDeveloperSession();
    final encoded = jsonEncode(_snapshot(includeLocal: true));
    _pendingSave = _pendingSave.then((_) async {
      try {
        if (_prefs == null) {
          saveError = '저장소를 사용할 수 없습니다. 이번 진행은 앱을 종료하면 사라집니다.';
          if (!_disposed) notifyListeners();
          return;
        }
        final success = await _prefs.setString(storageKey, encoded);
        if (!success) throw StateError('Storage rejected write');
        saveError = null;
      } catch (_) {
        saveError = '진행 저장에 실패했습니다. 브라우저 저장 공간을 확인하세요.';
      }
      if (!_disposed) notifyListeners();
    });
    return _pendingSave;
  }

  void _changed() {
    if (developerMode) _refillDeveloperResources();
    online?.changed();
    if (!_disposed) notifyListeners();
    save();
  }

  bool claimChapterReward(int stage, int milestone) {
    if (stage < 0 || stage >= stages.length) return false;
    return claimChapterMilestone(
      stage,
      milestone,
      stages[stage].duration,
      clearedStages,
    );
  }

  bool canStage(int index) =>
      index >= 0 &&
      index < stages.length &&
      (developerMode || index == 0 || activeClears.contains(index - 1));
  bool unlockShip(int index) {
    if (index < 0 ||
        index >= ships.length ||
        unlockedShips.contains(index) ||
        credits < ships[index].unlockCost) {
      return false;
    }
    credits -= ships[index].unlockCost;
    unlockedShips.add(index);
    _changed();
    return true;
  }

  int upgradeLevel(String kind) => switch (kind) {
    'attack' => attackLevel,
    'hull' => hullLevel,
    'magnet' => magnetLevel,
    _ => -1,
  };
  bool buyUpgrade(String kind) {
    final level = upgradeLevel(kind);
    if (level < 0 || level >= maxUpgradeLevel || credits < upgradeCost(level)) {
      return false;
    }
    credits -= upgradeCost(level);
    switch (kind) {
      case 'attack':
        attackLevel++;
      case 'hull':
        hullLevel++;
      case 'magnet':
        magnetLevel++;
    }
    _changed();
    return true;
  }

  void selectShip(int index) {
    if (unlockedShips.contains(index) && index >= 0 && index < ships.length) {
      selectedShip = index;
      _changed();
    }
  }

  void selectStage(int index) {
    if (canStage(index)) {
      selectedStage = index;
      _changed();
    }
  }

  void selectEquipment(int index) {
    if (index >= 0 && index < equipmentOptions.length) {
      equipment = index;
      _changed();
    }
  }

  void finishOnboarding() {
    onboarded = true;
    _changed();
  }

  void updateSettings({
    bool? soundEnabled,
    bool? reducedEffects,
    double? volume,
    bool? musicEnabled,
    double? musicVolume,
  }) {
    if (soundEnabled != null) this.soundEnabled = soundEnabled;
    if (reducedEffects != null) this.reducedEffects = reducedEffects;
    if (volume != null && volume.isFinite) this.volume = volume.clamp(0, 1);
    if (musicEnabled != null) this.musicEnabled = musicEnabled;
    if (musicVolume != null && musicVolume.isFinite) {
      this.musicVolume = musicVolume.clamp(0, 1);
    }
    _changed();
  }

  int completeDailyChallenge({
    required String runId,
    required DailyChallengeEntry entry,
    required bool victory,
    required int kills,
    required int seconds,
    required int bosses,
    required int deployedPet,
  }) {
    if (runId.isEmpty ||
        runId.length > 200 ||
        _processedRunIds.contains(runId)) {
      return 0;
    }
    refreshContentClock(DateTime.now());
    _processedRunIds.add(runId);
    if (_processedRunIds.length > 100) {
      _processedRunIds.remove(_processedRunIds.first);
    }
    final earned = dailyChallenge.complete(
      entry,
      victory: victory,
      seconds: seconds.toDouble(),
      kills: kills,
      bosses: bosses,
    );
    // Favor also requires a current rotation and real participation, and is
    // independently capped. Failed combat does not mint challenge tokens.
    final expected = dailyChallenge.begin(entry.tier);
    if (expected != null &&
        expected.day == entry.day &&
        expected.seed == entry.seed &&
        expected.variant == entry.variant) {
      petBond.recordRun(
        pet: deployedPet,
        unlocked:
            deployedPet >= 0 && deployedPet < 3 && petLevels[deployedPet] > 0,
        runId: runId,
        seconds: seconds.clamp(0, 180),
        kills: kills,
        now: DateTime.fromMillisecondsSinceEpoch(lastClock, isUtc: true),
      );
    }
    lastLoot = earned > 0
        ? '일일 도전 첫 승리 · 도전 토큰 +$earned'
        : '추가 토큰 없음 · 당일 난이도별 첫 승리만 지급됩니다.';
    _changed();
    return earned;
  }

  int completeRun({
    required bool victory,
    required int stageIndex,
    required int kills,
    required int level,
    required int seconds,
    required bool training,
    String? runId,
    bool challenge = false,
    int bossesDefeated = 0,
    double creditBonus = 0,
    int? deployedPet,
  }) {
    lastCampaignReward = null;
    if (training ||
        !canStage(stageIndex) ||
        (challenge && !clearedStages.contains(stageIndex))) {
      return 0;
    }
    if (runId != null) {
      if (runId.isEmpty ||
          runId.length > 200 ||
          _processedRunIds.contains(runId)) {
        return 0;
      }
      _processedRunIds.add(runId);
      if (_processedRunIds.length > 100) {
        _processedRunIds.remove(_processedRunIds.first);
      }
    }
    final safeKills = kills.clamp(0, 100000);
    final progressSeconds = seconds.clamp(0, stages[stageIndex].duration);
    final bosses = bossesDefeated.clamp(0, stages[stageIndex].bossCount);
    final payout = RunRewards(
      seconds: progressSeconds,
      kills: safeKills,
      bosses: bosses,
      victory: victory,
    );
    final reward =
        (payout.credits *
                (1 + (creditBonus.isFinite ? creditBonus.clamp(0, .4) : 0)))
            .floor();
    final beforeCredits = credits;
    credits = (credits + reward).clamp(0, 9999999);
    final baseCredits = credits - beforeCredits;
    if (seconds >= 15 || kills > 0) runs++;
    totalKills += safeKills;
    if (payout.eligible) {
      recordContentRun(
        runId: runId ?? 'run-$runs',
        kills: safeKills,
        seconds: progressSeconds,
        victory: victory,
        bossesDefeated: bosses,
        stageIndex: stageIndex,
        challenge: challenge,
      );
      final pet = deployedPet ?? activePet;
      petBond.recordRun(
        pet: pet,
        unlocked: pet >= 0 && pet < 3 && petLevels[pet] > 0,
        runId: runId ?? 'run-$runs',
        seconds: progressSeconds,
        kills: safeKills,
        now: DateTime.fromMillisecondsSinceEpoch(lastClock, isUtc: true),
      );
      if (stageIndex == 0 && (bosses > 0 || victory)) {
        starterTechUnlocked = true;
      }
    }
    final receiptEntries = <(String, FleetReward)>[];
    final newRewards = campaignRewards.settle(
      stage: stageIndex,
      bosses: bosses,
      clear:
          !challenge &&
          victory &&
          progressSeconds >= stages[stageIndex].duration &&
          bosses >= stages[stageIndex].bossCount,
      eligible: payout.eligible,
    );
    for (final (title, extra) in newRewards) {
      receiptEntries.add((title, _deliverCampaignReward(extra)));
    }
    if (payout.eligible) {
      lastCampaignReward = CampaignRewardReceipt(baseCredits, receiptEntries);
      bossGear.record(stageIndex ~/ 10, bosses);
      if (bosses > 0 && bossGear.pending(stageIndex ~/ 10) > 0) {
        lastLoot +=
            ' · 보스 전용 장비 ${bossGear.pending(stageIndex ~/ 10)}개 회수 대기 · 성장 관리에서 확인';
      }
    }
    if (challenge && victory && !clearedChallenges.contains(stageIndex)) {
      clearedChallenges.add(stageIndex);
      blueprints += 5;
    }
    if (safeKills > bestKills) bestKills = safeKills;
    if (payout.eligible) {
      pilotXp += progressSeconds ~/ 3 + bosses * 40 + (victory ? 80 : 0);
      while (pilotLevel < 200 && pilotXp >= pilotXpNeeded) {
        pilotXp -= pilotXpNeeded;
        pilotLevel++;
      }
      if (pilotLevel == 200) pilotXp = 0;
    }
    lastGearDrop = null;
    if (payout.eligible) quests.bosses += bosses;
    if (victory &&
        !challenge &&
        payout.eligible &&
        catGear.items.length < CatGearState.capacity) {
      final drop = catGear.rollDrop(
        math.Random(runs * 7919 + stageIndex * 131 + totalKills),
        stage: stageIndex,
        finale: stageIndex % 10 == 9,
      );
      lastGearDrop = drop;
      lastLoot += ' · ${drop.name} (${catGearRarityNames[drop.rarity]}) 획득';
    }
    if (victory && !challenge) {
      clearedStages.add(stageIndex);
      cycleClears.add(stageIndex);
      if (stageIndex == 99) {
        campaignLoop = (campaignLoop + 1).clamp(0, 9999);
        cycleClears.clear();
        selectedStage = 0;
      } else {
        selectedStage = stageIndex + 1;
      }
    }
    _changed();
    return credits - beforeCredits;
  }

  bool claimBossGear(int world) {
    if (world < 0 ||
        world >= 10 ||
        bossGear.pending(world) <= 0 ||
        inventory.length >= 240) {
      return false;
    }
    final gear = grantItem(bossGear.nextSpec(world), rank: 2);
    if (gear == null) return false;
    gear.locked = true;
    bossGear.claimed[world]++;
    lastLoot = '${gear.definition.name} · 희귀 · 보호 잠금 · 보관 탭에서 장착';
    _changed();
    return true;
  }

  FleetReward _deliverCampaignReward(FleetReward r) {
    int delta(int value, int amount, int cap) =>
        ((value + amount).clamp(0, cap) - value).clamp(0, amount);
    final actual = FleetReward(
      credits: delta(credits, r.credits, 9999999),
      plans: delta(blueprints, r.plans, 999999),
      food: delta(petFood, r.food, 999999),
      gearKeys: delta(gearKeys, r.gearKeys, 99999),
      techKeys: delta(techKeys, r.techKeys, 99999),
      eggs: delta(petEggs, r.eggs, 99999),
      collectionKeys: delta(collections.keys, r.collectionKeys, 99999),
    );
    credits += actual.credits;
    blueprints += actual.plans;
    petFood += actual.food;
    gearKeys += actual.gearKeys;
    techKeys += actual.techKeys;
    petEggs += actual.eggs;
    collections.keys += actual.collectionKeys;
    return actual;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
