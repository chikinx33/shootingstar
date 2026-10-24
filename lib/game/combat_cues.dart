import 'dart:ui';
import 'dart:math' as math;

enum CombatCueKind {
  muzzle,
  impact,
  lightning,
  explosion,
  bossExplosion,
  pickup,
  heal,
  magnet,
  bomb,
  level,
  evolution,
  synergy,
  shield,
  ultimate,
  bossPhase,
  pilot,
  victory,
  defeat,
  area,
}

class CombatCue {
  CombatCue(
    this.kind,
    this.at,
    this.duration, {
    this.from,
    this.radius = 28,
    this.source = '',
    this.amount = 0,
  });
  final CombatCueKind kind;
  final Offset at;
  final Offset? from;
  final double duration, radius, amount;
  final String source;
  double age = 0;
  double get progress => (age / duration).clamp(0, 1);
}

/// Transient presentation only. Never reads combat RNG or enters a save record.
class CombatCues {
  static const limit = 80;
  final List<CombatCue> active = [];
  final Map<String, double> _last = {};
  double _clock = 0;
  bool enabled = true;
  final Map<String, ({Offset impulse, double age})> _recoil = {};
  void clearRecoil() => _recoil.clear();
  final Map<String, Offset> _follow = {};
  static const followTimes = <String, double>{
    'W1': .07,
    'W2': .055,
    'W3': .08,
    'W4': .06,
    'main': .045,
    'auxiliary': .06,
    'wings': .07,
    'rear': .08,
    'ground': .055,
    'armor': .05,
    'supportLeft': .095,
    'supportRight': .105,
    'supportRear': .115,
    'sensor': .04,
    'core': .065,
    'belt': .075,
    'thruster': .085,
  };
  Offset followOffset(String part) => _follow[part] ?? Offset.zero;

  /// Visual inertia only; authoritative mounts, collisions and saves stay fixed.
  void followMovement(Offset displacement, double dt) {
    if (!enabled) {
      _follow.clear();
      return;
    }
    for (final entry in followTimes.entries) {
      var lag =
          (followOffset(entry.key) - displacement) *
          math.exp(-dt / entry.value);
      final cap = entry.value * 32;
      if (lag.distance > cap) lag = lag / lag.distance * cap;
      _follow[entry.key] = lag.distance < .001 ? Offset.zero : lag;
    }
  }

  /// Presentation only: one impulse per mount; pellet count never stacks it.
  void kick(String mount, Offset impulse) {
    if (!enabled) return;
    if (_recoil.length >= 24 && !_recoil.containsKey(mount)) return;
    _recoil[mount] = (impulse: impulse, age: 0);
  }

  Offset recoil(String mount) {
    if (!enabled) return Offset.zero;
    final state = _recoil[mount];
    if (state == null) return Offset.zero;
    final t = state.age;
    final factor = t < .025
        ? t / .025
        : (1 - (t - .025) / .135).clamp(0.0, 1.0);
    return state.impulse * factor * factor;
  }

  // Audio observes authoritative occurrences even with decorative VFX disabled
  // or their visual pool full. It has its own bounded wall-clock budget.
  void Function(CombatCueKind, String)? onSound;
  void emit(
    CombatCueKind kind,
    Offset at, {
    Offset? from,
    double radius = 28,
    String source = '',
    double amount = 0,
    String? throttle,
    double interval = .06,
  }) {
    onSound?.call(kind, source);
    if (!enabled) return;
    if (throttle != null) {
      if (_clock - (_last[throttle] ?? -100) < interval) return;
      _last[throttle] = _clock;
    }
    // Ambient hits cannot evict an evolution/ultimate/boss presentation.
    if (active.length >= limit) {
      final index = active.indexWhere(
        (c) =>
            c.kind == CombatCueKind.impact ||
            c.kind == CombatCueKind.muzzle ||
            c.kind == CombatCueKind.area,
      );
      if (index < 0) return;
      active.removeAt(index);
    }
    final duration = switch (kind) {
      CombatCueKind.muzzle => .12,
      CombatCueKind.impact => .28,
      CombatCueKind.lightning => .24,
      CombatCueKind.explosion => .55,
      CombatCueKind.bossExplosion => 1.2,
      CombatCueKind.area => .45,
      _ => .85,
    };
    active.add(
      CombatCue(
        kind,
        at,
        duration,
        from: from,
        radius: radius,
        source: source,
        amount: amount,
      ),
    );
  }

  void advance(double dt) {
    _clock += dt;
    _recoil.updateAll((_, r) => (impulse: r.impulse, age: r.age + dt));
    _recoil.removeWhere((_, r) => r.age >= .16);
    for (final c in active) {
      c.age += dt;
    }
    active.removeWhere((c) => c.age >= c.duration);
    _last.removeWhere((_, time) => _clock - time > 2);
  }
}
