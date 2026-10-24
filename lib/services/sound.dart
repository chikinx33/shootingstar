import 'dart:async';

import '../data/profile.dart';
import '../game/combat_cues.dart';
import 'audio_director.dart';
export 'audio_director.dart';

/// Battle ownership shares the app director; isolated previews also work.
class GameSound {
  GameSound(this.profile) {
    _owned = AudioDirector.current == null;
    director = AudioDirector.current ?? AudioDirector();
    director.settings(enabled: profile.soundEnabled, volume: profile.volume);
    director.enterBattle();
  }
  final Profile profile;
  late final AudioDirector director;
  late final bool _owned;
  void startMusic({bool boss = false}) =>
      director.setScene(boss ? AudioScene.boss : AudioScene.battle);
  void beginFlight({required bool paused}) =>
      director.beginFlight(paused: paused);
  void pauseMusic() => director.setScene(AudioScene.quiet);
  void stop() {
    pauseMusic();
    director.silenceEffects();
  }

  void play(String event, {String armament = 'pulse'}) =>
      director.play(event, armament: armament);
  void cue(CombatCueKind kind, String source) {
    final event = switch (kind) {
      CombatCueKind.muzzle => null,
      CombatCueKind.impact => source == 'hit' ? null : skillImpact(source),
      CombatCueKind.lightning => 'skill-electric',
      CombatCueKind.area => skillImpact(source),
      CombatCueKind.explosion => 'explosion',
      CombatCueKind.bossExplosion => 'boss-explosion',
      CombatCueKind.pickup => source == 'chest' ? 'chest' : 'pickup',
      CombatCueKind.bossPhase => source == 'boss' ? 'boss' : 'boss-phase',
      _ => kind.name,
    };
    if (event != null) play(event);
  }

  static String skillImpact(String source) {
    if ([
      'missile',
      'rocket',
      'mine',
      'brick',
      'durian',
      'bomb',
    ].any(source.startsWith)) {
      return 'skill-blast';
    }
    if (source.startsWith('laser') || source == 'starforge') {
      return 'skill-beam';
    }
    if (source.startsWith('drone') || source == 'pet') return 'skill-drone';
    if ([
      'guardian',
      'boomerang',
      'drill',
      'side',
      'ball',
    ].any(source.startsWith)) {
      return 'skill-blade';
    }
    if (source == 'trail' || source == 'forcefield') return 'skill-field';
    return 'impact';
  }

  void dispose() {
    if (_owned) {
      unawaited(director.dispose());
    } else {
      director.leaveBattle();
    }
  }
}
