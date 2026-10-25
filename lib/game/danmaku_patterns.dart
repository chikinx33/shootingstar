import 'package:flutter/painting.dart';

import '../data/campaign.dart';

/// v12.9.8 enemy bullet patterns (user 2026-10-25: "analyse the reference
/// shooter thoroughly, don't invent"). Every table below is transcribed
/// from docs/WING_FIGHTER_ENEMY_PATTERNS.md §8 — the reference's own
/// emitter presets (bullet count, ways, angles, gaps, speeds, cycles,
/// telegraphs, damage coefficients). Speeds are reference units per second
/// (the screen is ~9 units tall); [danmakuUnit] converts them to pixels.
/// Own names and art; only the numbers come from the reference.
enum BulletLook {
  /// small round orb: rings, fans, spirals (spreading attacks)
  orb,

  /// big round orb (large picture, small hit box)
  bigOrb,

  /// long needle: fast snipes, needle trains
  needle,

  /// bar: aimed shots and aimed streams
  bar,

  /// homing missile
  missile,

  /// telegraphed beam
  beam,
}

/// One emitter: a reference `m_emitParam` queue item plus its cycle.
class Emit {
  const Emit({
    this.look = BulletLook.orb,
    this.ways = 1,
    this.step = 0,
    this.gap = 0,
    this.volleys = 1,
    this.volleyGap = 0,
    this.speed = 1,
    this.accel = 0,
    this.offset = 0,
    this.shift = 0,
    this.sweep = 0,
    this.sweepPeriod = 3.5,
    this.jitter = 0,
    this.speedJitter = 0,
    this.aimed = false,
    this.track = 0,
    this.warn = 0,
    this.beam = 0,
    this.dmg = 1,
    this.at = Offset.zero,
    this.mirror = false,
    this.start = 0,
    this.period = 4,
    this.life = 7,
  });

  final BulletLook look;

  /// Bullets per volley, [step] degrees apart (a full circle makes a ring);
  /// with [step] 0 they fly side by side [gap] units apart.
  final int ways;
  final double step, gap;

  /// Volleys per cycle, [volleyGap] seconds apart.
  final int volleys;
  final double volleyGap;

  /// Units/s, units/s² (negative stops the bullet: a mine).
  final double speed, accel;

  /// Degrees added to the base angle, and per volley (a spiral).
  final double offset, shift;

  /// A sine sweep of ±[sweep] degrees over [sweepPeriod] seconds.
  final double sweep, sweepPeriod;

  /// Random ±degrees per bullet and ± fraction of speed.
  final double jitter, speedJitter;

  /// Aimed at the cat (taken at the start of each cycle unless [track]).
  final bool aimed;

  /// Turret tracking in degrees/s: the barrel turns toward the cat slowly.
  final double track;

  /// Telegraph seconds before the cycle fires; with [beam] > 0 the cycle is
  /// a laser lasting [beam] seconds instead of bullets.
  final double warn, beam;

  /// Reference damage coefficient (rings 0.5, aimed streams 0.15-0.4,
  /// snipes up to 2.5).
  final double dmg;

  /// Muzzle offset from the unit's centre (px); [mirror] adds the mirrored
  /// muzzle (-dx) with the same timing.
  final Offset at;
  final bool mirror;

  /// First cycle after [start] seconds, then every [period] seconds.
  final double start, period;

  /// Bullet lifetime in seconds.
  final double life;
}

/// A boss phase: its share of the boss's health and its weapons.
class BossPhase {
  const BossPhase(this.share, this.emits);
  final double share;
  final List<Emit> emits;
}

class BossPatternSet {
  const BossPatternSet(this.name, this.phases);
  final String name;
  final List<BossPhase> phases;
}

const _b = BulletLook.bar, _n = BulletLook.needle;
const _big = BulletLook.bigOrb,
    _m = BulletLook.missile,
    _beam = BulletLook.beam;

/// §8.1 ordinary enemy patterns N1-N13 (N13 death mines stay the existing
/// miner mines). Air formations of rammers do not shoot (reference).
abstract final class NormalPatterns {
  // N1 aimed single turret (DanGuanPao_1): barrel tracks at 120°/s
  static const n1 = [
    Emit(look: _b, aimed: true, track: 120, speed: 1.0, period: 2.0, start: .8),
  ];
  // N2 aimed three-round burst (DanGuanPao)
  static const n2 = [
    Emit(
      look: _b,
      aimed: true,
      volleys: 3,
      volleyGap: .18,
      speed: 1.4,
      period: 4,
      start: 1,
      dmg: .5,
    ),
  ];
  // N3 straight repeater (lianshepao)
  static const n3 = [
    Emit(look: _b, volleys: 5, volleyGap: .21, speed: 1.0, period: 3.2),
  ];
  // N4 X four-way (sandanpao_4_01) / strong: 5 volleys, accel 0.2
  static const n4 = [
    Emit(ways: 4, step: 90, offset: 45, speed: 1.0, period: 4.5, dmg: .5),
  ];
  static const n4Strong = [
    Emit(
      ways: 4,
      step: 90,
      offset: 45,
      volleys: 5,
      volleyGap: .15,
      speed: 1.0,
      accel: .2,
      period: 4.5,
      dmg: .5,
    ),
  ];
  // N5 layered ring turret (sandanpao / _8_02): 3 rings, +4° each
  static const n5 = [
    Emit(
      ways: 8,
      step: 45,
      volleys: 3,
      volleyGap: .1,
      shift: 4,
      speed: 1.0,
      period: 5.2,
      dmg: .5,
    ),
  ];
  static const n5Strong = [
    Emit(
      ways: 16,
      step: 22.5,
      volleys: 3,
      volleyGap: .1,
      shift: 4,
      speed: 1.0,
      period: 5.2,
      dmg: .5,
    ),
  ];
  // N6 rotating trident (sanshepao / _up): -12° per volley
  static const n6 = [
    Emit(
      ways: 3,
      step: 120,
      volleys: 10,
      volleyGap: .28,
      shift: -12,
      speed: 1.0,
      period: 8,
    ),
  ];
  static const n6Strong = [
    Emit(
      ways: 5,
      step: 72,
      volleys: 10,
      volleyGap: .28,
      shift: -12,
      speed: 1.0,
      period: 8,
    ),
  ];
  // N7 six-way pulse (sanshepao_1)
  static const n7 = [
    Emit(ways: 6, step: 60, volleys: 3, volleyGap: .4, speed: .7, period: 4),
  ];
  // N8 twin wavering streams (jiguangpao): sine 24/18 as a sweep
  static const n8 = [
    Emit(
      look: _n,
      volleys: 45,
      volleyGap: .05,
      speed: 2.5,
      sweep: 18,
      sweepPeriod: 1.6,
      at: Offset(12, 0),
      mirror: true,
      period: 4,
      dmg: .3,
    ),
  ];
  // N9 telegraphed twin snipe (gaoshepao): warn 0.8 s, barrel 200°/s
  static const n9 = [
    Emit(
      look: _n,
      ways: 2,
      gap: .3,
      aimed: true,
      track: 200,
      speed: 6,
      warn: .8,
      period: 3.2,
      start: 1.2,
      dmg: .75,
    ),
  ];
  // N10 telegraphed laser turret (Tank_Laser): track 30°/s
  static const n10 = [
    Emit(
      look: _beam,
      aimed: true,
      track: 30,
      warn: .6,
      beam: 1.0,
      period: 6,
      start: 1.5,
      dmg: .6,
    ),
  ];
  // N11 homing missile pair (helicopter_small): left, 5 s, right
  static const n11 = [
    Emit(look: _m, at: Offset(-14, 0), speed: 1.8, start: .5, period: 8),
    Emit(look: _m, at: Offset(14, 0), speed: 1.8, start: 5.5, period: 8),
  ];
  // N12 close-range gatling (Tank_Gatlin): 2 rows, life 0.4 s
  static const n12 = [
    Emit(
      ways: 2,
      gap: .25,
      aimed: true,
      volleys: 10,
      volleyGap: .03,
      speed: 3,
      speedJitter: .33,
      life: .8,
      period: 6,
    ),
  ];

  /// The pattern a role uses; [deep] houses get the stronger variant.
  static List<Emit>? forRole(EnemyRole role, bool deep) => switch (role) {
    EnemyRole.scout => deep ? n3 : n1,
    EnemyRole.weaver => deep ? n8 : n2,
    EnemyRole.bulwark => deep ? n5Strong : n5,
    EnemyRole.spitter => deep ? n4Strong : n4,
    EnemyRole.lancer => n11,
    EnemyRole.orbiter => deep ? n6Strong : n6,
    EnemyRole.splitter => n7,
    EnemyRole.sniper => deep ? n10 : n9,
    EnemyRole.carrier => deep ? n12 : n3,
    // miners keep their mines; rammers never shoot (reference)
    EnemyRole.miner || EnemyRole.kamikaze => null,
  };
}

/// §8.2 mid-boss sets M1-M6, each with the reference's tempo ladder:
/// base / difficult / crazy.
abstract final class MidBossPatterns {
  static const sets = <List<List<Emit>>>[
    // M1 three-way bomber (helicopter → Sboss_helicopter_difficult/crazy)
    [
      [
        Emit(
          look: _big,
          ways: 3,
          step: 16,
          aimed: true,
          speed: 1,
          start: 2,
          period: 3,
        ),
      ],
      [
        Emit(
          look: _big,
          ways: 3,
          step: 16,
          aimed: true,
          speed: 1,
          start: 1.5,
          period: 1.5,
        ),
      ],
      [
        Emit(
          look: _big,
          ways: 3,
          step: 16,
          aimed: true,
          volleys: 3,
          volleyGap: .25,
          shift: 8,
          speed: 1,
          start: 1.5,
          period: 2.1,
        ),
      ],
    ],
    // M2 aimed repeater (helicopter_01 → Sboss_helicopter_01)
    [
      [
        Emit(
          look: _b,
          aimed: true,
          volleys: 12,
          volleyGap: .07,
          speed: 1.6,
          period: 5.6,
          dmg: .35,
        ),
      ],
      [
        Emit(
          look: _b,
          aimed: true,
          volleys: 12,
          volleyGap: .07,
          speed: 1.6,
          period: 1.6,
          dmg: .5,
        ),
      ],
      [
        Emit(
          look: _b,
          aimed: true,
          volleys: 12,
          volleyGap: .07,
          speed: 1.6,
          at: Offset(18, 6),
          mirror: true,
          period: 1.2,
          dmg: .5,
        ),
      ],
    ],
    // M3 missile chopper (helicopter_small → Sboss_helicopter_small_*)
    [
      [
        Emit(look: _m, at: Offset(-20, 0), speed: 1.8, start: 1, period: 8),
        Emit(look: _m, at: Offset(20, 0), speed: 1.8, start: 5, period: 8),
      ],
      [
        Emit(look: _m, at: Offset(-20, 0), speed: 1.8, start: 1, period: 4.4),
        Emit(look: _m, at: Offset(20, 0), speed: 1.8, start: 3.2, period: 4.4),
      ],
      [
        Emit(look: _m, at: Offset(-20, 0), speed: 1.8, start: 1, period: 2.8),
        Emit(look: _m, at: Offset(20, 0), speed: 1.8, start: 2.4, period: 2.8),
      ],
    ],
    // M4 V-shaped harasser (Sboss_helicopter_crazy_2, _difficult_1)
    [
      [
        Emit(
          ways: 2,
          step: 16,
          offset: 24,
          volleys: 4,
          volleyGap: .5,
          speed: .8,
          period: 5,
        ),
        Emit(
          ways: 2,
          step: 16,
          offset: -26,
          volleys: 4,
          volleyGap: .5,
          speed: .8,
          period: 5,
        ),
      ],
      [
        Emit(
          ways: 2,
          step: 16,
          offset: 24,
          volleys: 4,
          volleyGap: .5,
          speed: .8,
          period: 5,
        ),
        Emit(
          ways: 2,
          step: 16,
          offset: -26,
          volleys: 4,
          volleyGap: .5,
          speed: .8,
          period: 5,
        ),
        Emit(
          look: _n,
          aimed: true,
          volleys: 2,
          volleyGap: .5,
          speed: 1.5,
          start: 1.5,
          period: 3,
        ),
      ],
      [
        Emit(
          ways: 2,
          step: 16,
          offset: 24,
          volleys: 4,
          volleyGap: .5,
          speed: .8,
          period: 1.8,
        ),
        Emit(
          ways: 2,
          step: 16,
          offset: -26,
          volleys: 4,
          volleyGap: .5,
          speed: .8,
          period: 1.8,
        ),
        Emit(
          look: _n,
          aimed: true,
          volleys: 2,
          volleyGap: .5,
          speed: 1.5,
          start: 1,
          period: 1.2,
        ),
      ],
    ],
    // M5 bar-laser gunship (syzsj, helicopter_03)
    [
      [
        Emit(
          look: _b,
          aimed: true,
          volleys: 5,
          volleyGap: .14,
          speed: 3.2,
          period: 3,
          dmg: .4,
        ),
      ],
      [
        Emit(
          look: _b,
          aimed: true,
          volleys: 5,
          volleyGap: .14,
          speed: 3.2,
          period: 3,
          dmg: .4,
        ),
        Emit(
          look: _b,
          aimed: true,
          volleys: 13,
          volleyGap: .07,
          speed: 5,
          jitter: 2,
          at: Offset(16, 4),
          mirror: true,
          start: 2,
          period: 4,
          dmg: .25,
        ),
      ],
      [
        Emit(
          look: _b,
          aimed: true,
          volleys: 5,
          volleyGap: .14,
          speed: 3.2,
          period: 1.8,
          dmg: .4,
        ),
        Emit(
          look: _b,
          aimed: true,
          volleys: 13,
          volleyGap: .07,
          speed: 5,
          jitter: 2,
          at: Offset(16, 4),
          mirror: true,
          start: 1.2,
          period: 2.4,
          dmg: .25,
        ),
      ],
    ],
    // M6 multi-armed small boss (smallboss1, smallboss4, helicopter_02_1)
    [
      [
        Emit(ways: 15, step: 16, jitter: 14, speed: 2, period: 5, dmg: .4),
        Emit(
          look: _m,
          at: Offset(-18, 0),
          mirror: true,
          speed: 1.6,
          start: 2.5,
          period: 5,
        ),
      ],
      [
        Emit(ways: 15, step: 16, jitter: 14, speed: 2, period: 5, dmg: .4),
        Emit(
          ways: 3,
          step: 10,
          aimed: true,
          volleys: 3,
          volleyGap: .4,
          speed: 2,
          period: 3,
        ),
        Emit(
          look: _n,
          ways: 2,
          gap: .3,
          aimed: true,
          speed: 6,
          warn: .8,
          start: 6,
          period: 5,
        ),
      ],
      [
        Emit(ways: 15, step: 16, jitter: 14, speed: 2, period: 3.5, dmg: .4),
        Emit(
          ways: 3,
          step: 10,
          aimed: true,
          volleys: 3,
          volleyGap: .4,
          speed: 2,
          period: 2.1,
        ),
        Emit(
          look: _n,
          ways: 2,
          gap: .3,
          aimed: true,
          speed: 6,
          warn: .8,
          start: 4,
          period: 3.5,
        ),
        Emit(
          look: _m,
          at: Offset(-18, 0),
          mirror: true,
          speed: 1.6,
          start: 2.5,
          period: 5,
        ),
      ],
    ],
  ];
}

/// §8.3 stage boss sets B1-B11: phases by the reference's health shares,
/// several parts (muzzles) firing on their own cycles and start delays.
abstract final class BossPatterns {
  static final sets = <BossPatternSet>[
    BossPatternSet('지상 전차', [
      BossPhase(.50, [
        Emit(
          look: _b,
          aimed: true,
          track: 20,
          speed: 3,
          start: 2,
          period: 4,
          at: Offset(0, 30),
        ),
        Emit(
          look: _b,
          aimed: true,
          track: 120,
          volleys: 8,
          volleyGap: .08,
          speed: 1,
          start: 1.2,
          period: 3,
          at: Offset(46, 10),
          mirror: true,
          dmg: .4,
        ),
      ]),
      BossPhase(.17, [
        for (final x in [-30.0, 0.0, 30.0])
          Emit(
            look: _b,
            aimed: true,
            track: 40,
            volleys: 5,
            volleyGap: .05,
            speed: 1,
            start: 2,
            period: 4,
            at: Offset(x, 30),
          ),
      ]),
      BossPhase(.33, [
        Emit(look: _m, at: Offset(-30, 0), speed: 1.8, start: .5, period: 6),
        Emit(look: _m, at: Offset(30, 0), speed: 1.8, start: 3.5, period: 6),
        Emit(
          look: _b,
          aimed: true,
          volleys: 3,
          volleyGap: .15,
          speed: 2,
          period: 2.5,
        ),
      ]),
    ]),
    BossPatternSet('공격 헬기', [
      BossPhase(.67, [
        Emit(
          look: _b,
          aimed: true,
          volleys: 22,
          volleyGap: .04,
          speed: 1.2,
          period: 6,
          at: Offset(44, 0),
          mirror: true,
          dmg: .3,
        ),
        Emit(
          look: _n,
          aimed: true,
          volleys: 14,
          volleyGap: .06,
          speed: 2.5,
          start: 4,
          period: 5,
          at: Offset(16, 30),
          mirror: true,
          dmg: .3,
        ),
      ]),
      BossPhase(.17, [
        Emit(
          ways: 16,
          step: 22.5,
          volleys: 3,
          volleyGap: .05,
          shift: 3,
          speed: 2.5,
          period: 5.1,
          dmg: .5,
        ),
      ]),
      BossPhase(.16, [
        Emit(
          look: _n,
          aimed: true,
          volleys: 14,
          volleyGap: .06,
          speed: 2.5,
          period: 2,
          dmg: .3,
        ),
      ]),
    ]),
    BossPatternSet('대형 헬기', [
      BossPhase(.18, [
        Emit(
          look: _n,
          ways: 10,
          step: 2,
          aimed: true,
          speed: 3,
          period: 3,
          at: Offset(40, 10),
          mirror: true,
          dmg: .4,
        ),
        Emit(
          ways: 3,
          step: 5,
          volleys: 5,
          volleyGap: .05,
          speed: 2,
          speedJitter: .1,
          period: 6,
          at: Offset(0, 34),
        ),
      ]),
      BossPhase(.18, [
        Emit(
          ways: 16,
          step: 22.5,
          volleys: 3,
          volleyGap: .1,
          shift: 2.5,
          speed: .5,
          period: 2.2,
          at: Offset(50, 0),
          mirror: true,
          dmg: .5,
        ),
        Emit(
          look: _b,
          aimed: true,
          volleys: 6,
          volleyGap: 1,
          speed: 1.2,
          period: 6,
        ),
      ]),
      BossPhase(.58, [
        Emit(
          ways: 13,
          step: 9.5,
          speed: 1,
          start: 4,
          period: 9,
          at: Offset(-40, 20),
        ),
        Emit(
          ways: 13,
          step: 9.5,
          speed: 1,
          start: 5.5,
          period: 9,
          at: Offset(0, 30),
        ),
        Emit(
          ways: 13,
          step: 9.5,
          speed: 1,
          start: 7,
          period: 9,
          at: Offset(40, 20),
        ),
        Emit(
          look: _b,
          aimed: true,
          volleys: 3,
          volleyGap: .15,
          speed: 2,
          period: 9,
          at: Offset(24, 20),
          mirror: true,
        ),
      ]),
      BossPhase(.06, [
        Emit(
          look: _b,
          aimed: true,
          volleys: 3,
          volleyGap: .15,
          speed: 2,
          period: 2,
        ),
      ]),
    ]),
    BossPatternSet('폭격기', [
      BossPhase(.16, [
        for (final x in [-21.0, -7.0, 7.0, 21.0])
          Emit(
            look: _b,
            volleys: 12,
            volleyGap: .052,
            speed: 2.3,
            period: 3.5,
            at: Offset(x, 30),
            dmg: .3,
          ),
        Emit(
          look: _n,
          ways: 3,
          step: 13,
          aimed: true,
          speed: 3,
          start: 3,
          period: 4,
        ),
      ]),
      BossPhase(.32, [
        for (final (i, x) in [-60.0, -40.0, -20.0, 20.0, 40.0, 60.0].indexed)
          Emit(
            ways: 16,
            step: 22.5,
            volleys: 3,
            volleyGap: .1,
            shift: 3,
            speed: 2,
            start: .5 + i * 1.4,
            period: 9,
            at: Offset(x, 6),
            dmg: .5,
          ),
        Emit(
          look: _b,
          aimed: true,
          volleys: 5,
          volleyGap: .15,
          speed: 2,
          period: 3,
          at: Offset(56, 16),
          mirror: true,
        ),
      ]),
      BossPhase(.48, [
        Emit(
          ways: 16,
          step: 22.5,
          volleys: 3,
          volleyGap: .1,
          shift: 4,
          speed: 2,
          period: 2.2,
          dmg: .5,
        ),
        Emit(
          look: _b,
          aimed: true,
          speed: 2,
          period: 4,
          at: Offset(40, 10),
          mirror: true,
        ),
      ]),
      BossPhase(.04, [
        for (final x in [-21.0, -7.0, 7.0, 21.0])
          Emit(
            look: _b,
            volleys: 12,
            volleyGap: .052,
            speed: 2.3,
            period: 3.5,
            at: Offset(x, 30),
            dmg: .3,
          ),
      ]),
    ]),
    BossPatternSet('중전차', [
      BossPhase(.25, [
        for (final (i, x) in [-36.0, -12.0, 12.0, 36.0].indexed)
          Emit(
            look: _n,
            aimed: true,
            volleys: 30,
            volleyGap: .1,
            speed: 3,
            start: 2 + i * .3,
            period: 6,
            at: Offset(x, 20),
            dmg: .25,
          ),
        Emit(
          look: _b,
          volleys: 12,
          volleyGap: .08,
          speed: 2,
          period: 6,
          at: Offset(52, 10),
          mirror: true,
          dmg: .4,
        ),
      ]),
      BossPhase(.31, [
        Emit(
          look: _b,
          aimed: true,
          volleys: 3,
          volleyGap: 1,
          speed: 2,
          period: 3,
          at: Offset(30, 30),
          mirror: true,
        ),
        Emit(
          look: _n,
          aimed: true,
          speed: 6,
          warn: .6,
          period: 5,
          at: Offset(46, -10),
          mirror: true,
          dmg: 1.2,
        ),
        Emit(
          look: _beam,
          aimed: true,
          track: 10,
          warn: 1.8,
          beam: 2,
          period: 6,
          dmg: .6,
        ),
      ]),
      BossPhase(.31, [
        Emit(
          ways: 7,
          step: 51.4,
          volleys: 26,
          volleyGap: .2,
          sweep: 25,
          sweepPeriod: 3.5,
          speed: 1,
          period: 6,
        ),
        Emit(
          look: _n,
          ways: 3,
          step: 13,
          aimed: true,
          speed: 3,
          period: 4,
          at: Offset(40, 16),
          mirror: true,
        ),
      ]),
      BossPhase(.13, [
        Emit(ways: 12, step: 30, speed: 5, period: 30, dmg: .5),
        Emit(
          look: _b,
          aimed: true,
          volleys: 3,
          volleyGap: .2,
          speed: 2,
          start: 1.5,
          period: 2.2,
        ),
      ]),
    ]),
    BossPatternSet('열차', [
      BossPhase(.21, [
        Emit(
          look: _b,
          aimed: true,
          track: 80,
          volleys: 15,
          volleyGap: .05,
          speed: 3,
          period: 4.5,
          at: Offset(40, 10),
          mirror: true,
          dmg: .3,
        ),
        Emit(
          ways: 6,
          step: 60,
          volleys: 10,
          volleyGap: .2,
          shift: -10,
          speed: 1,
          period: 6,
        ),
      ]),
      BossPhase(.36, [
        for (final (i, x) in [-54.0, -18.0, 18.0, 54.0].indexed)
          Emit(
            look: _b,
            aimed: true,
            track: 50,
            volleys: 4,
            volleyGap: .1,
            speed: 3.2,
            start: i * 1.5,
            period: 6,
            at: Offset(x, 16),
          ),
        Emit(
          ways: 3,
          step: 10,
          aimed: true,
          track: 10,
          speed: 1,
          period: .8,
          dmg: .5,
        ),
      ]),
      BossPhase(.36, [
        Emit(
          ways: 6,
          step: 5,
          volleys: 2,
          volleyGap: .2,
          aimed: true,
          speed: .8,
          period: 4,
          at: Offset(40, 10),
          mirror: true,
        ),
        Emit(
          look: _n,
          aimed: true,
          speed: 6,
          warn: .6,
          period: 5,
          at: Offset(20, 24),
          mirror: true,
        ),
        Emit(look: _m, speed: 1.5, period: 2.5),
      ]),
      BossPhase(.07, [
        Emit(
          look: _b,
          aimed: true,
          volleys: 4,
          volleyGap: .1,
          speed: 3.2,
          period: 2,
        ),
      ]),
    ]),
    BossPatternSet('전함', [
      BossPhase(.31, [
        Emit(
          look: _b,
          aimed: true,
          track: 20,
          volleys: 30,
          volleyGap: .05,
          speed: 1,
          period: 3.4,
          at: Offset(44, 10),
          mirror: true,
          dmg: .25,
        ),
        Emit(
          look: _n,
          volleys: 12,
          volleyGap: .08,
          speed: 2.5,
          start: 4,
          period: 6,
          at: Offset(22, 24),
          mirror: true,
          dmg: .4,
        ),
        Emit(
          look: _n,
          ways: 3,
          gap: .3,
          aimed: true,
          speed: 6,
          warn: .6,
          period: 4,
        ),
      ]),
      BossPhase(.38, [
        Emit(
          look: _b,
          aimed: true,
          volleys: 20,
          volleyGap: .1,
          speed: 1.2,
          period: 4,
          at: Offset(40, 10),
          mirror: true,
          dmg: .3,
        ),
        for (var i = 0; i < 3; i++)
          Emit(
            look: _n,
            ways: 2,
            gap: .3,
            aimed: true,
            speed: 6,
            warn: .6,
            start: i * .2,
            period: 3,
            at: Offset(-50.0 + i * 50, 30),
          ),
        Emit(
          ways: 6,
          step: 12,
          volleys: 70,
          volleyGap: .02,
          sweep: 27,
          sweepPeriod: 3.5,
          speed: 1.5,
          start: 2,
          period: 5,
          dmg: .3,
        ),
      ]),
      BossPhase(.25, [
        for (final x in [-60.0, -42.0, -24.0, -8.0, 8.0, 24.0, 42.0, 60.0])
          Emit(
            volleys: 4,
            volleyGap: .4,
            jitter: 6,
            speed: 4,
            start: (x.abs() % 5) * .16,
            period: 6.5,
            at: Offset(x, 20),
            dmg: .5,
          ),
        for (final (i, x) in [-30.0, 0.0, 30.0].indexed)
          Emit(
            look: _n,
            ways: 2,
            gap: .3,
            aimed: true,
            speed: 6,
            warn: .5,
            start: 4.3 + i * .4,
            period: 6.5,
            at: Offset(x, 30),
          ),
      ]),
      BossPhase(.06, [Emit(look: _m, speed: 1.8, period: 3)]),
    ]),
    BossPatternSet('거미 전차', [
      BossPhase(.38, [
        Emit(
          look: _b,
          aimed: true,
          track: 60,
          volleys: 20,
          volleyGap: .06,
          speed: 1.5,
          period: 4,
          dmg: .3,
        ),
        Emit(
          look: _m,
          volleys: 4,
          volleyGap: .2,
          speed: 3,
          period: 4,
          at: Offset(-40, 10),
        ),
        Emit(
          look: _m,
          volleys: 4,
          volleyGap: .2,
          speed: 3,
          start: 2,
          period: 4,
          at: Offset(40, 10),
        ),
      ]),
      BossPhase(.50, [
        Emit(
          ways: 30,
          step: 12,
          volleys: 2,
          volleyGap: .6,
          speed: 3,
          period: 4,
          at: Offset(40, 0),
          mirror: true,
          dmg: .5,
        ),
        for (final a in [-30.0, -10.0, 10.0, 30.0])
          Emit(
            volleys: 32,
            volleyGap: .09,
            speed: 6,
            life: .65,
            aimed: true,
            track: 15,
            offset: a,
            period: 6,
            dmg: .3,
          ),
        Emit(
          look: _n,
          ways: 2,
          gap: .3,
          aimed: true,
          speed: 6,
          warn: .7,
          period: 5,
        ),
      ]),
      BossPhase(.12, [
        Emit(
          look: _b,
          aimed: true,
          volleys: 4,
          volleyGap: .12,
          speed: 2,
          period: 2,
        ),
      ]),
    ]),
    BossPatternSet('쌍둥이기', [
      BossPhase(.27, [
        Emit(
          look: _n,
          volleys: 80,
          volleyGap: .008,
          speed: 6,
          accel: -3,
          life: 2,
          sweep: 15,
          sweepPeriod: .8,
          jitter: 4,
          period: 4,
          dmg: .15,
        ),
        Emit(
          look: _n,
          aimed: true,
          volleys: 8,
          volleyGap: .04,
          speed: 6,
          speedJitter: .17,
          jitter: 1.5,
          period: 4,
          start: 2,
          dmg: .4,
        ),
        Emit(
          look: _b,
          aimed: true,
          volleys: 20,
          volleyGap: .05,
          speed: 1.5,
          period: 4,
          at: Offset(42, 10),
          mirror: true,
          dmg: .3,
        ),
      ]),
      BossPhase(.27, [
        Emit(
          ways: 6,
          step: 8,
          volleys: 4,
          volleyGap: .4,
          aimed: true,
          speed: 2.4,
          period: 4,
        ),
        Emit(look: _m, volleys: 5, volleyGap: .5, speed: 1.6, period: 5),
        Emit(
          look: _n,
          aimed: true,
          volleys: 8,
          volleyGap: .07,
          speed: 4,
          period: 4,
          at: Offset(42, 10),
          mirror: true,
          dmg: .3,
        ),
      ]),
      BossPhase(.33, [
        for (final (i, x) in [-48.0, -16.0, 16.0, 48.0].indexed)
          Emit(
            look: _n,
            volleys: 15,
            volleyGap: .02,
            shift: 3,
            offset: -20,
            speed: 3,
            start: i * 1.0,
            period: 7,
            at: Offset(x, 20),
            dmg: .3,
          ),
        Emit(
          look: _beam,
          aimed: true,
          track: 20,
          warn: .7,
          beam: .8,
          period: 3,
          dmg: .6,
        ),
      ]),
      BossPhase(.13, [
        for (final (i, x) in [-45.0, -15.0, 15.0, 45.0].indexed)
          Emit(
            look: _beam,
            warn: 2,
            beam: 1.6,
            start: 1 + i * 1.0,
            period: 5,
            at: Offset(x, 20),
            dmg: .6,
          ),
      ]),
    ]),
    BossPatternSet('잠수함', [
      BossPhase(.31, [
        Emit(
          ways: 16,
          step: 22.5,
          volleys: 3,
          volleyGap: .1,
          shift: 3,
          speed: 1,
          period: 5.2,
          at: Offset(-30, 10),
          dmg: .5,
        ),
        Emit(
          ways: 16,
          step: 22.5,
          volleys: 3,
          volleyGap: .1,
          shift: 3,
          speed: 1,
          start: 1,
          period: 5.2,
          at: Offset(30, 10),
          dmg: .5,
        ),
        Emit(
          look: _n,
          ways: 2,
          gap: .3,
          aimed: true,
          speed: 6,
          warn: .8,
          period: 6.5,
        ),
        Emit(
          look: _n,
          ways: 6,
          gap: .25,
          speed: .5,
          accel: .5,
          period: 7,
          start: 3,
        ),
      ]),
      BossPhase(.31, [
        Emit(
          ways: 16,
          step: 22.5,
          volleys: 3,
          volleyGap: .1,
          shift: 3,
          speed: 1,
          period: 4,
          at: Offset(-30, 10),
          dmg: .5,
        ),
        Emit(
          ways: 16,
          step: 22.5,
          volleys: 3,
          volleyGap: .1,
          shift: 3,
          speed: 1,
          start: 1,
          period: 4,
          at: Offset(30, 10),
          dmg: .5,
        ),
        Emit(
          look: _n,
          ways: 2,
          gap: .3,
          aimed: true,
          speed: 6,
          warn: .8,
          period: 6.5,
        ),
        Emit(
          look: _n,
          ways: 6,
          gap: .25,
          speed: .5,
          accel: .5,
          period: 7,
          start: 3,
        ),
      ]),
      BossPhase(.32, [
        Emit(
          look: _beam,
          aimed: true,
          track: 30,
          warn: 1.8,
          beam: 2,
          period: 4,
          dmg: .6,
        ),
        Emit(
          look: _m,
          ways: 2,
          gap: .3,
          volleys: 2,
          volleyGap: .5,
          speed: 1.6,
          period: 3.5,
        ),
        Emit(
          look: _b,
          aimed: true,
          track: 20,
          volleys: 30,
          volleyGap: .05,
          speed: 1,
          period: 3.4,
          dmg: .25,
        ),
      ]),
      BossPhase(.06, [
        Emit(ways: 12, step: 30, speed: 1.2, period: 2.5, dmg: .5),
      ]),
    ]),
    BossPatternSet('얼굴 요새', [
      BossPhase(.23, [
        Emit(
          look: _beam,
          aimed: true,
          warn: .7,
          beam: 2.5,
          period: 7,
          at: Offset(0, 30),
          dmg: .6,
        ),
        Emit(
          look: _beam,
          aimed: true,
          track: 30,
          warn: .6,
          beam: .4,
          period: 6,
          start: 3,
          at: Offset(26, -10),
          mirror: true,
          dmg: .5,
        ),
        Emit(
          ways: 3,
          step: 10,
          volleys: 2,
          volleyGap: .2,
          aimed: true,
          speed: 2,
          period: 4,
          at: Offset(30, 30),
          mirror: true,
        ),
      ]),
      BossPhase(.31, [
        Emit(
          look: _n,
          volleys: 6,
          volleyGap: .05,
          aimed: true,
          jitter: 4,
          speed: 6,
          speedJitter: .15,
          period: 6,
          at: Offset(0, 30),
        ),
        Emit(
          look: _m,
          volleys: 3,
          volleyGap: .3,
          speed: 1.6,
          period: 10,
          at: Offset(40, -20),
          mirror: true,
        ),
        Emit(
          look: _n,
          aimed: true,
          speed: 8,
          warn: .6,
          period: 6,
          start: 2,
          at: Offset(26, -10),
          mirror: true,
          dmg: 2.5,
        ),
        Emit(
          look: _m,
          volleys: 3,
          volleyGap: .6,
          speed: 1.6,
          period: 5,
          at: Offset(0, 40),
        ),
      ]),
      BossPhase(.42, [
        Emit(
          look: _big,
          ways: 3,
          step: 20,
          aimed: true,
          speed: 2,
          period: 8,
          at: Offset(0, 30),
        ),
        Emit(
          look: _n,
          volleys: 8,
          volleyGap: .05,
          shift: 4,
          offset: -16,
          aimed: true,
          speed: 2,
          period: 4,
          at: Offset(26, -10),
          mirror: true,
        ),
        for (var i = 0; i < 6; i++)
          Emit(
            ways: 16,
            step: 22.5,
            speed: 2,
            start: i * 3.0,
            period: 10,
            at: Offset(-62.0 + i * 25, 24),
            dmg: .5,
          ),
        for (var i = 0; i < 5; i++)
          Emit(
            look: _n,
            volleys: 30,
            volleyGap: .1,
            speed: 3,
            start: i * 1.0,
            period: 10,
            at: Offset(-48.0 + i * 24, 36),
            dmg: .25,
          ),
      ]),
      BossPhase(.04, [
        Emit(ways: 12, step: 30, speed: 1.2, period: 2.5, dmg: .5),
      ]),
    ]),
  ];

  /// Each house boss its own set: 11 sets over the houses of a lap.
  static BossPatternSet forStage(int stageIndex) =>
      sets[stageIndex % sets.length];
}
