import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import 'reward_popup.dart';

import '../data/content_catalog.dart';
import '../data/pet_bond.dart';
import '../data/profile.dart';
import '../main.dart';
import '../art/toon_assets.dart';
import '../art/game_icons.dart';
import 'game_slots.dart';
import 'item_info_card.dart';
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
        // v12.14: the refund reads as item chips; what resets and what
        // stays are separate coloured notes.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GameTag('돌려받는 재료', tone: GameTone.good),
            gap(6),
            _costSlots(refund),
            gap(10),
            const GameHint('각성 단계와 선택 스킬은 초기화됩니다', tone: GameTone.danger),
            const GameHint('호감도·육성·승급·오늘의 교감 횟수는 그대로입니다'),
          ],
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
      // v12.14: rules as a labelled block; each awakening step's requirement
      // and cost as two small tables instead of "a · b / c" sentences.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GameInfoBlock(
            label: '호감도 얻기',
            tone: GameTone.good,
            lead: '120초 생존 + 10기 처치 = 호감도 +10',
            detail: '하루 전투 교감 30 · 먹이 선물 2회(모든 펫 공용, 자정 갱신)',
          ),
          gap(8),
          _TierTable(
            label: '각성 조건',
            tone: GameTone.sky,
            columns: const ['펫 Lv', '승급', '호감도'],
            rows: [
              for (var i = 0; i < 3; i++)
                [
                  '${PetBond.levelRequirements[i]}',
                  '${i + 1}',
                  '${PetBond.favorRequirements[i]}',
                ],
            ],
          ),
          gap(8),
          _TierTable(
            label: '각성 비용',
            tone: GameTone.gold,
            columns: const ['츄르', '먹이', '유전자'],
            rows: [
              for (var i = 0; i < 3; i++)
                ['${(i + 1) * 100}', '${(i + 1) * 20}', '${i + 1}'],
            ],
          ),
          gap(8),
          const GameHint('출전 펫에만 적용 · 호감도는 전투 능력과 무관 · 스킬 변경 무료'),
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
            appBar: GameAppBar(
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
        return Scaffold(
          appBar: GameAppBar(
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
              // v12.15: the chick in its frame with its pills, the favour
              // gauge with a heart, today's counts and prices as pictures
              ItemHero(
                image: ToonTile('ships', 3 + pet, size: 64),
                name: petNames[pet],
                rarity: p.petRanks[pet],
                size: 80,
                chips: unlocked
                    ? [
                        ('Lv.${p.petLevels[pet]}', const Color(0xFFFFD43D)),
                        (
                          message('승급 {0}', [p.petRanks[pet]]),
                          const Color(0xFF8FD3FF),
                        ),
                        ('각성 $level/3', const Color(0xFF7CE08A)),
                      ]
                    : [('미구조', const Color(0xFFFF7A6B))],
              ),
              gap(6),
              Row(
                children: [
                  GameIconImage(GameIcons.heart, size: 28),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RasterGauge(
                      minHeight: 12,
                      color: cyan,
                      value: book.favor[pet] / PetBond.favorCap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${book.favor[pet]}/${PetBond.favorCap}',
                    style: const TextStyle(
                      color: cyan,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              gap(4),
              StatGrid([
                StatLine(
                  label: '오늘 교감',
                  value: '${book.combatFavorToday}/30',
                  icon: GameIcons.heart,
                ),
                StatLine(
                  label: '오늘 선물',
                  value: '${book.giftsToday}/2',
                  icon: GameIcons.food,
                ),
              ]),
              gap(6),
              GameActionButton(
                label: '먹이 10 선물 · 호감도 +10',
                displayLabel: '선물 10',
                primary: true,
                image: GameIcons.food,
                onPressed: audible(
                  book.canGift(pet, unlocked: unlocked, food: p.petFood)
                      ? () => _act(context, () => p.giftPet(pet))
                      : null,
                ),
              ),
              gap(10),
              if (cost != null) ...[
                _price(cost, p.credits, p.petFood, p.petShards[pet]),
                if (issue != null) GameHint(issue, tone: GameTone.danger),
                gap(6),
                GameActionButton(
                  label: '펫 각성 ${level + 1}단계 · ${cost.credits} 츄르',
                  displayLabel: message('각성 {0}단계', [level + 1]),
                  primary: true,
                  image: 'assets/art/ui_v13/act_promote.webp',
                  onPressed: audible(
                    issue == null
                        ? () => _act(context, () => p.awakenPet(pet))
                        : null,
                  ),
                ),
              ] else
                const Center(child: ItemPill('최대 각성', Color(0xFFFFD43D))),
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

/// A refund as picture slots with ×N badges.
Widget _costSlots(PetBondCost cost) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    for (final (i, r) in [
      GameReward(GameIcons.churu, cost.credits, '츄르'),
      GameReward(GameIcons.food, cost.food, '먹이'),
      GameReward(GameIcons.gene, cost.shards, '유전자'),
    ].indexed) ...[
      if (i > 0) const SizedBox(width: 10),
      GameRewardSlot(r, size: 58),
    ],
  ],
);

/// An awakening price: each material's picture and amount, red when short.
Widget _price(PetBondCost cost, int credits, int food, int shards) {
  Widget part(String image, int need, int have) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      GameIconImage(image, size: 26),
      const SizedBox(width: 2),
      Text(
        '$need',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: have >= need ? Colors.white : const Color(0xFFFF7A6B),
        ),
      ),
    ],
  );
  return Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xE60B1830),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFF3A5A8C), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          part(GameIcons.churu, cost.credits, credits),
          const SizedBox(width: 10),
          part(GameIcons.food, cost.food, food),
          const SizedBox(width: 10),
          part(GameIcons.gene, cost.shards, shards),
        ],
      ),
    ),
  );
}

/// Awakening steps 1–3 against [columns]: a tagged three-row table.
class _TierTable extends StatelessWidget {
  const _TierTable({
    required this.label,
    required this.tone,
    required this.columns,
    required this.rows,
  });
  final String label;
  final GameTone tone;
  final List<String> columns;
  final List<List<String>> rows;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    Widget cell(String text, {Color? color, bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        tr(text),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? Colors.white,
          fontSize: bold ? GameUi.body : GameUi.caption,
          height: 1.3,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
        ),
      ),
    );
    return GameInset(
      tone: tone,
      child: Column(
        children: [
          GameTag(label, tone: tone),
          const SizedBox(height: 4),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  cell('단계', color: GameTone.muted.color),
                  for (final c in columns) cell(c, color: tone.color),
                ],
              ),
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  children: [
                    cell(
                      message('각성 {0}', [i + 1]),
                      color: GameTone.gold.color,
                    ),
                    for (final v in rows[i]) cell(v, bold: true),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
