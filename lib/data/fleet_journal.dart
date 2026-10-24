import 'dart:math' as math;

/// Original earned rewards. No premium currency, checkout or ad entitlement.
class FleetReward {
  const FleetReward({
    this.credits = 0,
    this.plans = 0,
    this.food = 0,
    this.gearKeys = 0,
    this.techKeys = 0,
    this.eggs = 0,
    this.collectionKeys = 0,
  });
  final int credits, plans, food, gearKeys, techKeys, eggs, collectionKeys;
  String get summary => [
    if (credits > 0) '$credits 츄르',
    if (plans > 0) '별가루 $plans',
    if (food > 0) '먹이 $food',
    if (gearKeys > 0) '장비권 $gearKeys',
    if (techKeys > 0) '테크권 $techKeys',
    if (eggs > 0) '펫 구조권 $eggs',
    if (collectionKeys > 0) '수집품 보급권 $collectionKeys',
  ].join(' · ');
}

/// KST day/week ledger. Claim IDs are bounded, serializable and idempotent.
/// Local monotonic time blocks ordinary rollback, not deliberate save editing.
class FleetJournal {
  String day = '', week = '', signInDay = '';
  int signIns = 0,
      weeklyRuns = 0,
      weeklyKills = 0,
      weeklyBosses = 0,
      weeklySeconds = 0;
  bool quickPatrolClaimed = false;
  Set<int> dailyChests = {},
      weeklyClaims = {},
      weeklyChests = {},
      signInChests = {};
  Map<int, int> chapterBest = {};
  Set<int> chapterWins = {}, chapterClaims = {};

  static const signInRewards = [
    FleetReward(credits: 30, collectionKeys: 1),
    FleetReward(plans: 2, food: 10),
    FleetReward(gearKeys: 1),
    FleetReward(techKeys: 1),
    FleetReward(collectionKeys: 1),
    FleetReward(credits: 50, eggs: 1),
    FleetReward(collectionKeys: 2, plans: 3),
  ];
  static const signInTargets = [2, 4, 7, 14, 28];
  static const signInChestRewards = [
    FleetReward(food: 10),
    FleetReward(plans: 2),
    FleetReward(collectionKeys: 1),
    FleetReward(collectionKeys: 2),
    FleetReward(collectionKeys: 3, gearKeys: 1),
  ];
  static const dailyChestRewards = [
    FleetReward(credits: 30),
    FleetReward(plans: 1, food: 10),
    FleetReward(collectionKeys: 1),
  ];
  static const weeklyNames = [
    '유효 출격 5회',
    '군집 1,200기 격파',
    '보스 3기 처치',
    '항로 진행 30분',
  ];
  static const weeklyTargets = [5, 1200, 3, 1800];
  static const weeklyReward = FleetReward(credits: 50, collectionKeys: 1);
  static const weeklyChestRewards = [
    FleetReward(collectionKeys: 1),
    FleetReward(collectionKeys: 2, gearKeys: 1),
  ];
  static const quickPatrolReward = FleetReward(credits: 80, plans: 2, food: 10);

  bool advance(DateTime safeUtc) {
    final kst = safeUtc.toUtc().add(const Duration(hours: 9));
    final nextDay = kst.toIso8601String().substring(0, 10);
    final monday = kst.subtract(Duration(days: kst.weekday - 1));
    final nextWeek = monday.toIso8601String().substring(0, 10);
    bool changed = false;
    if (day != nextDay) {
      day = nextDay;
      dailyChests.clear();
      quickPatrolClaimed = false;
      changed = true;
    }
    if (week != nextWeek) {
      week = nextWeek;
      weeklyRuns = weeklyKills = weeklyBosses = weeklySeconds = 0;
      weeklyClaims.clear();
      weeklyChests.clear();
      changed = true;
    }
    return changed;
  }

  bool get signedInToday => day.isNotEmpty && signInDay == day;
  int get signInNext => signIns % 7;
  FleetReward? claimSignIn() {
    if (day.isEmpty || signedInToday) return null;
    final reward = signInRewards[signInNext];
    signIns = math.min(999999, signIns + 1);
    signInDay = day;
    return reward;
  }

  FleetReward? claimSignInChest(int id) {
    if (id < 0 ||
        id >= signInTargets.length ||
        signInChests.contains(id) ||
        signIns < signInTargets[id]) {
      return null;
    }
    signInChests.add(id);
    return signInChestRewards[id];
  }

  FleetReward? claimDailyChest(int id, int claimedMissions) {
    if (id < 0 ||
        id >= 3 ||
        claimedMissions < id + 1 ||
        dailyChests.contains(id)) {
      return null;
    }
    dailyChests.add(id);
    return dailyChestRewards[id];
  }

  int weeklyProgress(int id) => switch (id) {
    0 => weeklyRuns,
    1 => weeklyKills,
    2 => weeklyBosses,
    3 => weeklySeconds,
    _ => 0,
  };
  FleetReward? claimWeekly(int id) {
    if (id < 0 ||
        id >= 4 ||
        weeklyClaims.contains(id) ||
        weeklyProgress(id) < weeklyTargets[id]) {
      return null;
    }
    weeklyClaims.add(id);
    return weeklyReward;
  }

  FleetReward? claimWeeklyChest(int id) {
    if (id < 0 ||
        id >= 2 ||
        weeklyChests.contains(id) ||
        weeklyClaims.length < (id + 1) * 2) {
      return null;
    }
    weeklyChests.add(id);
    return weeklyChestRewards[id];
  }

  FleetReward? claimQuickPatrol(int validRunsToday) {
    if (validRunsToday < 1 || quickPatrolClaimed) return null;
    quickPatrolClaimed = true;
    return quickPatrolReward;
  }

  void recordRun({
    required int stage,
    required int seconds,
    required int kills,
    required int bosses,
    required bool victory,
    bool challenge = false,
  }) {
    if (stage < 0 || stage >= 100 || seconds < 30 || kills < 10) return;
    if (seconds >= 120 || bosses > 0 || victory) {
      weeklyRuns = math.min(99999, weeklyRuns + 1);
    }
    weeklyKills = math.min(9999999, weeklyKills + kills.clamp(0, 100000));
    weeklyBosses = math.min(99999, weeklyBosses + bosses.clamp(0, 3));
    weeklySeconds = math.min(9999999, weeklySeconds + seconds.clamp(0, 3600));
    if (!challenge) {
      chapterBest[stage] = math.max(
        chapterBest[stage] ?? 0,
        seconds.clamp(0, 3600),
      );
      if (victory) chapterWins.add(stage);
    }
  }

  bool canClaimChapter(
    int stage,
    int milestone,
    int duration,
    Set<int> legacyClears,
  ) {
    if (stage < 0 ||
        stage >= 100 ||
        milestone < 0 ||
        milestone > 2 ||
        duration <= 0 ||
        chapterClaims.contains(stage * 3 + milestone)) {
      return false;
    }
    if (legacyClears.contains(stage) || chapterWins.contains(stage)) {
      return true;
    }
    return milestone < 2 &&
        (chapterBest[stage] ?? 0) >= duration * (milestone + 1) ~/ 3;
  }

  static FleetReward chapterReward(int milestone) => switch (milestone) {
    0 => const FleetReward(credits: 40, plans: 1),
    1 => const FleetReward(collectionKeys: 1, food: 10),
    _ => const FleetReward(collectionKeys: 1, techKeys: 1),
  };
  FleetReward? claimChapter(
    int stage,
    int milestone,
    int duration,
    Set<int> legacyClears,
  ) {
    if (!canClaimChapter(stage, milestone, duration, legacyClears)) return null;
    chapterClaims.add(stage * 3 + milestone);
    return chapterReward(milestone);
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'week': week,
    'signInDay': signInDay,
    'signIns': signIns,
    'weeklyRuns': weeklyRuns,
    'weeklyKills': weeklyKills,
    'weeklyBosses': weeklyBosses,
    'weeklySeconds': weeklySeconds,
    'quickPatrolClaimed': quickPatrolClaimed,
    'dailyChests': dailyChests.toList(),
    'weeklyClaims': weeklyClaims.toList(),
    'weeklyChests': weeklyChests.toList(),
    'signInChests': signInChests.toList(),
    'chapterBest': {for (final e in chapterBest.entries) '${e.key}': e.value},
    'chapterWins': chapterWins.toList(),
    'chapterClaims': chapterClaims.toList(),
  };

  static FleetJournal restore(dynamic raw) {
    final j = FleetJournal();
    if (raw is! Map) return j;
    String date(dynamic v) {
      if (v is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
        return '';
      }
      return DateTime.tryParse(v) == null ? '' : v;
    }

    int value(String key, int maximum) {
      final v = raw[key];
      return v is num && v.isFinite ? v.toInt().clamp(0, maximum) : 0;
    }

    Set<int> ids(String key, int n) => raw[key] is List
        ? (raw[key] as List)
              .whereType<int>()
              .where((i) => i >= 0 && i < n)
              .toSet()
        : {};
    j.day = date(raw['day']);
    j.week = date(raw['week']);
    j.signInDay = date(raw['signInDay']);
    j.signIns = value('signIns', 999999);
    j.weeklyRuns = value('weeklyRuns', 99999);
    j.weeklyKills = value('weeklyKills', 9999999);
    j.weeklyBosses = value('weeklyBosses', 99999);
    j.weeklySeconds = value('weeklySeconds', 9999999);
    j.quickPatrolClaimed = raw['quickPatrolClaimed'] == true;
    j.dailyChests = ids('dailyChests', 3);
    j.weeklyClaims = ids('weeklyClaims', 4);
    j.weeklyChests = ids('weeklyChests', 2);
    j.signInChests = ids('signInChests', 5);
    j.chapterWins = ids('chapterWins', 100);
    j.chapterClaims = ids('chapterClaims', 300);
    if (raw['chapterBest'] is Map) {
      for (final e in (raw['chapterBest'] as Map).entries.take(100)) {
        final stage = int.tryParse('${e.key}');
        final seconds = e.value;
        if (stage != null &&
            stage >= 0 &&
            stage < 100 &&
            seconds is num &&
            seconds.isFinite) {
          j.chapterBest[stage] = seconds.toInt().clamp(0, 3600);
        }
      }
    }
    return j;
  }
}
