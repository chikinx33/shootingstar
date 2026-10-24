import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/collection_book.dart';

void main() {
  test('malformed restore validates every resource, tier and active set', () {
    for (final raw in [null, 4, 'invalid', [], true]) {
      expect(CollectionBook.restore(raw).toJson(), CollectionBook().toJson());
    }
    final book = CollectionBook.restore({
      'keys': double.infinity,
      'dust': -8,
      'serial': '4',
      'levels': [99, -1, '5', double.nan, 2.5, true, 1, 1, 1],
      'shards': [100000000, -1, 2.5, '7'],
      'spent': [9999999, -5, true],
      'activeSets': [0, 2, 2, 4, -1, '2', 2.5],
    });
    expect(book.keys, 0);
    expect(book.dust, 0);
    expect(book.serial, 0);
    expect(book.levels, [5, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0]);
    expect(book.shards.take(4), [CollectionBook.resourceCap, 0, 0, 0]);
    expect(book.activeSets, {2});
    expect(book.resetRefund(0), 20);
    expect(
      CollectionBook.restore({'levels': 'bad', 'shards': {}}).discoveredCount,
      0,
    );
  });

  test(
    'earned supplies are deterministic across reload and cover all relics',
    () {
      final uninterrupted = CollectionBook()..keys = 24;
      final reloaded = CollectionBook()..keys = 24;
      for (var i = 0; i < 5; i++) {
        expect(uninterrupted.nextRelicId, i);
        expect(uninterrupted.openSupply(), true);
        expect(reloaded.openSupply(), true);
      }
      final continued = CollectionBook.restore(
        jsonDecode(jsonEncode(reloaded.toJson())),
      );
      for (var i = 5; i < 24; i++) {
        expect(uninterrupted.nextRelicId, continued.nextRelicId);
        expect(uninterrupted.openSupply(), true);
        expect(continued.openSupply(), true);
      }
      expect(continued.toJson(), uninterrupted.toJson());
      expect(continued.keys, 0);
      expect(continued.serial, 24);
      expect(continued.shards, List.filled(12, 6));
      final before = continued.toJson();
      expect(continued.openSupply(), false);
      expect(continued.toJson(), before);
    },
  );

  test(
    'failed operations are atomic and reject invalid IDs and overspending',
    () {
      final book = CollectionBook();
      final before = book.toJson();
      for (final id in [-1, 12, 9999]) {
        expect(book.upgrade(id), false);
        expect(book.reset(id), false);
        expect(book.recycle(id, 1), false);
        expect(book.craft(id), false);
        expect(book.toggleSet(id), false);
      }
      expect(book.upgrade(0), false);
      expect(book.craft(0), false);
      expect(book.recycle(0, 0), false);
      expect(book.recycle(0, -1), false);
      expect(book.recycle(0, 1), false);
      expect(book.toggleSet(0), false);
      expect(book.toJson(), before);
      book.shards[0] = 1;
      expect(book.upgrade(0), true);
      final discovered = book.toJson();
      expect(book.upgrade(0), false);
      expect(book.reset(0), false);
      expect(book.toJson(), discovered);
    },
  );

  test('reset refunds actual upgrade investment once and preserves discovery', () {
    final book = CollectionBook();
    book.shards[0] = 21;
    for (var level = 0; level < 5; level++) {
      expect(book.upgradeCost(0), CollectionBook.upgradeCosts[level]);
      expect(book.upgrade(0), true);
    }
    expect(book.levels[0], 5);
    expect(book.shards[0], 0);
    expect(book.upgrade(0), false);
    expect(book.resetRefund(0), 20);
    final restored = CollectionBook.restore(
      jsonDecode(jsonEncode(book.toJson())),
    );
    expect(restored.reset(0), true);
    expect(restored.levels[0], 1);
    expect(restored.shards[0], 20);
    expect(restored.discoveredCount, 1);
    expect(restored.reset(0), false);
    for (var i = 1; i < 5; i++) {
      expect(restored.upgrade(0), true);
    }
    expect(restored.reset(0), true);
    expect(restored.shards[0], 20);
    // A malformed/missing expense ledger cannot turn restored tiers into loot.
    final missingLedger = CollectionBook.restore({
      'levels': [5],
    });
    expect(missingLedger.reset(0), true);
    expect(missingLedger.shards[0], 0);
  });

  test('complete sets require discovery and at most two can be active', () {
    final book = CollectionBook();
    for (var id = 0; id < 9; id++) {
      book.shards[id] = 1;
      expect(book.upgrade(id), true);
    }
    expect(book.completeSets, {0, 1, 2});
    expect(book.toggleSet(3), false);
    expect(book.toggleSet(0), true);
    expect(book.toggleSet(1), true);
    final twoActive = book.toJson();
    expect(book.toggleSet(2), false);
    expect(book.toJson(), twoActive);
    expect(book.toggleSet(0), true);
    expect(book.toggleSet(2), true);
    expect(book.activeSets, {1, 2});
    final raw = book.toJson()..['activeSets'] = [2, 1, 0, 3, 7, 1];
    expect(CollectionBook.restore(raw).activeSets, {0, 1});
    // Reset retains discovery and therefore cannot leave an invalid active set.
    book.shards[3] = 2;
    expect(book.upgrade(3), true);
    expect(book.reset(3), true);
    expect(book.isSetComplete(1), true);
    expect(book.activeSets, {1, 2});
  });

  test(
    'fragment conversion spends exact amounts and cannot mint resources',
    () {
      final book = CollectionBook();
      book.shards[0] = 6;
      expect(book.recycle(0, 7), false);
      expect(book.recycle(0, 6), true);
      expect(book.shards[0], 0);
      expect(book.dust, 6);
      expect(book.craft(11), true);
      expect(book.craft(11), true);
      expect(book.shards[11], 2);
      expect(book.dust, 0);
      expect(book.craft(11), false);
      expect(book.recycle(11, 2), true);
      expect(book.dust, 2);
      expect(book.craft(0), false);
      expect(book.discoveredCount, 0);
    },
  );

  test('capacity failures do not consume keys, fragments, dust or refunds', () {
    final book = CollectionBook()..keys = 1;
    book.shards[0] = CollectionBook.resourceCap;
    var before = book.toJson();
    expect(book.openSupply(), false);
    expect(book.toJson(), before);
    book.dust = 3;
    before = book.toJson();
    expect(book.craft(0), false);
    expect(book.toJson(), before);
    book.dust = CollectionBook.resourceCap;
    before = book.toJson();
    expect(book.recycle(0, 1), false);
    expect(book.toJson(), before);
    book.shards[0] = 3;
    expect(book.upgrade(0), true);
    expect(book.upgrade(0), true);
    book.shards[0] = CollectionBook.resourceCap;
    before = book.toJson();
    expect(book.reset(0), false);
    expect(book.toJson(), before);
  });

  test(
    'maximum permanent bonuses stay in budget and switching changes builds',
    () {
      final book = CollectionBook();
      for (var id = 0; id < 12; id++) {
        book.shards[id] = 21;
        for (var tier = 0; tier < 5; tier++) {
          expect(book.upgrade(id), true);
        }
      }
      expect(book.damageBonus, closeTo(.06, 1e-12));
      expect(book.hullBonus, closeTo(.075, 1e-12));
      expect(book.pickupBonus, closeTo(.09, 1e-12));
      expect(book.cooldownBonus, closeTo(.01, 1e-12));
      expect(book.toggleSet(0), true);
      expect(book.toggleSet(1), true);
      expect(book.damageBonus, closeTo(.10, 1e-12));
      expect(book.hullBonus, closeTo(.12, 1e-12));
      expect(book.toggleSet(0), true);
      expect(book.toggleSet(1), true);
      expect(book.toggleSet(2), true);
      expect(book.toggleSet(3), true);
      expect(book.pickupBonus, closeTo(.15, 1e-12));
      expect(book.cooldownBonus, closeTo(.02, 1e-12));
      final restored = CollectionBook.restore(
        jsonDecode(jsonEncode(book.toJson())),
      );
      expect(restored.toJson(), book.toJson());
      expect(restored.damageBonus, lessThanOrEqualTo(.10));
      expect(restored.hullBonus, lessThanOrEqualTo(.12));
      expect(restored.pickupBonus, lessThanOrEqualTo(.15));
      expect(restored.cooldownBonus, lessThanOrEqualTo(.02));
    },
  );

  test('serialized snapshots cannot mutate live resources or active sets', () {
    final book = CollectionBook();
    final snapshot = book.toJson();
    (snapshot['shards'] as List)[0] = 10;
    (snapshot['levels'] as List)[0] = 5;
    (snapshot['spent'] as List)[0] = 20;
    (snapshot['activeSets'] as List).add(0);
    expect(book.toJson(), CollectionBook().toJson());
  });
}
