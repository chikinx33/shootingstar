part of 'engine.dart';

/// Main-gun hit helpers shared by the cat guns (v12.17: the old '주포 특화'
/// branch choices that lived here are gone).
extension MainGunHits on GameEngine {
  bool _choiceIsPassive(UpgradeChoice c) =>
      !c.specialization && c.id != 'repair' && isPassiveSkill(c.id);

  // Shards are deferred until after collision iteration; they never split again.
  double _primaryHitDamage(Shot s) {
    if (!s.closeRange) return s.damage;
    return s.damage * (s.distanceTravelled <= 140 ? 1.5 : .55);
  }

  void _splitShell(Shot s, Foe hit) {
    if (!s.splitOnHit) return;
    s.splitOnHit = false;
    final angle = math.atan2(s.velocity.dy, s.velocity.dx);
    for (final turn in [-.65, .65]) {
      final shard = Shot(
        s.position,
        _direction(angle + turn) * 330 * skillSpeed,
        s.damage * .4,
        0,
        weapon: 'gun',
        life: .45,
        radius: 3,
      );
      shard.hitTargets.add(hit);
      shard.triggersSynergies = false;
      _deferredShots.add(shard);
    }
  }
}
