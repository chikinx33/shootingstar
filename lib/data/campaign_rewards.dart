import 'fleet_journal.dart';

class CampaignRewardReceipt {
  const CampaignRewardReceipt(this.baseCredits, this.entries);
  final int baseCredits;
  final List<(String, FleetReward)> entries;
  bool get hasExtras => entries.isNotEmpty;
}

/// Existing currencies only. New first bonuses are paid on a future eligible
/// run, never retroactively on load. All first records are lifetime, not loops.
class CampaignRewardBook {
  final Set<int> bossWorlds = {}, routes = {};
  static const bossRewards = [
    FleetReward(plans: 1),
    FleetReward(credits: 12, plans: 1),
    FleetReward(plans: 2),
    FleetReward(plans: 1, food: 5),
    FleetReward(food: 8),
    FleetReward(credits: 8, plans: 2),
    FleetReward(credits: 25),
    FleetReward(plans: 1, food: 5),
    FleetReward(plans: 1, food: 4),
    FleetReward(plans: 2, food: 5),
  ];
  static const firstBossRewards = [
    FleetReward(credits: 40, plans: 2),
    FleetReward(gearKeys: 1, plans: 1),
    FleetReward(techKeys: 1),
    FleetReward(plans: 4, food: 10),
    FleetReward(food: 25, eggs: 1),
    FleetReward(gearKeys: 1, plans: 3),
    FleetReward(credits: 80, plans: 2),
    FleetReward(techKeys: 1, food: 15),
    FleetReward(collectionKeys: 1, plans: 2),
    FleetReward(gearKeys: 1, techKeys: 1, collectionKeys: 1),
  ];
  static FleetReward clearReward(int stage) => FleetReward(
    credits: 20 + stage ~/ 10 * 3 + stage % 10 * 2,
    plans: stage % 10 == 9
        ? 2
        : stage % 10 == 4
        ? 1
        : 0,
  );
  static FleetReward firstClearReward(int stage) =>
      FleetReward(credits: 40 + stage ~/ 10 * 5 + stage % 10 * 2, plans: 2);
  static FleetReward multiply(FleetReward r, int n) => FleetReward(
    credits: r.credits * n,
    plans: r.plans * n,
    food: r.food * n,
    gearKeys: r.gearKeys * n,
    techKeys: r.techKeys * n,
    eggs: r.eggs * n,
    collectionKeys: r.collectionKeys * n,
  );

  List<(String, FleetReward)> settle({
    required int stage,
    required int bosses,
    required bool clear,
    required bool eligible,
  }) {
    if (!eligible || stage < 0 || stage >= 100) return [];
    final world = stage ~/ 10;
    final requiredBosses = stage % 10 == 9
        ? 3
        : stage % 10 == 4
        ? 2
        : 1;
    bosses = bosses.clamp(0, requiredBosses);
    final rewards = <(String, FleetReward)>[];
    if (bosses > 0) {
      rewards.add(('보스 처치 ×$bosses', multiply(bossRewards[world], bosses)));
      if (bossWorlds.add(world)) {
        rewards.add(('동네 첫 보스', firstBossRewards[world]));
      }
    }
    if (clear && bosses >= requiredBosses) {
      rewards.add(('집 지킴', clearReward(stage)));
      if (routes.add(stage))
        rewards.add(('처음 지킨 보너스', firstClearReward(stage)));
    }
    return rewards;
  }

  Map<String, dynamic> toJson() => {
    'bossWorlds': bossWorlds.toList()..sort(),
    'routes': routes.toList()..sort(),
  };
  static CampaignRewardBook restore(dynamic raw) {
    final book = CampaignRewardBook();
    if (raw is! Map) return book;
    for (final (key, limit, target) in [
      ('bossWorlds', 10, book.bossWorlds),
      ('routes', 100, book.routes),
    ]) {
      if (raw[key] is List) {
        target.addAll(
          (raw[key] as List).whereType<int>().where((n) => n >= 0 && n < limit),
        );
      }
    }
    return book;
  }
}
