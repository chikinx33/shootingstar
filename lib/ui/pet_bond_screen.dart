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
import 'arcade_home_widgets.dart' show CurrencyArt;
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
            GameInfoBlock(
              label: '돌려받는 재료',
              tone: GameTone.good,
              children: [const SizedBox(height: 6), _costChips(refund)],
            ),
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
                        const SizedBox(height: 4),
                        if (unlocked)
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _Pair('Lv', '${p.petLevels[pet]}'),
                              _Pair(
                                '승급',
                                message('{0}단계', [p.petRanks[pet]]),
                                tone: GameTone.sky,
                              ),
                              _Pair('각성', '$level/3', tone: GameTone.good),
                            ],
                          )
                        else
                          const GameHint(
                            '구조가 필요한 펫입니다.',
                            tone: GameTone.danger,
                          ),
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
              _pairLine([
                ('오늘 전투 교감', '${book.combatFavorToday}/30', GameTone.sky),
                ('오늘 선물', '${book.giftsToday}/2', GameTone.sky),
              ]),
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
              // v12.14: holdings as coloured label + value pairs.
              _pairLine([
                ('보유 츄르', '${p.credits}', GameTone.gold),
                ('먹이', '${p.petFood}', GameTone.good),
                ('유전자', '${p.petShards[pet]}', GameTone.sky),
              ]),
              if (cost != null) ...[
                GameHint(
                  issue ?? '각성 조건을 충족했습니다.',
                  tone: issue == null ? GameTone.good : GameTone.danger,
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

List<Widget> _holdingChips(int credits, int food, int shards) => [
  GameRewardChip('츄르', credits, image: CurrencyArt.churu),
  GameRewardChip('먹이', food),
  GameRewardChip('유전자', shards),
];

Widget _costChips(PetBondCost cost) => Wrap(
  alignment: WrapAlignment.center,
  spacing: 6,
  runSpacing: 6,
  children: _holdingChips(cost.credits, cost.food, cost.shards),
);

/// Several "label value" pairs as one paragraph: it wraps like text, so the
/// pager keeps it as lines instead of one item per pair.
Widget _pairLine(List<(String, String, GameTone)> pairs) => Builder(
  builder: (context) {
    AppLanguage.watch(context);
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, (label, value, tone)) in pairs.indexed) ...[
            if (i > 0) const TextSpan(text: '    '),
            TextSpan(
              text: '${tr(label)} ',
              style: TextStyle(color: tone.color, fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: GameUi.body),
    );
  },
);

/// "label value" inline: the label in its tone colour, the value in bold
/// white, one text line high so the one-page layout keeps its height.
class _Pair extends StatelessWidget {
  const _Pair(this.label, this.value, {this.tone = GameTone.gold});
  final String label, value;
  final GameTone tone;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${tr(label)} ',
            style: TextStyle(color: tone.color, fontWeight: FontWeight.w800),
          ),
          TextSpan(
            text: tr(value),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: GameUi.body),
    );
  }
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
