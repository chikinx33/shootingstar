import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'reward_popup.dart';

import '../data/advanced_equipment.dart';
import '../data/content_catalog.dart';
import '../data/profile.dart';
import '../main.dart';
import 'compact_choice.dart';
import 'components.dart';
import '../art/toon_assets.dart';

class AdvancedEquipmentScreen extends StatefulWidget {
  const AdvancedEquipmentScreen({
    super.key,
    required this.profile,
    this.initialItemId,
  });
  final Profile profile;
  final int? initialItemId;
  @override
  State<AdvancedEquipmentScreen> createState() =>
      _AdvancedEquipmentScreenState();
}

class _AdvancedEquipmentScreenState extends State<AdvancedEquipmentScreen> {
  Profile get p => widget.profile;
  int? selectedId;
  int selectedMode = 0;

  /// Visible growth section: 0 precision tuning, 1 fusion. Chosen once per
  /// target (fusion when it is the next step) and then only by the player.
  int section = 0;
  int _autoSection(int? id) {
    final target = p.item(id ?? -1) ?? p.gearAt(0);
    final ledger = p.advancedEquipment;
    return ledger.canAscend(target) &&
            (ledger.entry(target.id)?.ascension ?? 0) < 2
        ? 1
        : 0;
  }

  final Set<int> materials = {};
  @override
  void initState() {
    super.initState();
    selectedId = widget.initialItemId;
    selectedMode = p.advancedEquipment.entry(selectedId ?? -1)?.mode ?? 0;
    section = _autoSection(selectedId);
    p.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    p.removeListener(_refresh);
    super.dispose();
  }

  void _act(bool Function() action) {
    final before = RewardSnapshot(p);
    final done = action();
    if (done) {
      final target = p.item(selectedId ?? -1);
      showTransactionFeedback(
        context,
        p,
        before,
        item: target == null
            ? null
            : RewardEntry(
                target.definition.name,
                1,
                Icons.inventory_2,
                atlas: 'equipment',
                index: target.spec,
                rarity: target.rank,
              ),
      );
    }
    if (done) materials.clear();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          // Centered single-page layout: keep the notice above any page bar.
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 160),
          content: Text(
            tr(done ? p.lastLoot : '장비·재료·보유 자원을 다시 확인하세요.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
  }

  String _label(GearItem g) =>
      '${g.definition.name} #${g.id} · ${qualityNames[g.rank]} Lv.${g.level}';
  String _percent(double n) =>
      '${(n * 100).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}%';

  /// v12.4.3 (user 2026-10-25): rules and long notes open here so the
  /// growth decisions fit one phone page without page arrows or scrolling.
  void _guide(GearItem target) => showDialog<void>(
    context: context,
    builder: (_) => GameDialog(
      title: '정밀 성장 안내',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in [
            '기존 강화·합성에 원하는 성능을 더하세요. 정밀 성장한 장비와 저장 편성의 장비는 합성 재료에서 보호됩니다.',
            '우수 등급부터 3단계까지 성장합니다. 한 가지 성향을 선택하며, 성장 후에도 비용 없이 바꿀 수 있습니다.',
            '희귀 등급·정밀 3단계 장비에 같은 부위의 우수 이상 장비 2개를 융합합니다. 성능은 확정되며 대상 장비의 번호와 기본 성장은 유지됩니다.',
            target.definition.slot < 3
                ? '단계마다 화력 +1.5% · 최대 2단계'
                : '단계마다 선체 +2% · 최대 2단계',
            '장착·잠금·강화·정밀 성장·저장 편성의 장비는 재료로 선택할 수 없습니다.',
            '초기화는 정밀·초월 성장만 되돌립니다. 기존 등급·기본 강화·장착·저장 편성은 유지됩니다. 재료가 들어갈 인벤토리 공간이 필요합니다.',
          ]) ...[Text(tr(line), textAlign: TextAlign.center), gap(10)],
        ],
      ),
    ),
  );

  /// Fusion materials are a repeated item choice, so they live in a popup.
  Future<void> _pickMaterials(int targetId) => showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setDialog) {
        final candidates = p.advancedMaterialCandidates(targetId);
        final asc = p.advancedEquipment.entry(targetId)?.ascension ?? 0;
        void toggle(int id, bool on) {
          setState(() => on ? materials.add(id) : materials.remove(id));
          setDialog(() {});
        }

        return GameDialog(
          title: '융합 재료 선택',
          actions: [
            GameActionButton(
              key: const Key('advanced-materials-done'),
              label: '선택 완료',
              primary: true,
              onPressed: audible(() => Navigator.pop(dialog)),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message("선택 재료 {0}/2", [materials.length]),
                textAlign: TextAlign.center,
              ),
              Text(
                tr('장착·잠금·강화·정밀 성장·저장 편성의 장비는 재료로 선택할 수 없습니다.'),
                style: TextStyle(color: muted, fontSize: GameUi.caption),
                textAlign: TextAlign.center,
              ),
              if (candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    tr('사용 가능한 융합 재료가 없습니다.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final g in candidates)
                CheckboxListTile(
                  key: Key('advanced-material-${g.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(_label(g)), textAlign: TextAlign.center),
                  value: materials.contains(g.id),
                  onChanged: audibleChange(
                    asc >= 2 ||
                            (!materials.contains(g.id) && materials.length >= 2)
                        ? null
                        : (value) => toggle(g.id, value == true),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final target = p.item(selectedId ?? -1) ?? p.gearAt(0);
    final ledger = p.advancedEquipment, state = ledger.entry(target.id);
    final mode = state?.mode ?? selectedMode;
    final candidates = p.advancedMaterialCandidates(target.id);
    final validIds = candidates.map((g) => g.id).toSet();
    materials.removeWhere((id) => !validIds.contains(id));
    final ref = state?.refinement ?? 0, asc = state?.ascension ?? 0;
    final fusion = section;
    final canRefine =
        ledger.canRefine(target) &&
        p.credits >= ledger.refineCredits(target.id) &&
        p.blueprints >= ledger.refinePlans(target.id);
    final canAscend =
        ledger.canAscend(target) &&
        materials.length == 2 &&
        p.credits >= ledger.ascendCredits(target.id) &&
        p.blueprints >= ledger.ascendPlans(target.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('장비 정밀 성장'), textAlign: TextAlign.center),
        actions: [
          IconButton(
            key: const Key('advanced-guide'),
            tooltip: tr('정밀 성장 안내'),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const RasterIcon(Icons.help_outline, size: 32),
            onPressed: audible(() => _guide(target)),
          ),
        ],
      ),
      body: GamePages(
        framed: true,
        centerContent: true,
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            onTap: audible(() {}),
            key: ValueKey('advanced-target-${target.id}'),
            initialValue: target.id,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('성장할 장비')),
            items: [
              for (final g in p.inventory)
                DropdownMenuItem(
                  value: g.id,
                  child: Text(
                    tr(_label(g)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    textAlign: TextAlign.center,
                  ),
                ),
            ],
            onChanged: audibleChange(
              (value) => setState(() {
                selectedId = value;
                section = _autoSection(value);
                materials.clear();
                selectedMode = ledger.entry(value ?? -1)?.mode ?? 0;
              }),
            ),
          ),
          gap(10),
          Row(
            children: [
              ToonRarityFrame(
                rank: target.rank,
                child: ToonTile('equipment', target.spec, size: 72),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr(target.definition.name),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      message("{0} · 기본 강화 Lv.{1}", [
                        qualityNames[target.rank],
                        target.level,
                      ]),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      message("정밀 {0}/3 · 초월 {1}/2", [ref, asc]),
                      style: const TextStyle(
                        color: cyan,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          gap(6),
          Text(
            message("화력 +{0} · 선체 +{1} · 회수 +{2}", [
              _percent(ledger.damageBonus([target.id])),
              _percent(ledger.hullBonus([target.id])),
              _percent(ledger.pickupBonus([target.id])),
            ]),
            textAlign: TextAlign.center,
          ),
          Text(
            message("보유 {0} 츄르 · 별가루 {1}", [p.credits, p.blueprints]),
            style: TextStyle(color: muted, fontSize: GameUi.body),
            textAlign: TextAlign.center,
          ),
          gap(10),
          GameChoiceRow(
            children: [
              for (final (i, name) in const [(0, '정밀 조정'), (1, '초월 융합')])
                GameCompactChoice(
                  key: Key('advanced-tab-$i'),
                  title: name,
                  selected: fusion == i,
                  onPressed: audible(() => setState(() => section = i)),
                ),
            ],
          ),
          gap(10),
          if (fusion == 0) ...[
            GameChoiceRow(
              children: [
                for (var i = 0; i < 3; i++)
                  GameCompactChoice(
                    key: Key('advanced-mode-$i'),
                    title: AdvancedEquipment.modeNames[i],
                    caption: AdvancedEquipment.modeEffects[i],
                    selected: mode == i,
                    onPressed: audible(() {
                      if (state != null) {
                        _act(() => p.chooseEquipmentMode(target.id, i));
                      } else {
                        setState(() => selectedMode = i);
                      }
                    }),
                  ),
              ],
            ),
            GameCostLine(
              '${ledger.refineCredits(target.id)} 츄르 · 별가루 ${ledger.refinePlans(target.id)}',
            ),
            GameActionButton(
              key: const Key('advanced-refine'),
              primary: true,
              icon: Icons.tune,
              label: ref >= 3
                  ? '정밀 조정 완료'
                  : '정밀 조정 · ${ledger.refineCredits(target.id)} 츄르 + 별가루 ${ledger.refinePlans(target.id)}',
              displayLabel: ref >= 3 ? '정밀 조정 완료' : '정밀 조정',
              onPressed: audible(
                canRefine
                    ? () => _act(() => p.refineEquipment(target.id, mode))
                    : null,
              ),
            ),
            if (target.rank < 1)
              Text(
                tr('기본 합성으로 우수 등급을 만들면 열립니다.'),
                style: TextStyle(color: muted, fontSize: GameUi.body),
                textAlign: TextAlign.center,
              ),
          ] else ...[
            GameActionButton(
              key: const Key('advanced-materials'),
              icon: Icons.inventory_2,
              label: '융합 재료 선택 · ${materials.length}/2',
              displayLabel: '재료 선택 ${materials.length}/2',
              onPressed: audible(
                asc >= 2 ? null : () => _pickMaterials(target.id),
              ),
            ),
            GameCostLine(
              '${ledger.ascendCredits(target.id)} 츄르 · 별가루 ${ledger.ascendPlans(target.id)}',
            ),
            GameActionButton(
              key: const Key('advanced-ascend'),
              primary: true,
              icon: Icons.compare_arrows,
              label: asc >= 2
                  ? '초월 융합 완료'
                  : '융합 확인 · ${ledger.ascendCredits(target.id)} 츄르 + 별가루 ${ledger.ascendPlans(target.id)}',
              displayLabel: asc >= 2 ? '초월 융합 완료' : '융합 확인',
              onPressed: audible(
                canAscend
                    ? () => _confirmFusion(target, materials.toList())
                    : null,
              ),
            ),
            if (!ledger.canAscend(target) && asc < 2)
              Text(
                tr('조건: 희귀 이상 등급 · 정밀 조정 3단계'),
                style: TextStyle(color: muted, fontSize: GameUi.body),
                textAlign: TextAlign.center,
              ),
          ],
          gap(10),
          GameActionButton(
            label: '정밀 성장 초기화 · 자원·융합 재료 반환',
            displayLabel: '정밀 성장 초기화',
            icon: Icons.refresh,
            key: const Key('advanced-reset'),
            onPressed: audible(
              state == null ? null : () => _confirmReset(target, state),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFusion(GearItem target, List<int> ids) async {
    final ledger = p.advancedEquipment;
    final body = [
      for (final id in ids)
        if (p.item(id) != null) _label(p.item(id)!),
    ].join('\n');
    final accept = await showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '초월 융합 확인',
        actions: [
          GameActionButton(
            label: '취소',
            primary: false,
            onPressed: audible(() => Navigator.pop(dialog, false)),
          ),
          GameActionButton(
            label: '선택한 2개로 융합',
            primary: true,
            onPressed: audible(() => Navigator.pop(dialog, true)),
          ),
        ],
        child: GamePages(
          child: Text(
            message(
              "{0} #{1}\n초월 {2} → {3}\n\n융합할 장비\n{4}\n\n{5} 츄르 · 별가루 {6} 사용\n선택한 재료는 정밀 성장 초기화 때 돌려받습니다.",
              [
                target.definition.name,
                target.id,
                ledger.entry(target.id)!.ascension,
                ledger.entry(target.id)!.ascension + 1,
                body,
                ledger.ascendCredits(target.id),
                ledger.ascendPlans(target.id),
              ],
            ),

            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
    if (accept == true &&
        mounted &&
        identical(ledger, p.advancedEquipment) &&
        identical(target, p.item(target.id))) {
      _act(() => p.ascendEquipment(target.id, ids));
    }
  }

  Future<void> _confirmReset(GearItem target, EquipmentGrowth state) async {
    final ledger = p.advancedEquipment;
    final accept = await showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '정밀 성장 초기화',
        actions: [
          GameActionButton(
            label: '취소',
            primary: false,
            onPressed: audible(() => Navigator.pop(dialog, false)),
          ),
          GameActionButton(
            label: '정밀 성장만 초기화',
            primary: true,
            onPressed: audible(() => Navigator.pop(dialog, true)),
          ),
        ],
        child: Text(
          message(
            "{0} #{1}\n{2} 츄르 · 별가루 {3} · 융합 재료 {4}개를 반환합니다.\n정밀 조정과 초월 단계가 0이 됩니다.",
            [
              target.definition.name,
              target.id,
              state.spentCredits,
              state.spentPlans,
              state.materials.length,
            ],
          ),

          textAlign: TextAlign.center,
        ),
      ),
    );
    if (accept == true &&
        mounted &&
        identical(ledger, p.advancedEquipment) &&
        identical(target, p.item(target.id))) {
      _act(() => p.resetAdvancedEquipment(target.id));
    }
  }
}
