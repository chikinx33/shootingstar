import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../game/survival_skills.dart';
import 'components.dart';
import 'detail_widgets.dart';
import 'catalog_screens.dart';
import 'item_slots.dart';

/// Read-only recipes come from the combat catalog; browsing never grants power.
class EvolutionCodex extends StatefulWidget {
  const EvolutionCodex({super.key});
  @override
  State<EvolutionCodex> createState() => _EvolutionCodexState();
}

class _EvolutionCodexState extends State<EvolutionCodex> {
  int tab = 0;
  String recipe(SurvivalSkill skill) => skill.passive
      ? '보조 슬롯에 장착해 무기의 진화를 지원합니다.'
      : skill.recipeHint ??
            (skill.partner == null
                ? '고유 모듈 5단계'
                : '${skill.name} 5단계 + ${skillFor(skill.partner!).name}');
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Column(
      children: [
        CatalogHeader(
          title: '진화 도감',
          icon: Icons.auto_stories,
          status:
              '무기 ${survivalSkills.where((s) => !s.passive).length}종 · 보조 ${survivalSkills.where((s) => s.passive).length}종',
        ),
        CatalogTabs(
          labels: const ['무기', '보조'],
          selected: tab,
          onSelected: audibleChange((value) => setState(() => tab = value)),
        ),
        Expanded(
          child: GameSlotList(
            listKey: ValueKey('codex-$tab'),
            children: [
              for (final skill in survivalSkills.where(
                (s) => s.passive == (tab == 1),
              ))
                GameItemSlot(
                  title: skill.name,
                  image: RasterSkillIcon(skill.id, size: 56),
                  status: skill.fusionOnly
                      ? '융합'
                      : (skill.passive ? '보조' : '무기'),
                  semanticLabel: '${skill.name} 진화 상세',
                  onTap: audible(() => detail(context, skill)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> detail(BuildContext context, SurvivalSkill skill) =>
      showDialog<void>(
        context: context,
        builder: (dialog) => GameDialog(
          title: skill.passive ? '보조 스킬' : '무기 진화',
          actions: [
            if (skill.passive)
              GameActionButton(
                label: '도감으로',
                onPressed: audible(() => Navigator.pop(dialog)),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GameActionButton(
                      label: '${skill.name} 진화 자세히',
                      displayLabel: '자세히',
                      onPressed: audible(() => more(dialog, skill)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GameActionButton(
                      label: '도감으로',
                      onPressed: audible(() => Navigator.pop(dialog)),
                    ),
                  ),
                ],
              ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GameDetailHeader(
                image: RasterSkillIcon(skill.id, size: 72),
                title: skill.name,
                status: skill.passive ? '보조 모듈' : '전투 무기',
              ),
              Text(
                tr(skill.description),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              gap(16),
              const GameSectionTitle('진화 조건'),
              Text(
                tr(recipe(skill)),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (!skill.passive && skill.evolution != null) ...[
                gap(8),
                Text(
                  'EVO · ${tr(skill.evolution)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD66B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );

  /// Secondary evolution notes open in a second small popup, never new pages.
  Future<void> more(BuildContext context, SurvivalSkill skill) =>
      showDialog<void>(
        context: context,
        builder: (dialog) => GameDialog(
          title: '자세히',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RasterSkillIcon(skill.id, size: 56),
                  if (skill.partner != null) ...[
                    const SizedBox(width: 8),
                    const RasterIcon(Icons.add, size: 28),
                    const SizedBox(width: 8),
                    RasterSkillIcon(skill.partner!, size: 56),
                  ],
                  const SizedBox(width: 8),
                  const RasterIcon(Icons.auto_awesome, size: 56),
                ],
              ),
              gap(12),
              if (skill.evolution != null)
                GameSectionTitle('EVO · ${skill.evolution}'),
              Text(
                tr(
                  '전투 중 무기 5단계와 대응 보조 스킬 또는 합성 쌍을 준비하세요. 독립 주포와 R·P·N 보급은 현장에서 회수합니다.',
                ),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              gap(12),
              Text(
                tr('도감 열람은 저장된 편성·재화·성장 수치를 바꾸지 않습니다.'),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
