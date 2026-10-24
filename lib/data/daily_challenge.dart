import 'dart:math' as math;

import 'fleet_journal.dart';

/// Original rotating sortie rules. Reference data proves the three-mode UI,
/// refresh/buff/shop structure, not these combat values or exchange prices.
class DailyChallengeEntry {
  const DailyChallengeEntry({
    required this.day,
    required this.variant,
    required this.tier,
    required this.seed,
  });
  final String day;
  final int variant, tier, seed;
  static const double duration = 180;
  int get stageIndex => 0;
  int get requiredBosses => 1;
  double get densityMultiplier => 1 + .15 * tier;
  double get healthMultiplier => 1 + .2 * tier;
  double get waveIntervalMultiplier => variant == 0 ? .82 : 1;
  double get enemySpeedMultiplier => variant == 2 ? 1.15 : 1;
  double get projectileIntervalMultiplier => variant == 1 ? .78 : 1;
  double get pickupMultiplier => variant == 2 ? 1.2 : 1;
  double get spawnIntervalFactor => waveIntervalMultiplier;
  double get enemySpeedFactor => enemySpeedMultiplier;
  double get hostileIntervalFactor => projectileIntervalMultiplier;
  double get bonusPickup => pickupMultiplier - 1;
  double get tierFoeHpFactor => healthMultiplier;
  String get name => DailyChallengeBook.variantNames[variant];
  String get tierName => DailyChallengeBook.tierNames[tier];
}

class DailyChallengeExchange {
  const DailyChallengeExchange(this.name, this.cost, this.limit, this.reward);
  final String name;
  final int cost, limit;
  final FleetReward reward;
}

/// Per-day first-clear ledger; earned tokens persist across rotations.
/// Caller supplies its safe monotonic clock; an additional day check prevents
/// rollback even after save/reload. This is local integrity, not anti-cheat.
class DailyChallengeBook {
  static const tokenCap = 999999;
  static const tierNames = ['정찰', '돌파', '극한'];
  static const tokenRewards = [3, 5, 8];
  static const variantNames = ['돌입 항로', '포화 항로', '고속 항로'];
  static const variantDescriptions = [
    '적 편대가 18% 짧은 간격으로 도착합니다. 먼저 길을 열고 밀집을 피하세요.',
    '적 사격 간격이 22% 짧아집니다. 탄막의 빈 공간으로 이동하세요.',
    '적 이동 속도 +15% · 경험치 회수 범위 +20%. 회피하며 빠르게 성장하세요.',
  ];
  static const exchanges = [
    DailyChallengeExchange('별가루 2', 3, 2, FleetReward(plans: 2)),
    DailyChallengeExchange('펫 먹이 15', 5, 2, FleetReward(food: 15)),
    DailyChallengeExchange('수집품 보급권 1', 8, 1, FleetReward(collectionKeys: 1)),
    DailyChallengeExchange('장비 보급권 1', 12, 1, FleetReward(gearKeys: 1)),
  ];

  String day = '';
  int tokens = 0;
  final Set<int> cleared = {};
  final List<int> purchases = List.filled(exchanges.length, 0);

  static String? _date(dynamic raw) {
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return null;
    }
    final value = DateTime.tryParse('${raw}T00:00:00Z');
    return value != null && value.toIso8601String().substring(0, 10) == raw
        ? raw
        : null;
  }

  static int _int(dynamic value, int maximum) =>
      value is num && value.isFinite && value == value.roundToDouble()
      ? value.toInt().clamp(0, maximum)
      : 0;

  bool advance(DateTime safeUtc) {
    final next = safeUtc
        .toUtc()
        .add(const Duration(hours: 9))
        .toIso8601String()
        .substring(0, 10);
    if (_date(next) == null || (day.isNotEmpty && next.compareTo(day) <= 0)) {
      return false;
    }
    day = next;
    cleared.clear();
    purchases.fillRange(0, purchases.length, 0);
    return true;
  }

  int get variant => day.isEmpty ? 0 : _dayNumber % variantNames.length;
  int get _dayNumber =>
      DateTime.parse('${day}T00:00:00Z').millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  DateTime? get nextResetUtc => day.isEmpty
      ? null
      : DateTime.parse('${day}T00:00:00Z').add(const Duration(hours: 15));

  DailyChallengeEntry? begin(int tier) {
    if (day.isEmpty || tier < 0 || tier >= tierNames.length) return null;
    return DailyChallengeEntry(
      day: day,
      variant: variant,
      tier: tier,
      seed: (_dayNumber * 7919 + tier * 101 + 47) & 0x7fffffff,
    );
  }

  int complete(
    DailyChallengeEntry entry, {
    required bool victory,
    required double seconds,
    required int kills,
    required int bosses,
  }) {
    final expected = begin(entry.tier);
    if (expected == null ||
        expected.day != entry.day ||
        expected.variant != entry.variant ||
        expected.seed != entry.seed ||
        cleared.contains(entry.tier) ||
        !victory ||
        !seconds.isFinite ||
        seconds < DailyChallengeEntry.duration - 1 ||
        seconds > DailyChallengeEntry.duration + 60 ||
        kills < 20 ||
        bosses < 1) {
      return 0;
    }
    cleared.add(entry.tier);
    final reward = math.min(tokenRewards[entry.tier], tokenCap - tokens);
    tokens += reward;
    return reward;
  }

  bool canExchange(int item) =>
      day.isNotEmpty &&
      item >= 0 &&
      item < exchanges.length &&
      purchases[item] < exchanges[item].limit &&
      tokens >= exchanges[item].cost;

  FleetReward? exchange(int item) {
    if (!canExchange(item)) return null;
    final offer = exchanges[item];
    tokens -= offer.cost;
    purchases[item]++;
    return offer.reward;
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'tokens': tokens,
    'cleared': cleared.toList()..sort(),
    'purchases': [...purchases],
  };

  static DailyChallengeBook restore(dynamic raw) {
    final book = DailyChallengeBook();
    if (raw is! Map) return book;
    book.tokens = _int(raw['tokens'], tokenCap);
    book.day = _date(raw['day']) ?? '';
    if (book.day.isEmpty) return book;
    if (raw['cleared'] is List) {
      for (final id in (raw['cleared'] as List).take(100)) {
        if (id is int && id >= 0 && id < tierNames.length) book.cleared.add(id);
      }
    }
    if (raw['purchases'] is List) {
      final values = raw['purchases'] as List;
      for (var i = 0; i < math.min(values.length, exchanges.length); i++) {
        book.purchases[i] = _int(values[i], exchanges[i].limit);
      }
    }
    return book;
  }
}
