import '../data/campaign.dart' show EnemyRole;

enum FlightFormation { column, fan, bulwark, assault }

/// Route identity changes composition and cadence, never enemy telegraph time.
class RouteWavePlan {
  const RouteWavePlan(
    this.name,
    this.phases,
    this.formations,
    this.interval,
    this.assaultFirst,
    this.assaultInterval,
    this.role,
    this.roleChance,
  );
  final String name;
  final List<int> phases;
  final List<FlightFormation> formations;
  final double interval, assaultFirst, assaultInterval, roleChance;
  final EnemyRole role;
}

const _column = FlightFormation.column;
const _fan = FlightFormation.fan;
const _shield = FlightFormation.bulwark;

// Ten route archetypes × ten existing world role pools. Order is deterministic;
// only the existing ordinary population rolls use the seeded random stream.
const routeWavePlans = [
  RouteWavePlan(
    '접근',
    [0, 1, 2, 3, 4, 5],
    [_column, _fan, _shield],
    20,
    18,
    34,
    EnemyRole.scout,
    0,
  ),
  RouteWavePlan(
    '외곽',
    [0, 1, 2, 1, 4, 5],
    [_fan, _column, _shield],
    21,
    20,
    36,
    EnemyRole.scout,
    .30,
  ),
  RouteWavePlan(
    '측면',
    [0, 2, 1, 2, 4, 5],
    [_fan, _column, _shield],
    20,
    18,
    30,
    EnemyRole.weaver,
    .32,
  ),
  RouteWavePlan(
    '포격',
    [0, 1, 3, 2, 3, 5],
    [_column, _shield, _fan, _shield],
    22,
    22,
    36,
    EnemyRole.spitter,
    .30,
  ),
  RouteWavePlan(
    '전초',
    [0, 3, 2, 3, 4, 5],
    [_column, _shield, _fan],
    19,
    20,
    32,
    EnemyRole.bulwark,
    .28,
  ),
  RouteWavePlan(
    '기뢰',
    [0, 1, 3, 2, 4, 5],
    [_fan, _shield, _column],
    22,
    22,
    36,
    EnemyRole.miner,
    .30,
  ),
  RouteWavePlan(
    '추격',
    [0, 2, 1, 2, 4, 5],
    [_column, _fan, _shield],
    18,
    18,
    26,
    EnemyRole.lancer,
    .30,
  ),
  RouteWavePlan(
    '장갑',
    [0, 3, 1, 3, 4, 5],
    [_shield, _column, _shield, _fan],
    21,
    22,
    34,
    EnemyRole.bulwark,
    .34,
  ),
  RouteWavePlan(
    '혼성',
    [0, 2, 3, 1, 4, 5],
    [_fan, _shield, _column],
    18,
    18,
    28,
    EnemyRole.splitter,
    .26,
  ),
  RouteWavePlan(
    '수문장',
    [0, 3, 2, 4, 3, 5],
    [_column, _shield, _fan, _shield],
    18,
    18,
    28,
    EnemyRole.carrier,
    .24,
  ),
];

/// Chapter time drives encounters; the clock stops during boss combat.
class WaveSpec {
  const WaveSpec(
    this.name,
    this.interval,
    this.count,
    this.runnerChance,
    this.heavyChance, {
    this.grouped = false,
  });
  final String name;
  final double interval, runnerChance, heavyChance;
  final int count;
  final bool grouped;
}

const encounterWaves = [
  WaveSpec('정찰 교전', .95, 3, .10, 0),
  WaveSpec('측면 포위', .75, 6, .20, 0),
  WaveSpec('교차 비행 · 돌입 편대', .65, 7, .70, .05, grouped: true),
  WaveSpec('중장갑 포격', .95, 6, .10, .55, grouped: true),
  WaveSpec('혼성 함대', .50, 10, .35, .15),
  WaveSpec('잔적 소탕', 1.3, 3, .15, .10),
];

int encounterPhase(double elapsed, double sectorDuration) {
  final progress = (elapsed % sectorDuration) / sectorDuration;
  if (progress < .15) return 0;
  if (progress < .35) return 1;
  if (progress < .55) return 2;
  if (progress < .70) return 3;
  if (progress < .90) return 4;
  return 5;
}

WaveSpec routeWave(int sector, int phase) {
  final plan = routeWavePlans[sector.clamp(0, 9)];
  final index = plan.phases[phase.clamp(0, 5)];
  final base = encounterWaves[index];
  // A readable opening, two tests, a peak, then collection before each boss.
  // The late-route peak adds at most one ordinary unit, not new HP/damage.
  final recovery = phase == 5;
  return WaveSpec(
    '${plan.name} · ${recovery ? '보스 전 소탕' : base.name}',
    recovery ? 1.65 : base.interval,
    recovery ? 2 : base.count + (sector >= 6 && phase >= 2 ? 1 : 0),
    base.runnerChance,
    recovery ? 0 : base.heavyChance,
    grouped: base.grouped,
  );
}
