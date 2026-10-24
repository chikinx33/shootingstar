import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../data/control_preferences.dart';
import '../data/profile.dart';
import 'compact_choice.dart';
import 'components.dart';

class ControlSettingsScreen extends StatefulWidget {
  const ControlSettingsScreen({super.key, required this.profile});
  final Profile profile;
  @override
  State<ControlSettingsScreen> createState() => _ControlSettingsScreenState();
}

class _ControlSettingsScreenState extends State<ControlSettingsScreen> {
  Profile get p => widget.profile;
  Offset? anchor;
  Offset sample = Offset.zero;
  void update({
    int? sensitivity,
    int? deadZone,
    bool? leftActions,
    bool? followTouch,
  }) {
    final c = p.controls;
    p.updateControls(
      ControlPreferences(
        sensitivity: sensitivity ?? c.sensitivity,
        deadZone: deadZone ?? c.deadZone,
        leftActions: leftActions ?? c.leftActions,
        followTouch: followTouch ?? c.followTouch,
      ),
    );
    setState(() {
      anchor = null;
      sample = Offset.zero;
    });
  }

  void move(Offset point) {
    setState(() {
      anchor ??= point;
      // drag steering preview: how far the cat would move
      sample = (point - anchor!) * p.controls.dragScale;
    });
  }

  void release() => setState(() {
    anchor = null;
    sample = Offset.zero;
  });

  /// v12.4.3 (user 2026-10-25): explanations live in this popup so the
  /// settings themselves fit one phone page without arrows or scrolling.
  void _guide() => showDialog<void>(
    context: context,
    builder: (_) => GameDialog(
      title: '조작 안내',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in const [
            '기체 최고 속도·공격·보상은 같습니다. 손을 떼면 기존처럼 전투 시간이 5%로 느려집니다.',
            '손가락 따라가기: 누른 곳 바로 위로 고양이가 날아갑니다',
            '드래그 이동: 민 만큼만 움직이고 손을 멈추면 바로 멈춥니다',
            '드래그 속도: 손가락 이동의 0.9배 · 1.15배 · 1.4배',
            '능력 버튼 왼쪽: 항성포·파일럿 능력을 왼쪽에 표시',
            '시험 영역은 실제 전투나 보상을 변경하지 않습니다.',
          ]) ...[
            Text(tr(line), textAlign: TextAlign.center),
            const SizedBox(height: 10),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final c = p.controls;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('조작·음향'), textAlign: TextAlign.center),
        actions: [
          IconButton(
            key: const Key('control-guide'),
            tooltip: tr('조작 안내'),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const RasterIcon(Icons.help_outline, size: 32),
            onPressed: audible(_guide),
          ),
        ],
      ),
      body: SafeArea(
        child: GamePages(
          framed: true,
          centerContent: true,
          padding: const EdgeInsets.all(16),
          children: [
            GameChoiceRow(
              label: '조작 방식',
              children: [
                GameCompactChoice(
                  title: '손가락 따라가기',
                  caption: '누른 곳으로',
                  icon: Icons.ads_click,
                  selected: c.followTouch,
                  onPressed: audible(() => update(followTouch: true)),
                ),
                GameCompactChoice(
                  title: '드래그 이동',
                  caption: '민 만큼만',
                  icon: Icons.gamepad,
                  selected: !c.followTouch,
                  onPressed: audible(() => update(followTouch: false)),
                ),
              ],
            ),
            gap(10),
            GameChoiceRow(
              label: '드래그 속도',
              children: [
                for (final option in const [(0, '느리게'), (1, '기본'), (2, '빠르게')])
                  GameCompactChoice(
                    title: option.$2,
                    selected: c.sensitivity == option.$1,
                    onPressed: audible(() => update(sensitivity: option.$1)),
                  ),
              ],
            ),
            gap(10),
            Listener(
              key: const Key('steering-test-pad'),
              onPointerDown: (e) => move(e.localPosition),
              onPointerMove: (e) => move(e.localPosition),
              onPointerUp: (_) => release(),
              onPointerCancel: (_) => release(),
              child: RasterPanel(
                child: SizedBox(
                  height: 72,
                  child: Center(
                    child: Text(
                      message("조작 시험: 누르고 움직여 보세요\n가로 {0} · 세로 {1}", [
                        sample.dx.toStringAsFixed(0),
                        sample.dy.toStringAsFixed(0),
                      ]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            gap(10),
            GameChoiceRow(
              label: '능력 버튼 위치',
              children: [
                GameCompactChoice(
                  title: '오른쪽',
                  selected: !c.leftActions,
                  onPressed: audible(() => update(leftActions: false)),
                ),
                GameCompactChoice(
                  title: '왼쪽',
                  selected: c.leftActions,
                  onPressed: audible(() => update(leftActions: true)),
                ),
              ],
            ),
            gap(6),
            RasterSwitchListTile(
              title: Text(tr('효과음·배경음'), textAlign: TextAlign.center),
              value: p.soundEnabled,
              onChanged: audibleChange((value) {
                p.updateSettings(soundEnabled: value);
                setState(() {});
              }),
            ),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    message("음량 {0}%", [(p.volume * 100).round()]),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: p.volume,
                    onChanged: audibleChange((value) {
                      p.updateSettings(volume: value);
                      setState(() {});
                    }),
                    label: '${(p.volume * 100).round()}%',
                  ),
                ),
              ],
            ),
            gap(6),
            GameActionButton(
              label: '조작 기본값 복원',
              icon: Icons.restore,
              onPressed: audible(() {
                p.updateControls(const ControlPreferences());
                release();
              }),
            ),
          ],
        ),
      ),
    );
  }
}
