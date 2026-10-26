import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import 'settings_screen.dart';

import '../data/control_preferences.dart';
import '../data/profile.dart';
import 'compact_choice.dart';
import 'components.dart';
import 'info_dialog.dart';
import '../art/game_icons.dart';

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

  /// The control rules behind the app bar's '?': a picture per setting and
  /// one short line each (v12.15).
  void _guide() => showInfoDialog(
    context,
    title: '조작 안내',
    children: const [
      RuleLine(GameIcons.crosshair, '손가락 따라가기: 누른 곳 바로 위로 날아감'),
      RuleLine(GameIcons.speed, '드래그 이동: 민 만큼만 움직이고 멈추면 멈춤'),
      RuleLine(GameIcons.fastForward, '드래그 속도: 손가락 이동의 0.9 · 1.15 · 1.4배'),
      RuleLine(GameIcons.bolt, '능력 버튼: 항성포·파일럿 능력의 위치'),
      RuleLine(GameIcons.hourglass, '손을 떼면 전투 시간이 5%로 느려짐'),
      RuleLine(GameIcons.check, '어느 방식이든 속도·공격·보상은 같음'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final c = p.controls;
    return Scaffold(
      appBar: GameAppBar(
        title: Text(tr('조작·음향'), textAlign: TextAlign.center),
        actions: [
          InfoAction(
            key: const Key('control-guide'),
            label: '조작 안내',
            onPressed: _guide,
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
                  icon: Icons.gps_fixed,
                  selected: c.followTouch,
                  onPressed: audible(() => update(followTouch: true)),
                ),
                GameCompactChoice(
                  title: '드래그 이동',
                  caption: '민 만큼만',
                  icon: Icons.speed,
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
              // The whole pad takes the drag, not only its labels.
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => move(e.localPosition),
              onPointerMove: (e) => move(e.localPosition),
              onPointerUp: (_) => release(),
              onPointerCancel: (_) => release(),
              child: RasterPanel(
                child: SizedBox(
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // the cat rocket shows where a drag would carry it
                      Transform.translate(
                        offset: Offset(
                          (sample.dx / 3).clamp(-120.0, 120.0),
                          (sample.dy / 6).clamp(-18.0, 18.0),
                        ),
                        child: Opacity(
                          opacity: anchor == null ? .35 : 1,
                          child: const GameIconImage(
                            GameIcons.launch,
                            size: 44,
                          ),
                        ),
                      ),
                      if (anchor == null)
                        const Positioned(
                          top: 6,
                          child: GameTag('조작 시험', tone: GameTone.sky),
                        ),
                      Positioned(
                        bottom: 4,
                        child: Text(
                          message('가로 {0} · 세로 {1}', [
                            sample.dx.toStringAsFixed(0),
                            sample.dy.toStringAsFixed(0),
                          ]),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: GameTone.gold.color,
                            fontSize: GameUi.caption,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
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
            AudioChannelRow(
              id: 'music',
              label: '배경음',
              enabled: p.musicEnabled,
              volume: p.musicVolume,
              onEnabled: (v) {
                p.updateSettings(musicEnabled: v);
                setState(() {});
              },
              onVolume: (v) {
                p.updateSettings(musicVolume: v);
                setState(() {});
              },
            ),
            AudioChannelRow(
              id: 'sfx',
              label: '효과음',
              enabled: p.soundEnabled,
              volume: p.volume,
              onEnabled: (v) {
                p.updateSettings(soundEnabled: v);
                setState(() {});
              },
              onVolume: (v) {
                p.updateSettings(volume: v);
                setState(() {});
              },
            ),
            gap(6),
            GameActionButton(
              label: '조작 기본값 복원',
              image: GameIcons.refresh,
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
