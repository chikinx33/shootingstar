import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/profile.dart';
import '../services/audio_director.dart';
import 'reward_popup.dart';

/// Wrap actual control callbacks, including keyboard / screen-reader activation.
/// Disabled callbacks stay null. Pointer movement and scrolling remain silent.
VoidCallback? audible(VoidCallback? action, {String cue = 'click'}) =>
    action == null
    ? null
    : () {
        AudioDirector.current?.unlock();
        AudioDirector.current?.play(cue);
        action();
      };
ValueChanged<T>? audibleChange<T>(ValueChanged<T>? action) => action == null
    ? null
    : (value) {
        AudioDirector.current?.unlock();
        AudioDirector.current?.play('select');
        action(value);
      };

String buttonCue(String label) {
  if (['닫기', '취소', '이전', '로비', '귀환'].any(label.contains)) return 'back';
  if (label.contains('재추첨') || label.contains('다시 뽑기')) return 'reroll';
  if (label.contains('확인')) return 'confirm';
  return 'click';
}

/// Includes automatic AppBar back and platform/browser back navigation.
class AudioNavigationObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AudioDirector.current?.play('back');
  }
}

class GameAudioHost extends StatefulWidget {
  const GameAudioHost({super.key, required this.profile, required this.child});
  final Profile profile;
  final Widget child;
  @override
  State<GameAudioHost> createState() => _GameAudioHostState();
}

class _GameAudioHostState extends State<GameAudioHost>
    with WidgetsBindingObserver {
  late final AudioDirector audio;
  String? _loadout;
  // Progress before the latest lobby change; actions the player just caused
  // (a tap/key within 1.5s) get a success sound on any screen.
  RewardSnapshot? _wallet;
  int _growth = 0;
  DateTime _touched = DateTime(2000);
  void _touch() {
    _touched = DateTime.now();
    audio.unlock();
  }

  @override
  void initState() {
    super.initState();
    audio = AudioDirector();
    AudioDirector.current = audio;
    widget.profile.addListener(_settings);
    _settings();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_keyboard);
  }

  void _settings() {
    final p = widget.profile;
    audio.settings(enabled: p.soundEnabled, volume: p.volume);
    final tech = p.equippedTech.toList()..sort();
    final loadout =
        '${p.selectedShip}/${p.selectedArmament}/${p.selectedPilot}/'
        '${p.equipment}/${p.activePet}/${p.equippedGear}/$tech/${p.assistingPets}/'
        '${p.moduleLoadout.toJson()}/${p.catGear.equipped}/${p.aircraftAssembly.parts}';
    final lobby = audio.scene == AudioScene.lobby;
    final growth =
        p.catGear.items.fold<int>(0, (sum, g) => sum + g.level) +
        p.shipModules.owned.values.fold<int>(0, (sum, m) => sum + m.level);
    final wallet = lobby ? RewardSnapshot(p) : null;
    final recent =
        DateTime.now().difference(_touched) <
        const Duration(milliseconds: 1500);
    if (_loadout != null && _loadout != loadout && lobby) {
      audio.play('equip');
    } else if (recent && _wallet != null && wallet != null) {
      if (growth > _growth || _wallet!.improvements(p).isNotEmpty) {
        audio.play('upgrade');
      } else if (_wallet!.spent(p).isNotEmpty) {
        audio.play('purchase');
      } else if (_wallet!.earned(p).isNotEmpty) {
        audio.play('reward');
      }
    }
    _loadout = loadout;
    _wallet = wallet;
    _growth = growth;
  }

  bool _keyboard(KeyEvent event) {
    if (event is KeyDownEvent) _touch();
    return false;
  }

  @override
  void didUpdateWidget(GameAudioHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      oldWidget.profile.removeListener(_settings);
      widget.profile.addListener(_settings);
      _loadout = null;
      _wallet = null;
      _settings();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      audio.setBackground(state != AppLifecycleState.resumed);
  @override
  void dispose() {
    widget.profile.removeListener(_settings);
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_keyboard);
    unawaited(audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _touch(),
    child: widget.child,
  );
}
