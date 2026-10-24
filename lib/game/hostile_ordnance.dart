part of 'engine.dart';

/// Hostile kinds 19..24 never enter the player-weapon hit loop.
extension HostileOrdnance on GameEngine {
  bool _stepHostileShot(Shot s, double dt) {
    if (s.kind < 19 || s.kind > 24) return false;
    if (s.life < -dt) return true;
    if (s.kind == 23) {
      final length = s.velocity.distance;
      final direction = _unit(s.velocity);
      final relative = position - s.position;
      final along = relative.dx * direction.dx + relative.dy * direction.dy;
      final across = (relative.dx * direction.dy - relative.dy * direction.dx)
          .abs();
      if (along >= 0 &&
          along <= length &&
          across <= s.radius + hitRadius &&
          s.hitCooldown <= 0) {
        if (_hurt <= 0) _damage(s.damage, source: '레이저');
        s.hitCooldown = 1;
      }
      return true;
    }
    if (s.kind == 24) {
      // Damage was applied once when the explosion was created.
      return true;
    }
    if (s.kind == 19 || s.kind == 20) {
      final missile = s.kind == 20;
      // Limited steering ends before expiry, allowing lateral evasion.
      if (s.age < (missile ? 1.7 : 1.05)) {
        final desired = math.atan2(
          position.dy - s.position.dy,
          position.dx - s.position.dx,
        );
        final heading = math.atan2(s.velocity.dy, s.velocity.dx);
        final difference = math.atan2(
          math.sin(desired - heading),
          math.cos(desired - heading),
        );
        final turn = (missile ? .85 : 1.25) * dt;
        s.velocity =
            _direction(heading + difference.clamp(-turn, turn)) *
            (missile ? 180 : 140);
      }
      s.position += s.velocity * dt;
      if ((position - s.position).distance < s.radius + hitRadius) {
        if (missile) {
          _enemyBlast(s.position, 30, s.damage);
        } else if (_hurt <= 0) {
          _damage(s.damage, source: '유도탄');
        }
        s.life = 0;
      }
      return true;
    }
    if (s.anchor != null) {
      final delta = s.anchor! - s.position;
      final step = s.velocity.distance * dt;
      if (s.life <= 0 || delta.distance <= step) {
        s.position = s.anchor!;
        _enemyBlast(s.position, s.radius, s.damage);
        s.life = 0;
      } else {
        s.position += _unit(delta) * step;
      }
    }
    return true;
  }

  void _enemyBlast(Offset at, double radius, double damage) {
    onEvent?.call('explosion');
    if ((position - at).distance < radius + hitRadius && _hurt <= 0) {
      _damage(damage, source: '폭발');
    }
    // A short-lived raster blast; damage is applied once at detonation.
    _deferredShots.add(
      Shot(
        at,
        Offset.zero,
        0,
        24,
        weapon: 'enemy-blast',
        life: .4,
        radius: radius,
      ),
    );
    _burst(at, 0, 6);
  }
}
