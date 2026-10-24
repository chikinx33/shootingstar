import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/art/experience_gem_art.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/seeded_random.dart';

GameEngine arena() =>
    GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 61,
      )
      ..developerInvincible = true
      ..xpNeeded = 1e9;
GameEngine reload(GameEngine g) =>
    BattleCheckpoint.restore(jsonDecode(jsonEncode(g.checkpoint())));
double fieldValue(GameEngine g) =>
    g.crystals.fold(0, (sum, point) => sum + ExperienceCrystal.valueOf(point));

void main() {
  test('later gems are richer and rarer without starving XP or long droughts', () {
    var previousDrops = 100000;
    for (final progress in [0.0, .4, .8]) {
      final drops = ExperienceDrops(CombatRandom(61));
      var count = 0, value = 0.0, dry = 0, maxDry = 0;
      final rule = ExperienceDrops.plan(progress);
      for (var i = 0; i < 50000; i++) {
        final reward = drops.ordinary(progress);
        if (reward > 0) {
          expect(reward, rule.value);
          count++;
          value += reward;
          dry = 0;
        } else {
          dry++;
          if (dry > maxDry) maxDry = dry;
        }
      }
      expect(count, lessThan(previousDrops));
      previousDrops = count;
      expect(value / 50000, inInclusiveRange(.75, .9));
      expect(maxDry, lessThanOrEqualTo(rule.maxMisses));
      print(
        'XP_PLAN $progress drops=$count xpPerKill=${value / 50000} maxDry=$maxDry',
      );
    }
  });

  test('ordinary deaths do not always drop; armored enemies roll richer drops, bosses retain 40 XP', () {
    final g = arena();
    for (var i = 0; i < 50; i++) {
      g.enemies.add(
        Foe(g.position + ui.Offset(250, -100 - i.toDouble()), 1, 0, 10, 0)
          ..hp = 0,
      );
    }
    g.update(.001);
    expect(g.kills, 50);
    expect(g.crystals.length, inInclusiveRange(1, 49));
    expect(g.crystals.every((c) => ExperienceCrystal.valueOf(c) == 4), isTrue);
    final old = g.crystals.first;
    g.elapsed = g.duration * .8;
    for (var i = 0; i < 30; i++) {
      g.enemies.add(
        Foe(g.position + const ui.Offset(250, -100), 1, 0, 10, 0)..hp = 0,
      );
    }
    // Avoid a boss spawn clearing the controlled ordinary-death batch.
    g.bossesDefeated = g.requiredBosses;
    final saved = g.checkpoint();
    (saved['state'] as Map)['_bossWave'] = g.requiredBosses;
    final late = BattleCheckpoint.restore(jsonDecode(jsonEncode(saved)));
    late.update(.001);
    expect(
      ExperienceCrystal.valueOf(late.crystals.first),
      ExperienceCrystal.valueOf(old),
    );
    expect(
      late.crystals.any((c) => ExperienceCrystal.valueOf(c) == 16),
      isTrue,
    );

    final elite = arena();
    for (var i = 0; i < 100; i++) {
      elite.enemies.add(
        Foe(elite.position + const ui.Offset(250, -100), 1, 0, 10, 2)..hp = 0,
      );
    }
    elite.update(.001);
    expect(elite.crystals.length, inInclusiveRange(10, 60));
    expect(
      elite.crystals.every((c) => ExperienceCrystal.valueOf(c) == 8),
      true,
    );
    final boss = arena()..elapsed = 60;
    boss.enemies.add(
      Foe(boss.position + const ui.Offset(100, -150), 1, 0, 34, 3)..hp = 0,
    );
    boss.update(.001);
    expect(fieldValue(boss), 40);
    expect(boss.crystals.length, 3);
  });

  test('movement, pickup, magnet, overflow and restore preserve exact XP', () {
    final g = arena()..passives['xp'] = 2;
    final crystal = ExperienceCrystal.at(g.position, 16);
    expect(ExperienceCrystal.valueOf(crystal + const ui.Offset(2, 3)), 16);
    g.crystals.add(crystal);
    g.update(.001);
    expect(g.xp, closeTo(16 * 1.16, 1e-8));
    g.crystals.addAll([
      ExperienceCrystal.at(g.position + const ui.Offset(250, 0), 4),
      ExperienceCrystal.at(g.position + const ui.Offset(-250, 0), 8),
      ExperienceCrystal.at(g.position + const ui.Offset(0, -250), 16),
    ]);
    for (var i = 0; i < 7; i++) g.experienceDrops.ordinary(.8);
    final copy = reload(g);
    expect(copy.checkpoint(), g.checkpoint());
    for (var i = 0; i < 30; i++) {
      expect(copy.experienceDrops.ordinary(.8), g.experienceDrops.ordinary(.8));
    }
    copy.supplies.add(Supply(copy.position, 1));
    copy.update(.001);
    expect(
      copy.absorbingCrystals.fold<double>(0, (s, m) => s + m.value),
      closeTo(28 * 1.16, 1e-8),
    );
    final magnet = reload(copy);
    for (var i = 0; i < 200; i++) magnet.update(.01);
    expect(magnet.xp, closeTo(44 * 1.16, 1e-8));
    final overflow = arena();
    overflow.crystals.addAll(
      List.generate(
        1402,
        (i) => ExperienceCrystal.at(
          overflow.position + const ui.Offset(500, 0),
          i == 0 ? 16 : 8,
        ),
      ),
    );
    final kept = reload(overflow);
    expect(kept.xp + fieldValue(kept), 16 + 1401 * 8);
    expect(kept.crystals.length, 1400);
  });

  test(
    'legacy 2-XP checkpoints load; invalid values and drop states reject',
    () {
      final g = arena();
      g.crystals.add(g.position + const ui.Offset(200, 0));
      final data = g.checkpoint()
        ..remove('crystalXp')
        ..remove('xpDrops');
      expect(fieldValue(BattleCheckpoint.restore(data)), 2);
      final bad = g.checkpoint();
      bad['crystalXp'] = [-1];
      expect(() => BattleCheckpoint.restore(bad), throwsFormatException);
      bad['crystalXp'] = [];
      expect(() => BattleCheckpoint.restore(bad), throwsFormatException);
      bad['crystalXp'] = [1e12];
      expect(() => BattleCheckpoint.restore(bad), throwsFormatException);
      final badRng = g.checkpoint();
      badRng['xpDrops'] = {'rng': 0, 'misses': 0};
      expect(() => BattleCheckpoint.restore(badRng), throwsFormatException);
    },
  );

  test(
    'three original gem tiers render with distinct color and silhouette',
    () async {
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.scale(5);
      for (var i = 0; i < 3; i++)
        ExperienceGemArt.paint(
          canvas,
          ui.Offset(16 + i * 28, 16),
          [4.0, 8.0, 16.0][i],
        );
      final picture = recorder.endRecording(),
          image = await picture.toImage(440, 160);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('.local/experience-v61')
        ..createSync(recursive: true);
      File('${dir.path}/gem-tiers.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
      final pixels = await image.toByteData();
      final green = pixels!.getUint32((70 * 440 + 90) * 4);
      final blue = pixels.getUint32((70 * 440 + 230) * 4);
      final gold = pixels.getUint32((70 * 440 + 370) * 4);
      expect({green, blue, gold}.length, 3);
      image.dispose();
      picture.dispose();
    },
  );
}
