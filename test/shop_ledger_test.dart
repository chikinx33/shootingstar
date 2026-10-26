import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/fleet_journal.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/shop_ledger.dart';

void main() {
  Future<Profile> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return Profile.load();
  }

  test('run bonus pays half the run once per run, three a day', () async {
    final p = await fresh();
    expect(ShopSystems.runBonus(257), 129);
    expect(ShopSystems.runBonus(5), 10);
    final start = p.credits;
    expect(p.grantAdOffer(AdOffer.runBonus, runId: 'a', runCredits: 200), isTrue);
    expect(p.credits, start + 100);
    expect(p.canOffer(AdOffer.runBonus, runId: 'a', runCredits: 200), isFalse);
    expect(p.grantAdOffer(AdOffer.runBonus, runId: 'b', runCredits: 200), isTrue);
    expect(p.grantAdOffer(AdOffer.runBonus, runId: 'c', runCredits: 200), isTrue);
    expect(p.shop.left(AdOffer.runBonus), 0);
    expect(p.grantAdOffer(AdOffer.runBonus, runId: 'd', runCredits: 200), isFalse);
    // a zero-reward run never offers
    expect(p.canOffer(AdOffer.runBonus, runId: 'e'), isFalse);
  });

  test('doubling opens only right after its claim and pays the same again', () async {
    final p = await fresh();
    expect(p.canOffer(AdOffer.patrolDouble), isFalse);
    p.lastPatrol =
        DateTime.now().toUtc().millisecondsSinceEpoch - 2 * 3600 * 1000;
    final before = (p.credits, p.blueprints, p.petFood);
    expect(p.claimPatrol(DateTime.now()), isTrue);
    final once = (p.credits - before.$1, p.blueprints - before.$2);
    expect(once.$1, 80);
    expect(p.grantAdOffer(AdOffer.patrolDouble), isTrue);
    expect(p.credits - before.$1, once.$1 * 2);
    expect(p.blueprints - before.$2, once.$2 * 2);
    expect(p.canOffer(AdOffer.patrolDouble), isFalse, reason: 'one per claim');

    p.dailyRuns = 1;
    expect(p.claimDaily(0), isTrue);
    expect(p.claimDailyActivity(0), isTrue);
    final chest = FleetJournal.dailyChestRewards[0];
    final c = p.credits;
    expect(p.grantAdOffer(AdOffer.chestDouble), isTrue);
    expect(p.credits - c, chest.credits);
  });

  test('purchases apply once per token and survive a save round trip', () async {
    final p = await fresh();
    final now = DateTime.utc(2026, 10, 26);
    final credits = p.credits;
    expect(p.applyPurchase(ShopItem.starter, 'tok1', now), isTrue);
    expect(p.applyPurchase(ShopItem.starter, 'tok1', now), isFalse);
    expect(p.credits, credits + 1000);
    // a restored one-time item on another token pays its goods only once
    expect(p.applyPurchase(ShopItem.starter, 'tok2', now), isTrue);
    expect(p.credits, credits + 1000);

    expect(p.applyPurchase(ShopItem.adPass, 'pass1', now), isTrue);
    expect(p.applyPurchase(ShopItem.adPass, 'pass2', now), isTrue);
    expect(p.shop.daysLeft(p.shop.adPassUntil, now), 60);
    expect(p.applyPurchase(ShopItem.supporter, 'frame', now), isTrue);

    final copy = Profile.presentationCopy(p);
    final restored = ShopLedger.restore(
      jsonDecode(jsonEncode(p.shop.toJson())),
    );
    expect(restored.starterGranted, isTrue);
    expect(restored.supporterOwned, isTrue);
    expect(restored.adPassUntil, p.shop.adPassUntil);
    expect(restored.tokens, containsAll(['tok1', 'tok2', 'pass1', 'frame']));
    expect(copy, isNotNull);
  });

  test('monthly pays daily while active; the fund pays per world kept', () async {
    final p = await fresh();
    expect(p.claimMonthly(), isFalse);
    p.applyPurchase(ShopItem.monthly, 'm1', DateTime.now());
    final dust = p.blueprints;
    expect(p.claimMonthly(), isTrue);
    expect(p.blueprints, dust + 2);
    expect(p.claimMonthly(), isFalse, reason: 'once a day');

    p.applyPurchase(ShopItem.growthFund, 'f1', DateTime.now());
    expect(p.fundAttention, 0);
    p.clearedStages.addAll(List.generate(10, (s) => 40 + s));
    expect(p.fundReady(4), isTrue);
    final gear = p.catGear.items.length;
    expect(p.claimFund(4), isTrue);
    expect(p.catGear.items.length, gear + 1);
    expect(p.catGear.items.last.rarity, 3);
    expect(p.claimFund(4), isFalse);
  });
}
