import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'reward_popup.dart';

import '../data/content.dart';
import '../data/profile.dart';
import '../art/toon_assets.dart';
import '../art/lobby_art.dart';
import 'evolution_codex.dart';
import '../main.dart';
import 'components.dart';
import 'content_hub.dart';
import 'guild_screen.dart';

class SurvivalMeta extends StatelessWidget {
  const SurvivalMeta({
    super.key,
    required this.profile,
    required this.section,
    required this.onChallenge,
    this.onDailyChallenge,
  });
  final Profile profile;
  final int section;
  final VoidCallback? onDailyChallenge;
  final void Function(int) onChallenge;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return section == 4
        ? const EvolutionCodex()
        : GameItemList(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  tr(['', '', '장비 공방', '도전', '진화 도감'][section]),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),

                  textAlign: TextAlign.center,
                ),
                if (section == 3) ...[
                  gap(14),
                  Row(
                    key: const Key('challenge-shortcuts'),
                    children: [
                      if (onDailyChallenge != null)
                        _ChallengeShortcut(
                          id: 'daily',
                          label: '일일',
                          description: '일일 순환 도전 · 교환소',
                          icon: Icons.emoji_events,
                          onTap: onDailyChallenge!,
                        ),
                      _ChallengeShortcut(
                        id: 'season',
                        label: '시즌',
                        description: '시즌 · 일일 임무 · 순찰',
                        icon: Icons.card_giftcard,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: Text(
                                  tr('시즌'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              body: ContentHub(
                                profile: profile,
                                initialPage: 4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _ChallengeShortcut(
                        id: 'guild',
                        label: '길드',
                        description: '길드 토벌',
                        icon: Icons.groups,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => GuildScreen(profile: profile),
                          ),
                        ),
                      ),
                    ],
                  ),
                  gap(14),
                ],
                gap(8),
                if (section == 3) ...[
                  Text(
                    tr('군집 증가 · 보스 체력 +40%\n챕터 완주 시 도전 개방\n첫 승리 별가루 +5'),
                    style: TextStyle(color: muted),

                    textAlign: TextAlign.center,
                  ),
                  gap(),
                  for (int i = 0; i < stages.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Surface(
                        child: Row(
                          children: [
                            ToonTile('bosses', i ~/ 10, size: 48),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                message("{0}\n{1}", [
                                  stages[i].name,
                                  profile.clearedChallenges.contains(i)
                                      ? '도전 완료'
                                      : '군집 돌파 도전',
                                ]),

                                textAlign: TextAlign.center,
                              ),
                            ),
                            TextButton(
                              onPressed: audible(
                                profile.clearedStages.contains(i) &&
                                        profile.canStage(i)
                                    ? () => onChallenge(i)
                                    : null,
                              ),
                              child: Text(
                                tr(
                                  profile.clearedStages.contains(i) &&
                                          profile.canStage(i)
                                      ? '도전'
                                      : '잠김',
                                ),

                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  gap(),
                  Text(
                    tr('성장 임무'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),

                    textAlign: TextAlign.center,
                  ),
                  gap(),
                  for (int i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              tr(Profile.missionNames[i]),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),

                              textAlign: TextAlign.center,
                            ),
                            Text(
                              message("{0} / {1} · 100 츄르 + 별가루 3", [
                                profile.missionProgress(i),
                                Profile.missionTargets[i],
                              ]),
                              style: const TextStyle(
                                fontSize: 14,
                                color: muted,
                              ),

                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: audible(
                                !profile.claimedMissions.contains(i) &&
                                        profile.missionProgress(i) >=
                                            Profile.missionTargets[i]
                                    ? () => claimWithRewardPopup(
                                        context,
                                        profile,
                                        () => profile.claimMission(i),
                                      )
                                    : null,
                              ),
                              child: Text(
                                tr(
                                  profile.claimedMissions.contains(i)
                                      ? '수령 완료'
                                      : '보상 수령',
                                ),

                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
  }
}

/// Fixed navigation: short captions, full accessible destination names.
class _ChallengeShortcut extends StatelessWidget {
  const _ChallengeShortcut({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
  });
  final String id, label, description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final action = audible(onTap);
    return Expanded(
      child: Semantics(
        key: ValueKey('challenge-shortcut-$id'),
        button: true,
        label: tr(description),
        excludeSemantics: true,
        onTap: action,
        child: InkWell(
          onTap: action,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LobbyIcon(icon, size: 52),
                const SizedBox(height: 6),
                Text(
                  tr(label),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'NotoSansKR',
                    fontSize: GameUi.navigationLabel,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
