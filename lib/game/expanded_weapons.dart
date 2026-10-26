part of 'engine.dart';

extension ExpandedWeapons on GameEngine {
  bool _ready(String id, double period) {
    if ((_extraTimers[id] ?? 0) > 0) return false;
    _extraTimers[id] = period;
    return true;
  }

  void _radialDamage(
    Offset at,
    double radius,
    double amount,
    String source, {
    bool slow = false,
    bool mark = false,
  }) {
    if (const {'gun', 'soul', 'starforge'}.contains(source)) {
      radius *= mainReachFactor;
    }
    visuals.emit(
      CombatCueKind.area,
      at,
      radius: radius,
      source: source,
      throttle: 'area-$source',
      interval: .28,
    );
    for (final e in enemies) {
      if (e.hp > 0 &&
          (!modular || modularSourceCanHit(source, e)) &&
          (e.position - at).distance < radius + e.radius) {
        _hit(e, amount * damageFactor, source);
        if (slow) {
          e.status = 2;
          e.statusTime = 1.2;
        }
        if (mark) e.vulnerable = 3;
      }
    }
  }

  // The same forward swept volume is used for direct damage and branch hit
  // confirmation. Include the target's radius at the far end of the strike.
  bool _lineHits(
    Foe target,
    Offset at,
    Offset unit,
    double length,
    double width,
  ) {
    if (target.hp <= 0 || target.retired) return false;
    final delta = target.position - at;
    final along = delta.dx * unit.dx + delta.dy * unit.dy;
    if (along <= 0) return false;
    final nearest = at + unit * math.min(along, length);
    return (target.position - nearest).distance < width + target.radius;
  }

  void _lineDamage(
    Offset at,
    Offset direction,
    double length,
    double width,
    double damage,
    String source, {
    bool slow = false,
  }) {
    if (source == 'gun' || source == 'havoc') length *= mainReachFactor;
    final unit = _unit(direction);
    for (final e in enemies) {
      if ((!modular || modularSourceCanHit(source, e)) &&
          _lineHits(e, at, unit, length, width)) {
        _hit(e, damage * damageFactor, source);
        if (slow && e.hp > 0 && e.kind != 3) {
          e.status = 2;
          e.statusTime = math.max(e.statusTime, .8);
        }
      }
    }
    shots.add(
      Shot(at, unit * length, 0, 18, weapon: source, life: .16, radius: width),
    );
  }

  void _mainPickup(int axis) {
    if (axis == 0) mainRate = (mainRate + 1).clamp(0, 5);
    if (axis == 1) mainPower = (mainPower + 1).clamp(0, 5);
    if (axis == 2) mainCount = (mainCount + 1).clamp(0, 4);
    // Field pickups cannot erase a level earned from a draft or boss chest.
    upgrades['gun'] = math.max(
      upgrades['gun'] ?? 1,
      (1 + (mainRate + mainPower + mainCount) ~/ 3).clamp(1, 5),
    );
    if (mainRate >= 3 &&
        mainPower >= 3 &&
        mainCount >= 2 &&
        !evolved.contains('gun')) {
      _evolve('gun');
      pickupNotice =
          '주포 독립 진화 · ${content.armaments.firstWhere((w) => w.id == armament).name}';
    } else {
      pickupNotice =
          '주포 ${['연사', '출력·굵기', '발사 수'][axis]} 강화 · $mainRate / $mainPower / $mainCount';
    }
    _event('level');
  }

  Offset _safeDrop() {
    for (var attempt = 0; attempt < 8; attempt++) {
      final at =
          position +
          _direction(random.nextDouble() * math.pi * 2) *
              (120 + random.nextDouble() * 45);
      if (at.dx >= 36 &&
          at.dx <= GameEngine.worldWidth - 36 &&
          at.dy >= 36 &&
          at.dy <= GameEngine.worldHeight - 36)
        return at;
    }
    // A corner cannot clamp a pickup onto the player. Head inward instead.
    return position +
        _unit(
              const Offset(
                    GameEngine.worldWidth / 2,
                    GameEngine.worldHeight / 2,
                  ) -
                  position,
            ) *
            140;
  }

  void _dropFieldSupplies(double dt) {
    _magnetClock -= dt;
    _mainClock -= dt;
    if (_magnetClock <= 0 && supplies.where((s) => s.kind == 1).isEmpty) {
      supplies.add(Supply(_safeDrop(), 1));
      _magnetClock = 60;
    }
    if (_mainClock <= 0 && supplies.where((s) => s.kind >= 4).length < 2) {
      final axes = [mainRate < 5, mainPower < 5, mainCount < 4];
      for (int n = 0; n < 3; n++) {
        final axis = (_mainDrop + n) % 3;
        if (axes[axis]) {
          supplies.add(Supply(_safeDrop(), 4 + axis));
          _mainDrop = axis + 1;
          break;
        }
      }
      _mainClock = 30;
    }
  }

  void _fireArmament(int gun) {
    final evo = evolved.contains('gun');
    final power =
        (13 + gun * 4) * mainDamage * techDamage('gun') * _mainAttackMultiplier;
    final target = _mainTarget();
    final forward = _direction(movementAngle);
    switch (armament) {
      case 'shotgun':
        final count = evo ? mainProjectiles + 1 : 5 + mainCount;
        final aimed = math.atan2(forward.dy, forward.dx);
        final spacing = evo ? .04 : .13;
        for (int i = 0; i < count; i++) {
          shots.add(
            Shot(
              position,
              _direction(aimed + (i - (count - 1) / 2) * spacing) *
                  420 *
                  skillSpeed,
              power * .65 * damageFactor,
              0,
              weapon: 'gun',
              radius: mainWidth,
            ),
          );
        }
        _gun *= evo ? .55 : 1.5;
      case 'revolver':
        final railDamage = power * 3 * damageFactor;
        final railPierce = evo ? 3 : 0;
        final direction = target == null
            ? forward
            : _unit(target.position - position);
        shots.add(
          Shot(
            position,
            direction * 520 * skillSpeed,
            railDamage,
            0,
            weapon: 'gun',
            radius: mainWidth,
            pierce: railPierce,
          ),
        );
        for (int i = 1; i < mainProjectiles; i++) {
          shots.add(
            Shot(
              position + Offset((i.isOdd ? 1 : -1) * ((i + 1) ~/ 2) * 12.0, 0),
              direction * 520 * skillSpeed,
              railDamage,
              0,
              weapon: 'gun',
              radius: mainWidth,
              pierce: railPierce,
            ),
          );
        }
        revolverAmmo--;
        _gun *= 1.4;
        if (revolverAmmo <= 0) {
          _gun = 1.4;
          revolverAmmo = 6;
        }
      default:
        _radialDamage(position, 150 * areaFactor, power, 'gun');
        _gun = 1 * cooldownFactor * mainInterval;
    }
  }

  void _expandedWeapons(double dt) {
    _extraTimers.updateAll((key, value) => value - dt);
    for (final id in ['ball', 'drill', 'brick', 'boomerang', 'durian']) {
      final level = upgrades[id] ?? 0;
      if (level == 0) continue;
      final evo = evolved.contains(id);
      if (!_ready(
        id,
        (id == 'durian'
                ? 4
                : id == 'brick'
                ? 1.5
                : 2.5) *
            cooldownFactor,
      )) {
        continue;
      }
      final count = id == 'durian'
          ? 1
          : math.min(evo ? 6 : 4, 1 + level ~/ 2 + (evo ? 2 : 0));
      for (int i = 0; i < count; i++) {
        final target = _nearest();
        var direction = _direction(random.nextDouble() * math.pi * 2);
        if (id == 'brick' && evo) {
          direction = _direction(i * math.pi * 2 / count);
        } else if (id == 'brick') {
          direction = _direction(-math.pi / 2 + (i - (count - 1) / 2) * .3);
        }
        if (id == 'boomerang') {
          direction = _direction(movementAngle + (i - (count - 1) / 2) * .4);
        }
        final kind = switch (id) {
          'ball' => 7,
          'boomerang' => 8,
          'drill' => 9,
          'brick' => 10,
          _ => 12,
        };
        shots.add(
          Shot(
            position,
            direction *
                (id == 'durian'
                    ? 100
                    : id == 'brick'
                    ? 260
                    : id == 'ball' && evo
                    ? 420
                    : 250) *
                skillSpeed,
            (18 + level * 9) * (evo ? 1.35 : 1) * damageFactor,
            kind,
            weapon: id,
            target: evo && id == 'drill' ? target : null,
            life: (id == 'brick' ? 2.5 : 4) * durationFactor,
            radius: id == 'durian'
                ? 26 * areaFactor * (evo ? 1.4 : 1)
                : id == 'brick'
                ? 10
                : 7,
            anchor: null,
          ),
        );
      }
    }
    final laser = upgrades['laser'] ?? 0;
    if (laser > 0 && _ready('laser', 2.1 * cooldownFactor)) {
      final evo = evolved.contains('laser');
      for (int i = 0; i < (evo ? 6 : 2 + laser ~/ 2); i++) {
        _lineDamage(
          position,
          _direction(combatTime * .8 + i * math.pi / 3),
          420,
          7,
          (16 + laser * 7),
          'laser',
          slow: synergyReady('front-break'),
        );
      }
      if (evo) {
        for (final e in enemies) {
          if ((e.position - position).distance < 220) {
            e.status = 2;
            e.statusTime = 1.3;
          }
        }
      }
    }
    final force = upgrades['forcefield'] ?? 0;
    if (force > 0 && _ready('forcefield', .5)) {
      _radialDamage(
        position,
        (55 + force * 8) * areaFactor,
        5 + force * 3,
        'forcefield',
        slow: evolved.contains('forcefield'),
      );
    }
    final droneB = upgrades['droneB'] ?? 0;
    if (droneB > 0 && _ready('droneB', .9 * cooldownFactor)) {
      for (int i = 0; i < 2; i++) {
        shots.add(
          Shot(
            position,
            _direction(movementAngle + (i == 0 ? -.4 : .4)) * 260,
            (12 + droneB * 5) * damageFactor,
            2,
            weapon: 'droneB',
            life: 2,
          ),
        );
      }
    }
    if ((upgrades['medicDrone'] ?? 0) > 0) {
      if (_ready('medicFire', .3 * cooldownFactor)) {
        final target = _nearest();
        if (target != null) {
          shots.add(
            Shot(
              position,
              _unit(target.position - position) * 340,
              42 * damageFactor,
              9,
              weapon: 'medicDrone',
              target: target,
              life: 2,
            ),
          );
        }
      }
      if (_ready('medicHeal', 5)) hp = math.min(maxHp, hp + maxHp * .04);
    }
    for (final id in ['infernoMine', 'thunderMine']) {
      if ((upgrades[id] ?? 0) > 0 && _ready(id, 1.5 * cooldownFactor)) {
        shots.add(
          Shot(
            position - _direction(movementAngle) * 35,
            Offset.zero,
            120 * damageFactor,
            15,
            weapon: id,
            life: 4,
            radius: 26 * areaFactor,
          ),
        );
      }
    }
    if ((passives['regen'] ?? 0) > 0 && _ready('regen', 5)) {
      hp = math.min(maxHp, hp + maxHp * .01 * passives['regen']!);
    }
    _pilotWeapon(dt);
  }

  bool _stepExpandedShot(Shot s, double dt) {
    if (s.kind == 18) {
      return true; // short-lived beam visual; damage resolved at fire time
    }
    if (s.kind == 17) {
      if (s.weapon == 'boss-mine') s.position += s.velocity * dt;
      if (s.age > 1 &&
          (position - s.position).distance < s.radius + 12 &&
          _hurt <= 0) {
        _damage(s.damage, source: '기뢰');
        s.life = 0;
      }
      return true;
    }
    if (s.kind < 7) return false;
    if (s.kind == 13) {
      if (s.hitCooldown <= 0) {
        for (final e in enemies) {
          if (e.hp > 0 &&
              (e.position - s.position).distance < s.radius + e.radius) {
            _hit(e, s.damage, s.weapon);
          }
        }
        s.hitCooldown = .4;
      }
      return true;
    }
    if (s.kind == 15) {
      if (s.age > .6 &&
          (s.life <= 0 ||
              enemies.any(
                (e) =>
                    e.hp > 0 &&
                    (e.position - s.position).distance < s.radius + e.radius,
              ))) {
        _radialDamage(
          s.position,
          100 * areaFactor,
          s.damage / damageFactor,
          s.weapon,
        );
        if (s.weapon == 'emp') {
          for (final e in enemies) {
            if ((e.position - s.position).distance < 120) {
              e.status = 2;
              e.statusTime = 2;
            }
          }
        } else if (s.weapon == 'infernoMine') {
          _deferredShots.add(
            Shot(
              s.position,
              Offset.zero,
              s.damage * .18,
              13,
              weapon: 'inferno',
              life: 3,
              radius: 85 * areaFactor,
            ),
          );
        } else {
          for (final e
              in enemies
                  .where(
                    (e) => e.hp > 0 && (e.position - s.position).distance < 220,
                  )
                  .take(6)) {
            _hit(e, s.damage * .4, 'thunderMine');
          }
        }
        _burst(s.position, 1, 8);
        s.life = 0;
      }
      return true;
    }
    if (s.kind == 8 && evolved.contains('boomerang')) {
      s.anchor ??= Offset(math.atan2(s.velocity.dy, s.velocity.dx), 0);
      s.position =
          position + _direction(s.age * 2 + s.anchor!.dx) * 130 * areaFactor;
      s.velocity = Offset.zero;
    } else if (s.kind == 8 && s.age > 1) {
      s.velocity = _unit(position - s.position) * 300 * skillSpeed;
      if ((s.position - position).distance < 15) {
        s.life = 0;
        _extraTimers['boomerang'] = 0;
      }
    }
    if (s.kind == 9 &&
        (s.target != null || const {'primary'}.contains(s.weapon))) {
      if (s.target == null ||
          s.target!.hp <= 0 ||
          !enemies.contains(s.target) ||
          s.hitTargets.contains(s.target)) {
        s.target = const {'primary'}.contains(s.weapon)
            ? _mainTarget(exclude: s.hitTargets)
            : _nearest();
      }
      if (s.target != null) {
        s.velocity = _unit(s.target!.position - s.position) * 320 * skillSpeed;
      }
    }
    if (s.kind == 10) s.velocity += Offset(0, 300 * dt);
    s.position += s.velocity * dt;
    if (s.kind == 7 || s.kind == 12) {
      s.anchor ??= position;
      final bounds = Rect.fromCenter(
        center: s.anchor!,
        width: 400,
        height: 560,
      );
      if (s.position.dx < bounds.left || s.position.dx > bounds.right) {
        s.velocity = Offset(-s.velocity.dx, s.velocity.dy);
        s.position = Offset(
          s.position.dx.clamp(bounds.left, bounds.right),
          s.position.dy,
        );
      }
      if (s.position.dy < bounds.top || s.position.dy > bounds.bottom) {
        s.velocity = Offset(s.velocity.dx, -s.velocity.dy);
        s.position = Offset(
          s.position.dx,
          s.position.dy.clamp(bounds.top, bounds.bottom),
        );
      }
      if (s.kind == 12 && evolved.contains('durian') && s.hitCooldown <= 0) {
        for (int i = 0; i < 6; i++) {
          _deferredShots.add(
            Shot(
              s.position,
              _direction(i * math.pi / 3) * 220,
              s.damage * .3,
              2,
              weapon: 'spike',
              life: 1.3,
            ),
          );
        }
      }
    }
    if (s.kind == 9 &&
        const {'primary'}.contains(s.weapon) &&
        (s.pierce > 0 || s.hitTargets.isNotEmpty)) {
      // Distinct-target tracking is authoritative; a global hit delay would
      // let fast penetrating missiles pass through the next foe harmlessly.
      s.hitCooldown = 0;
    }
    if (s.hitCooldown <= 0) {
      for (final e in enemies) {
        if (e.hp <= 0 ||
            (e.position - s.position).distance > e.radius + s.radius ||
            s.hitTargets.contains(e)) {
          continue;
        }
        _hit(e, s.damage, s.weapon);
        if (s.kind == 10 || (s.kind == 9 && !evolved.contains('drill'))) {
          s.hitTargets.add(e);
        }
        if (s.kind == 9 && ['primary', 'medicDrone'].contains(s.weapon)) {
          // Main-weapon penetration must retarget and never hit one foe twice.
          s.hitTargets.add(e);
          if (s.pierce > 0) {
            s.pierce--;
            s.target = null;
          } else {
            s.life = 0;
            break;
          }
        }
      }
      s.hitCooldown = s.kind == 12 ? .6 : .2;
    }
    return true;
  }

  void _offerFusionChoices(List<UpgradeChoice> pool) {
    for (final pair in [
      ('infernoMine', 'trail'),
      ('thunderMine', 'lightning'),
    ]) {
      if ((upgrades['mine'] ?? 0) == 5 &&
          (upgrades[pair.$2] ?? 0) == 5 &&
          !evolved.contains(pair.$2)) {
        final skill = skillFor(pair.$1);
        pool.add(
          UpgradeChoice(
            skill.id,
            skill.name,
            skill.recipeHint!,
            skill.id,
            evolution: true,
          ),
        );
      }
    }
    if (pilot == 'cat' &&
        evolved.contains('drone') &&
        pilotSkillLevel == 5 &&
        !upgrades.containsKey('medicDrone')) {
      final skill = skillFor('medicDrone');
      pool.add(
        UpgradeChoice(
          skill.id,
          skill.name,
          skill.recipeHint!,
          skill.id,
          evolution: true,
        ),
      );
    }
  }

  void _completeFusion(String id) {
    if (id == 'infernoMine' || id == 'thunderMine') {
      upgrades.remove('mine');
      evolved.remove('mine');
      final element = id == 'infernoMine' ? 'trail' : 'lightning';
      upgrades.remove(element);
      evolved.remove(element);
      upgrades[id] = 5;
    }
    if (id == 'medicDrone') {
      upgrades.remove('drone');
      upgrades.remove('pilot');
      evolved.remove('drone');
      upgrades[id] = 5;
    }
  }
}
