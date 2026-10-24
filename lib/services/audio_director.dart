import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';

import 'audio_clip_levels.dart';

abstract interface class AudioPort {
  Future<void> music(String? asset, double volume);
  Future<void> cutMusic();
  Future<void> effect(int voice, String asset, double volume);
  Future<void> stopVoice(int voice);
  Future<void> silence();
  Future<void> dispose();
}

/// One music player and six reserved effect voices for the entire app.
class PlayerAudioPort implements AudioPort {
  // No sound scrubber uses position streams. Avoid polling seven players on
  // every Flutter frame during combat.
  AudioPlayer _player() => AudioPlayer()..positionUpdater = null;
  AudioPlayer? _music;
  final Map<int, AudioPlayer> _voices = {};
  String? _track;
  bool _playing = false;
  int _musicEpoch = 0;
  double _musicVolume = 0;
  Timer? _fade;
  void _ramp(AudioPlayer player, double target) {
    _fade?.cancel();
    final start = _musicVolume;
    var step = 0;
    _fade = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      _musicVolume = start + (target - start) * (++step / 7);
      unawaited(player.setVolume(_musicVolume).catchError((Object _) {}));
      if (step == 7) {
        timer.cancel();
        _fade = null;
      }
    });
  }

  @override
  Future<void> cutMusic() async {
    _musicEpoch++;
    _fade?.cancel();
    _fade = null;
    _playing = false;
    _musicVolume = 0;
    await _music?.pause();
  }

  @override
  Future<void> stopVoice(int voice) async => _voices[voice]?.stop();
  @override
  Future<void> music(String? asset, double volume) async {
    if (asset == null) {
      await cutMusic();
      return;
    }
    final epoch = _musicEpoch;
    final player = _music ??= _player();
    if (_track != asset) {
      _fade?.cancel();
      // Short sequential fade, one music player: no two loops can overlap.
      final start = _musicVolume;
      if (_playing) {
        for (var i = 1; i <= 3 && epoch == _musicEpoch; i++) {
          _musicVolume = start * (1 - i / 3);
          await player.setVolume(_musicVolume);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }
      if (epoch != _musicEpoch) return;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('audio/$asset.ogg'), volume: 0);
      if (epoch != _musicEpoch) {
        await player.pause();
        return;
      }
      _track = asset;
      _musicVolume = 0;
    } else if (!_playing) {
      await player.setVolume(0);
      await player.resume();
      if (epoch != _musicEpoch) {
        await player.pause();
        return;
      }
      _musicVolume = 0;
    }
    _playing = true;
    if ((volume - _musicVolume).abs() > .001) _ramp(player, volume);
  }

  @override
  Future<void> effect(int voice, String asset, double volume) async {
    final player = _voices.putIfAbsent(voice, _player);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.play(AssetSource('audio/$asset.ogg'), volume: volume);
  }

  @override
  Future<void> silence() async =>
      Future.wait(_voices.values.map((p) => p.stop()));
  @override
  Future<void> dispose() async {
    _fade?.cancel();
    await _music?.dispose();
    await Future.wait(_voices.values.map((p) => p.dispose()));
  }
}

enum AudioScene { lobby, battle, boss, quiet }

class SoundSpec {
  const SoundSpec(this.voice, this.gain, this.gap);
  final int voice, gap;
  final double gain;
}

class _SoundRequest {
  _SoundRequest(this.asset, this.spec, this.epoch, this.id, this.event);
  final String asset, event;
  final SoundSpec spec;
  final int epoch, id;
  DateTime until = DateTime(2000);
  int get priority => switch (event) {
    'victory' || 'defeat' || 'pause' => 100,
    'transform' => 97,
    'hit' || 'evolution' => 95,
    'warning' || 'ultimate' => 90,
    'boss-explosion' => 85,
    'shield' || 'pilot' => 80,
    'boss' || 'boss-phase' || 'level' => 70,
    'enemy-charge' => 30,
    _ => 55,
  };
}

class AudioDirector {
  AudioDirector({AudioPort? port, DateTime Function()? now})
    : port = port ?? PlayerAudioPort(),
      now = now ?? DateTime.now;
  final AudioPort port;
  final DateTime Function() now;
  static AudioDirector? current;
  static const weapons = {
    'pulse',
    'kunai',
    'katana',
    'bat',
    'shotgun',
    'revolver',
    'lightchaser',
    'void',
    'disorder',
    'lance',
  };
  // Engine event names that share a clip with another event.
  static const aliases = {
    'lightning': 'skill-electric',
    'explode': 'explosion',
  };
  // Continuous weapons / hits / pickups cannot consume alert voices 4 and 5.
  static const specs = <String, SoundSpec>{
    'enemy-charge': SoundSpec(4, .38, 900),
    'enemy-fire': SoundSpec(2, .16, 300),
    'skill-electric': SoundSpec(1, .26, 350),
    'skill-beam': SoundSpec(1, .24, 400),
    'skill-blast': SoundSpec(1, .27, 350),
    'skill-drone': SoundSpec(1, .18, 400),
    'skill-blade': SoundSpec(1, .23, 350),
    'skill-field': SoundSpec(1, .16, 550),
    'missile': SoundSpec(1, .2, 300),
    'laser': SoundSpec(1, .22, 450),
    'pet': SoundSpec(2, .2, 800),
    'shoot': SoundSpec(0, .24, 150),
    'impact': SoundSpec(1, .13, 150),
    'explosion': SoundSpec(2, .23, 180),
    'pickup': SoundSpec(3, .25, 160),
    'click': SoundSpec(3, .52, 75),
    'select': SoundSpec(3, .52, 110),
    'back': SoundSpec(3, .5, 110),
    'confirm': SoundSpec(3, .55, 110),
    'pick': SoundSpec(3, .55, 110),
    'pause': SoundSpec(4, .5, 160),
    'resume': SoundSpec(4, .5, 160),
    'hit': SoundSpec(4, .72, 250),
    'shield': SoundSpec(4, .6, 180),
    'error': SoundSpec(4, .55, 240),
    'boss': SoundSpec(4, .65, 1000),
    'boss-phase': SoundSpec(4, .65, 750),
    'warning': SoundSpec(4, .58, 1200),
    'heal': SoundSpec(4, .55, 300),
    'magnet': SoundSpec(5, .6, 400),
    'bomb': SoundSpec(5, .65, 400),
    'chest': SoundSpec(5, .6, 400),
    'level': SoundSpec(5, .62, 400),
    'evolution': SoundSpec(5, .68, 500),
    'transform': SoundSpec(5, .74, 1200),
    'synergy': SoundSpec(5, .55, 700),
    'ultimate': SoundSpec(5, .72, 500),
    'pilot': SoundSpec(5, .62, 500),
    'boss-explosion': SoundSpec(5, .65, 700),
    'victory': SoundSpec(5, .74, 1800),
    'defeat': SoundSpec(5, .67, 1800),
    'equip': SoundSpec(5, .58, 240),
    'purchase': SoundSpec(5, .6, 300),
    'reward': SoundSpec(5, .6, 500),
    'upgrade': SoundSpec(5, .65, 350),
    'launch': SoundSpec(5, .62, 600),
    'reroll': SoundSpec(5, .55, 300),
  };
  final Map<String, DateTime> _last = {};
  final Set<int> _busy = {};
  final Map<int, _SoundRequest> _pending = {}, _active = {};
  final Map<int, DateTime> _voiceAt = {};
  AudioScene scene = AudioScene.lobby;
  bool enabled = true, background = false;
  double volume = .7;
  bool _unlocked = false, _disposed = false, _dirty = false, _pumping = false;
  int _epoch = 0, _battleOwners = 0;
  int _serial = 0;
  Timer? _duckTimer;
  DateTime _duckUntil = DateTime(2000);
  // Sum of all six worst-case effect peaks is .66. Even the louder lobby
  // loop adds at most .72*.44, keeping the conservative full-volume sum <.98.
  static const voicePeaks = [.10, .06, .08, .08, .16, .18];
  static double effectGain(String asset, SoundSpec spec) {
    final clip = audioClips[asset]!;
    return math.min(
      spec.gain * .16 / clip.rms,
      voicePeaks[spec.voice] / clip.peak,
    );
  }

  // Loops differ in density; match their average loudness (lobby is the
  // reference) while never exceeding the .44 peak budget below.
  double get musicGain {
    final clip = audioClips[track ?? 'lobby-groove']!;
    return volume *
        math.min(.44, .062 / clip.rms) *
        (now().isBefore(_duckUntil) ? .52 : 1);
  }

  void _duck(int milliseconds) {
    final until = now().add(Duration(milliseconds: milliseconds + 100));
    if (until.isAfter(_duckUntil)) _duckUntil = until;
    _duckTimer?.cancel();
    _duckTimer = Timer(_duckUntil.difference(now()), () {
      _duckTimer = null;
      _syncMusic();
    });
    _syncMusic();
  }

  DateTime _retry = DateTime(2000);
  Future<void> _musicTask = Future<void>.value();
  final Set<Future<void>> _effectTasks = {};
  bool get audible =>
      !_disposed && _unlocked && enabled && volume > 0 && !background;
  String? get track => !audible
      ? null
      : switch (scene) {
          AudioScene.lobby => 'lobby-groove',
          AudioScene.battle => 'battle-drive',
          AudioScene.boss => 'boss-theme',
          AudioScene.quiet => null,
        };
  void settings({required bool enabled, required double volume}) {
    final level = volume.clamp(0.0, 1.0);
    if (this.enabled == enabled && this.volume == level) return;
    this.enabled = enabled;
    this.volume = level;
    silenceEffects();
    _syncMusic();
  }

  void unlock() {
    if (_disposed) return;
    if (_unlocked && now().isBefore(_retry)) return;
    _unlocked = true;
    _syncMusic();
  }

  void setScene(AudioScene value) {
    if (scene == value || _disposed) return;
    scene = value;
    _syncMusic();
  }

  void enterBattle() {
    _battleOwners++;
    silenceEffects();
    setScene(AudioScene.battle);
  }

  void beginFlight({required bool paused}) {
    silenceEffects();
    setScene(paused ? AudioScene.quiet : AudioScene.battle);
    if (!paused) play('launch');
  }

  void leaveBattle() {
    if (_battleOwners > 0) _battleOwners--;
    if (_battleOwners == 0) {
      silenceEffects();
      setScene(AudioScene.lobby);
    }
  }

  void setBackground(bool value) {
    if (background == value) return;
    background = value;
    if (value) silenceEffects();
    _syncMusic();
  }

  void _syncMusic() {
    if (_disposed) return;
    if (track == null) unawaited(port.cutMusic().catchError((Object _) {}));
    _dirty = true;
    if (_pumping) return;
    _pumping = true;
    _musicTask = () async {
      while (_dirty && !_disposed) {
        _dirty = false;
        try {
          await port.music(track, musicGain);
        } catch (_) {
          // Retry only at a later user gesture, not every animation frame.
          _retry = now().add(const Duration(seconds: 2));
        }
      }
      _pumping = false;
    }();
  }

  void play(String event, {String armament = 'pulse'}) {
    event = aliases[event] ?? event;
    final spec = specs[event];
    if (!audible || spec == null) return;
    final time = now();
    // A weapon's ultimate transformation also emits its evolution cue.
    if (event == 'evolution' &&
        time.difference(_last['transform'] ?? DateTime(2000)).inMilliseconds <
            400) {
      return;
    }
    if (time.difference(_last[event] ?? DateTime(2000)).inMilliseconds <
        spec.gap) {
      return;
    }
    if (spec.voice < 3 &&
        time.difference(_voiceAt[spec.voice] ?? DateTime(2000)).inMilliseconds <
            120) {
      return;
    }
    if (spec.voice == 3 &&
        event != 'pickup' &&
        time.difference(_voiceAt[3] ?? DateTime(2000)).inMilliseconds < 75) {
      return;
    }
    final asset = event == 'shoot'
        ? 'weapon-${weapons.contains(armament) ? armament : 'pulse'}'
        : event;
    final request = _SoundRequest(asset, spec, _epoch, ++_serial, event);
    final active = _active[spec.voice];
    if (spec.voice >= 4 &&
        active != null &&
        (_busy.contains(spec.voice) || time.isBefore(active.until)) &&
        request.priority <= active.priority) {
      return;
    }
    _last[event] = time;
    _voiceAt[spec.voice] = time;
    request.until = time.add(
      Duration(milliseconds: audioClips[asset]!.milliseconds),
    );
    _active[spec.voice] = request;
    if (_busy.contains(spec.voice)) {
      // Bounded latest-important-event slot. Rapid decoration never queues.
      if (spec.voice >= 4) _pending[spec.voice] = request;
      return;
    }
    _busy.add(spec.voice);
    late Future<void> task;
    task = () async {
      _SoundRequest? next = request;
      try {
        while (next != null && audible) {
          final epoch = next.epoch;
          if (epoch != _epoch) break;
          try {
            // A phase change can immediately lock a new dangerous pattern.
            // Coalesce that one short boundary instead of playing 20ms of a
            // decorative phase chord before abruptly replacing it with a tell.
            if (next.event == 'boss-phase') {
              await Future<void>.delayed(const Duration(milliseconds: 45));
              if (epoch != _epoch || !audible) break;
              final newer = _pending[spec.voice];
              if (newer != null && newer.priority > next.priority) {
                next = _pending.remove(spec.voice);
                continue;
              }
            }
            if (spec.voice >= 4) _duck(audioClips[next.asset]!.milliseconds);
            await port.effect(
              spec.voice,
              next.asset,
              volume * effectGain(next.asset, next.spec),
            );
            if (_active[spec.voice]?.id == next.id) {
              next.until = now().add(
                Duration(milliseconds: audioClips[next.asset]!.milliseconds),
              );
            }
            if (spec.voice >= 4 && audible && epoch == _epoch) {
              _duck(audioClips[next.asset]!.milliseconds);
            }
          } catch (_) {
            /* Audio must never break input or saved progress. */
          }
          if (!audible || epoch != _epoch) {
            try {
              await port.stopVoice(spec.voice);
            } catch (_) {}
          }
          next = _pending.remove(spec.voice);
        }
      } finally {
        _busy.remove(spec.voice);
        _pending.remove(spec.voice);
      }
    }();
    _effectTasks.add(task);
    unawaited(task.whenComplete(() => _effectTasks.remove(task)));
  }

  void silenceEffects() {
    _epoch++;
    _pending.clear();
    _active.clear();
    _duckTimer?.cancel();
    _duckTimer = null;
    _duckUntil = DateTime(2000);
    unawaited(port.silence().catchError((Object _) {}));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _duckTimer?.cancel();
    _epoch++;
    _pending.clear();
    if (identical(current, this)) current = null;
    await _musicTask;
    await Future.wait(_effectTasks.toList());
    try {
      await port.dispose();
    } catch (_) {
      /* Optional platform teardown. */
    }
  }
}
