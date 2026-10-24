import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../game/engine.dart';
import '../art/module_aircraft_art.dart';
import 'components.dart';

/// Only the selectable slots float above the darkened, frozen battlefield.
class UpgradeSlots extends StatelessWidget {
  const UpgradeSlots({
    super.key,
    required this.game,
    required this.onChoose,
    required this.onReroll,
    this.selected,
    this.onReplace,
  });
  final GameEngine game;
  final ValueChanged<String> onChoose;
  final VoidCallback onReroll;
  final VoidCallback? onReplace;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ColoredBox(
      key: const Key('upgrade-dark-backdrop'),
      color: const Color(0xD9091523),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: tr(
                    game.chestSelection
                        ? '보스 보급 진화 선택'
                        : '레벨 ${game.level} 스킬 선택. 전투 일시정지',
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < game.choices.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(child: _slot(context, game.choices[i], i)),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!game.chestSelection && game.rerolls > 0) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: SizedBox(
                      width: 264,
                      child: GameActionButton(
                        label: '다시 뽑기 ${game.rerolls}회',
                        displayLabel: '재추첨 ${game.rerolls}회',
                        icon: Icons.refresh,
                        onPressed: audible(selected == null ? onReroll : null),
                      ),
                    ),
                  ),
                ],
                if (onReplace != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: GameActionButton(
                      label: '보조 교체',
                      icon: Icons.swap_horiz,
                      onPressed: audible(selected == null ? onReplace : null),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slot(BuildContext context, UpgradeChoice choice, int index) {
    final skill = !choice.specialization && choice.id != 'repair';
    // v12 growth card ids ('enh|…', 'evo|…', 'ult|…') are not skills
    final passive =
        skill && !choice.id.contains('|') && game.isPassiveSkill(choice.id);
    final rank = skill
        ? ((passive ? game.passives : game.upgrades)[choice.id] ?? 0)
        : 0;
    // v12 growth cards: blue enhance, purple evolve, gold ultimate
    final growthColor = switch (choice.growth) {
      'enh' => const Color(0xFF5FB8FF),
      'evo' => const Color(0xFFC08BFF),
      'ult' => const Color(0xFFFFC85C),
      'new' => const Color(0xFF73DFFF),
      _ => null,
    };
    final growthId = choice.id.contains('|')
        ? choice.id.substring(choice.id.indexOf('|') + 1)
        : null;
    final color = growthColor != null
        ? growthColor
        : choice.evolution
        ? const Color(0xFFFFC85C)
        : passive
        ? const Color(0xFF86EDB4)
        : const Color(0xFF73DFFF);
    final chosen = selected == choice.id;
    return TweenAnimationBuilder<double>(
      key: ValueKey('entry-${choice.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 65),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - t)),
          child: child,
        ),
      ),
      child: Semantics(
        button: true,
        label: tr(choice.title),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('upgrade-${choice.id}'),
            onTap: audible(
              selected == null ? () => onChoose(choice.id) : null,
              cue: 'pick',
            ),
            onLongPress: audible(
              () => showDialog<void>(
                context: context,
                builder: (_) => GameDialog(
                  title: choice.title,
                  child: Text(
                    tr(game.choiceDetail(choice)),
                    style: const TextStyle(fontSize: 16),

                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: chosen
                      ? [color.withValues(alpha: .8), const Color(0xFF24475C)]
                      : [const Color(0xFF28495E), const Color(0xFF102638)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: chosen ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: chosen ? .5 : .12),
                    blurRadius: chosen ? 18 : 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(
                      choice.growth == 'enh'
                          ? '강화'
                          : choice.growth == 'evo'
                          ? '진화'
                          : choice.growth == 'ult'
                          ? '궁극'
                          : choice.growth == 'new'
                          ? 'NEW'
                          : choice.specialization
                          ? '특화'
                          : choice.evolution
                          ? 'EVO'
                          : passive
                          ? '보조'
                          : skill
                          ? '무기'
                          : '회복',
                    ),
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),

                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (choice.iconKey.startsWith('part:') && game.unifiedModules)
                    ModulePartIcon(
                      game
                          .moduleLoadout!
                          .parts[choice.iconKey.substring(5)]!
                          .definition,
                      size: 44,
                    )
                  else
                    RasterSkillIcon(choice.iconKey, size: 44, color: color),
                  const SizedBox(height: 10),
                  Text(
                    tr(choice.title.replaceAll(' ', '\n')),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (growthId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      choice.growth == 'ult'
                          ? tr('변신!')
                          : '${tr('강화')} ${_dots(game.enh(growthId))}\n'
                                '${tr('진화')} ${_dots(game.evo(growthId))}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ] else if (skill && choice.growth != 'new') ...[
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        choice.evolution
                            ? '진화'
                            : 'Lv.$rank → ${(rank + 1).clamp(1, 5)}',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: color, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    tr(choice.description),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                  if (chosen)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(Icons.check_circle, size: 28),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _dots(int filled) =>
      List.generate(3, (i) => i < filled ? '●' : '○').join();
}
