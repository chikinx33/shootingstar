import '../l10n/app_language.dart';

import 'package:flutter/material.dart';

import '../data/campaign_rewards.dart';
import '../data/content.dart';
import '../data/fleet_journal.dart';
import '../data/profile.dart';
import 'components.dart';
import 'game_slots.dart';

/// v12.15 (user 2026-10-26): rewards are picture slots with ×N badges under a
/// coloured header band (the attendance card language); one-time bonuses
/// already taken carry the 받음 check. Two cards per row, no sentences.
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
    return GameDialog(
      title: '보상 안내',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameSectionTitle(stages[stage].house.place),
          const SizedBox(height: 8),
          _RewardCards([
            ('지킬 때마다', CampaignRewardBook.clearReward(stage), false),
            ('처음 지키면', CampaignRewardBook.firstClearReward(stage), firstClear),
            ('보스 처치마다', CampaignRewardBook.bossRewards[world], false),
            ('동네 첫 보스', CampaignRewardBook.firstBossRewards[world], firstBoss),
          ]),
          const SizedBox(height: 8),
          const GameHint('30초·10기 이상 격파 시 보상 지급'),
        ],
      ),
    );
  },
);

/// Reward cards two to a row; an empty reward reads as "상한".
class _RewardCards extends StatelessWidget {
  const _RewardCards(this.cards);
  final List<(String, FleetReward, bool)> cards;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return LayoutBuilder(
      builder: (context, box) {
        const gapX = 8.0;
        final w = (box.maxWidth - gapX) / 2;
        return Wrap(
          spacing: gapX,
          runSpacing: 8,
          children: [
            for (final (label, reward, claimed) in cards)
              SizedBox(
                width: w,
                child: GameReward.of(reward).isEmpty
                    ? GameDayCard(label: label, rewards: const [])
                    : GameDayCard(
                        label: label,
                        rewards: GameReward.of(reward),
                        state: claimed ? SlotState.claimed : SlotState.open,
                        slotSize: 52,
                      ),
              ),
          ],
        );
      },
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
        _RewardCards([
          ('기본 전투', FleetReward(credits: r.baseCredits), false),
          for (final (title, reward) in r.entries) (title, reward, false),
        ]),
        if (r.entries.any((e) => GameReward.of(e.$2).isEmpty)) ...[
          const SizedBox(height: 6),
          const GameHint('빈 칸은 보유 상한에 닿아 더 받지 못한 보상입니다'),
        ],
      ],
    ),
  ),
);
