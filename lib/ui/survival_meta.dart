import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'catalog_screens.dart' show RewardChips, RewardGroup;

import 'reward_popup.dart';

import '../data/content.dart';
import '../data/profile.dart';
import '../art/lobby_art.dart';
import 'evolution_codex.dart';
import 'components.dart';
import 'content_hub.dart';
import 'game_motion.dart';
import 'game_decor.dart';
import 'guild_screen.dart';
import '../data/houses.dart';

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
                RibbonTitle(
                  ['', '', '장비 공방', '도전', '진화 도감'][section],
                  width: 340,
                  height: 64,
                  size: 26,
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
                              appBar: GameAppBar(
                                title: Text(
                                  tr('시즌 원정'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              body: ContentHub(
                                profile: profile,
                                initialPage: 4,
                                showNavigation: false,
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
                  // v12.14: rule, unlock and reward as labelled tiles
                  const GameFactRow([
                    GameFact('규칙', '보스 체력 +40%', tone: GameTone.danger),
                    GameFact('개방', '집을 지킨 뒤'),
                    GameFact('첫 승리', '별가루 +5', tone: GameTone.good),
                  ]),
                  gap(6),
                  const GameHint('적 무리가 더 많이 몰려옵니다'),
                  gap(),
                  for (int i = 0; i < stages.length; i++)
                    StaggerIn(
                      index: i,
                      child: _ChallengeRow(
                        stage: i,
                        cleared: profile.clearedChallenges.contains(i),
                        open:
                            profile.clearedStages.contains(i) &&
                            profile.canStage(i),
                        onChallenge: () => onChallenge(i),
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
                            GameHint(
                              message('진행 {0} / {1}', [
                                profile.missionProgress(i),
                                Profile.missionTargets[i],
                              ]),
                              tone: GameTone.sky,
                            ),
                            gap(6),
                            RewardGroup(
                              label: '보상',
                              claimed: profile.claimedMissions.contains(i),
                              chips: const RewardChips(credits: 100, plans: 3),
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

/// One challenge: the house it is fought over, its state and the action
/// (v12.8 — every house shows its own picture; locked ones are greyed).
class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({
    required this.stage,
    required this.cleared,
    required this.open,
    required this.onChallenge,
  });
  final int stage;
  final bool cleared, open;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    const grey = ColorFilter.matrix([
      .3, .5, .1, 0, 0, //
      .3, .5, .1, 0, 0,
      .3, .5, .1, 0, 0,
      0, 0, 0, 1, 0,
    ]);
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        houseMap(stage),
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        cacheWidth: 200,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Surface(
        active: open && !cleared,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                open
                    ? picture
                    : ColorFiltered(colorFilter: grey, child: picture),
                if (!open)
                  const Icon(Icons.lock, size: 34, color: Color(0xFFE6EDF5)),
                if (cleared)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Image.asset(
                      'assets/art/menu_v13/achievement.webp',
                      width: 30,
                      height: 30,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Text(
                    tr(stages[stage].name),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(cleared ? '도전 완료' : '군집 돌파 도전'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: cleared
                          ? const Color(0xFF7FE0A0)
                          : const Color(0xFFFFC85C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 76,
              child: open
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 48),
                        backgroundColor: const Color(0xFFFFCC47),
                        foregroundColor: const Color(0xFF202838),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: audible(onChallenge),
                      child: Text(
                        tr('도전'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  : Text(
                      tr('잠김'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8DA2B6),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
