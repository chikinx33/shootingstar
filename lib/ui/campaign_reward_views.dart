import '../l10n/app_language.dart';

import 'package:flutter/material.dart';

import '../data/campaign_rewards.dart';
import '../data/content.dart';
import '../data/profile.dart';
import 'components.dart';

Future<void> showCampaignRewardGuide(
  BuildContext context,
  Profile p,
  int stage,
) => showDialog<void>(
  context: context,
  builder: (dialog) {
    final world = stage ~/ 10;
    return GameDialog(
      title: '보스·항로 보상',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GameSectionTitle(
            '${worlds[world].name} ${world + 1}-${stage % 10 + 1}',
          ),
          Text(
            tr('기본 전투 보상·기존 항로 상자에 더해 자동 지급합니다.'),
            style: TextStyle(fontSize: 16),

            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const GameSectionTitle('보스 전용 장비'),
          Text(
            message(
              "이 세계 보스 누적 {0}기 · 회수 대기 {1}개\n1·3·5…기마다 희귀 선체/추진기 교대 확정. 성장 → 장비 → 관리 → 보스 전용 장비에서 회수합니다.",
              [p.bossGear.defeats[world], p.bossGear.pending(world)],
            ),
            style: const TextStyle(fontSize: 16),

            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const GameSectionTitle('보스 회수 · 매 처치'),
          Text(
            tr(CampaignRewardBook.bossRewards[world].summary),
            style: const TextStyle(fontSize: 18),

            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GameSectionTitle(
            p.campaignRewards.bossWorlds.contains(world)
                ? '세계 첫 보스 · 수령 완료'
                : '세계 첫 보스 보너스',
          ),
          Text(
            tr(CampaignRewardBook.firstBossRewards[world].summary),
            style: const TextStyle(fontSize: 18),

            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const GameSectionTitle('항로 완주 · 매 클리어'),
          Text(
            tr(CampaignRewardBook.clearReward(stage).summary),
            style: const TextStyle(fontSize: 18),

            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GameSectionTitle(
            p.campaignRewards.routes.contains(stage)
                ? '항로 첫 보너스 · 수령 완료'
                : '항로 첫 보너스',
          ),
          Text(
            tr(CampaignRewardBook.firstClearReward(stage).summary),
            style: const TextStyle(fontSize: 18),

            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              '30초 이상·10기 이상 격파한 출격에서 지급합니다. 보스를 잡은 뒤 패배해도 보스 회수는 유지됩니다. 완주는 일반 항로의 전체 시간·필수 보스 처치를 요구합니다.',
            ),
            style: TextStyle(fontSize: 16),

            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              '첫 보너스는 이번 확장 이후 세계/항로마다 1회입니다. 이전 완주 이력만으로 자동 지급하지 않으며 재도전으로 받을 수 있습니다. 순환해도 초기화하지 않습니다. 훈련·일일 도전은 별도 규칙입니다.',
            ),
            style: TextStyle(fontSize: 16),

            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  },
);

Future<void> showCampaignRewardReceipt(
  BuildContext context,
  CampaignRewardReceipt r,
) => showDialog<void>(
  context: context,
  builder: (_) => GameDialog(
    title: '출격 보상 내역',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const GameSectionTitle('기본 전투 츄르'),
        Text(
          message("{0} 츄르", [r.baseCredits]),
          style: const TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        for (final (title, reward) in r.entries) ...[
          const SizedBox(height: 16),
          GameSectionTitle(title),
          Text(
            tr(reward.summary.isEmpty ? '보유 상한 도달 · 추가 지급 없음' : reward.summary),
            style: const TextStyle(fontSize: 18),

            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          tr(
            '실제로 증가한 수량입니다. 기존 회수 상자·장비/테크·시즌 보상은 결과 화면에서 확인할 수 있습니다. 다시 열어도 보상을 중복 지급하지 않습니다.',
          ),
          style: TextStyle(fontSize: 16),

          textAlign: TextAlign.center,
        ),
      ],
    ),
  ),
);
