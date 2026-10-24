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
            CatalogHeader(
              title: '동네 지도',
              icon: Icons.map,
              status:
                  '${profile.campaignLoop + 1}순환 · 조종사 Lv.${profile.pilotLevel + 1}\nXP ${profile.pilotXp} / ${profile.pilotXpNeeded}',
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
                          subtitle: Text(
                            message("{0}/10 완주 · {1}", [
                              profile.activeClears
                                  .where((id) => id ~/ 10 == world)
                                  .length,
                              profile.selectedStage ~/ 10 == world
                                  ? '선택 중'
                                  : profile.canStage(world * 10)
                                  ? '진입 가능'
                                  : '잠김',
                            ]),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, height: 1.3),
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
                icon: Icons.check_circle,
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
          icon: Icons.card_giftcard,
          onPressed: audible(
            () => showCampaignRewardGuide(dialog, profile, id),
          ),
        ),
        GameActionButton(
          label: '이 집 지키기',
          primary: true,
          icon: Icons.shield,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
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
              ],
            ),
          ),
          GameSectionTitle(stages[id].house.owner),
          Text(
            '“${tr(stages[id].house.line)}”',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const GameSectionTitle('이 집을 노리는 보스'),
          for (final style in houseBosses(id, stages[id].bossCount))
            Text(
              tr(style),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          GameCostLine(
            '${stages[id].duration ~/ 60}분 · 보스 ${stages[id].bossCount}회 · 위험도 ${id + 1}',
            icon: Icons.shield,
          ),
          Text(
            tr('집을 지키면 다음 집이 열립니다'),
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// Compact route overview. Decisions and full combat information stay in detail.
class CampaignStageCard extends StatelessWidget {
  const CampaignStageCard({
    super.key,
    required this.title,
    required this.name,
    required this.status,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });
  final String title, name, status, description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label: tr(description),
      excludeSemantics: true,
      onTap: audible(onPressed),
      child: InkWell(
        onTap: audible(onPressed),
        child: Opacity(
          opacity: selected || onPressed != null ? 1 : .58,
          child: Surface(
            active: selected,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tr(title),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(name),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.25),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          tr(status),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
