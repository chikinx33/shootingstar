import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/campaign_rewards.dart';
import 'package:shootingstar/data/campaign.dart';
import 'package:shootingstar/data/run_rewards.dart';

int finish(
  Profile p,
  String id, {
  int stage = 0,
  bool win = true,
  int? seconds,
  int? bosses,
  bool training = false,
  bool challenge = false,
  int kills = 100,
}) => p.completeRun(
  runId: id,
  victory: win,
  stageIndex: stage,
  kills: kills,
  level: 5,
  seconds: seconds ?? stages[stage].duration,
  training: training,
  challenge: challenge,
  bossesDefeated: bosses ?? stages[stage].bossCount,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('all 100 routes pay clear and first rewards once without altering ownership or progression', () async {
    final p = await Profile.load();
    final weapons = p.armamentCollection.toJson();
    for (var stage = 0; stage < 100; stage++) {
      final before = p.credits;
      final base = RunRewards(
        seconds: stages[stage].duration,
        kills: 100,
        bosses: stages[stage].bossCount,
        victory: true,
      ).credits;
      final earned = finish(p, 'stage-$stage', stage: stage);
      expect(
        earned,
        greaterThanOrEqualTo(
          base +
              CampaignRewardBook.clearReward(stage).credits +
              CampaignRewardBook.firstClearReward(stage).credits,
        ),
      );
      expect(p.credits - before, earned);
      expect(
        p.lastCampaignReward!.entries.map((e) => e.$1),
        containsAll(['항로 완주', '항로 첫 보너스']),
      );
    }
    expect(p.campaignRewards.routes.length, 100);
    expect(p.campaignRewards.bossWorlds.length, 10);
    expect(p.campaignLoop, 1);
    expect(p.selectedStage, 0);
    expect(p.armamentCollection.toJson(), weapons);
    finish(p, 'loop-2');
    expect(p.lastCampaignReward!.entries.any((e) => e.$1.contains('첫')), false);
    await p.save();
    p.dispose();
  });
  test('defeated bosses secure world resources on loss and world first persists across routes', () async {
    final p = await Profile.load();
    p.clearedStages.add(19);
    p.blueprints = 0;
    final keys = p.techKeys;
    final first = finish(
      p,
      'boss-loss',
      stage: 20,
      win: false,
      seconds: 30,
      bosses: 1,
      kills: 10,
    );
    expect(first, 51);
    expect(p.blueprints, 3);
    expect(p.techKeys, keys + 1);
    expect(p.campaignRewards.bossWorlds, {2});
    expect(p.campaignRewards.routes, isEmpty);
    finish(
      p,
      'boss-loss-2',
      stage: 20,
      win: false,
      seconds: 30,
      bosses: 1,
      kills: 10,
    );
    expect(p.blueprints, 6);
    expect(p.techKeys, keys + 1);
    expect(p.lastCampaignReward!.entries.length, 1);
    await p.save();
    p.dispose();
  });
  test(
    'first-route clear is additive and repeat has no one-time windfall',
    () async {
      final p = await Profile.load();
      p.blueprints = 0;
      final first = finish(p, 'first');
      expect(first, 312);
      expect(p.credits, 462);
      expect(p.blueprints, 8);
      final second = finish(p, 'repeat');
      expect(second, 232);
      expect(p.lastCampaignReward!.entries.map((e) => e.$1).toList(), [
        '세계 보스 회수 ×1',
        '항로 완주',
      ]);
      await p.save();
      p.dispose();
    },
  );
  test(
    'same run and reload do not duplicate rewards or erase first ledgers',
    () async {
      final p = await Profile.load();
      finish(p, 'idempotent');
      await p.save();
      final before = p.exportProgress();
      expect(finish(p, 'idempotent'), 0);
      expect(p.exportProgress(), before);
      final loaded = await Profile.load();
      expect(finish(loaded, 'idempotent'), 0);
      expect(loaded.campaignRewards.toJson(), p.campaignRewards.toJson());
      expect(loaded.credits, p.credits);
      expect(loaded.blueprints, p.blueprints);
      loaded.dispose();
      p.dispose();
    },
  );
  test('insufficient progress, missing bosses and training cannot mint new clear bonuses', () async {
    final p = await Profile.load();
    expect(finish(p, 'training', training: true), 0);
    expect(p.campaignRewards.toJson(), {'bossWorlds': [], 'routes': []});
    expect(finish(p, 'short', seconds: 29, bosses: 1), 0);
    expect(p.lastCampaignReward, isNull);
    finish(p, 'missing-boss', bosses: 0);
    expect(p.campaignRewards.routes, isEmpty);
    expect(p.campaignRewards.bossWorlds, isEmpty);
    finish(p, 'missing-time', seconds: 40, bosses: 1);
    expect(p.campaignRewards.routes, isEmpty);
    expect(p.campaignRewards.bossWorlds, {0});
    await p.save();
    p.dispose();
  });
  test('training, locked routes, chapter challenges and lost progress preserve their separate gates', () async {
    final p = await Profile.load();
    expect(finish(p, 'locked', stage: 10), 0);
    expect(finish(p, 'unavailable-challenge', challenge: true), 0);
    p.clearedStages.add(0);
    finish(p, 'chapter-challenge', challenge: true);
    expect(p.campaignRewards.routes, isEmpty);
    expect(p.campaignRewards.bossWorlds, {0});
    expect(p.clearedChallenges, {0});
    await p.save();
    p.dispose();
  });
  test('legacy clear records do not auto-grant and remain eligible for one new bonus on replay', () async {
    final p = await Profile.load();
    final old = p.exportProgress();
    old.remove('campaignRewardsVersion');
    old.remove('campaignRewards');
    old['clearedStages'] = [0, 1];
    old['credits'] = 777;
    old['armamentCollection'] = {'pulse': 4, 'shotgun': 2};
    old['selectedArmament'] = 4;
    await p.replaceProgress(old);
    expect(p.credits, 777);
    expect(p.campaignRewards.routes, isEmpty);
    finish(p, 'legacy-replay');
    expect(p.campaignRewards.routes, {0});
    expect(p.activeArmamentIndex, 4);
    expect(p.activeArmamentLevel, 2);
    final next = p.exportProgress();
    expect(next['campaignRewardsVersion'], 1);
    await p.replaceProgress(next);
    expect(p.campaignRewards.routes, {0});
    expect(p.armamentCollection.toJson(), {'pulse': 4, 'shotgun': 2});
    p.dispose();
  });
  test('resource caps display real positive deltas and never remove existing resources', () async {
    final p = await Profile.load();
    p.credits = 9999999;
    p.blueprints = 999999;
    p.petFood = 999999;
    final amount = finish(p, 'at-cap');
    expect(amount, 0);
    expect(p.credits, 9999999);
    expect(p.blueprints, greaterThanOrEqualTo(999999));
    for (final (_, r) in p.lastCampaignReward!.entries) {
      expect(r.credits, 0);
      expect(r.plans, 0);
      expect(r.food, 0);
    }
    expect(p.campaignRewards.routes, {0});
    await p.save();
    p.dispose();
  });
  test('malformed local records are bounded and serializable without touching other data', () {
    final b = CampaignRewardBook.restore({
      'bossWorlds': [-1, 0, 0, 9, 10, '1'],
      'routes': [0, 99, 100, -1, '3'],
    });
    expect(b.bossWorlds, {0, 9});
    expect(b.routes, {0, 99});
    expect(
      CampaignRewardBook.restore(jsonDecode(jsonEncode(b.toJson()))).toJson(),
      b.toJson(),
    );
  });
  test(
    'boss counts are clamped and multi-boss clears require the full chain',
    () async {
      final p = await Profile.load();
      p.clearedStages.add(8);
      finish(p, 'partial-gate', stage: 9, bosses: 2);
      expect(p.campaignRewards.routes, isEmpty);
      finish(p, 'whole-gate', stage: 9, bosses: 999);
      expect(p.campaignRewards.routes, {9});
      expect(p.lastCampaignReward!.entries.first.$1, '세계 보스 회수 ×3');
      await p.save();
      p.dispose();
    },
  );
}
