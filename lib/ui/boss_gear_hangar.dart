import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../data/profile.dart';
import '../data/content.dart';
import '../data/content_catalog.dart';
import '../art/toon_assets.dart';
import 'components.dart';
import 'reward_popup.dart';
import 'item_slots.dart';

class BossGearHangar extends StatelessWidget {
  const BossGearHangar({super.key, required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: GameAppBar(title: Text(tr('보스 전용 장비'), textAlign: TextAlign.center)),
      body: AnimatedBuilder(
        animation: profile,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                message("{0}\n인벤토리 {1}/240", [
                  profile.activeBossSetWorld >= 0
                      ? '활성: ${worlds[profile.activeBossSetWorld].name} 2피스'
                      : '세트 미장착 · 같은 세계 희귀 이상 선체+추진기',
                  profile.inventory.length,
                ]),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),

                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: GameSlotList(
                listKey: const Key('boss-gear-items'),
                children: [
                  for (var world = 0; world < 10; world++)
                    GameItemSlot(
                      title: worlds[world].name,
                      image: ToonTile('worlds', world, size: 56),
                      status: '대기 ${profile.bossGear.pending(world)}',
                      onTap: audible(
                        () => showDialog<void>(
                          context: context,
                          builder: (_) => AnimatedBuilder(
                            animation: profile,
                            builder: (_, _) => GameDialog(
                              title: worlds[world].name,
                              child: _worldCard(context, world),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _worldCard(BuildContext context, int world) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(child: ToonTile('worlds', world, size: 96)),
        GameSectionTitle(worlds[world].name),
        Text(
          message("보스 {0}기 · 회수 대기 {1}개", [
            profile.bossGear.defeats[world],
            profile.bossGear.pending(world),
          ]),
          style: const TextStyle(fontSize: 18),

          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message("다음 회수: {0}", [
            gearCatalog[profile.bossGear.nextSpec(world)].name,
          ]),
          style: const TextStyle(fontSize: 16),

          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          tr(gearCatalog[12 + world * 2].perk),
          style: const TextStyle(fontSize: 16),

          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            '보스 누적1·3·5…기마다 두 부위 교대 확정. 희귀·보호 잠금으로 지급하며 보관 탭에서 장착합니다. 인벤토리가 가득 차도 대기는 사라지지 않습니다.',
          ),
          style: TextStyle(fontSize: 16),

          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Center(
          child: GameActionButton(
            label: '${worlds[world].name} 전용 장비 회수',
            displayLabel: '장비 회수',
            primary: true,
            icon: Icons.inventory_2,
            onPressed: audible(
              profile.bossGear.pending(world) > 0 &&
                      profile.inventory.length < 240
                  ? () => claimWithRewardPopup(
                      context,
                      profile,
                      () => profile.claimBossGear(world),
                      title: '보스 장비 회수',
                    )
                  : null,
            ),
          ),
        ),
      ],
    ),
  );
}
