import 'package:flutter/material.dart';

import '../data/guardian_quests.dart';
import '../data/profile.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';
import 'game_ui.dart';
import 'item_slots.dart';

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

  Widget _bar(double ratio) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: LinearProgressIndicator(
      value: ratio.clamp(0, 1),
      minHeight: 10,
      backgroundColor: const Color(0xFF223650),
      color: const Color(0xFFFFC84A),
    ),
  );

  Widget _story(BuildContext context) {
    final p = profile;
    final q = p.quests.currentStory;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2140),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB84A), width: 2),
      ),
      child: q == null
          ? Text(
              tr('모모 대장: 이제 너는 진정한 수호묘다. 봉인은 네게 맡기마.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            )
          : Column(
              children: [
                Image.asset(
                  'assets/art/story_v11/momo.webp',
                  key: const Key('story-quest-momo'),
                  width: 84,
                  height: 84,
                ),
                Text(
                  message('모모 대장의 임무 {0}/{1} · {2}', [
                    p.quests.storyStep + 1,
                    storyQuests.length,
                    tr(q.title),
                  ]),
                  key: const Key('story-quest-title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD43D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('“${q.line}”'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 6),
                _bar(p.guardianStat(q.stat) / q.target),
                const SizedBox(height: 4),
                Text(
                  message('{0} {1}/{2} · 보상 {3}', [
                    tr(guardianStatNames[q.stat]!),
                    p.guardianStat(q.stat).clamp(0, q.target),
                    q.target,
                    tr(q.reward.summary),
                  ]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB8C7DA),
                  ),
                ),
                const SizedBox(height: 6),
                GameActionButton(
                  key: const Key('story-quest-claim'),
                  label: p.storyReady ? '보상 받기' : '진행 중',
                  icon: Icons.card_giftcard,
                  primary: p.storyReady,
                  onPressed: p.storyReady
                      ? () => _notify(context, p.claimStory())
                      : null,
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('수호묘 임무·업적'), textAlign: TextAlign.center)),
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
          return Column(
            children: [
              _story(context),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tr('업적 · 끝없이 이어지는 목표'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: GameSlotList(
                  listKey: const ValueKey('achievements'),
                  children: [
                    for (final stat in stats)
                      GameItemSlot(
                        // Name on one line, the tier on the next.
                        title:
                            '${guardianStatNames[stat]}\n${p.quests.nextAchievement(stat).tier}단계',
                        status: p.achievementReady(stat)
                            ? '보상 받기'
                            : '${p.guardianStat(stat)}/${p.quests.nextAchievement(stat).target}',
                        selected: p.achievementReady(stat),
                        rarity: p.achievementReady(stat) ? 5 : 0,
                        image: Image.asset(
                          trophyArt[stat]!,
                          width: GameItemSlot.imageHeight,
                          height: GameItemSlot.imageHeight,
                        ),
                        semanticLabel:
                            '${p.quests.nextAchievement(stat).title} ${p.guardianStat(stat)}/${p.quests.nextAchievement(stat).target} 보상 ${p.quests.nextAchievement(stat).reward.summary}',
                        onTap: audible(
                          p.achievementReady(stat)
                              ? () => _notify(context, p.claimAchievement(stat))
                              : null,
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
