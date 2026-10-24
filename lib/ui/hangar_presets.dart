import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

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
      appBar: AppBar(title: Text(tr('출격 구성 저장'), textAlign: TextAlign.center)),
      body: AnimatedBuilder(
        animation: profile,
        builder: (context, _) => Column(
          children: [
            CatalogHeader(
              title: '출격 구성',
              status:
                  '${profile.hangarPresets.where((p) => p != null).length} / 6 저장 · 장비의 현재 성능 적용',
              icon: Icons.flight,
            ),
            Expanded(
              child: GameSlotList(
                listKey: const Key('preset-items'),
                children: [
                  for (var i = 0; i < 6; i++)
                    GameItemSlot(
                      title: profile.hangarPresets[i]?.name ?? '빈 편성',
                      image: const RasterIcon(Icons.flight, size: 52),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 8),
        Expanded(child: b),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const RasterIcon(Icons.flight, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${index + 1}  ${preset?.name ?? tr('빈 구성')}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        gap(8),
        Text(
          preset == null ? tr('지금 배치를 이 칸에 저장합니다.') : tr(_brief(preset)),
          style: const TextStyle(fontSize: GameUi.body),
          textAlign: TextAlign.center,
        ),
        if (issue != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr(issue),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
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
            icon: Icons.check_circle,
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

  /// The two facts a player checks first; the full list opens from '자세히'.
  String _brief(HangarPreset p) => [
    '${ships[p.ship].name} · ${pilots[p.pilot].name}',
    '${armaments[p.armament].name} · ${equipmentOptions[p.equipment].name}',
  ].join('\n');

  Future<void> _details(BuildContext context, HangarPreset preset) =>
      showDialog<void>(
        context: context,
        builder: (_) => GameDialog(
          title: '편성 정보',
          child: Text(
            message("{0}\n{1}", [preset.name, _summary(preset)]),
            textAlign: TextAlign.center,
          ),
        ),
      );

  String _summary(HangarPreset p) => [
    '${ships[p.ship].name} · ${pilots[p.pilot].name}',
    '${armaments[p.armament].name} · ${equipmentOptions[p.equipment].name}',
    '장비: ${p.gearIds.map((id) => profile.item(id)?.definition.name ?? '소실된 장비').join(' / ')}',
    '테크: ${p.techIds.isEmpty ? '미장착' : p.techIds.map((id) => techNames[id]).join(' / ')}',
    '출격 펫: ${p.pet < 0 ? '없음' : petNames[p.pet]}',
    if (p.assistPets.isNotEmpty)
      '보조 펫: ${p.assistPets.map((id) => petNames[id]).join(' / ')}',
  ].join('\n');

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
        child: Text(
          message("{0}\n저장한 구성만 삭제됩니다. 보유 장비와 현재 배치는 유지됩니다.", [preset.name]),
          textAlign: TextAlign.center,
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
        child: Text(
          message("{0}\n{1}\n\n{2}", [
            preset.name,
            _brief(preset),
            issue ?? '현재 배치를 이 구성으로 바꿉니다.',
          ]),
          textAlign: TextAlign.center,
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
