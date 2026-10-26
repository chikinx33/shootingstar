import '../art/game_icons.dart';
import 'item_info_card.dart';
import 'lobby_cat_hero.dart';
import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../data/content.dart';
import '../data/content_catalog.dart';
import '../data/hangar_preset.dart';
import '../data/profile.dart';
import 'components.dart';
import 'catalog_screens.dart';
import 'item_slots.dart';

class HangarPresets extends StatelessWidget {
  const HangarPresets({super.key, required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: GameAppBar(
        title: Text(tr('출격 구성 저장'), textAlign: TextAlign.center),
      ),
      body: AnimatedBuilder(
        animation: profile,
        builder: (context, _) => Column(
          children: [
            CatalogHeader(
              title: '출격 구성',
              status: message('저장 {0} / 6', [
                profile.hangarPresets.where((p) => p != null).length,
              ]),
              icon: Icons.flight,
            ),
            Expanded(
              child: GameSlotList(
                listKey: const Key('preset-items'),
                children: [
                  for (var i = 0; i < 6; i++)
                    GameItemSlot(
                      title: profile.hangarPresets[i]?.name ?? '빈 편성',
                      // v12.15: the saved cat's face (empty: the launch picture)
                      image: _face(profile.hangarPresets[i]?.ship, 72),
                      status: '${i + 1}번',
                      onTap: audible(
                        () => showDialog<void>(
                          context: context,
                          builder: (_) => AnimatedBuilder(
                            animation: profile,
                            builder: (_, _) => GameDialog(
                              title: '출격 편성',
                              child: _slot(context, i),
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

  Widget _slot(BuildContext context, int index) {
    final preset = profile.hangarPresets[index];
    final issue = preset?.issue(profile);
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: a),
        const SizedBox(width: 8),
        Expanded(child: b),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ItemHero(
          image: _face(preset?.ship, 48),
          name: preset?.name ?? '빈 구성',
          rarity: preset == null ? 0 : 3,
          size: 56,
          chips: [
            (message('{0}번', [index + 1]), const Color(0xFF8FD3FF)),
            if (preset != null)
              (ships[preset.ship].name, const Color(0xFFFFD43D)),
          ],
        ),
        if (issue != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GameHint(issue, tone: GameTone.danger),
          ),
        gap(20),
        if (preset == null)
          GameActionButton(
            key: Key('preset-save-$index'),
            primary: true,
            onPressed: audible(() => _save(context, index)),
            label: '현재 구성 저장',
            displayLabel: '편성 저장',
            icon: Icons.save,
          )
        else ...[
          GameActionButton(
            key: Key('preset-load-$index'),
            onPressed: audible(() => _load(context, index, preset)),
            label: '구성 확인 · 적용',
            displayLabel: '편성 적용',
            primary: true,
            icon: Icons.check,
          ),
          gap(12),
          pair(
            GameActionButton(
              key: Key('preset-save-$index'),
              onPressed: audible(() => _save(context, index)),
              label: '현재 구성 덮어쓰기',
              displayLabel: '편성 교체',
            ),
            GameActionButton(
              onPressed: audible(() => _details(context, preset)),
              label: '편성 자세히',
              displayLabel: '자세히',
            ),
          ),
          gap(12),
          pair(
            GameActionButton(
              onPressed: audible(() => _rename(context, index, preset)),
              label: '이름 변경',
            ),
            GameActionButton(
              onPressed: audible(() => _delete(context, index, preset)),
              label: '삭제',
            ),
          ),
        ],
      ],
    );
  }

  /// The cat of a ship (its face picture), or the launch picture.
  static Widget _face(int? ship, double size) => ship == null
      ? GameIconImage(GameIcons.launch, size: size * .8)
      : Image.asset(
          LobbyCatHero.faces[ship.clamp(0, 2)],
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
        );

  /// The two facts a player checks first; the full list opens from '자세히'.
  List<Widget> _brief(HangarPreset p) => [
    _PresetRow('기체', ships[p.ship].name, tone: GameTone.gold),
    _PresetRow('출격 펫', p.pet < 0 ? '없음' : petNames[p.pet], tone: GameTone.good),
  ];

  Future<void> _details(BuildContext context, HangarPreset preset) =>
      showDialog<void>(
        context: context,
        builder: (_) => GameDialog(
          title: '편성 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GameSectionTitle(preset.name),
              gap(8),
              ..._summary(preset),
            ],
          ),
        ),
      );

  List<Widget> _summary(HangarPreset p) => [
    _PresetRow('기체', ships[p.ship].name, tone: GameTone.gold),
    _PresetRow('특기', catTraitFor(p.ship).name, tone: GameTone.gold),
    _PresetRow('출격 펫', p.pet < 0 ? '없음' : petNames[p.pet], tone: GameTone.good),
    if (p.assistPets.isNotEmpty)
      _PresetRow(
        '보조 펫',
        p.assistPets.map((id) => petNames[id]).join(' / '),
        tone: GameTone.good,
      ),
  ];

  Future<String?> _name(
    BuildContext context,
    String title,
    String initial, {
    String? detail,
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        _PresetNameDialog(title: title, initial: initial, detail: detail),
  );

  Future<void> _save(BuildContext context, int slot) async {
    final existing = profile.hangarPresets[slot];
    final name = await _name(
      context,
      existing == null ? '편성 저장' : '편성 교체',
      existing?.name ?? '구성 ${slot + 1}',
      detail: existing == null ? null : '${existing.name}\n이 슬롯을 현재 배치로 교체합니다.',
    );
    if (name == null ||
        !context.mounted ||
        !identical(profile.hangarPresets[slot], existing)) {
      return;
    }
    profile.hangarPresets[slot] = HangarPreset.capture(profile, name);
    profile.contentChanged();
    _message(context, '현재 출격 구성을 저장했습니다.');
  }

  Future<void> _rename(
    BuildContext context,
    int slot,
    HangarPreset preset,
  ) async {
    final name = await _name(context, '이름 변경', preset.name);
    if (name == null || !context.mounted) return;
    // Ignore a stale dialog after an account/progress replacement.
    if (!identical(profile.hangarPresets[slot], preset)) return;
    profile.hangarPresets[slot] = preset.renamed(name);
    profile.contentChanged();
  }

  Future<void> _delete(
    BuildContext context,
    int slot,
    HangarPreset preset,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '편성 삭제',
        actions: [
          GameActionButton(
            onPressed: audible(() => Navigator.pop(dialog, false)),
            label: '취소',
          ),
          GameActionButton(
            primary: true,
            onPressed: audible(() => Navigator.pop(dialog, true)),
            label: '삭제',
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameSectionTitle(preset.name),
            gap(6),
            const GameHint('저장한 구성만 삭제됩니다. 보유 장비와 현재 배치는 유지됩니다.'),
          ],
        ),
      ),
    );
    if (yes != true ||
        !context.mounted ||
        !identical(profile.hangarPresets[slot], preset)) {
      return;
    }
    profile.hangarPresets[slot] = null;
    profile.contentChanged();
  }

  Future<void> _load(
    BuildContext context,
    int slot,
    HangarPreset preset,
  ) async {
    final issue = preset.issue(profile);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '편성 적용',
        actions: [
          GameActionButton(
            onPressed: audible(() => Navigator.pop(dialog, false)),
            label: '적용 취소',
          ),
          GameActionButton(
            primary: true,
            onPressed: audible(
              issue == null ? () => Navigator.pop(dialog, true) : null,
            ),
            label: '이 구성 적용',
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameSectionTitle(preset.name),
            gap(6),
            ..._brief(preset),
            gap(8),
            GameHint(
              issue ?? '현재 배치를 이 구성으로 바꿉니다.',
              tone: issue == null ? GameTone.muted : GameTone.danger,
            ),
          ],
        ),
      ),
    );
    if (yes != true ||
        !context.mounted ||
        !identical(profile.hangarPresets[slot], preset)) {
      return;
    }
    final applied = preset.apply(profile);
    _message(
      context,
      applied ? '출격 구성을 적용했습니다.' : preset.issue(profile) ?? '구성을 적용할 수 없습니다.',
    );
  }

  void _message(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
          content: Text(tr(message), textAlign: TextAlign.center),
        ),
      );
}

class _PresetNameDialog extends StatefulWidget {
  const _PresetNameDialog({
    required this.title,
    required this.initial,
    this.detail,
  });
  final String title, initial;
  final String? detail;
  @override
  State<_PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<_PresetNameDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _save() =>
      Navigator.pop(context, HangarPreset.cleanName(controller.text));
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return GameDialog(
      title: widget.title,
      actions: [
        GameActionButton(
          onPressed: audible(() => Navigator.pop(context)),
          label: '취소',
        ),
        GameActionButton(primary: true, onPressed: audible(_save), label: '저장'),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.detail != null) ...[
            Text(tr(widget.detail!), textAlign: TextAlign.center),
            gap(),
          ],
          TextField(
            controller: controller,
            style: const TextStyle(fontSize: 20),
            maxLength: 24,
            decoration: InputDecoration(labelText: tr('구성 이름')),
            textInputAction: TextInputAction.done,
            onSubmitted: audibleChange((_) => _save()),

            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// One labelled preset fact: a coloured tag beside its value.
class _PresetRow extends StatelessWidget {
  const _PresetRow(this.label, this.value, {this.tone = GameTone.sky});
  final String label, value;
  final GameTone tone;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Center(child: GameTag(label, tone: tone)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tr(value),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: GameUi.body,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
