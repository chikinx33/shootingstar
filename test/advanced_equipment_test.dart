import 'ui_actions.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/advanced_equipment.dart';
import 'package:shootingstar/data/content_catalog.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/advanced_equipment_screen.dart';

void main() {
  AdvancedEquipment ready(GearItem target, {int mode = 0}) {
    final ledger = AdvancedEquipment();
    for (var i = 0; i < 3; i++) {
      expect(
        ledger.refine(target: target, credits: 10000, plans: 100, mode: mode),
        isNotNull,
      );
    }
    return ledger;
  }

  test(
    'empty or legacy ledger has no power and leaves original items unchanged',
    () {
      final inventory = List.generate(
        6,
        (i) => GearItem(i + 1, i * 2, rank: 2, level: 7),
      );
      final before = jsonEncode(inventory.map((g) => g.toJson()).toList());
      for (final raw in [
        null,
        {},
        {'entries': 'wrong'},
        {
          'entries': [
            null,
            {},
            {'id': 999, 'refinement': 3},
          ],
        },
      ]) {
        final ledger = AdvancedEquipment.restore(raw, inventory: inventory);
        expect(ledger.damageBonus(inventory.map((g) => g.id)), 0);
        expect(ledger.hullBonus([4, 5, 6]), 0);
        expect(ledger.highestReservedId, 0);
      }
      expect(jsonEncode(inventory.map((g) => g.toJson()).toList()), before);
    },
  );

  test('refinement rejects missing eligibility or resources atomically, then stops at three', () {
    final target = GearItem(1, 0), ledger = AdvancedEquipment();
    expect(
      ledger.refine(target: target, credits: 9999, plans: 100, mode: 0),
      isNull,
    );
    target.rank = 1;
    for (final args in [(149, 3, 0), (150, 2, 0), (150, 3, -1), (150, 3, 3)]) {
      final before = jsonEncode(ledger.toJson());
      expect(
        ledger.refine(
          target: target,
          credits: args.$1,
          plans: args.$2,
          mode: args.$3,
        ),
        isNull,
      );
      expect(jsonEncode(ledger.toJson()), before);
    }
    final costs = <int>[], plans = <int>[];
    for (var n = 0; n < 3; n++) {
      final change = ledger.refine(
        target: target,
        credits: 10000,
        plans: 100,
        mode: 0,
      )!;
      costs.add(change.creditsCost);
      plans.add(change.plansCost);
    }
    expect(costs, [150, 250, 350]);
    expect(plans, [3, 5, 7]);
    expect(
      ledger.refine(target: target, credits: 10000, plans: 100, mode: 0),
      isNull,
    );
    expect(ledger.entry(1)!.spentCredits, 750);
    expect(ledger.entry(1)!.spentPlans, 15);
    expect(target.toJson(), GearItem(1, 0, rank: 1).toJson());
  });

  test('mode choice allocates one axis and only equipped identities grant bounded power', () {
    final gears = List.generate(6, (i) => GearItem(i + 1, i * 2, rank: 1));
    final ledger = AdvancedEquipment();
    for (final gear in gears) {
      for (var i = 0; i < 3; i++) {
        ledger.refine(target: gear, credits: 10000, plans: 100, mode: 0);
      }
    }
    expect(ledger.damageBonus([1, 2, 3, 4, 5, 6]), closeTo(.09, 1e-9));
    expect(ledger.damageBonus([1, 1, 1, 999]), closeTo(.015, 1e-9));
    expect(ledger.hullBonus([1, 2, 3, 4, 5, 6]), 0);
    for (final gear in gears) {
      expect(ledger.chooseMode(gear.id, 1), isTrue);
    }
    expect(ledger.damageBonus([1, 2, 3, 4, 5, 6]), 0);
    expect(ledger.hullBonus([1, 2, 3, 4, 5, 6]), closeTo(.135, 1e-9));
    for (final gear in gears) {
      ledger.chooseMode(gear.id, 2);
    }
    expect(ledger.pickupBonus([1, 2, 3, 4, 5, 6]), closeTo(.18, 1e-9));
    expect(ledger.chooseMode(1, 2), isFalse);
    expect(ledger.chooseMode(1, -1), isFalse);
    expect(ledger.chooseMode(999, 0), isFalse);
    final refund = ledger.reset(targetId: 1, inventory: gears)!;
    expect([refund.creditsCost, refund.plansCost], [-750, -15]);
    expect(ledger.damageBonus([1]), 0);
    expect(ledger.reset(targetId: 1, inventory: gears), isNull);
  });

  test('materials exclude equipped, locked, leveled, paid, advanced and saved preset gear', () {
    final target = GearItem(1, 0, rank: 2);
    final inventory = [
      target,
      GearItem(2, 1, rank: 1), // valid, same slot but alternative weapon
      GearItem(3, 0, rank: 1, locked: true),
      GearItem(4, 0, rank: 1, level: 1),
      GearItem(5, 0, rank: 1), // equipped
      GearItem(6, 0, rank: 1), // preset
      GearItem(7, 0, rank: 1), // refined
      GearItem(8, 0), // below minimum rank
      GearItem(9, 2, rank: 1), // wrong slot
      GearItem(10, 0, rank: 1, spentCredits: 30),
      GearItem(11, 0, rank: 1, spentPlans: 1),
    ];
    final ledger = ready(target);
    ledger.refine(target: inventory[6], credits: 1000, plans: 10, mode: 1);
    expect(
      ledger
          .candidates(
            target: target,
            inventory: inventory,
            equipped: [1, 5],
            protectedIds: [6],
          )
          .map((g) => g.id),
      [2],
    );
    final before = jsonEncode(ledger.toJson());
    for (final ids in [
      [2, 2],
      [2],
      [2, 3],
      [2, 4],
      [2, 5],
      [2, 6],
      [2, 7],
      [2, 8],
      [2, 9],
      [2, 10],
      [2, 11],
      [2, 999],
    ]) {
      expect(
        ledger.ascend(
          target: target,
          inventory: inventory,
          equipped: [1, 5],
          protectedIds: [6],
          materialIds: ids,
          credits: 9999,
          plans: 100,
        ),
        isNull,
      );
      expect(jsonEncode(ledger.toJson()), before);
    }
  });

  test('two explicit fusions preserve identity and round trip exact material IDs and costs', () {
    final target = GearItem(
      1,
      0,
      rank: 2,
      level: 8,
      locked: true,
      spentCredits: 800,
      spentPlans: 8,
    );
    final originals = [
      GearItem(90, 0, rank: 1),
      GearItem(91, 1, rank: 2),
      GearItem(92, 0, rank: 3),
      GearItem(93, 1, rank: 1),
    ];
    final inventory = [target, ...originals];
    final before = target.toJson();
    var ledger = ready(target);
    for (final ids in [
      [90, 91],
      [92, 93],
    ]) {
      final change = ledger.ascend(
        target: target,
        inventory: inventory,
        equipped: [1],
        materialIds: ids,
        credits: 10000,
        plans: 100,
      )!;
      expect(change.consumedIds, ids);
      inventory.removeWhere((g) => change.consumedIds.contains(g.id));
    }
    expect(ledger.highestReservedId, 93);
    expect(ledger.damageBonus([1]), closeTo(.045, 1e-9));
    expect(
      ledger.ascend(
        target: target,
        inventory: inventory,
        equipped: [1],
        materialIds: [90, 91],
        credits: 10000,
        plans: 100,
      ),
      isNull,
    );
    final snapshot = jsonDecode(jsonEncode(ledger.toJson()));
    ledger = AdvancedEquipment.restore(snapshot, inventory: inventory);
    expect(ledger.entry(1)!.ascension, 2);
    expect(ledger.highestReservedId, 93);
    // Public state is detached from the material refund ledger.
    ledger.entry(1)!.materials[0].rank = 5;
    final reset = ledger.reset(targetId: 1, inventory: inventory)!;
    expect(reset.creditsCost, -2350);
    expect(reset.plansCost, -41);
    expect(
      reset.returnedItems.map((g) => g.toJson()).toList(),
      originals.map((g) => g.toJson()).toList(),
    );
    expect(target.toJson(), before);
    expect(ledger.reset(targetId: 1, inventory: inventory), isNull);
  });

  test('fusion and reset guard stale inputs and refund inventory overflow before mutation', () {
    final target = GearItem(1, 6, rank: 2);
    final ledger = ready(target, mode: 1);
    final inventory = [
      target,
      GearItem(8, 6, rank: 1),
      GearItem(9, 7, rank: 1),
    ];
    final before = jsonEncode(ledger.toJson());
    for (final budget in [(599, 10), (600, 9)]) {
      expect(
        ledger.ascend(
          target: target,
          inventory: inventory,
          equipped: [1],
          materialIds: [8, 9],
          credits: budget.$1,
          plans: budget.$2,
        ),
        isNull,
      );
      expect(jsonEncode(ledger.toJson()), before);
    }
    expect(
      ledger.ascend(
        target: GearItem(1, 6, rank: 2),
        inventory: inventory,
        equipped: [1],
        materialIds: [8, 9],
        credits: 9999,
        plans: 100,
      ),
      isNull,
    );
    final fusion = ledger.ascend(
      target: target,
      inventory: inventory,
      equipped: [1],
      materialIds: [8, 9],
      credits: 9999,
      plans: 100,
    )!;
    inventory.removeWhere((g) => fusion.consumedIds.contains(g.id));
    expect(ledger.hullBonus([1]), closeTo(.0425, 1e-9));
    final after = jsonEncode(ledger.toJson());
    expect(
      ledger.reset(targetId: 1, inventory: [target, GearItem(8, 0)]),
      isNull,
    );
    expect(
      ledger.reset(
        targetId: 1,
        inventory: [target, ...List.generate(238, (i) => GearItem(i + 100, 0))],
      ),
      isNull,
    );
    expect(ledger.reset(targetId: 1, inventory: []), isNull);
    expect(jsonEncode(ledger.toJson()), after);
    expect(ledger.reset(targetId: 1, inventory: inventory), isNotNull);
  });

  test('restore bounds malformed data and never refunds forged or duplicate material records', () {
    final target = GearItem(1, 0, rank: 2), other = GearItem(2, 2, rank: 2);
    final ledger = ready(target);
    final raw = jsonDecode(jsonEncode(ledger.toJson())) as Map<String, dynamic>;
    final rows = raw['entries'] as List;
    (rows.first as Map)['spentCredits'] = double.infinity;
    (rows.first as Map)['spentPlans'] = 99999999;
    (rows.first as Map)['mode'] = -100;
    (rows.first as Map)['ascension'] = 999;
    (rows.first as Map)['materials'] = [
      GearItem(90, 0, rank: 1).toJson(),
      GearItem(90, 0, rank: 1).toJson(),
    ];
    rows.addAll([
      rows.first,
      {'id': 99999, 'refinement': 3},
      {'id': 2, 'refinement': -4},
    ]);
    final restored = AdvancedEquipment.restore(raw, inventory: [target, other]);
    expect(restored.entry(1)!.refinement, 3);
    expect(restored.entry(1)!.ascension, 0);
    expect(restored.entry(1)!.mode, 0);
    expect(restored.entry(1)!.spentCredits, 0);
    expect(restored.entry(1)!.spentPlans, 15);
    expect(restored.entry(2), isNull);
    expect(restored.highestReservedId, 1);
    final refund = restored.reset(targetId: 1, inventory: [target, other])!;
    expect(refund.returnedItems, isEmpty);
    expect(refund.plansCost, -15);
  });

  test('pruning removes orphan growth and it cannot be applied to a replacement item', () {
    final target = GearItem(1, 0, rank: 1), ledger = ready(target);
    expect(ledger.isProtected(1), isTrue);
    ledger.pruneTo({2});
    expect(ledger.isProtected(1), isFalse);
    expect(ledger.damageBonus([1]), 0);
    expect(ledger.highestReservedId, 0);
  });

  testWidgets(
    '320px advanced growth selects exact materials and restores them through its UI',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.credits = 5000;
      p.blueprints = 100;
      p.gearAt(0).rank = 2;
      p.inventory.addAll([
        GearItem(100, 0, rank: 1),
        GearItem(101, 1, rank: 1),
      ]);
      await tester.pumpWidget(
        MaterialApp(home: AdvancedEquipmentScreen(profile: p)),
      );
      await tester.pumpAndSettle();
      Future<void> tapKey(String key) => tapUi(tester, find.byKey(Key(key)));

      for (var n = 0; n < 3; n++) {
        await tapKey('advanced-refine');
      }
      expect(p.advancedEquipment.entry(1)!.refinement, 3);
      expect(p.credits, 4250);
      await tapKey('advanced-mode-1');
      expect(p.advancedEquipment.hullBonus([1]), closeTo(.0225, 1e-9));
      // v12.4.3: fusion is its own section and materials open in a popup.
      await tapKey('advanced-tab-1');
      await tapKey('advanced-materials');
      expect(find.text('융합 재료 선택'), findsOneWidget);
      await tapKey('advanced-material-100');
      await tapKey('advanced-material-101');
      await tapKey('advanced-materials-done');
      await tester.pumpAndSettle();
      expect(find.text('융합 재료 선택'), findsNothing);
      await tapKey('advanced-ascend');
      expect(find.text('초월 융합 확인'), findsOneWidget);
      await revealUi(tester, find.text('선택한 2개로 융합'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('선택한 2개로 융합'));
      await tester.pumpAndSettle();
      expect(p.advancedEquipment.entry(1)!.ascension, 1);
      expect(p.item(100), isNull);
      expect(p.item(101), isNull);
      expect(p.gearAt(0).rank, 2);
      expect(p.gearAt(0).id, 1);
      await tapKey('advanced-reset');
      await revealUi(tester, find.text('정밀 성장만 초기화'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('정밀 성장만 초기화'));
      await tester.pumpAndSettle();
      expect(p.advancedEquipment.entry(1), isNull);
      expect(p.item(100)!.spec, 0);
      expect(p.item(101)!.spec, 1);
      expect(p.credits, 5000);
      expect(p.blueprints, 100);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
