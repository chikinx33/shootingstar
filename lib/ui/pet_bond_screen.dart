import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'reward_popup.dart';

import '../data/content_catalog.dart';
import '../data/pet_bond.dart';
import '../data/profile.dart';
import '../main.dart';
import '../art/toon_assets.dart';
import 'compact_choice.dart';
import 'components.dart';

class PetBondScreen extends StatelessWidget {
  const PetBondScreen({super.key, required this.profile, required this.pet});
  final Profile profile;
  final int pet;

  void _act(BuildContext context, bool Function() action) {
    final before = RewardSnapshot(profile);
    if (!action()) return;
    showTransactionFeedback(
      context,
      profile,
      before,
      item: RewardEntry(
        petNames[pet],
        1,
        Icons.pets,
        atlas: 'ships',
        index: pet + 3,
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          // Centered single-page layout: keep the notice above any page bar.
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 160),
          content: Text(tr(profile.lastLoot), textAlign: TextAlign.center),
        ),
      );
  }

  Future<void> _reset(BuildContext context) async {
    final book = profile.petBond;
    final refund = book.resetRefund(pet);
    if (refund == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '펫 각성 초기화',
        actions: [
          GameActionButton(
            label: '취소',
            onPressed: audible(() => Navigator.pop(dialog, false)),
          ),
          GameActionButton(
            label: '각성 초기화',
            primary: true,
            icon: Icons.refresh,
            onPressed: audible(() => Navigator.pop(dialog, true)),
          ),
        ],
        child: Text(
          tr(
            '각성에 사용한 ${refund.summary}을 돌려받습니다.\n'
            '각성 단계와 선택 스킬은 초기화하며 호감도, 기존 육성·승급, 오늘의 교감 횟수는 유지합니다.',
          ),

          textAlign: TextAlign.center,
        ),
      ),
    );
    // An account replacement while a dialog is open must not reset new data.
    if (accepted == true &&
        context.mounted &&
        identical(book, profile.petBond)) {
      _act(context, () => profile.resetPetAwakening(pet));
    }
  }

  String _skillDescription(int skill, int level) {
    final tier = level == 0 ? 1 : level;
    if (skill == 1) return '출전 펫의 행동 간격 ${tier * 4}% 단축';
    return switch (pet) {
      0 => '출전 펫 에너지탄 피해량 +${tier * 6}%',
      1 => '출전 펫의 선체 회복량 +${tier * 5}%',
      _ => '출전 펫의 탄환 제거 반경 +${tier * 5}%',
    };
  }

  /// Rules and the requirement table stay one tap away instead of paging.
  void _guide(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => GameDialog(
      title: '교감·각성 안내',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(
              '출전 펫과 120초 이상 생존하고 적 10기 이상 처치하면 호감도 +10. '
              '하루 전투 교감 +30, 먹이 선물 2회까지 모든 펫이 함께 사용합니다. 한국 시간 자정에 갱신됩니다.',
            ),
            textAlign: TextAlign.center,
          ),
          gap(12),
          Text(
            tr('단계별 각성'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          gap(8),
          for (var i = 0; i < 3; i++) ...[
            Text(
              tr(
                '각성 ${i + 1} · Lv.${PetBond.levelRequirements[i]} / 승급 ${i + 1} / 호감도 ${PetBond.favorRequirements[i]}\n'
                '${(i + 1) * 100} 츄르 · 먹이 ${(i + 1) * 20} · 유전자 ${i + 1}',
              ),
              textAlign: TextAlign.center,
            ),
            gap(8),
          ],
          gap(4),
          Text(
            tr('출전 펫에만 적용됩니다. 호감도 자체는 전투 능력을 올리지 않습니다. 선택 변경은 무료입니다.'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) {
        final p = profile;
        if (pet < 0 || pet >= petNames.length) {
          return Scaffold(
            appBar: AppBar(
              title: Text(tr('펫 교감·각성'), textAlign: TextAlign.center),
            ),
            body: Center(
              child: Text(tr('올바른 펫을 선택하세요.'), textAlign: TextAlign.center),
            ),
          );
        }
        final book = p.petBond;
        final unlocked = p.petLevels[pet] > 0;
        final level = book.awakening[pet];
        final cost = book.nextCost(pet);
        final issue = book.awakeningIssue(
          pet,
          petLevel: p.petLevels[pet],
          petRank: p.petRanks[pet],
          credits: p.credits,
          food: p.petFood,
          shards: p.petShards[pet],
        );
        final rescued = unlocked
            ? 'Lv.${p.petLevels[pet]} · 승급 ${p.petRanks[pet]}단계 · 각성 $level/3'
            : '구조가 필요한 펫입니다.';
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('펫 교감·각성'), textAlign: TextAlign.center),
            actions: [
              IconButton(
                key: const Key('pet-bond-guide'),
                tooltip: tr('교감·각성 안내'),
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const RasterIcon(Icons.help_outline, size: 32),
                onPressed: audible(() => _guide(context)),
              ),
            ],
          ),
          // v12.4.3 (user 2026-10-25): one phone page. Rules, the awakening
          // requirement table and skill notes open from the AppBar guide.
          body: GamePages(
            framed: true,
            centerContent: true,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              Row(
                children: [
                  ToonTile('ships', 3 + pet, size: 80),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tr(petNames[pet]),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(tr(rescued), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ],
              ),
              gap(6),
              Row(
                children: [
                  Text(
                    message("호감도 {0}/{1}", [book.favor[pet], PetBond.favorCap]),
                    style: const TextStyle(
                      color: cyan,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RasterGauge(
                      minHeight: 12,
                      color: cyan,
                      value: book.favor[pet] / PetBond.favorCap,
                    ),
                  ),
                ],
              ),
              gap(4),
              Text(
                message("오늘 전투 교감 {0}/30 · 선물 {1}/2", [
                  book.combatFavorToday,
                  book.giftsToday,
                ]),
                style: TextStyle(color: muted, fontSize: GameUi.body),
                textAlign: TextAlign.center,
              ),
              gap(6),
              GameActionButton(
                label: '먹이 10 선물 · 호감도 +10',
                displayLabel: '먹이 10 선물',
                primary: true,
                icon: Icons.favorite,
                onPressed: audible(
                  book.canGift(pet, unlocked: unlocked, food: p.petFood)
                      ? () => _act(context, () => p.giftPet(pet))
                      : null,
                ),
              ),
              gap(10),
              Text(
                message("보유 {0} 츄르 · 먹이 {1} · 유전자 {2}", [
                  p.credits,
                  p.petFood,
                  p.petShards[pet],
                ]),
                style: const TextStyle(color: cyan, fontSize: GameUi.body),
                textAlign: TextAlign.center,
              ),
              if (cost != null) ...[
                Text(
                  tr(issue ?? '각성 조건을 충족했습니다.'),
                  style: TextStyle(
                    color: issue == null ? cyan : muted,
                    fontSize: GameUi.body,
                  ),
                  textAlign: TextAlign.center,
                ),
                gap(6),
                GameActionButton(
                  label: '펫 각성 ${level + 1}단계 · ${cost.credits} 츄르',
                  displayLabel: '각성 ${level + 1}단계 · ${cost.credits} 츄르',
                  primary: true,
                  icon: Icons.auto_awesome,
                  onPressed: audible(
                    issue == null
                        ? () => _act(context, () => p.awakenPet(pet))
                        : null,
                  ),
                ),
              ] else
                Text(
                  tr('최대 각성에 도달했습니다.'),
                  style: const TextStyle(color: cyan, fontSize: GameUi.body),
                  textAlign: TextAlign.center,
                ),
              gap(10),
              GameChoiceRow(
                label: '각성 스킬 · 한 가지 선택',
                children: [
                  for (var skill = 0; skill < 2; skill++)
                    GameCompactChoice(
                      title: skill == 0 ? '전문 행동' : '신속 동행',
                      caption: _skillDescription(skill, level),
                      selected: level > 0 && book.skills[pet] == skill,
                      onPressed: audible(
                        unlocked && level > 0 && book.skills[pet] != skill
                            ? () => _act(
                                context,
                                () => p.selectPetAwakeSkill(pet, skill),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              gap(10),
              GameActionButton(
                label: '각성 재료 반환·초기화',
                displayLabel: '각성 되돌리기',
                icon: Icons.refresh,
                onPressed: audible(
                  unlocked && level > 0 ? () => _reset(context) : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
