part of 'engine.dart';

/// v12.16 airframe ultimates (user 2026-10-27): the star cannon is the
/// craft's own finisher, so it charges slowly (about a minute and a half of
/// flight) and each cat fires one signature attack:
/// * 0 치즈 — a storm of fish missiles that hunts down every enemy in sight;
/// * 1 구름 — two shadow clones flank the cat and fight beside it;
/// * 2 까미 — invincible charge: no damage at all, enemies it rams take hits.
/// Activation plays a slow-motion cut-in (the shared [ultimateBanner]).
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

  /// Seconds of flight for a full charge before support bonuses.
  static const chargeSeconds = 90.0;

  /// Which signature the current craft fires (0 storm, 1 clones, 2 shield).
  int get ultimateKind => unifiedModules ? shipIndex.clamp(0, 2) : 0;

  static const ultimateNames = ['생선 미사일 폭풍', '그림자 분신', '무적 돌진'];
  static const ultimateAssets = [
    'assets/art/icons_v14/ult_storm.webp',
    'assets/art/icons_v14/ult_clone.webp',
    'assets/art/icons_v14/ult_shield.webp',
  ];
  String get ultimateName => ultimateNames[ultimateKind];

  String get ultimateDescription => hasCommonUltimate
      ? '$ultimateName · 충전 ${_ultimateCharge.floor()}% · 사용 $_ultimateUses회\n'
            '${switch (ultimateKind) {
              0 => '추적 미사일로 화면의 모든 적 격추',
              1 => '분신 2기가 10초 동안 함께 사격',
              _ => '8초 동안 무적 · 부딪힌 적에게 피해',
            }}'
      : '';

  bool get clonesActive => combatTime < cloneUntil;
  bool get invincibleActive => combatTime < invincibleUntil;

  /// The clones' places beside the cat (they trail its moves a little).
  List<Offset> get clonePositions =>
      clonesActive ? List.unmodifiable(_clonePos) : const [];

  bool activateCommonUltimate() {
    if (!ultimateReady) return false;
    visuals.emit(CombatCueKind.ultimate, position, radius: 130);
    _ultimateCharge = 0;
    _ultimateUses++;
    // the cut-in: name banner over a short slow motion
    ultimateBanner = ultimateName;
    ultimateShow = 1.6;
    // every signature first wipes the bullets around the cat
    shots.removeWhere(
      (s) => s.interceptable && (s.position - position).distance < 260,
    );
    switch (ultimateKind) {
      case 0:
        _stormLeft = math.min(48, math.max(18, enemies.length + 10));
        _stormNext = combatTime;
        _ultimateUntil = combatTime + 2.4;
      case 1:
        cloneUntil = combatTime + 10;
        // they fly in from beyond both edges of the cat
        _clonePos[0] = position + const Offset(-150, 30);
        _clonePos[1] = position + const Offset(150, 30);
        _ultimateUntil = cloneUntil;
        for (final c in clonePositions) {
          visuals.emit(CombatCueKind.level, c, radius: 60);
        }
      default:
        invincibleUntil = combatTime + 8;
        _ultimateUntil = invincibleUntil;
        visuals.emit(CombatCueKind.shield, position, radius: 90);
    }
    pickupNotice = ultimateName;
    noticeTime = 2;
    _event('shoot');
    return true;
  }

  void _updateCommonUltimate(double dt) {
    if (!hasCommonUltimate) return;
    if (ultimateRemaining > 0) {
      switch (ultimateKind) {
        case 0:
          _missileStorm();
        case 1:
          // clones glide into formation and trail the cat's moves
          const slots = [Offset(-62, 14), Offset(62, 14)];
          for (var i = 0; i < 2; i++) {
            _clonePos[i] = Offset.lerp(
              _clonePos[i],
              position + slots[i],
              math.min(1, dt * 6),
            )!;
          }
        default:
          _invincibleCharge();
      }
    } else {
      // Only charge the portion of a boundary frame after firing ends.
      final charging = math.min(dt, math.max(0, combatTime - _ultimateUntil));
      _ultimateCharge = math.min(
        100,
        _ultimateCharge +
            charging *
                (100 / chargeSeconds) *
                (1 + .15 * (moduleLoadout?.supportPower('capacitor') ?? 0)),
      );
    }
  }

  /// 치즈: fish missiles pour out of both sides in waves, each homing on its
  /// own enemy so the whole screen is cleared.
  void _missileStorm() {
    if (_stormLeft <= 0 || combatTime < _stormNext) return;
    _stormNext = combatTime + .1;
    final targets = enemies.where((e) => e.hp > 0 && !e.retired).toList()
      ..sort(
        (a, b) => (a.position - position).distance.compareTo(
          (b.position - position).distance,
        ),
      );
    for (var i = 0; i < 4 && _stormLeft > 0; i++, _stormLeft--) {
      final side = _stormLeft.isEven ? -1.0 : 1.0;
      final spread = (i - 1.5) * .35;
      final target = targets.isEmpty
          ? null
          : targets[_stormLeft % targets.length];
      shots.add(
        Shot(
          position + Offset(side * 22, 6),
          Offset(side * (220 + 60 * spread.abs()), -120 + 140 * spread),
          (target?.kind == 3 ? 90 : 900) * damageFactor,
          1,
          weapon: 'ult-missile',
          target: target,
          life: 3,
          radius: 7,
        ),
      );
    }
  }

  /// 까미: nothing hurts the cat; enemies it touches are rammed.
  void _invincibleCharge() {
    if (combatTime < _ramNext) return;
    _ramNext = combatTime + .25;
    for (final e in enemies) {
      if (e.hp <= 0 || e.retired) continue;
      if ((e.position - position).distance < e.radius + 54) {
        _hit(e, (e.kind == 3 ? 30 : 120) * damageFactor, 'common-ultimate');
        visuals.emit(CombatCueKind.impact, e.position, radius: 30);
      }
    }
    shots.removeWhere(
      (s) => s.interceptable && (s.position - position).distance < 60,
    );
  }
}
