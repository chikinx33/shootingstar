part of 'engine.dart';

extension CommonUltimate on GameEngine {
  bool get hasCommonUltimate => unifiedModules || pilot == 'common';
  double get ultimateCharge => _ultimateCharge;
  double get ultimateRemaining => math.max(0, _ultimateUntil - combatTime);
  bool get ultimateReady =>
      hasCommonUltimate &&
      _ultimateCharge >= 100 &&
      ultimateRemaining == 0 &&
      !paused &&
      !finished &&
      choices.isEmpty;
  String get ultimateDescription => hasCommonUltimate
      ? '${moduleLoadout?.ultimateName ?? '항성포'} · 충전 ${_ultimateCharge.floor()}% · 사용 ${_ultimateUses}회\n'
            '20초 충전 · ${!unifiedModules || shipIndex == 0
                ? '전방 광선'
                : shipIndex == 1
                ? '주변 추적 포격'
                : '근거리 충격파'} 2초 · 탄막 정리'
      : '';

  bool activateCommonUltimate() {
    if (!ultimateReady) return false;
    visuals.emit(CombatCueKind.ultimate, position, radius: 130);
    _ultimateCharge = 0;
    _ultimateUses++;
    _ultimateUntil = combatTime + 2;
    _ultimateNextPulse = combatTime + .5;
    _ultimatePulse();
    pickupNotice = moduleLoadout?.ultimateName ?? '항성포 · 전방 돌파';
    noticeTime = 2;
    _event('shoot');
    return true;
  }

  bool _inUltimateCorridor(Offset at, double radius) {
    final delta = at - position;
    if (unifiedModules && shipIndex == 1) return delta.distance <= 420;
    if (unifiedModules && shipIndex == 2) return delta.distance <= 220 + radius;
    return delta.dy <= 0 && delta.dy >= -520 && delta.dx.abs() <= 70 + radius;
  }

  void _clearUltimateBullets() {
    shots.removeWhere(
      (s) => s.interceptable && _inUltimateCorridor(s.position, s.radius),
    );
  }

  void _ultimatePulse() {
    for (final e in enemies) {
      if (e.hp > 0 && !e.retired && _inUltimateCorridor(e.position, e.radius)) {
        final factor = unifiedModules && shipIndex == 1 ? .65 : 1.0;
        _hit(e, 45 * damageFactor * factor, 'common-ultimate');
        if (unifiedModules && shipIndex != 0)
          visuals.emit(
            shipIndex == 1 ? CombatCueKind.explosion : CombatCueKind.shield,
            e.position,
            source: 'airframe-ultimate',
            radius: shipIndex == 1 ? 32 : 50,
          );
      }
    }
    _clearUltimateBullets();
  }

  void _updateCommonUltimate(double dt) {
    if (!hasCommonUltimate) return;
    if (ultimateRemaining > 0) {
      _clearUltimateBullets();
      if (combatTime >= _ultimateNextPulse) {
        _ultimateNextPulse += .5;
        _ultimatePulse();
      }
    } else {
      // Only charge the portion of a boundary frame after firing ends.
      final charging = math.min(dt, math.max(0, combatTime - _ultimateUntil));
      _ultimateCharge = math.min(
        100,
        _ultimateCharge +
            charging *
                5 *
                (1 + .15 * (moduleLoadout?.supportPower('capacitor') ?? 0)),
      );
    }
  }
}
