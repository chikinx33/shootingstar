import '../l10n/app_language.dart';

import 'audio_feedback.dart';
import 'module_workshop.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import 'reward_popup.dart';

import '../data/armament_collection.dart';
import '../data/combat_loadout.dart';
import '../data/profile.dart';
import 'catalog_screens.dart';
import 'components.dart';
import 'item_slots.dart';
import 'detail_widgets.dart';
import '../art/armament_art.dart';

/// Only the ten weapon entries scroll. Detail and decisions use fixed pages.
class ArmamentHangar extends StatelessWidget {
  const ArmamentHangar({super.key, required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ModuleWorkshop(profile: profile);
  }

  Widget legacyBuild(BuildContext context) {
    return Scaffold(
      appBar: GameAppBar(title: Text(tr('주무기 소유·성장'), textAlign: TextAlign.center)),
      body: AnimatedBuilder(
        animation: profile,
        builder: (context, _) => Column(
          children: [
            CatalogHeader(
              title: '주무기 격납고',
              status:
                  '보유 ${profile.armamentCollection.ownedCount}/10 · ${profile.credits} 츄르 · 별가루 ${profile.blueprints}',
              icon: Icons.rocket_launch,
            ),
            Expanded(
              child: GameSlotList(
                listKey: const Key('armament-items'),
                children: [
                  for (final a in armaments)
                    GameItemSlot(
                      key: ValueKey('armament-detail-${a.id}'),
                      title: a.name,
                      image: ArmamentArt(a.id),
                      status: profile.armamentCollection.owns(a.id)
                          ? 'Lv.${profile.armamentCollection.level(a.id)}'
                          : '미보유',
                      selected:
                          profile.activeArmamentIndex == armaments.indexOf(a),
                      semanticLabel: '${a.name} 소유·성장 상세',
                      onTap: audible(() => _detail(context, a)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _detail(
    BuildContext context,
    ArmamentSpec a,
  ) => showDialog<void>(
    context: context,
    builder: (dialog) => AnimatedBuilder(
      animation: profile,
      builder: (_, _) {
        final ledger = profile.armamentCollection;
        final owned = ledger.owns(a.id), level = ledger.level(a.id);
        final cost = ArmamentCollection.upgradeCredits(level);
        final plans = ArmamentCollection.upgradeBlueprints(level);
        final atMax = level >= ArmamentCollection.maxLevel;
        return GameDialog(
          title: a.name,
          actions: [
            if (!owned)
              GameActionButton(
                key: ValueKey('armament-unlock-${a.id}'),
                primary: true,
                label: '${a.name} 해금',
                displayLabel: '확정 해금',
                icon: Icons.lock_open,
                onPressed: audible(
                  profile.credits >= ArmamentCollection.unlockCredits &&
                          profile.blueprints >=
                              ArmamentCollection.unlockBlueprints
                      ? () => _act(
                          context,
                          () => profile.unlockArmament(a.id),
                          '주무기를 영구 소유했습니다.',
                          itemName: a.name,
                        )
                      : null,
                ),
              ),
            if (owned) ...[
              if (profile.activeArmamentIndex != armaments.indexOf(a))
                GameActionButton(
                  key: ValueKey('armament-equip-${a.id}'),
                  primary: true,
                  label: '${a.name} 장착',
                  displayLabel:
                      profile.activeArmamentIndex == armaments.indexOf(a)
                      ? '장착 중'
                      : '장착',
                  icon: Icons.check,
                  onPressed: audible(
                    profile.activeArmamentIndex == armaments.indexOf(a)
                        ? null
                        : () {
                            profile.selectArmament(armaments.indexOf(a));
                            RewardFlights.show(context, [
                              RewardEntry(a.name, 1, Icons.rocket_launch),
                            ]);
                          },
                  ),
                ),
              if (!atMax)
                GameActionButton(
                  key: ValueKey('armament-upgrade-${a.id}'),
                  primary: true,
                  label: '${a.name} 강화',
                  displayLabel: atMax ? '최대 강화' : '강화 +1',
                  icon: Icons.upgrade,
                  onPressed: audible(
                    !atMax &&
                            profile.credits >= cost &&
                            profile.blueprints >= plans
                        ? () => _act(
                            context,
                            () => profile.upgradeArmament(
                              a.id,
                              expectedLevel: level,
                            ),
                            '주무기 강화 +1 · 영구 저장',
                            itemName: a.name,
                          )
                        : null,
                  ),
                ),
              if (level > 0)
                GameActionButton(
                  key: ValueKey('armament-reset-${a.id}'),
                  label: '${a.name} 강화 초기화',
                  displayLabel: '강화 초기화',
                  icon: Icons.restart_alt,
                  onPressed: audible(() => _reset(context, a, level)),
                ),
            ],
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GameDetailHeader(
                image: ArmamentArt(a.id, size: 72),
                title: owned ? '영구 강화 $level/10' : '미보유',
                status:
                    '${profile.activeArmamentIndex == armaments.indexOf(a) ? '장착 중 · ' : ''}주무기 피해 +${level * 2}%',
              ),
              Text(tr(a.detail), textAlign: TextAlign.center),
              gap(8),
              Text(
                tr(
                  owned
                      ? (atMax ? '최대 강화 완료' : '강화 $cost 츄르 · 별가루 $plans')
                      : '해금 ${ArmamentCollection.unlockCredits} 츄르 · 별가루 ${ArmamentCollection.unlockBlueprints}',
                ),

                textAlign: TextAlign.center,
              ),
              Text(
                message("보유 {0} 츄르 · 별가루 {1}", [
                  profile.credits,
                  profile.blueprints,
                ]),
                style: const TextStyle(fontSize: 14, color: Color(0xFFB9D0DF)),

                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    ),
  );

  void _act(
    BuildContext context,
    bool Function() action,
    String success, {
    String? itemName,
  }) {
    final before = RewardSnapshot(profile);
    final done = action();
    if (done) {
      showTransactionFeedback(
        context,
        profile,
        before,
        item: itemName == null
            ? null
            : RewardEntry(itemName, 1, Icons.rocket_launch),
      );
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
          content: Text(
            tr(done ? success : '보유 자원과 주무기 상태를 다시 확인하세요.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
  }

  Future<void> _reset(BuildContext context, ArmamentSpec a, int level) async {
    final ledger = profile.armamentCollection;
    final credits = ledger.refundCredits(a.id),
        plans = ledger.refundBlueprints(a.id);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '강화 초기화',
        actions: [
          GameActionButton(
            label: '취소',
            onPressed: audible(() => Navigator.pop(dialog, false)),
          ),
          GameActionButton(
            primary: true,
            label: '재료 반환 · 초기화',
            displayLabel: '반환·초기화',
            onPressed: audible(() => Navigator.pop(dialog, true)),
          ),
        ],
        child: Text(
          message(
            "{0} · 강화 {1} → 0\n{2} 츄르 + 별가루 {3} 전액 반환\n소유·장착·편성은 유지됩니다. 자원 상한을 넘으면 초기화할 수 없습니다.",
            [a.name, level, credits, plans],
          ),

          textAlign: TextAlign.center,
        ),
      ),
    );
    if (yes == true &&
        context.mounted &&
        identical(ledger, profile.armamentCollection)) {
      _act(
        context,
        () => profile.resetArmament(a.id, expectedLevel: level),
        '강화 재료를 전액 반환했습니다.',
      );
    }
  }
}
