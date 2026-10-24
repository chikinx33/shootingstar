import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/cat_gear.dart';
import 'package:shootingstar/data/guardian_quests.dart';
import 'package:shootingstar/data/profile.dart';

void main() {
  test('a new pilot wears the full common Sunshine set', () {
    final gear = CatGearState.starter();
    expect(gear.items, hasLength(5));
    for (final slot in CatGearSlot.values) {
      expect(gear.equippedIn(slot)?.set, 'sunshine');
    }
    expect(gear.setCounts['sunshine'], 5);
    // 5-piece Sunshine adds +10% firepower on top of the nose stat
    expect(
      gear.bonuses.damage,
      closeTo(.10 + gear.equippedIn(CatGearSlot.nose)!.value, 1e-9),
    );
    expect(
      gear.layerAssets['wing_l'],
      'assets/art/ship_parts/sunshine/wing_left.webp',
    );
  });

  test('equipping a Night Guard piece swaps the sprite and breaks the set', () {
    final gear = CatGearState.starter();
    final wing = gear.add('night', CatGearSlot.wings, 2);
    gear.equipped[CatGearSlot.wings] = wing.id;
    expect(
      gear.layerAssets['wing_l'],
      'assets/art/ship_parts/night/wing_left.webp',
    );
    expect(gear.setCounts['sunshine'], 4);
    expect(
      gear.bonuses.damage,
      closeTo(.04 + gear.equippedIn(CatGearSlot.nose)!.value, 1e-9),
    );
  });

  test('gear survives a save round trip and rejects foreign slots', () {
    final gear = CatGearState.starter()..add('bloom', CatGearSlot.shield, 4);
    final back = CatGearState.restore(gear.toJson());
    expect(back.items, hasLength(6));
    expect(back.items.last.rarity, 4);
    final bad = gear.toJson()..['equipped'] = {'nose': back.items.last.id};
    expect(CatGearState.restore(bad).equippedIn(CatGearSlot.nose), isNull);
  });

  test('drops get better deeper in the campaign and finales give rare+', () {
    double meanRarity(int stage) {
      final gear = CatGearState([], {}, 1);
      final rng = math.Random(7);
      var sum = 0;
      for (var i = 0; i < 2000; i++) {
        sum += gear.rollDrop(rng, stage: stage).rarity;
      }
      return sum / 2000;
    }

    expect(meanRarity(95), greaterThan(meanRarity(5)));
    final gear = CatGearState([], {}, 1);
    for (var i = 0; i < 50; i++) {
      expect(
        gear.rollDrop(math.Random(i), stage: 9, finale: true).rarity,
        greaterThanOrEqualTo(2),
      );
    }
  });

  test('achievement targets grow and every fifth tier pays star dust', () {
    final a1 = achievementFor(GuardianStat.kills, 1),
        a2 = achievementFor(GuardianStat.kills, 2);
    expect(a2.target, greaterThan(a1.target));
    expect(
      achievementFor(GuardianStat.flights, 5).reward.stardust,
      greaterThan(achievementFor(GuardianStat.flights, 4).reward.stardust + 5),
    );
  });

  test('profile: upgrade, dismantle, story and achievement claims', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.credits = 10000;
    p.blueprints = 100;
    final nose = p.catGear.equippedIn(CatGearSlot.nose)!;
    expect(p.upgradeCatGear(nose.id), isTrue);
    expect(nose.level, 2);
    expect(p.guardianStat(GuardianStat.gearUpgrades), 1);
    final spare = p.catGear.add('night', CatGearSlot.armor, 1);
    final churu = p.credits;
    expect(p.dismantleCatGear(spare.id), isTrue);
    expect(p.credits, greaterThan(churu));
    expect(p.dismantleCatGear(nose.id), isFalse); // equipped pieces stay
    // story step 1 needs one sortie
    expect(p.claimStory(), isNull);
    p.runs = 1;
    expect(p.claimStory(), isNotNull);
    expect(p.quests.storyStep, 1);
    p.runs = 3;
    expect(p.claimAchievement(GuardianStat.flights), isNotNull);
    expect(p.quests.achievementTier[GuardianStat.flights], 2);
    final saved = p.exportProgress();
    expect(saved['catGearVersion'], 1);
    expect((saved['quests'] as Map)['storyStep'], 1);
  });
}
