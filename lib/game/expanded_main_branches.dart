part of 'engine.dart';

extension ExpandedMainBranches on GameEngine {
  bool _branchLine(
    Offset at,
    Offset direction,
    double length,
    double width,
    double amount,
    String source,
  ) {
    final unit = _unit(direction);
    final landed = enemies.any(
      (e) => _lineHits(e, at, unit, length * mainReachFactor, width),
    );
    _lineDamage(at, direction, length, width, amount, source);
    return landed;
  }

  void _branchRing(Offset at, double radius, double amount, String source) {
    _radialDamage(at, radius, amount, source);
    shots.add(
      Shot(
        at,
        Offset.zero,
        0,
        13,
        weapon: 'main-ring',
        radius: radius * mainReachFactor,
        life: .16,
      ),
    );
  }

  bool _fireExpandedMainBranch(
    double power,
    bool evo,
    Foe? target,
    Offset forward,
  ) {
    final branch = mainBranch;
    if (branch == null ||
        !mainBranches.any(
          (s) =>
              s.branch == branch &&
              s.armament == armament &&
              s.branch.index >= 6,
        )) {
      return false;
    }
    final angle = math.atan2(forward.dy, forward.dx);
    final n = mainProjectiles;
    switch (armament) {
      case 'kunai':
        if (target == null) return true;
        final swarm = branch == MainBranch.needleSwarm;
        final candidates =
            enemies
                .where(
                  (e) =>
                      e.hp > 0 &&
                      !e.retired &&
                      (e.position - position).distance <= 600,
                )
                .toList()
              ..sort(
                (a, b) => precisionLinkActive && a.maxHp != b.maxHp
                    ? b.maxHp.compareTo(a.maxHp)
                    : (a.position - position).distanceSquared.compareTo(
                        (b.position - position).distanceSquared,
                      ),
              );
        final count = n + (evo ? 2 : 0) + (swarm ? 2 : 0);
        for (int i = 0; i < count; i++) {
          final aim = swarm && candidates.isNotEmpty
              ? candidates[i % candidates.length]
              : target;
          shots.add(
            Shot(
              position + Offset((i - (count - 1) / 2) * 6, -12),
              _unit(aim.position - position) * 360 * skillSpeed,
              power * damageFactor * (swarm ? .55 : .85),
              9,
              weapon: 'primary',
              target: aim,
              life: 2,
              pierce: swarm ? 0 : 2,
            ),
          );
        }
        _gun *= (evo ? .65 : 1) * (swarm ? 1.4 : 1);
      case 'katana':
      case 'bat':
      case 'lightchaser':
        var landed = false;
        for (int i = 0; i < n; i++) {
          final at =
              position + Offset((i.isOdd ? 1 : -1) * ((i + 1) ~/ 2) * 16.0, 0);
          if (branch == MainBranch.bladeLong) {
            landed =
                _branchLine(
                  at,
                  forward,
                  262.5 * areaFactor,
                  18,
                  power * 2.2,
                  'gun',
                ) ||
                landed;
            landed =
                _branchLine(
                  at,
                  -forward,
                  262.5 * areaFactor,
                  18,
                  power * 1.65,
                  'gun',
                ) ||
                landed;
          } else if (branch == MainBranch.bladeFan) {
            for (final turn in [-.45, 0.0, .45]) {
              landed =
                  _branchLine(
                    at,
                    _direction(angle + turn),
                    131.25 * areaFactor,
                    28,
                    power * 1.2,
                    'gun',
                  ) ||
                  landed;
            }
          } else if (branch == MainBranch.batRam) {
            _branchLine(
              at,
              forward,
              178.5 * areaFactor,
              35,
              power * 2.6,
              'gun',
            );
            if (evo) _branchRing(at, 84 * areaFactor, power * 1.4, 'gun');
          } else if (branch == MainBranch.batOrbit) {
            _branchRing(at, (evo ? 126 : 84) * areaFactor, power * 1.4, 'gun');
          } else if (branch == MainBranch.lightLance) {
            _branchLine(at, forward, 280 * areaFactor, 18, power * 2.1, 'gun');
            if (_primaryStrikes % 5 == 0 || evo) {
              _branchLine(
                at,
                -forward,
                175 * areaFactor,
                24,
                power * 1.5,
                'gun',
              );
            }
          } else if (branch == MainBranch.lightCross) {
            for (int ray = 0; ray < 4; ray++) {
              _branchLine(
                at,
                _direction(angle + ray * math.pi / 2),
                125 * areaFactor,
                24,
                power,
                'gun',
              );
            }
          }
        }
        if (armament == 'bat') {
          final ram = branch == MainBranch.batRam;
          for (final e in enemies) {
            final d = e.position - position;
            final along = d.dx * forward.dx + d.dy * forward.dy;
            final inRange = ram
                ? along > 0 &&
                      along < 178.5 * areaFactor * mainReachFactor &&
                      (d.dx * forward.dy - d.dy * forward.dx).abs() <
                          35 + e.radius
                : d.distance < (evo ? 126 : 84) * areaFactor * mainReachFactor;
            if (e.hp > 0 && e.kind != 3 && inRange) {
              e.position += _unit(d) * (ram ? 55 : 24);
            }
          }
        }
        if (armament == 'katana' && evo && landed) {
          hp = math.min(maxHp, hp + maxHp * .005);
        }
        if (armament == 'lightchaser' && evo && _primaryStrikes % 10 == 0) {
          shots.add(
            Shot(
              position,
              Offset.zero,
              power * damageFactor,
              13,
              weapon: 'sword-array',
              life: 2,
              radius: 90 * areaFactor,
            ),
          );
        }
        _gun *= branch == MainBranch.bladeLong || branch == MainBranch.batRam
            ? 2.5
            : armament == 'lightchaser'
            ? 2.3
            : 2;
        _primaryStrikes++;
      case 'void':
        final drift = branch == MainBranch.voidDrift;
        if (!drift && target == null) return true;
        for (int i = 0; i < n; i++) {
          final offset = Offset((i.isOdd ? 1 : -1) * ((i + 1) ~/ 2) * 70.0, 0);
          shots.add(
            Shot(
              (drift ? position + forward * 60 : target!.position) + offset,
              drift ? forward * 70 : Offset.zero,
              power * .65 * damageFactor * (drift ? .7 : 1.35),
              13,
              weapon: 'void',
              life: drift ? (evo ? 2.4 : 1.6) : (evo ? 3 : 2),
              radius: (drift ? 90 : 49) * areaFactor,
            ),
          );
        }
        _gun = (drift ? 1.8 : 2.2) * cooldownFactor * mainInterval;
      case 'disorder':
        if (target == null) return true;
        final release = branch == MainBranch.soulRelease;
        if (release) {
          final spent = math.min(10, soulStacks);
          soulStacks -= spent;
          for (int i = 0; i < n; i++) {
            shots.add(
              Shot(
                position,
                _direction(angle + (i - (n - 1) / 2) * .18) * 420 * skillSpeed,
                power * .8 * (1 + spent * .06) * damageFactor,
                0,
                weapon: 'soul',
                pierce: 1,
                radius: mainWidth,
              ),
            );
          }
        } else {
          for (int i = 0; i < n; i++) {
            shots.add(
              Shot(
                position + Offset(i * 10.0, 0),
                _unit(target.position - position) * 330 * skillSpeed,
                power * .8 * (1 + soulStacks * .012) * damageFactor,
                9,
                weapon: 'soul',
                target: target,
                pierce: 2,
                life: 3,
              ),
            );
          }
        }
        if (evo && _primaryStrikes++ % 8 == 0) {
          _radialDamage(
            position,
            150,
            power + soulStacks * permanentMainFactor * _mainAttackMultiplier,
            'soul',
          );
        }
      case 'lance':
        final ring = branch == MainBranch.lanceRing;
        _branchRing(
          position,
          (100 + mainPower * 10) * areaFactor * (ring ? 1.45 : .65),
          power * (ring ? 1.5 : .75),
          'starforge',
        );
        for (int i = 0; i < n; i++) {
          _branchLine(
            position,
            _direction(angle + (i - (n - 1) / 2) * .16),
            ring ? 150 : 400,
            ring ? 25 : 18,
            power * (ring ? 1.2 : 2.4),
            'havoc',
          );
        }
        if (evo) {
          shots.add(
            Shot(
              position + forward * 100,
              Offset.zero,
              power * damageFactor,
              13,
              weapon: 'fissure',
              life: 1.6,
              radius: 60,
            ),
          );
          if (target != null) {
            shots.add(
              Shot(
                position,
                _unit(target.position - position) * 320,
                power * damageFactor,
                9,
                weapon: 'lance',
                target: target,
                life: 2,
              ),
            );
          }
        }
        _gun = (ring ? 1.3 : 1.4) * cooldownFactor * mainInterval;
    }
    return true;
  }
}
