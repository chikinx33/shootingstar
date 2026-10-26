import '../l10n/app_language.dart';

import 'package:flutter/material.dart';

import '../data/campaign_rewards.dart';
import '../data/content.dart';
import '../data/fleet_journal.dart';
import '../data/profile.dart';
import 'arcade_home_widgets.dart' show CurrencyArt;
import 'components.dart';

Future<void> showCampaignRewardGuide(
  BuildContext context,
  Profile p,
  int stage,
) => showDialog<void>(
  context: context,
  builder: (dialog) {
    final world = stage ~/ 10;
    final firstClear = p.campaignRewards.routes.contains(stage);
    final firstBoss = p.campaignRewards.bossWorlds.contains(world);
    // v12.14: each reward is a labelled group of item chips; claimed one-time
    // bonuses dim with a "받음" tag; the long rules live in quiet hints.
    return GameDialog(
      title: '보상 안내',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameSectionTitle(stages[stage].house.place),
          const SizedBox(height: 8),
          _RewardGroup(
            label: '지킬 때마다',
            tone: GameTone.good,
            reward: CampaignRewardBook.clearReward(stage),
          ),
          const SizedBox(height: 8),
          _RewardGroup(
            label: '처음 지키면',
            tone: GameTone.gold,
            reward: CampaignRewardBook.firstClearReward(stage),
            claimed: firstClear,
          ),
          const SizedBox(height: 8),
          _RewardGroup(
            label: '보스 처치마다',
            tone: GameTone.danger,
            reward: CampaignRewardBook.bossRewards[world],
          ),
          const SizedBox(height: 8),
          _RewardGroup(
            label: '동네 첫 보스',
            tone: GameTone.gold,
            reward: CampaignRewardBook.firstBossRewards[world],
            claimed: firstBoss,
          ),
          const SizedBox(height: 8),
          GameFactRow([
            GameFact(
              '보스 장비 처치',
              message('{0}기', [p.bossGear.defeats[world]]),
              tone: GameTone.danger,
            ),
            GameFact(
              '받을 보스 장비',
              message('{0}개', [p.bossGear.pending(world)]),
              tone: GameTone.good,
            ),
          ]),
          const SizedBox(height: 6),
          const GameHint('1·3·5…번째 보스마다 희귀 장비 확정'),
          const GameHint('30초·10기 이상 격파 시 보상 지급'),
        ],
      ),
    );
  },
);

class _RewardGroup extends StatelessWidget {
  const _RewardGroup({
    required this.label,
    required this.tone,
    required this.reward,
    this.claimed = false,
  });
  final String label;
  final GameTone tone;
  final FleetReward reward;
  final bool claimed;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final chips = [
      if (reward.credits > 0)
        GameRewardChip('츄르', reward.credits, image: CurrencyArt.churu),
      if (reward.plans > 0)
        GameRewardChip('별가루', reward.plans, image: CurrencyArt.stardust),
      if (reward.food > 0) GameRewardChip('먹이', reward.food),
      if (reward.gearKeys > 0)
        GameRewardChip(
          '장비 보급권',
          reward.gearKeys,
          image: CurrencyArt.gearTicket,
        ),
      if (reward.techKeys > 0)
        GameRewardChip(
          '테크 보급권',
          reward.techKeys,
          image: 'assets/art/icons_v11/blueprint.webp',
        ),
      if (reward.eggs > 0)
        GameRewardChip(
          '펫 구조권',
          reward.eggs,
          image: 'assets/art/icons_v11/egg.webp',
        ),
      if (reward.collectionKeys > 0)
        GameRewardChip(
          '수집품 보급권',
          reward.collectionKeys,
          image: 'assets/art/icons_v11/crate.webp',
        ),
    ];
    return Opacity(
      opacity: claimed ? .55 : 1,
      child: GameInset(
        tone: tone,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GameTag(label, tone: tone),
                if (claimed) ...[
                  const SizedBox(width: 6),
                  const GameTag('받음', tone: GameTone.muted),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (chips.isEmpty)
              const GameHint('보유 상한 도달 · 추가 지급 없음')
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: chips,
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCampaignRewardReceipt(
  BuildContext context,
  CampaignRewardReceipt r,
) => showDialog<void>(
  context: context,
  builder: (_) => GameDialog(
    title: '출격 보상 내역',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RewardGroup(
          label: '기본 전투',
          tone: GameTone.sky,
          reward: FleetReward(credits: r.baseCredits),
        ),
        for (final (title, reward) in r.entries) ...[
          const SizedBox(height: 8),
          _RewardGroup(
            label: title,
            tone: title.startsWith('보스')
                ? GameTone.danger
                : title == '집 지킴'
                ? GameTone.good
                : GameTone.gold,
            reward: reward,
          ),
        ],
        const SizedBox(height: 6),
        const GameHint('실제로 늘어난 수량입니다. 다시 열어도 중복 지급하지 않습니다.'),
      ],
    ),
  ),
);
