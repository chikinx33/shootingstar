import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/services/audio_director.dart';
import 'package:shootingstar/services/audio_clip_levels.dart';
import 'package:shootingstar/game/combat_cues.dart';
import 'package:shootingstar/ui/audio_feedback.dart';

class FakeAudio implements AudioPort {
  final musicCalls = <(String?, double)>[];
  final effects = <(int, String, double)>[];
  final stopped = <int>[];
  Completer<void>? gate;
  bool fail = false, disposed = false;
  int silences = 0;
  @override
  Future<void> cutMusic() async {
    musicCalls.add((null, 0));
  }

  @override
  Future<void> music(String? asset, double volume) async {
    musicCalls.add((asset, volume));
    if (fail) throw StateError('audio unavailable');
    await gate?.future;
  }

  @override
  Future<void> effect(int voice, String asset, double volume) async {
    effects.add((voice, asset, volume));
    if (fail) throw StateError('audio unavailable');
    await gate?.future;
  }

  @override
  Future<void> stopVoice(int voice) async {
    stopped.add(voice);
  }

  @override
  Future<void> silence() async {
    silences++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

// Loudness-matched battle loop level (lobby .44 is the peak-budget ceiling).
double get battleLevel => math.min(.44, .062 / audioClips['battle-drive']!.rms);

Future<void> drain() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'phase and imminent warning coalesce without an audible fragment',
    () async {
      final port = FakeAudio();
      final a = AudioDirector(port: port)..unlock();
      a.setScene(AudioScene.battle);
      await drain();
      a.play('boss-phase');
      await drain();
      a.play('warning');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(port.effects.map((e) => e.$2), ['warning']);
      await a.dispose();
    },
  );
  test(
    'new sortie clears result sounds, restored pause does not launch',
    () async {
      final port = FakeAudio();
      final a = AudioDirector(port: port)..unlock();
      a.enterBattle();
      await drain();
      a.beginFlight(paused: true);
      await drain();
      expect(a.track, isNull);
      expect(port.effects, isEmpty);
      a.play('victory');
      await drain();
      a.beginFlight(paused: false);
      await drain();
      expect(a.track, 'battle-drive');
      expect(port.effects.last.$2, 'launch');
      await a.dispose();
    },
  );
  test('boss loop, engine aliases and ultimate transform sound', () async {
    var time = DateTime(2026);
    final port = FakeAudio();
    final a = AudioDirector(port: port, now: () => time)..unlock();
    a.enterBattle();
    await drain();
    expect(a.track, 'battle-drive');
    a.setScene(AudioScene.boss);
    await drain();
    expect(port.musicCalls.last.$1, 'boss-theme');
    // Denser loops play quieter so every scene keeps the lobby's loudness.
    expect(a.musicGain, lessThan(a.volume * .44));
    a.play('lightning');
    a.play('explode');
    await drain();
    expect(port.effects.map((e) => e.$2), containsAll(['skill-electric']));
    time = time.add(const Duration(seconds: 1));
    a.play('explode');
    await drain();
    expect(port.effects.last.$2, 'explosion');
    time = time.add(const Duration(seconds: 2));
    a.play('transform');
    a.play('evolution');
    await drain();
    expect(port.effects.where((e) => e.$2 == 'evolution'), isEmpty);
    expect(port.effects.last.$2, 'transform');
    for (final event in ['missile', 'laser', 'pet', 'pick']) {
      expect(AudioDirector.specs, contains(event));
      expect(audioClips, contains(event));
    }
    await a.dispose();
  });
  test('normalized weapons and conservative full-volume peak budget', () {
    final shoot = AudioDirector.specs['shoot']!;
    final powers = [
      for (final w in AudioDirector.weapons)
        AudioDirector.effectGain('weapon-$w', shoot) *
            audioClips['weapon-$w']!.rms,
    ];
    expect(
      powers.reduce((a, b) => a > b ? a : b) -
          powers.reduce((a, b) => a < b ? a : b),
      lessThan(.004),
    );
    final peaks = List.filled(6, 0.0);
    for (final entry in AudioDirector.specs.entries) {
      final assets = entry.key == 'shoot'
          ? AudioDirector.weapons.map((w) => 'weapon-$w')
          : [entry.key];
      for (final asset in assets) {
        final peak =
            AudioDirector.effectGain(asset, entry.value) *
            audioClips[asset]!.peak;
        if (peak > peaks[entry.value.voice]) peaks[entry.value.voice] = peak;
      }
    }
    expect(
      peaks.reduce((a, b) => a + b) + audioClips['lobby-groove']!.peak * .44,
      lessThan(.98),
    );
  });
  test('important clips finish, high priority preempts, duck releases, mute cancels', () async {
    var time = DateTime(2026);
    final port = FakeAudio();
    final a = AudioDirector(port: port, now: () => time)..unlock();
    a.setScene(AudioScene.battle);
    await drain();
    a.play('warning');
    await drain();
    expect(a.musicGain, closeTo(.7 * battleLevel * .52, .00001));
    a.play('enemy-charge');
    a.play('boss-phase');
    await drain();
    expect(port.effects.map((e) => e.$2), ['warning']);
    a.play('hit');
    await drain();
    expect(port.effects.last.$2, 'hit');
    a.play('victory');
    await drain();
    a.play('level');
    a.play('boss-explosion');
    await drain();
    expect(port.effects.where((e) => e.$1 == 5).map((e) => e.$2), ['victory']);
    // The victory jingle ducks the loop until its clip ends (+100ms).
    time = time.add(
      Duration(milliseconds: audioClips['victory']!.milliseconds + 150),
    );
    expect(a.musicGain, closeTo(.7 * battleLevel, .00001));
    a.settings(enabled: false, volume: .7);
    await drain();
    expect(port.musicCalls.last.$1, isNull);
    expect(a.audible, false);
    await a.dispose();
  });
  test(
    'gesture, scene ownership, pause, background and live settings',
    () async {
      final port = FakeAudio(), audio = AudioDirector(port: FakeAudio());
      await audio.dispose();
      final a = AudioDirector(port: port);
      a.setScene(AudioScene.lobby);
      a.play('click');
      expect(port.effects, isEmpty);
      expect(a.track, isNull);
      a.unlock();
      await drain();
      expect(port.musicCalls.last.$1, 'lobby-groove');
      a.enterBattle();
      await drain();
      expect(port.musicCalls.last.$1, 'battle-drive');
      a.setScene(AudioScene.quiet);
      await drain();
      expect(port.musicCalls.last.$1, isNull);
      a.setScene(AudioScene.battle);
      await drain();
      a.setBackground(true);
      await drain();
      final count = port.effects.length;
      a.play('ultimate');
      expect(port.effects.length, count);
      expect(port.musicCalls.last.$1, isNull);
      a.setBackground(false);
      await drain();
      expect(port.musicCalls.last.$1, 'battle-drive');
      a.settings(enabled: false, volume: .8);
      await drain();
      expect(a.track, isNull);
      a.settings(enabled: true, volume: .3);
      await drain();
      expect(port.musicCalls.last.$2, closeTo(.3 * battleLevel, .0001));
      a.leaveBattle();
      await drain();
      expect(port.musicCalls.last.$1, 'lobby-groove');
      a.settings(enabled: true, volume: 0);
      await drain();
      expect(a.track, isNull);
      await a.dispose();
      expect(port.disposed, true);
    },
  );

  test('music and sound effects switch and mix separately', () async {
    final port = FakeAudio();
    final a = AudioDirector(port: port)..unlock();
    a.settings(enabled: true, volume: .6, musicEnabled: false, musicVolume: .4);
    await drain();
    expect(a.track, isNull, reason: 'music off');
    expect(a.audible, isTrue, reason: 'effects still play');
    a.settings(enabled: false, volume: .6, musicEnabled: true, musicVolume: .4);
    await drain();
    expect(a.track, 'lobby-groove', reason: 'music on alone');
    expect(a.audible, isFalse, reason: 'effects off');
    final quiet = a.musicGain;
    a.settings(enabled: false, volume: .6, musicEnabled: true, musicVolume: .8);
    expect(a.musicGain, closeTo(quiet * 2, 1e-9), reason: 'own level');
    await a.dispose();
  });

  test('muting during track load converges to silence', () async {
    final port = FakeAudio()..gate = Completer<void>();
    final a = AudioDirector(port: port)..unlock();
    a.enterBattle();
    a.settings(enabled: false, volume: .5);
    port.gate!.complete();
    await drain();
    expect(port.musicCalls.last.$1, isNull);
    expect(a.track, isNull);
    await a.dispose();
  });

  test(
    'six voices, no shot backlog, newest important event and epoch safety',
    () async {
      var time = DateTime(2026);
      final port = FakeAudio(), a = AudioDirector(port: FakeAudio());
      await a.dispose();
      final sound = AudioDirector(port: port, now: () => time)..unlock();
      await drain();
      port.gate = Completer<void>();
      for (var i = 0; i < 1000; i++) {
        for (final event in [
          'shoot',
          'impact',
          'explosion',
          'pickup',
          'hit',
          'level',
        ])
          sound.play(event);
        time = time.add(const Duration(milliseconds: 10));
      }
      expect(port.effects.length, 6);
      sound.play('victory');
      port.gate!.complete();
      await drain();
      expect(port.effects.lastWhere((e) => e.$1 == 5).$2, 'victory');
      expect(port.effects.where((e) => e.$1 == 0).length, 1);
      expect(port.effects.map((e) => e.$1).toSet(), {0, 1, 2, 3, 4, 5});
      port.gate = Completer<void>();
      time = time.add(const Duration(seconds: 3));
      sound.play('hit');
      sound.settings(enabled: false, volume: .5);
      port.gate!.complete();
      await drain();
      expect(port.stopped, contains(4));
      await sound.dispose();
    },
  );

  test(
    'optional platform failure never breaks callbacks or progress',
    () async {
      var time = DateTime(2026);
      final port = FakeAudio()..fail = true;
      final a = AudioDirector(port: port, now: () => time);
      AudioDirector.current = a;
      var actions = 0;
      expect(audible(null), isNull);
      audible(() => actions++)!();
      await drain();
      expect(actions, 1);
      final calls = port.musicCalls.length;
      a.unlock();
      await drain();
      expect(port.musicCalls.length, calls);
      time = time.add(const Duration(seconds: 3));
      a.unlock();
      await drain();
      expect(port.musicCalls.length, calls + 1);
      await a.dispose();
      expect(AudioDirector.current, isNull);
    },
  );

  test('forwarded callbacks make one sound and keep disabled state', () async {
    final port = FakeAudio();
    final a = AudioDirector(port: port)..unlock();
    AudioDirector.current = a;
    var count = 0;
    audible(audible(() => count++))!();
    await drain();
    expect(count, 1);
    expect(port.effects.length, 1);
    expect(buttonCue('로비로 귀환'), 'back');
    await a.dispose();
  });

  test('audio occurrence independent of VFX switch and visual pool budget', () {
    final cues = CombatCues()..enabled = false;
    final sounds = <CombatCueKind>[];
    cues.onSound = (kind, _) => sounds.add(kind);
    cues.emit(CombatCueKind.ultimate, Offset.zero);
    expect(cues.active, isEmpty);
    expect(sounds, [CombatCueKind.ultimate]);
    cues.enabled = true;
    for (var i = 0; i < 100; i++)
      cues.emit(CombatCueKind.evolution, Offset.zero);
    cues.emit(CombatCueKind.shield, Offset.zero);
    expect(cues.active.length, CombatCues.limit);
    expect(sounds.last, CombatCueKind.shield);
  });

  test(
    'all scheduled effects and both tracks exist, no legacy dark loop selected',
    () {
      final assets = {
        for (final name in AudioDirector.specs.keys)
          name == 'shoot' ? 'weapon-pulse' : name,
        for (final weapon in AudioDirector.weapons) 'weapon-$weapon',
        'lobby-groove',
        'battle-drive',
        'boss-theme',
      };
      for (final asset in assets) {
        final bytes = File('assets/audio/$asset.ogg').readAsBytesSync();
        expect(String.fromCharCodes(bytes.take(4)), 'OggS', reason: asset);
        expect(bytes.length, greaterThan(1000));
      }
      expect(
        File('lib/services/audio_director.dart').readAsStringSync(),
        isNot(contains('orbit-loop')),
      );
    },
  );
}
