import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../art/toon_assets.dart';
import '../data/content.dart';
import '../data/houses.dart';
import '../data/profile.dart';
import 'components.dart';
import 'catalog_screens.dart';
import 'campaign_reward_views.dart';
import 'house_tree.dart';
import 'game_slots.dart';
import '../data/campaign_rewards.dart';

class CampaignSelector extends StatelessWidget {
  const CampaignSelector({super.key, required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .86,
        child: Column(
          children: [
            const CatalogHeader(title: '동네 지도', icon: Icons.map, status: ''),
            // v12.14: the pilot's progress as labelled tiles, not one line.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: GameFactRow([
                GameFact(
                  '순환',
                  message('{0}회차', [profile.campaignLoop + 1]),
                  tone: GameTone.gold,
                ),
                GameFact('조종사', 'Lv.${profile.pilotLevel + 1}'),
                GameFact(
                  '경험치',
                  '${profile.pilotXp} / ${profile.pilotXpNeeded}',
                  tone: GameTone.good,
                ),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (var world = 0; world < 10; world++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Surface(
                        padding: EdgeInsets.zero,
                        child: ExpansionTile(
                          key: ValueKey('${profile.campaignLoop}-$world'),
                          initiallyExpanded:
                              profile.selectedStage ~/ 10 == world,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            8,
                            0,
                            8,
                            8,
                          ),
                          leading: ToonTile('worlds', world, size: 56),
                          trailing: const Icon(Icons.expand_more, size: 32),
                          title: Text(
                            '${world + 1}. ${tr(neighborhoodForWorld(world).name)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  message('{0}/10 지킴', [
                                    profile.activeClears
                                        .where((id) => id ~/ 10 == world)
                                        .length,
                                  ]),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.3,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                profile.selectedStage ~/ 10 == world
                                    ? const GameTag('선택 중')
                                    : profile.canStage(world * 10)
                                    ? const GameTag(
                                        '진입 가능',
                                        tone: GameTone.good,
                                      )
                                    : const GameTag('잠김', tone: GameTone.muted),
                              ],
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                tr(neighborhoodForWorld(world).concept),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            HouseTree(
                              firstStage: world * 10,
                              selected: profile.selectedStage,
                              cleared: profile.activeClears.contains,
                              available: profile.canStage,
                              onPick: (id) => _detail(context, id),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: GameActionButton(
                label: '선택 완료',
                icon: Icons.check,
                onPressed: audible(() => Navigator.pop(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _detail(BuildContext context, int id) => showDialog<void>(
    context: context,
    builder: (dialog) => GameDialog(
      title: stages[id].house.place,
      actions: [
        GameActionButton(
          label: '보상 안내',
          image: 'assets/art/menu_v13/supply.webp',
          onPressed: audible(
            () => showCampaignRewardGuide(dialog, profile, id),
          ),
        ),
        GameActionButton(
          label: '수호묘 출동!',
          primary: true,
          image: 'assets/art/menu_v13/launch.webp',
          onPressed: audible(
            profile.canStage(id)
                ? () {
                    profile.selectStage(id);
                    Navigator.pop(dialog);
                  }
                : null,
          ),
        ),
      ],
      // v12.14: labelled groups instead of a stack of same-white lines —
      // who lives here (name plate on the map), the cat's vow (bubble), the
      // bosses (red), and the run's facts in their own tiles.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 120,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      houseMap(id),
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -.5),
                      cacheWidth: 420,
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  bottom: 0,
                  child: Image.asset(houseOwner(id), width: 72, height: 72),
                ),
                Positioned(
                  left: 76,
                  right: 6,
                  bottom: 6,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _OwnerPlate(stages[id].house.owner),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GameQuote(stages[id].house.line, speaker: '수호묘의 다짐'),
          const SizedBox(height: 8),
          GameInset(
            tone: GameTone.danger,
            child: Column(
              children: [
                for (final boss in houseBosses(id, stages[id].bossCount)) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const GameTag('노리는 보스', tone: GameTone.danger),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tr(boss.name),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.3,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GameHint(message('공략: {0}', [boss.tip])),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          GameFactRow([
            GameFact('시간', message('{0}분', [stages[id].duration ~/ 60])),
            GameFact(
              '보스',
              message('{0}회', [stages[id].bossCount]),
              tone: GameTone.danger,
            ),
            GameFact('위험도', '${id + 1}', tone: GameTone.gold),
          ]),
          const SizedBox(height: 6),
          // what one guard pays, as picture slots (v12.15)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GameTag('지키면', tone: GameTone.good),
              for (final r in GameReward.of(
                CampaignRewardBook.clearReward(id),
              )) ...[const SizedBox(width: 8), GameRewardSlot(r, size: 44)],
            ],
          ),
        ],
      ),
    ),
  );
}

/// The house owner's name plate on the map picture.
class _OwnerPlate extends StatelessWidget {
  const _OwnerPlate(this.owner);
  final String owner;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xE60B1830),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: GameTone.gold.color, width: 2),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameTag('지킬 집사'),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr(owner),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GameTone.gold.color,
                  fontSize: 17,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
