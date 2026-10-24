import 'campaign.dart';

enum EnemyArmament {
  bullet,
  highExplosive,
  grenade,
  guidedBolt,
  missile,
  laser,
  mine,
  ram,
}

enum EnemyFlight { approach, patrol, evade, windup, attackRun }

class EnemyDoctrine {
  const EnemyDoctrine(this.range, this.weapon, this.cooldown, this.windup);
  final double range, cooldown, windup;
  final EnemyArmament weapon;
}

/// Ranges are in the same 420-wide battle coordinates as damage and art.
const enemyDoctrines = <EnemyRole, EnemyDoctrine>{
  EnemyRole.scout: EnemyDoctrine(175, EnemyArmament.bullet, 5.8, .45),
  EnemyRole.weaver: EnemyDoctrine(200, EnemyArmament.bullet, 5.2, .5),
  EnemyRole.bulwark: EnemyDoctrine(225, EnemyArmament.highExplosive, 7.5, 1.0),
  EnemyRole.spitter: EnemyDoctrine(245, EnemyArmament.grenade, 7.0, 1.0),
  EnemyRole.lancer: EnemyDoctrine(215, EnemyArmament.missile, 8.0, 1.0),
  EnemyRole.orbiter: EnemyDoctrine(220, EnemyArmament.guidedBolt, 6.5, .75),
  EnemyRole.miner: EnemyDoctrine(230, EnemyArmament.mine, 7.5, .7),
  EnemyRole.splitter: EnemyDoctrine(190, EnemyArmament.bullet, 6.2, .6),
  EnemyRole.sniper: EnemyDoctrine(295, EnemyArmament.laser, 8.0, 1.3),
  EnemyRole.carrier: EnemyDoctrine(310, EnemyArmament.missile, 10.0, 1.2),
  EnemyRole.kamikaze: EnemyDoctrine(0, EnemyArmament.ram, 0, 0),
};
