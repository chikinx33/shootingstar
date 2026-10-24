/// Original Shootingstar rules, informed by verified SPetAwakeManager method
/// declarations. The reference's costs and skill rules were not recovered.
class PetBondCost {
  const PetBondCost(this.credits, this.food, this.shards);
  final int credits, food, shards;
  String get summary => '$credits 츄르 · 먹이 $food · 유전자 $shards';
}

class PetBond {
  static const favorCap = 300;
  static const maxAwakening = 3;
  static const favorRequirements = [50, 120, 200];
  static const levelRequirements = [5, 10, 15];
  final List<int> favor = List.filled(3, 0);
  final List<int> awakening = List.filled(3, 0);
  final List<int> skills = List.filled(3, 0);
  final List<int> _spentCredits = List.filled(3, 0);
  final List<int> _spentFood = List.filled(3, 0);
  final List<int> _spentShards = List.filled(3, 0);
  final Set<String> _runs = {};
  String day = '';
  int lastClock = 0, combatFavorToday = 0, giftsToday = 0;

  bool _valid(int pet) => pet >= 0 && pet < 3;

  /// A monotonic local clock also protects gifts and combat across rollback.
  bool advance(DateTime now) {
    final millis = now.toUtc().millisecondsSinceEpoch;
    if (millis > lastClock) lastClock = millis;
    final local = DateTime.fromMillisecondsSinceEpoch(
      lastClock,
      isUtc: true,
    ).add(const Duration(hours: 9));
    final nextDay =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    if (day != nextDay) {
      day = nextDay;
      combatFavorToday = 0;
      giftsToday = 0;
      return true;
    }
    return false;
  }

  bool canGift(int pet, {required bool unlocked, required int food}) =>
      _valid(pet) &&
      unlocked &&
      food >= 10 &&
      giftsToday < 2 &&
      favor[pet] < favorCap;

  /// Parent pays ten food only when this operation succeeds.
  bool gift(
    int pet, {
    required bool unlocked,
    required int food,
    required DateTime now,
  }) {
    advance(now);
    if (!canGift(pet, unlocked: unlocked, food: food)) return false;
    favor[pet] = (favor[pet] + 10).clamp(0, favorCap);
    giftsToday++;
    return true;
  }

  int recordRun({
    required int pet,
    required bool unlocked,
    required String runId,
    required int seconds,
    required int kills,
    required DateTime now,
  }) {
    advance(now);
    if (!_valid(pet) ||
        !unlocked ||
        runId.isEmpty ||
        runId.length > 200 ||
        seconds < 120 ||
        kills < 10 ||
        _runs.contains(runId)) {
      return 0;
    }
    _runs.add(runId);
    // Profile separately protects all processed run IDs. This bounded ledger
    // also prevents duplicate callbacks within its own saved history.
    if (_runs.length > 256) _runs.remove(_runs.first);
    final gain = (favorCap - favor[pet]).clamp(0, 10);
    final allowed = gain.clamp(0, (30 - combatFavorToday).clamp(0, 30));
    favor[pet] += allowed;
    combatFavorToday += allowed;
    return allowed;
  }

  PetBondCost? nextCost(int pet) =>
      !_valid(pet) || awakening[pet] >= maxAwakening
      ? null
      : PetBondCost(
          (awakening[pet] + 1) * 100,
          (awakening[pet] + 1) * 20,
          awakening[pet] + 1,
        );

  String? awakeningIssue(
    int pet, {
    required int petLevel,
    required int petRank,
    required int credits,
    required int food,
    required int shards,
  }) {
    if (!_valid(pet)) return '올바른 펫을 선택하세요.';
    if (petLevel <= 0) return '먼저 펫을 구조하세요.';
    final tier = awakening[pet];
    if (tier >= maxAwakening) return '최대 각성에 도달했습니다.';
    if (petLevel < levelRequirements[tier]) {
      return '펫 Lv.${levelRequirements[tier]} 필요';
    }
    if (petRank < tier + 1) return '펫 승급 ${tier + 1}단계 필요';
    if (favor[pet] < favorRequirements[tier]) {
      return '호감도 ${favorRequirements[tier]} 필요';
    }
    final cost = nextCost(pet)!;
    if (credits < cost.credits || food < cost.food || shards < cost.shards) {
      return '각성 재료가 부족합니다.';
    }
    return null;
  }

  /// Returns the charge only on success. Caller deducts this exact charge and
  /// persists both ledgers together before notifying observers.
  PetBondCost? awaken(
    int pet, {
    required int petLevel,
    required int petRank,
    required int credits,
    required int food,
    required int shards,
  }) {
    if (awakeningIssue(
          pet,
          petLevel: petLevel,
          petRank: petRank,
          credits: credits,
          food: food,
          shards: shards,
        ) !=
        null) {
      return null;
    }
    final cost = nextCost(pet)!;
    awakening[pet]++;
    _spentCredits[pet] += cost.credits;
    _spentFood[pet] += cost.food;
    _spentShards[pet] += cost.shards;
    return cost;
  }

  PetBondCost? resetRefund(int pet) => !_valid(pet) || awakening[pet] <= 0
      ? null
      : PetBondCost(_spentCredits[pet], _spentFood[pet], _spentShards[pet]);

  PetBondCost? reset(int pet) {
    final refund = resetRefund(pet);
    if (refund == null) return null;
    awakening[pet] = skills[pet] = 0;
    _spentCredits[pet] = _spentFood[pet] = _spentShards[pet] = 0;
    // Favor and daily limits are retained; reset cannot farm food or favor.
    return refund;
  }

  bool selectSkill(int pet, int skill) {
    if (!_valid(pet) ||
        awakening[pet] <= 0 ||
        skill < 0 ||
        skill > 1 ||
        skills[pet] == skill) {
      return false;
    }
    skills[pet] = skill;
    return true;
  }

  double powerBonus(int pet) => !_valid(pet) || skills[pet] != 0
      ? 0
      : awakening[pet].clamp(0, maxAwakening) * (pet == 0 ? .06 : .05);
  double cooldownReduction(int pet) => !_valid(pet) || skills[pet] != 1
      ? 0
      : awakening[pet].clamp(0, maxAwakening) * .04;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'favor': List<int>.of(favor),
    'awakening': List<int>.of(awakening),
    'skills': List<int>.of(skills),
    'spentCredits': List<int>.of(_spentCredits),
    'spentFood': List<int>.of(_spentFood),
    'spentShards': List<int>.of(_spentShards),
    'day': day,
    'lastClock': lastClock,
    'combatFavorToday': combatFavorToday,
    'giftsToday': giftsToday,
    'runs': _runs.toList(),
  };

  static PetBond restore(dynamic raw) {
    final book = PetBond();
    if (raw is! Map) return book;
    int read(dynamic value, int max) => value is int ? value.clamp(0, max) : 0;
    dynamic at(String field, int i) =>
        raw[field] is List && i < (raw[field] as List).length
        ? raw[field][i]
        : null;
    for (var i = 0; i < 3; i++) {
      book.favor[i] = read(at('favor', i), favorCap);
      book.awakening[i] = read(at('awakening', i), maxAwakening);
      book.skills[i] = book.awakening[i] == 0 ? 0 : read(at('skills', i), 1);
      final total = book.awakening[i] * (book.awakening[i] + 1) ~/ 2;
      book._spentCredits[i] = read(at('spentCredits', i), total * 100);
      book._spentFood[i] = read(at('spentFood', i), total * 20);
      book._spentShards[i] = read(at('spentShards', i), total);
    }
    final ceiling = DateTime.now()
        .toUtc()
        .add(const Duration(days: 2))
        .millisecondsSinceEpoch;
    book.lastClock = read(raw['lastClock'], ceiling);
    book.combatFavorToday = read(raw['combatFavorToday'], 30);
    book.giftsToday = read(raw['giftsToday'], 2);
    if (book.lastClock > 0) {
      // Rebuild the calendar marker from the saved clock. An inconsistent
      // marker must not silently replenish a day's gifts on every reload.
      final local = DateTime.fromMillisecondsSinceEpoch(
        book.lastClock,
        isUtc: true,
      ).add(const Duration(hours: 9));
      book.day =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
    }
    if (raw['runs'] is List) {
      book._runs.addAll(
        (raw['runs'] as List)
            .whereType<String>()
            .where((id) => id.isNotEmpty && id.length <= 200)
            .take(256),
      );
    }
    return book;
  }
}
