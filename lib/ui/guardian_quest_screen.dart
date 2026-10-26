import 'package:flutter/material.dart';

import 'components.dart';

import 'game_decor.dart';

import '../data/guardian_quests.dart';
import '../data/profile.dart';
import '../l10n/app_language.dart';
import 'fleet_activity_screen.dart' show QuestRow;
import 'game_slots.dart';
import '../art/game_icons.dart';

/// Captain Momo's story quest on top, endless achievements below.

/// Each achievement has its own trophy (user 2026-10-25).
const trophyArt = {
  GuardianStat.flights: 'assets/art/menu_v13/trophy_flights.webp',
  GuardianStat.kills: 'assets/art/menu_v13/trophy_kills.webp',
  GuardianStat.bosses: 'assets/art/menu_v13/trophy_bosses.webp',
  GuardianStat.stagesCleared: 'assets/art/menu_v13/trophy_stages.webp',
  GuardianStat.worldsCleared: 'assets/art/menu_v13/trophy_worlds.webp',
  GuardianStat.gearUpgrades: 'assets/art/menu_v13/trophy_gear_upgrades.webp',
  GuardianStat.gearOwned: 'assets/art/menu_v13/trophy_gear_owned.webp',
  GuardianStat.pilotLevel: 'assets/art/menu_v13/trophy_pilot_level.webp',
  GuardianStat.chickLevel: 'assets/art/menu_v13/trophy_chick_level.webp',
};

class GuardianQuestScreen extends StatelessWidget {
  const GuardianQuestScreen({super.key, required this.profile});
  final Profile profile;

  void _notify(BuildContext context, String? line) {
    if (line == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        content: Text(
          message('보상 획득 · {0}', [tr(line)]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _bar(double ratio) => KitGauge(ratio, height: 14);

  /// v12.15: a quest reward as picture slots (a guaranteed gear piece shows
  /// the armour sprite in its rarity rim).
  static List<GameReward> rewards(QuestReward r) => [
    if (r.churu > 0) GameReward(GameIcons.churu, r.churu, '츄르'),
    if (r.stardust > 0) GameReward(GameIcons.stardust, r.stardust, '별가루'),
    if (r.gearRarity != null)
      GameReward(
        'assets/art/ship_parts/sunshine/armor.webp',
        1,
        '${const ['일반', '고급', '희귀', '영웅', '전설'][r.gearRarity!]} 장비',
        rarity: r.gearRarity! + 1,
      ),
  ];

  Widget _story(BuildContext context) {
    final p = profile;
    final q = p.quests.currentStory;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Surface(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: q == null
            ? Text(
                tr('모모 대장: 이제 너는 진정한 수호묘다. 봉인은 네게 맡기마.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              )
            : Column(
                children: [
                  Row(
                    children: [
                      MascotImage(
                        'assets/art/story_v11/momo.webp',
                        key: const Key('story-quest-momo'),
                        size: 64,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            GameTag(
                              message('모모 대장의 임무 {0}/{1}', [
                                p.quests.storyStep + 1,
                                storyQuests.length,
                              ]),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tr(q.title),
                              key: const Key('story-quest-title'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.3,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFD43D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: _bar(
                                    p.guardianStat(q.stat) / q.target,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${p.guardianStat(q.stat).clamp(0, q.target)}/${q.target}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: GameUi.caption,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GameQuote(q.line),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final r in rewards(q.reward))
                              GameRewardSlot(r, size: 44),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: GameActionButton(
                          key: const Key('story-quest-claim'),
                          label: p.storyReady ? '임무 보상 받기' : '진행 중',
                          displayLabel: p.storyReady ? '받기' : '진행 중',
                          image: GameIcons.chest,
                          primary: p.storyReady,
                          onPressed: p.storyReady
                              ? () => _notify(context, p.claimStory())
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: GameAppBar(
        title: Text(tr('수호묘 임무·업적'), textAlign: TextAlign.center),
      ),
      body: AnimatedBuilder(
        animation: profile,
        builder: (context, _) {
          final p = profile;
          final stats = [...GuardianStat.values]
            ..sort((a, b) {
              final r = (p.achievementReady(b) ? 1 : 0).compareTo(
                p.achievementReady(a) ? 1 : 0,
              );
              return r != 0 ? r : a.index.compareTo(b.index);
            });
          // v12.15: achievements are a quest list — trophy, name with its
          // tier tag and gauge, reward slots, a small claim button.
          return Column(
            children: [
              _story(context),
              Expanded(
                child: ListView(
                  key: const ValueKey('achievements'),
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                  children: [
                    for (final stat in stats)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: QuestRow(
                          key: ValueKey('achievement-${stat.name}'),
                          icon: trophyArt[stat]!,
                          iconSize: 52,
                          name: guardianStatNames[stat]!,
                          tag: message('{0}단계', [
                            p.quests.nextAchievement(stat).tier,
                          ]),
                          progress: p.guardianStat(stat),
                          target: p.quests.nextAchievement(stat).target,
                          rewards: rewards(
                            p.quests.nextAchievement(stat).reward,
                          ),
                          claimed: false,
                          claimLabel: '${guardianStatNames[stat]} 업적 보상 받기',
                          onClaim: () =>
                              _notify(context, p.claimAchievement(stat)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
