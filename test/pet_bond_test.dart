import 'ui_actions.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/pet_bond.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/pet_bond_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final beforeMidnight = DateTime.utc(2026, 10, 16, 14, 59);
  final afterMidnight = DateTime.utc(2026, 10, 16, 15);

  PetBond funded() => PetBond()..favor[0] = 300;
  PetBondCost? awaken(PetBond book, [int pet = 0]) => book.awaken(
    pet,
    petLevel: 20,
    petRank: 3,
    credits: 10000,
    food: 10000,
    shards: 100,
  );

  test('legacy and malformed saves start without new passive effects', () {
    for (final raw in [null, 1, 'bad', [], false]) {
      expect(PetBond.restore(raw).toJson(), PetBond().toJson());
    }
    final book = PetBond.restore({
      'favor': [999, -1, '200'],
      'awakening': [8, -2, 1.5],
      'skills': [999, 1, 1],
      'spentCredits': [999999, -1, 99],
      'spentFood': [999999],
      'spentShards': [999999],
      'giftsToday': 9999,
      'combatFavorToday': double.nan,
      'lastClock': -1,
      'runs': [5, '', 'valid'],
    });
    expect(book.favor, [300, 0, 0]);
    expect(book.awakening, [3, 0, 0]);
    expect(book.skills, [1, 0, 0]);
    expect(book.giftsToday, 2);
    expect(book.combatFavorToday, 0);
    expect(book.resetRefund(0)!.credits, 600);
    expect(book.resetRefund(0)!.food, 120);
    expect(book.resetRefund(0)!.shards, 6);
    for (var id = -1; id < 5; id++) {
      expect(PetBond().powerBonus(id), 0);
      expect(PetBond().cooldownReduction(id), 0);
    }
  });

  test('shared daily gift cap rolls at KST midnight and resists rollback', () {
    final book = PetBond();
    expect(book.gift(0, unlocked: true, food: 10, now: beforeMidnight), true);
    expect(book.gift(1, unlocked: true, food: 10, now: beforeMidnight), true);
    expect(book.gift(2, unlocked: true, food: 10, now: beforeMidnight), false);
    expect(book.favor, [10, 10, 0]);
    expect(book.advance(afterMidnight), true);
    expect(book.day, '2026-10-17');
    expect(book.gift(2, unlocked: true, food: 10, now: afterMidnight), true);
    expect(book.advance(beforeMidnight), false);
    expect(book.day, '2026-10-17');
    expect(book.giftsToday, 1);
    expect(book.gift(0, unlocked: true, food: 10, now: beforeMidnight), true);
    expect(book.gift(0, unlocked: true, food: 10, now: afterMidnight), false);
  });

  test('gift rejects invalid IDs locked pets poor stock and capped favor', () {
    final book = PetBond();
    for (final id in [-1, 3]) {
      expect(
        book.gift(id, unlocked: true, food: 10, now: beforeMidnight),
        false,
      );
    }
    expect(
      book.gift(0, unlocked: false, food: 100, now: beforeMidnight),
      false,
    );
    expect(book.gift(0, unlocked: true, food: 9, now: beforeMidnight), false);
    book.favor[0] = 300;
    expect(book.gift(0, unlocked: true, food: 100, now: beforeMidnight), false);
    expect(book.giftsToday, 0);
  });

  test(
    'combat favor requires actual eligible run and deduplicates across reload',
    () {
      var book = PetBond();
      int record(
        String id, {
        int pet = 0,
        int seconds = 120,
        int kills = 10,
        bool unlocked = true,
      }) => book.recordRun(
        pet: pet,
        unlocked: unlocked,
        runId: id,
        seconds: seconds,
        kills: kills,
        now: beforeMidnight,
      );
      expect(record('short', seconds: 119), 0);
      expect(record('empty', kills: 9), 0);
      expect(record('locked', unlocked: false), 0);
      expect(record('bad', pet: 3), 0);
      expect(record(''), 0);
      expect(record('a'), 10);
      expect(record('a'), 0);
      book = PetBond.restore(jsonDecode(jsonEncode(book.toJson())));
      expect(record('a'), 0);
      expect(record('b', pet: 1), 10);
      expect(record('c', pet: 2), 10);
      expect(record('d'), 0);
      expect(book.favor, [10, 10, 10]);
      expect(book.combatFavorToday, 30);
      book.advance(afterMidnight);
      expect(record('a'), 0);
    },
  );

  test(
    'favor cannot overfill and full pet does not consume combat daily budget',
    () {
      final book = PetBond()..favor[0] = 295;
      expect(
        book.recordRun(
          pet: 0,
          unlocked: true,
          runId: 'a',
          seconds: 120,
          kills: 20,
          now: beforeMidnight,
        ),
        5,
      );
      expect(book.favor[0], 300);
      expect(book.combatFavorToday, 5);
      expect(
        book.recordRun(
          pet: 0,
          unlocked: true,
          runId: 'b',
          seconds: 120,
          kills: 20,
          now: beforeMidnight,
        ),
        0,
      );
      expect(book.combatFavorToday, 5);
    },
  );

  test(
    'awakening validates all conditions before charging or changing ledger',
    () {
      final book = PetBond()..favor[0] = 50;
      PetBondCost? attempt({
        int pet = 0,
        int level = 5,
        int rank = 1,
        int credits = 100,
        int food = 20,
        int shards = 1,
      }) => book.awaken(
        pet,
        petLevel: level,
        petRank: rank,
        credits: credits,
        food: food,
        shards: shards,
      );
      expect(attempt(pet: 3), null);
      expect(attempt(level: 0), null);
      expect(attempt(level: 4), null);
      expect(attempt(rank: 0), null);
      expect(attempt(credits: 99), null);
      expect(attempt(food: 19), null);
      expect(attempt(shards: 0), null);
      book.favor[0] = 49;
      expect(attempt(), null);
      expect(book.awakening[0], 0);
      expect(book.resetRefund(0), null);
      book.favor[0] = 50;
      final charge = attempt()!;
      expect([charge.credits, charge.food, charge.shards], [100, 20, 1]);
      expect(book.awakening[0], 1);
      expect(attempt(), null);
    },
  );

  test('three tiers have finite costs separate choices and bounded pet-only effects', () {
    final book = funded();
    for (var tier = 1; tier <= 3; tier++) {
      final paid = awaken(book)!;
      expect(
        [paid.credits, paid.food, paid.shards],
        [tier * 100, tier * 20, tier],
      );
      expect(book.powerBonus(0), closeTo(tier * .06, 1e-10));
      expect(book.cooldownReduction(0), 0);
      expect(book.selectSkill(0, 1), true);
      expect(book.powerBonus(0), 0);
      expect(book.cooldownReduction(0), closeTo(tier * .04, 1e-10));
      expect(book.selectSkill(0, 1), false);
      expect(book.selectSkill(0, -1), false);
      expect(book.selectSkill(0, 2), false);
      expect(book.selectSkill(0, 0), true);
    }
    expect(awaken(book), null);
    expect(book.nextCost(0), null);
    book.awakening[0] = 999;
    expect(book.powerBonus(0), closeTo(.18, 1e-10));
    expect(book.selectSkill(1, 1), false);
    for (var pet = 1; pet <= 2; pet++) {
      book.favor[pet] = 300;
      for (var i = 0; i < 3; i++) {
        awaken(book, pet);
      }
      expect(book.powerBonus(pet), closeTo(.15, 1e-10));
    }
  });

  test(
    'refund is exact new spending and cannot farm favor gifts or resources',
    () {
      final book = funded();
      book.gift(1, unlocked: true, food: 10, now: beforeMidnight);
      awaken(book);
      awaken(book);
      book.selectSkill(0, 1);
      final saved = PetBond.restore(jsonDecode(jsonEncode(book.toJson())));
      final refund = saved.reset(0)!;
      expect([refund.credits, refund.food, refund.shards], [300, 60, 3]);
      expect(saved.favor[0], 300);
      expect(saved.giftsToday, 1);
      expect(saved.awakening[0], 0);
      expect(saved.skills[0], 0);
      expect(saved.powerBonus(0), 0);
      expect(saved.cooldownReduction(0), 0);
      expect(saved.reset(0), null);
      expect(saved.selectSkill(0, 1), false);
      final restoredWithoutPaid = PetBond.restore({
        'awakening': [3],
      });
      final noPhantomRefund = restoredWithoutPaid.reset(0)!;
      expect(
        [noPhantomRefund.credits, noPhantomRefund.food, noPhantomRefund.shards],
        [0, 0, 0],
      );
    },
  );

  test('profile transactions preserve existing pet growth and refund exactly after reload', () async {
    final p = await Profile.load();
    p.credits = 1000;
    p.petFood = 500;
    p.petShards[0] = 10;
    p.petLevels[0] = 15;
    p.petRanks[0] = 3;
    p.petBond.favor[0] = 200;
    expect(p.awakenPet(0), true);
    expect(p.awakenPet(0), true);
    expect(p.awakenPet(0), true);
    expect(p.awakenPet(0), false);
    expect([p.credits, p.petFood, p.petShards[0]], [400, 380, 4]);
    expect(p.selectPetAwakeSkill(0, 1), true);
    await p.save();
    final q = await Profile.load();
    expect(q.petBond.awakening[0], 3);
    expect(q.petBond.skills[0], 1);
    expect(q.petBond.favor[0], 200);
    expect([q.petLevels[0], q.petRanks[0]], [15, 3]);
    expect(q.resetPetAwakening(0), true);
    expect(q.resetPetAwakening(0), false);
    expect([q.credits, q.petFood, q.petShards[0]], [1000, 500, 10]);
    expect([q.petLevels[0], q.petRanks[0]], [15, 3]);
    final older = q.exportProgress();
    (older['content'] as Map).remove('petBond');
    await q.replaceProgress(older);
    expect(q.petBond.awakening, [0, 0, 0]);
    expect(q.petBond.favor, [0, 0, 0]);
    expect([q.petLevels[0], q.petRanks[0]], [15, 3]);
    expect([q.credits, q.petFood, q.petShards[0]], [1000, 500, 10]);
    p.dispose();
    q.dispose();
  });

  test(
    'captured deployed pet receives favor, training and duplicate runs do not',
    () async {
      final p = await Profile.load();
      p.petLevels[1] = 1;
      p.activePet = 1;
      void finish(
        String id, {
        bool training = false,
        int seconds = 120,
        int pet = 0,
      }) => p.completeRun(
        victory: false,
        stageIndex: 0,
        kills: 20,
        level: 2,
        seconds: seconds,
        training: training,
        runId: id,
        deployedPet: pet,
      );
      finish('training', training: true);
      finish('short', seconds: 119);
      expect(p.petBond.favor, [0, 0, 0]);
      finish('valid');
      finish('valid');
      expect(p.petBond.favor, [10, 0, 0]);
      finish('invalid-pet', pet: 2);
      expect(p.petBond.favor, [10, 0, 0]);
      await p.save();
      final q = await Profile.load();
      q.completeRun(
        victory: false,
        stageIndex: 0,
        kills: 20,
        level: 2,
        seconds: 120,
        training: false,
        runId: 'valid',
        deployedPet: 0,
      );
      expect(q.petBond.favor, [10, 0, 0]);
      p.dispose();
      q.dispose();
    },
  );

  testWidgets(
    '320px pet UI gifts, selects real skill and confirms refundable reset',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = await Profile.load();
      p.credits = 500;
      p.petFood = 100;
      p.petShards[0] = 3;
      p.petLevels[0] = 5;
      p.petRanks[0] = 1;
      p.petBond.favor[0] = 50;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: PetBondScreen(profile: p, pet: 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await revealUi(tester, find.text('먹이 10 선물'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('먹이 10 선물'));
      await tester.pumpAndSettle();
      expect(p.petFood, 90);
      expect(p.petBond.favor[0], 60);
      final awake = find.text('각성 1단계 · 100 츄르');
      await revealUi(tester, awake);
      await tester.pumpAndSettle();
      await tester.tap(awake);
      await tester.pumpAndSettle();
      expect(p.petBond.awakening[0], 1);
      expect([p.credits, p.petFood, p.petShards[0]], [400, 70, 2]);
      final fastSkill = find.textContaining('신속 동행');
      await revealUi(tester, fastSkill);
      await tester.pumpAndSettle();
      await tester.tap(fastSkill);
      await tester.pumpAndSettle();
      expect(p.petBond.skills[0], 1);
      final reset = find.text('각성 되돌리기');
      await revealUi(tester, reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(find.text('펫 각성 초기화'), findsOneWidget);
      await revealUi(tester, find.text('취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(p.petBond.awakening[0], 1);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await revealUi(tester, find.text('각성 초기화'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('각성 초기화'));
      await tester.pumpAndSettle();
      expect(p.petBond.awakening[0], 0);
      expect(p.petBond.skills[0], 0);
      expect(p.petBond.favor[0], 60);
      expect([p.credits, p.petFood, p.petShards[0]], [500, 90, 3]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await p.save();
      p.dispose();
    },
  );

  test('save snapshots do not alias ledger and inconsistent calendar cannot refill gifts', () {
    final book = PetBond();
    book.gift(0, unlocked: true, food: 10, now: beforeMidnight);
    book.gift(0, unlocked: true, food: 10, now: beforeMidnight);
    final raw = book.toJson();
    (raw['favor'] as List)[0] = 999;
    expect(book.favor[0], 20);
    raw['day'] = '1999-01-01';
    final loaded = PetBond.restore(raw);
    expect(
      loaded.gift(0, unlocked: true, food: 10, now: beforeMidnight),
      false,
    );
    expect(loaded.giftsToday, 2);
  });
}
