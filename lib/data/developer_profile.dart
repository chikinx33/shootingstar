part of 'profile.dart';

extension DeveloperProfile on Profile {
  Future<Profile> startDeveloperSession() async {
    if (developerMode) return this;
    final session = developerSession ?? Profile.developerCopy(this);
    session._developerOwner = this;
    developerSession = session;
    await session.save();
    _notifySessionChange();
    return session;
  }

  Future<void> restoreDeveloperSession() async {
    if (developerMode || _prefs == null) return;
    final raw = _prefs.getString(Profile.developerStorageKey);
    if (raw == null) return;
    try {
      final value = jsonDecode(raw);
      if (value is! Map || value['schema'] != 1 || value['progress'] is! Map) {
        return;
      }
      final session = Profile._(null, developerMode: true)
        .._restore(Map<String, dynamic>.from(value['progress']))
        .._developerOwner = this;
      if (value['settings'] is Map) {
        session.developerSettings = Map<String, dynamic>.from(
          value['settings'],
        );
      }
      session._refillDeveloperResources();
      developerSession = session;
      _notifySessionChange();
    } catch (_) {
      saveError = '개발자 저장을 읽지 못했습니다. 일반 진행은 보존되어 있습니다.';
    }
  }

  Future<void> _saveDeveloperSession() {
    final prefs = _developerOwner?._prefs;
    if (_developerClosed || prefs == null) return Future<void>.value();
    final encoded = jsonEncode({
      'schema': 1,
      'progress': _snapshot(),
      'settings': developerSettings,
    });
    _pendingSave = _pendingSave.then((_) async {
      if (_developerClosed) return;
      try {
        if (!await prefs.setString(Profile.developerStorageKey, encoded)) {
          throw StateError('write');
        }
        saveError = null;
      } catch (_) {
        saveError = '개발자 설정 저장에 실패했습니다. 일반 저장은 변경하지 않았습니다.';
      }
    });
    return _pendingSave;
  }

  Future<bool> endDeveloperSession() async {
    final owner = _developerOwner;
    if (owner == null) return true;
    _developerClosed = true;
    await _pendingSave;
    try {
      if (owner._prefs != null &&
          !await owner._prefs.remove(Profile.developerStorageKey)) {
        throw StateError('remove');
      }
    } catch (_) {
      _developerClosed = false;
      saveError = '개발자 모드 종료를 저장하지 못했습니다. 다시 눌러 주세요.';
      _notifySessionChange();
      return false;
    }
    owner.developerSession = null;
    owner._notifySessionChange();
    return true;
  }

  void _unlockDeveloperContent() {
    onboarded = true;
    saveError = null;
    unlockedShips.addAll(List.generate(ships.length, (i) => i));
    clearedStages.addAll(List.generate(stages.length, (i) => i));
    cycleClears.addAll(List.generate(stages.length, (i) => i));
    for (final a in armaments) {
      armamentCollection.unlock(a.id);
    }
    starterTechUnlocked = true;
    starterTechClaimed = false;
    for (var i = 0; i < petLevels.length; i++) {
      if (petLevels[i] == 0) petLevels[i] = 1;
    }
    for (final stock in techStock) {
      if (stock.every((n) => n == 0)) stock[2] = 1;
    }
    for (var spec = 0; spec < gearCatalog.length; spec++) {
      if (!inventory.any((g) => g.spec == spec && g.rank >= 2)) {
        // The copy may already have a full bag; developer grants have room.
        inventory.add(GearItem(nextItemId++, spec, rank: 2));
      }
    }
    for (var i = 0; i < collections.levels.length; i++) {
      if (collections.levels[i] == 0) collections.levels[i] = 1;
    }
    _refillDeveloperResources();
  }

  void _refillDeveloperResources() {
    gearKeys = techKeys = petEggs = 1000;
    petFood = 100000;
    petShards.fillRange(0, petShards.length, 1000);
    collections.keys = collections.dust = 100000;
    collections.shards.fillRange(0, collections.shards.length, 1000);
    dailyChallenge.tokens = 100000;
    dailyChallenge.purchases.fillRange(0, dailyChallenge.purchases.length, 0);
    shopCounts.clear();
    petBond.giftsToday = 0;
    for (var i = 0; i < 10; i++) {
      bossGear.defeats[i] = ((bossGear.claimed[i] + 2) * 2 - 1).clamp(0, 9999);
    }
  }

  void developerRewardConditions() {
    if (!developerMode) return;
    totalKills = 10000;
    runs = 100;
    dailyRuns = 10;
    dailyKills = 10000;
    dailyUpgrades = 100;
    seasonXp = 2000;
    journal.signIns = 7;
    journal.weeklyRuns = 10;
    journal.weeklyKills = 10000;
    journal.weeklyBosses = 30;
    journal.weeklySeconds = 3600;
    for (var i = 0; i < stages.length; i++) {
      journal.chapterBest[i] = stages[i].duration;
      journal.chapterWins.add(i);
    }
    _changed();
  }

  /// Explicit lab grants do not alter the player's normal ownership or ledger.
  GearItem? developerGear(int spec, int rank, int level) {
    if (!developerMode || spec < 0 || spec >= gearCatalog.length) return null;
    final g = GearItem(nextItemId++, spec, rank: rank.clamp(0, 5))
      ..level = level.clamp(0, 20 + rank.clamp(0, 5) * 10);
    inventory.add(g);
    _changed();
    return g;
  }

  void developerConfigure({
    int? pilotLevel,
    int? armamentLevel,
    int? researchLevel,
    int? techLevel,
    int? petLevel,
    int? petRank,
    int? petAwakening,
    int? loop,
  }) {
    if (!developerMode) return;
    if (pilotLevel != null) this.pilotLevel = pilotLevel.clamp(0, 100);
    if (loop != null) campaignLoop = loop.clamp(0, 20);
    if (researchLevel != null) {
      attackLevel = hullLevel = magnetLevel = researchLevel.clamp(
        0,
        maxUpgradeLevel,
      );
    }
    if (armamentLevel != null) {
      final raw = armamentCollection.toJson();
      raw[armaments[activeArmamentIndex].id] = armamentLevel.clamp(0, 10);
      armamentCollection = ArmamentCollection.restore(raw, legacy: false);
    }
    if (techLevel != null) {
      for (var i = 0; i < techStock.length; i++) {
        techStock[i].fillRange(0, 6, 0);
        if (techLevel >= 0) techStock[i][techLevel.clamp(0, 5)] = 20;
      }
    }
    for (var i = 0; i < petLevels.length; i++) {
      if (petRank != null) petRanks[i] = petRank.clamp(0, 5);
      if (petLevel != null) {
        petLevels[i] = petLevel.clamp(1, 20 + petRanks[i] * 10);
      }
      if (petAwakening != null) {
        petBond.favor[i] = 300;
        petBond.awakening[i] = petAwakening.clamp(0, 3);
      }
    }
    _changed();
  }
}
