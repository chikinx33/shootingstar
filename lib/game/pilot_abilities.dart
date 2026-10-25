part of 'engine.dart';

extension PilotAbilities on GameEngine {
  /// The three guardian cats' fixed traits (lib/data/combat_loadout.dart).
  bool get pilotIsCatTrait =>
      const ['common', 'king', 'elaine'].contains(pilot);
  int get pilotSkillLevel => pilotIsCatTrait
      ? traitLevel.clamp(1, 5)
      : (upgrades['pilot'] ?? passives['pilot'] ?? 0);
  bool get pilotUsesPassive => ['common', 'king', 'venato'].contains(pilot);
  String get pilotStateText => switch (pilot) {
    'yang' => pilotStance == 0 ? '태양 자세 · 관통 타격' : '보호 자세 · 회복·차폐',
    'metallia' => '원소 · ${['독', '냉기', '전기'][pilotStance]}',
    'taloxa' =>
      '동기화 ${pilotSync.round()}% · ${pilotMech ? '기갑 · 수평 빔' : '기본 · 추적 사격'}',
    'venato' =>
      '${pilotBuff > 0 ? '혈투 활성' : '혈투 대기'} · 차폐 ${pilotShield.round()}',
    _ => '',
  };
  bool isPassiveSkill(String id) =>
      id == 'pilot' ? pilotUsesPassive : combatSkill(id).passive;
  String get pilotAbilityLabel => switch (pilot) {
    'yang' => pilotStance == 0 ? '보호 자세' : '태양 자세',
    'metallia' => '원소 전환',
    'taloxa' => '체인 동기화',
    'venato' => '혈투 개시',
    _ => '고유 능력 발동',
  };
  bool get pilotHasActive => [
    'yang',
    'metallia',
    'taloxa',
    'venato',
    'nezha',
    'vulcan',
    'loki',
  ].contains(pilot);
  bool activatePilotAbility() {
    if (!pilotHasActive ||
        paused ||
        finished ||
        choices.isNotEmpty ||
        pilotAbilityCooldown > 0) {
      return false;
    }
    visuals.emit(CombatCueKind.pilot, position, radius: 85, source: pilot);
    pilotAbilityCooldown = 20;
    if (pilot == 'yang' || pilot == 'metallia') {
      pilotStance = (pilotStance + 1) % (pilot == 'yang' ? 2 : 3);
    }
    if (pilot == 'taloxa') {
      pilotSync = (pilotSync + 100).clamp(0, 400);
      if (pilotSync >= 200) pilotMech = true;
      pilotBuff = 10;
    } else if (pilot == 'venato') {
      pilotBuff = 10;
    } else {
      pilotShield = math.min(maxHp * .25, pilotShield + maxHp * .1);
      _radialDamage(
        position,
        150 * areaFactor,
        30 + pilotSkillLevel * 12,
        'pilot-active',
        mark: true,
      );
    }
    pickupNotice = pilotAbilityLabel;
    noticeTime = 2;
    return true;
  }

  void _pilotWeapon(double dt) {
    pilotAbilityCooldown = math.max(0, pilotAbilityCooldown - dt);
    pilotBuff = math.max(0, pilotBuff - dt);
    if (pilot == 'taloxa') {
      pilotSync = (pilotSync + (pilotMech ? -10 : 1) * dt).clamp(
        0,
        pilotMech ? 400 : 300,
      );
      if (pilotSync <= 0) pilotMech = false;
    }
    if (pilot == 'venato' && pilotBuff > 0) {
      final loss = math.min(math.max(0, hp - 1), maxHp * .08 * dt);
      hp -= loss;
      pilotShield = math.min(maxHp * .8, pilotShield + loss);
    }
    if (modular && aircraft!.parts[AircraftMount.auxiliary] != 'turret') return;
    final level = pilotSkillLevel;
    if (level <= 0) return;
    final evo = evolved.contains('pilot');
    final damage = ((12 + level * 7) * (evo ? 1.4 : 1.0)).toDouble();
    final at = _nearest();
    final period = switch (pilot) {
      'yelena' => .5,
      'taloxa' => pilotMech ? .8 : 1.2,
      'venato' => 1.0,
      'king' || 'common' => 5.0,
      _ => 2.0,
    };
    if (!_ready('pilot', period * cooldownFactor)) return;
    switch (pilot) {
      case 'common':
      case 'king':
        break;
      case 'cat':
        hp = math.min(maxHp, hp + maxHp * (evo ? .04 : .02));
        if (at != null) {
          shots.add(
            Shot(
              position,
              _unit(at.position - position) * 280,
              damage * .6 * damageFactor,
              9,
              weapon: 'medic',
              target: at,
              life: 2,
            ),
          );
        }
      case 'worm':
        for (final e in enemies) {
          if ((e.position - position).distance < 220 * areaFactor) {
            e.vulnerable = evo ? 5 : 3;
          }
        }
        if (evo && at != null) _hit(at, damage * damageFactor, 'bug');
      case 'wesson':
        if (at != null) {
          shots.add(
            Shot(
              at.position,
              Offset.zero,
              damage * 2 * damageFactor,
              15,
              weapon: 'emp',
              life: 1,
              radius: 30,
            ),
          );
        }
      case 'yelena':
        if (at != null) {
          for (int i = 0; i < (evo ? 5 : 3); i++) {
            shots.add(
              Shot(
                position + Offset(i * 5.0, 0),
                _unit(at.position - position) * 440 * skillSpeed,
                damage * .5 * damageFactor,
                0,
                weapon: 'pistol',
              ),
            );
          }
        }
      case 'yang':
        if (pilotStance == 0) {
          _lineDamage(
            position,
            _direction(movementAngle),
            300,
            35 * areaFactor,
            damage * 2,
            'palm',
          );
          if (evo && at != null) at.vulnerable = 4;
        } else {
          pilotShield = math.min(maxHp * .25, pilotShield + maxHp * .04);
          hp = math.min(maxHp, hp + maxHp * .02);
          _radialDamage(position, 100, damage, 'palm');
        }
      case 'metallia':
        for (final e in enemies) {
          if ((e.position - position).distance < 280) {
            e.status = pilotStance == 0
                ? 1
                : pilotStance == 1
                ? 2
                : 3;
            e.statusTime = 3;
            _hit(e, damage * damageFactor, 'element');
            if (evo) e.vulnerable = 3;
          }
        }
      case 'joey':
        _lineDamage(
          position,
          _direction(movementAngle),
          320,
          35,
          damage * 2,
          'weakpoint',
        );
        if (at != null && (at.position - position).distance < 320) {
          at.vulnerable = evo ? 5 : 3;
        }
      case 'taloxa':
        if (pilotMech) {
          _lineDamage(
            position,
            const Offset(1, 0),
            450,
            24,
            damage * 2,
            'mech',
          );
          _lineDamage(
            position,
            const Offset(-1, 0),
            450,
            24,
            damage * 2,
            'mech',
          );
        } else if (at != null) {
          shots.add(
            Shot(
              position,
              _unit(at.position - position) * 300,
              damage * damageFactor,
              9,
              weapon: 'funnel',
              target: at,
              life: 2,
            ),
          );
          at.vulnerable = 3;
        }
      case 'venato':
        if (pilotBuff > 0) {
          _radialDamage(
            position,
            140 * areaFactor,
            damage,
            'blood',
            mark: true,
          );
        }
      case 'elaine':
        pilotShield = math.min(
          maxHp * .25,
          pilotShield + maxHp * (hp < maxHp * .5 ? .08 : .03),
        );
        if (at != null) {
          _hit(
            at,
            damage * (hp < maxHp * .5 ? 1.5 : 1) * damageFactor,
            'shield-counter',
          );
        }
      case 'nezha':
      case 'vulcan':
        _radialDamage(
          position,
          (pilot == 'nezha' ? 130 : 170) * areaFactor,
          damage,
          'divine-fire',
        );
        for (final e in enemies) {
          if ((e.position - position).distance < 170) {
            e.status = 3;
            e.statusTime = 3;
          }
        }
        if (pilot == 'vulcan' && evo) {
          _radialDamage(position, 220, damage, 'forge');
        }
      case 'loki':
        if (at != null) {
          for (int i = 0; i < (evo ? 3 : 2); i++) {
            shots.add(
              Shot(
                position + Offset((i - 1) * 40.0, 20),
                _unit(at.position - position) * 300,
                damage * .65 * damageFactor,
                9,
                weapon: 'illusion',
                target: at,
                life: 2,
              ),
            );
          }
        }
      default: // tsuki: the round slash
        _radialDamage(position, 130 * areaFactor, damage, 'moon');
        if (evo) {
          _lineDamage(
            position,
            _direction(movementAngle),
            250,
            35,
            damage,
            'moon',
          );
        }
    }
  }
}
