import '../l10n/app_language.dart';

import 'audio_feedback.dart';
import 'module_workshop.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import 'reward_popup.dart';

import '../data/content.dart';
import '../data/profile.dart';
import 'components.dart';
import 'catalog_screens.dart';
import 'survival_meta.dart';
import 'item_slots.dart';

/// Existing permanent research only; branch tabs keep every node legible.
class TalentScreen extends StatefulWidget {
  const TalentScreen({super.key, required this.profile});
  final Profile profile;
  @override
  State<TalentScreen> createState() => _TalentScreenState();
}

class _TalentScreenState extends State<TalentScreen> {
  int branch = 0;
  static const branches = [
    ('attack', Icons.bolt, '화력', '+8% 화력'),
    ('hull', Icons.shield, '선체', '+12% 선체'),
    ('magnet', Icons.radar, '회수', '회수 +3 · 상한112'),
  ];
  Profile get profile => widget.profile;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ModuleWorkshop(profile: profile, embedded: true);
  }

  Widget legacyBuild(BuildContext context) {
    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) => Column(
        children: [
          CatalogHeader(
            title: '영구 연구',
            status: '${profile.credits} 츄르',
            icon: Icons.school,
            action: IconButton(
              tooltip: tr('무기 진화 도감'),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const RasterIcon(Icons.auto_stories, size: 32),
              onPressed: audible(() => _guide(context)),
            ),
          ),
          CatalogTabs(
            labels: const ['화력', '선체', '회수'],
            selected: branch,
            onSelected: audibleChange(
              (value) => setState(() => branch = value),
            ),
          ),
          Expanded(
            child: GameSlotList(
              listKey: ValueKey('research-$branch'),
              children: [
                for (var level = 0; level < maxUpgradeLevel; level++)
                  GameItemSlot(
                    title: '${branches[branch].$3} ${level + 1}',
                    image: RasterIcon(branches[branch].$2, size: 52),
                    selected:
                        profile.upgradeLevel(branches[branch].$1) == level,
                    status: profile.upgradeLevel(branches[branch].$1) > level
                        ? '완료'
                        : '${upgradeCost(level)} 츄르',
                    onTap: audible(
                      () => showDialog<void>(
                        context: context,
                        builder: (_) => AnimatedBuilder(
                          animation: profile,
                          builder: (_, _) => GameDialog(
                            title: '영구 연구',
                            child: _node(context, level),
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
    );
  }

  void _guide(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: GameAppBar(
          title: Text(tr('무기 진화 도감'), textAlign: TextAlign.center),
        ),
        body: SurvivalMeta(profile: profile, section: 4, onChallenge: (_) {}),
      ),
    ),
  );

  Widget _node(BuildContext context, int level) {
    final b = branches[branch],
        actual = profile.upgradeLevel(b.$1),
        done = actual > level,
        next = actual == level;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Surface(
        active: next,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                RasterIcon(
                  done
                      ? Icons.check_circle
                      : next
                      ? b.$2
                      : Icons.lock,
                  size: 64,
                  color: done ? const Color(0xFFA7E6B3) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        message("{0} · {1}단계", [b.$3, level + 1]),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),

                        textAlign: TextAlign.center,
                      ),
                      Text(
                        tr(b.$4),
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        tr(
                          done
                              ? '연구 완료'
                              : next
                              ? '연구 가능'
                              : '앞 단계 연구 필요',
                        ),
                        style: const TextStyle(fontSize: 16),

                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!done)
              GameCostLine('${upgradeCost(level)} 츄르', icon: Icons.hexagon),
            if (!done) ...[
              const SizedBox(height: 12),
              Center(
                child: GameActionButton(
                  key: ValueKey('research-${b.$1}-$level'),
                  label: done ? '연구 완료' : '${b.$3} ${level + 1}단계 연구',
                  displayLabel: done ? '연구 완료' : '연구',
                  primary: next,
                  onPressed: audible(
                    next && profile.credits >= upgradeCost(level)
                        ? () {
                            final before = RewardSnapshot(profile);
                            if (profile.buyUpgrade(b.$1)) {
                              showTransactionFeedback(context, profile, before);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    80,
                                  ),
                                  content: Text(
                                    message("{0} 연구 완료", [b.$4]),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
