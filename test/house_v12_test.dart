import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/campaign.dart';
import 'package:shootingstar/data/control_preferences.dart';
import 'package:shootingstar/data/houses.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/survival_skills.dart';

Future<GameEngine> houseRun({int seed = 31, int stage = 0}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await Profile.load();
  return GameEngine(
    stageIndex: stage,
    shipIndex: p.selectedShip,
    aircraft: p.aircraftAssembly,
    supportLevels: p.aircraftSupportLevels,
    attackLevel: 0,
    hullLevel: 0,
    magnetLevel: p.magnetLevel,
    equipmentIndex: -1,
    armament: p.moduleLoadout.signature,
    armamentLevel: p.moduleLoadout.airframeLevel - 1,
    seed: seed,
  )..viewportHeight = 760;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stages are neighbours\' houses', () {
    expect(stages[0].name, '민지네 집');
    expect(stages[9].name, '우리 집');
    expect(stages[0].description, contains('트램펄린'));
  });

  test('neighbourhood 2 has its own ten houses, art and street', () {
    expect(stages[10].name, '24시 편의점');
    expect(stages[14].name, '어린이집');
    expect(stages[19].name, '고양이 카페');
    expect(stages[10].description, contains('츄르'));
    expect(houseMap(10), endsWith('house_10.jpg'));
    expect(houseOwner(19), endsWith('owner_19.webp'));
    expect(streetMap(10), endsWith('street_1.jpg'));
    expect(streetMap(3), endsWith('street.jpg'));
    // worlds beyond the drawn neighbourhoods revisit them
    expect(stages[20].name, '민지네 집');
    expect(stages[30].name, '24시 편의점');
    final art = <String>{
      for (var i = 0; i < 20; i++) houseMap(i),
      for (var i = 0; i < 20; i++) houseOwner(i),
    };
    expect(art, hasLength(40));
  });

  test('house screen: fixed camera, formation waves from the top', () async {
    final g = await houseRun();
    expect(g.screenMode, isTrue);
    final camera = g.camera;
    var peak = 0, fromTop = 0, spawned = <Foe>{};
    for (var i = 0; i < 60 * 40; i++) {
      g.choices.isEmpty ? null : g.chooseUpgrade(g.choices.first.id);
      g.input = const Offset(.3, 0);
      g.update(.025);
      // v12.4: the view pans sideways a little near the field edges only
      expect(g.camera.dy, camera.dy, reason: 'no vertical camera follow');
      expect((g.camera.dx - camera.dx).abs(), lessThanOrEqualTo(sideReach));
      expect(g.fieldRect.inflate(1).contains(g.position), isTrue);
      final alive = g.enemies.where((e) => e.hp > 0 && !e.retired).length;
      if (alive > peak) peak = alive;
      for (final e in g.enemies) {
        // formations enter from beyond the screen edge, never pop in view
        if (spawned.add(e) && !g.screenRect.deflate(6).contains(e.position)) {
          fromTop++;
        }
      }
    }
    expect(peak, inInclusiveRange(10, 32));
    expect(fromTop, spawned.length);
  });

  test(
    'every paw weapon deals damage at base, fully grown and ultimate',
    () async {
      for (final paw in pawSkills) {
        // scripted weaving never dodges: keep the cat alive to measure damage
        final g = await houseRun(seed: 7)
          ..xpNeeded = 1e9
          ..developerInvincible = true;
        g.upgrades[paw.id] = 1;
        for (final stage in ['base', 'grown', 'ultimate']) {
          if (stage == 'grown') {
            g.growthEnhance[paw.id] = 3;
            g.growthEvolve[paw.id] = 3;
          }
          if (stage == 'ultimate') g.growthUltimates.add(paw.id);
          g.damageByWeapon.remove(paw.id);
          for (var i = 0; i < 40 * 25; i++) {
            // weave through the middle of the screen like a player would
            g.input = Offset(math.sin(i / 60), i % 400 < 200 ? -.6 : .4);
            g.update(.025);
          }
          expect(
            g.damageByWeapon[paw.id] ?? 0,
            greaterThan(0),
            reason: '${paw.id} $stage',
          );
        }
      }
    },
  );
  test(
    'three house boss archetypes: fortress parts, barrage, duelist',
    () async {
      for (final (stage, kind) in [
        (0, HouseBossKind.fortress),
        (1, HouseBossKind.barrage),
        (2, HouseBossKind.duelist),
      ]) {
        final g = await houseRun(stage: stage);
        g.elapsed = g.nextBossAt;
        g.update(.025);
        expect(g.boss, isNotNull, reason: '$kind');
        expect(g.houseBossKind, kind);
        final boss = g.boss!;
        if (kind == HouseBossKind.fortress) {
          expect(g.bossParts.length, 4);
          expect(g.houseBossShielded, isTrue);
          expect(g.houseBossDamage(boss), lessThan(.1));
        } else {
          expect(g.bossParts, isEmpty);
        }
        var bullets = 0;
        for (var i = 0; i < 40 * 20; i++) {
          if (g.choices.isNotEmpty) g.chooseUpgrade(g.choices.first.id);
          g.input = Offset(math.sin(i / 30), 0);
          final before = g.shots.where((s) => s.hostile).length;
          g.update(.025);
          bullets += math.max(
            0,
            g.shots.where((s) => s.hostile).length - before,
          );
          expect(g.screenRect.inflate(2).contains(boss.position), isTrue);
        }
        expect(bullets, greaterThan(20), reason: '$kind fires patterns');
        if (kind == HouseBossKind.fortress) {
          // break the generators: the shield drops and the core takes damage
          for (final part in g.bossParts.toList()) {
            part.hp = 0;
          }
          g.update(.025);
          expect(g.houseBossShielded, isFalse);
          expect(g.houseBossDamage(boss), 1);
        }
      }
    },
  );

  group('v12.4 field feel (user 2026-10-24)', () {
    Future<GameEngine> safeRun({int seed = 31}) async =>
        (await houseRun(seed: seed))
          ..developerInvincible = true
          ..xpNeeded = 1e9;
    void fly(GameEngine g, double seconds, {bool Function()? until}) {
      for (var i = 0; i < seconds * 40; i++) {
        if (g.choices.isNotEmpty) g.chooseUpgrade(g.choices.first.id);
        g.input = Offset(math.sin(i / 50) * .8, 0);
        g.update(.025);
        if (until?.call() == true) return;
      }
    }

    test(
      'only wiped formations drop items; gems drift until the cat is near',
      () async {
        final g = await safeRun();
        fly(g, 90, until: () => g.supplies.isNotEmpty);
        expect(g.supplies, isNotEmpty, reason: 'a wiped formation drops loot');
        expect(
          g.supplies.every((s) => const {0, 1, 2, 7, 8, 9}.contains(s.kind)),
          isTrue,
        );
        final far = g.position + const Offset(0, -320);
        g.crystals
          ..clear()
          ..add(ExperienceCrystal.at(far, 5));
        g.input = Offset.zero;
        g.update(.1);
        final gem = g.crystals.single;
        expect(gem.dx, far.dx, reason: 'no remote pull towards the cat');
        expect(gem.dy, greaterThan(far.dy));
      },
    );

    test('bullet / missile power-ups grow those weapons', () async {
      final g = await safeRun();
      g.supplies.add(Supply(g.position, 7));
      g.update(.025);
      expect(g.enh('gun') + g.evo('gun'), 1);
      final missile = g.nextMissileGrowth;
      if (missile != null) {
        g.supplies.add(Supply(g.position, 8));
        g.update(.025);
        expect(g.enh(missile) + g.evo(missile), 1);
      }
    });

    test('mid-boss: sturdy elite cycling patterns, golden box drop', () async {
      final g = await safeRun(seed: 5);
      Foe? elite() => g.enemies.where((e) => e.elite).firstOrNull;
      fly(g, 150, until: () => elite() != null);
      final e = elite()!;
      expect(e.radius, 30);
      final escort = g.enemies.firstWhere((o) => !o.elite && o.kind != 3);
      expect(e.maxHp, greaterThan(escort.maxHp * 3));
      fly(g, 12);
      expect(e.elitePattern, greaterThanOrEqualTo(2));
      e.hp = 0;
      g.update(.025);
      final box = g.supplies.where((s) => s.kind == 9).single;
      g.input = Offset.zero;
      g.position = box.position;
      g.update(.025);
      expect(g.supplies.where((s) => s.kind == 9), isEmpty);
      expect(g.enh('gun') + g.evo('gun'), greaterThanOrEqualTo(1));
    });

    test('clouds veil the street, then the boss house appears', () async {
      final g = await safeRun();
      g.elapsed = g.nextBossAt - 3.2;
      var peak = 0.0;
      while (g.boss == null && g.elapsed < g.nextBossAt + 1) {
        g.update(.025);
        peak = math.max(peak, g.cloudCover);
        if (!g.houseMapShown) {
          expect(g.cloudCover, lessThan(1.01));
        }
      }
      expect(peak, closeTo(1, .01));
      expect(g.boss, isNotNull);
      expect(g.houseMapShown, isTrue);
      expect(g.cloudCover, 0);
    });

    test(
      'follow-touch settles the cat under the finger after the pan',
      () async {
        final g = await safeRun();
        for (final view in const [Offset(380, 520), Offset(40, 300)]) {
          g.steerTarget = g.screenToField(view);
          for (var i = 0; i < 120; i++) {
            g.update(.025);
          }
          final onScreen = g.position - g.camera;
          expect(onScreen.dx, closeTo(view.dx, 1.5));
          expect(onScreen.dy, closeTo(view.dy, 1.5));
        }
      },
    );

    test('a full gauge opens the draft at once, never one gem later', () async {
      final g = await safeRun();
      g
        ..xpNeeded = 10
        ..xp = 9;
      g.enemies.clear();
      g.crystals.clear();
      // The gem that fills the bar opens the draft on that frame, even in
      // the first seconds of a run (no hidden cooldown behind a full bar).
      g.crystals.add(ExperienceCrystal.at(g.position, 1));
      g.update(.025);
      expect(g.choices, isNotEmpty);
      expect(g.level, 2);
      // Experience banked past the next level still shows a full bar, so
      // the next draft follows the choice instead of waiting for a gem.
      g.xp = g.xpNeeded + 1;
      g.chooseUpgrade(g.choices.first.id);
      expect(g.choices, isNotEmpty);
      expect(g.level, 3);
      expect(g.xp, lessThan(g.xpNeeded));
      g.chooseUpgrade(g.choices.first.id);
      for (var i = 0; i < 80; i++) {
        g.update(.025);
      }
      expect(
        g.choices,
        isEmpty,
        reason: 'a bar that is not full opens nothing',
      );
    });

    test(
      'steering to a point stops dead, without drift or overshoot',
      () async {
        final g = await safeRun();
        g.enemies.clear();
        final start = g.position;
        final goal = g.clampToField(start + const Offset(-120, -90));
        g.steerTarget = goal;
        var closest = double.infinity;
        for (var i = 0; i < 40; i++) {
          g.update(.025);
          final d = (g.position - goal).distance;
          expect(d, lessThanOrEqualTo(closest + 1e-6), reason: 'no overshoot');
          closest = d;
        }
        expect(g.position, goal);
        g.update(.025);
        expect(g.position, goal, reason: 'stays put when the finger stops');
      },
    );

    test('follow-touch glides with a hint of inertia, never slow or past the finger', () async {
      final g = await safeRun();
      g.enemies.clear();
      final start = g.position;
      final goal = g.clampToField(start + const Offset(150, -60));
      g
        ..steerGlide = true
        ..steerTarget = goal;
      var closest = double.infinity;
      var arrived = -1;
      for (var i = 0; i < 40; i++) {
        g.update(.025);
        final d = (g.position - goal).distance;
        expect(d, lessThanOrEqualTo(closest + 1e-6), reason: 'no overshoot');
        closest = d;
        if (arrived < 0 && d < .5) arrived = i;
      }
      // a quarter-second-ish trip: eased, but nowhere near a slow drift
      expect(arrived, inInclusiveRange(4, 16));
      // moving right and forward: the craft rolls right, flames stretch
      final h = await safeRun();
      h.enemies.clear();
      h
        ..steerGlide = true
        ..steerTarget = h.clampToField(h.position + const Offset(160, -160));
      for (var i = 0; i < 6; i++) {
        h.update(.025);
      }
      expect(h.bank, greaterThan(.3));
      expect(h.thrust, greaterThan(.3));
    });

    test('formation planes are big and gems are generous', () async {
      final g = await safeRun();
      fly(g, 8, until: () => g.enemies.any((e) => e.kind == 0));
      final small = g.enemies.firstWhere((e) => e.kind == 0);
      expect(small.radius, greaterThanOrEqualTo(11 * 1.3));
      expect(ControlPreferences.followLift, greaterThanOrEqualTo(100));
    });

    test('some formations come from behind', () async {
      final g = await safeRun(seed: 11);
      var rear = false;
      final seen = <Foe>{};
      fly(
        g,
        170,
        until: () {
          for (final e in g.enemies) {
            if (seen.add(e) && e.position.dy > g.camera.dy + g.viewportHeight) {
              rear = true;
            }
          }
          return rear;
        },
      );
      expect(rear, isTrue);
    });
  });
}
