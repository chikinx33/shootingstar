import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tabs.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/daily_challenge.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/daily_challenge_screen.dart';

DailyChallengeBook today() =>
    DailyChallengeBook()..advance(DateTime.utc(2026, 10, 17));

int win(DailyChallengeBook book, DailyChallengeEntry entry) =>
    book.complete(entry, victory: true, seconds: 180, kills: 100, bosses: 1);

void main() {
  test('fresh and malformed data have no free reward or active entry', () {
    for (final raw in [null, false, 3, 'bad', []]) {
      final book = DailyChallengeBook.restore(raw);
      expect(book.toJson(), DailyChallengeBook().toJson());
      expect(book.begin(0), isNull);
      expect(book.exchange(0), isNull);
    }
    final book = DailyChallengeBook.restore({
      'day': '2026-02-30',
      'tokens': double.infinity,
      'cleared': [0, 1],
      'purchases': [1, 1, 1, 1],
    });
    expect(book.day, '');
    expect(book.tokens, 0);
    expect(book.cleared, isEmpty);
    expect(book.purchases, [0, 0, 0, 0]);
  });

  test(
    'restoration bounds counts and rejects nonfinite and noninteger data',
    () {
      final book = DailyChallengeBook.restore({
        'day': '2026-10-17',
        'tokens': 10000000,
        'cleared': [0, 0, 1, 2, 3, -1, '2', 2.0, true],
        'purchases': [99, -1, 1.5, double.nan, 999],
      });
      expect(book.tokens, DailyChallengeBook.tokenCap);
      expect(book.cleared, {0, 1, 2});
      expect(book.purchases, [2, 0, 0, 0]);
      expect(DailyChallengeBook.restore({'tokens': '99'}).tokens, 0);
      expect(DailyChallengeBook.restore({'tokens': 2.5}).tokens, 0);
      expect(DailyChallengeBook.restore({'tokens': -9}).tokens, 0);
    },
  );

  test(
    'KST midnight rotates claims and shop while preserving earned tokens',
    () {
      final book = today();
      win(book, book.begin(2)!);
      expect(book.exchange(0), isNotNull);
      expect(book.tokens, 5);
      expect(book.advance(DateTime.utc(2026, 10, 17, 14, 59, 59)), false);
      expect(book.day, '2026-10-17');
      expect(book.cleared, {2});
      expect(book.purchases[0], 1);
      expect(book.nextResetUtc, DateTime.utc(2026, 10, 17, 15));
      expect(book.advance(DateTime.utc(2026, 10, 17, 15)), true);
      expect(book.day, '2026-10-18');
      expect(book.tokens, 5);
      expect(book.cleared, isEmpty);
      expect(book.purchases, [0, 0, 0, 0]);
    },
  );

  test('clock rollback after reload cannot reopen rewarded tiers or shop', () {
    final book = today();
    win(book, book.begin(2)!);
    book.exchange(0);
    final restored = DailyChallengeBook.restore(
      jsonDecode(jsonEncode(book.toJson())),
    );
    final before = restored.toJson();
    expect(restored.advance(DateTime.utc(2026, 10, 15)), false);
    expect(restored.toJson(), before);
    expect(win(restored, restored.begin(2)!), 0);
  });

  test(
    'rotating variants are deterministic and expose behavioral tradeoffs',
    () {
      final book = today();
      final variants = <int>{};
      final seeds = <int>{};
      for (var day = 17; day < 20; day++) {
        book.advance(DateTime.utc(2026, 10, day));
        final entry = book.begin(1)!;
        final restored = DailyChallengeBook.restore(book.toJson()).begin(1)!;
        expect(entry.seed, restored.seed);
        expect(entry.variant, restored.variant);
        variants.add(entry.variant);
        seeds.add(entry.seed);
        if (entry.variant == 0) expect(entry.waveIntervalMultiplier, .82);
        if (entry.variant == 1) expect(entry.projectileIntervalMultiplier, .78);
        if (entry.variant == 2) {
          expect(entry.enemySpeedMultiplier, 1.15);
          expect(entry.pickupMultiplier, 1.2);
        }
        expect(entry.stageIndex, 0);
        expect(entry.requiredBosses, 1);
      }
      expect(variants, {0, 1, 2});
      expect(seeds.length, 3);
    },
  );

  test('each tier pays once with a fixed daily maximum of sixteen', () {
    final book = today();
    expect(book.begin(-1), isNull);
    expect(book.begin(3), isNull);
    for (var tier = 0; tier < 3; tier++) {
      final entry = book.begin(tier)!;
      expect(win(book, entry), DailyChallengeBook.tokenRewards[tier]);
      expect(
        book.begin(tier),
        isNotNull,
        reason: 'free practice remains available',
      );
      expect(win(book, entry), 0);
    }
    expect(book.tokens, 16);
    expect(book.cleared, {0, 1, 2});
  });

  test(
    'failure, short, invalid, bossless and empty runs never award tokens',
    () {
      final book = today();
      final entry = book.begin(0)!;
      final invalid = [
        (false, 180.0, 100, 1),
        (true, 178.0, 100, 1),
        (true, double.infinity, 100, 1),
        (true, double.nan, 100, 1),
        (true, 180.0, 19, 1),
        (true, 180.0, 100, 0),
        (true, 241.0, 100, 1),
      ];
      for (final value in invalid) {
        expect(
          book.complete(
            entry,
            victory: value.$1,
            seconds: value.$2,
            kills: value.$3,
            bosses: value.$4,
          ),
          0,
        );
        expect(book.tokens, 0);
        expect(book.cleared, isEmpty);
      }
      expect(
        win(book, entry),
        3,
        reason: 'failure does not consume first clear',
      );
    },
  );

  test('previous-day and forged seed, variant, tier entries cannot settle', () {
    final book = today();
    final old = book.begin(0)!;
    book.advance(DateTime.utc(2026, 10, 18));
    expect(win(book, old), 0);
    final current = book.begin(0)!;
    final forged = [
      DailyChallengeEntry(
        day: current.day,
        variant: current.variant,
        tier: current.tier,
        seed: current.seed + 1,
      ),
      DailyChallengeEntry(
        day: current.day,
        variant: (current.variant + 1) % 3,
        tier: current.tier,
        seed: current.seed,
      ),
      DailyChallengeEntry(
        day: current.day,
        variant: current.variant,
        tier: 9,
        seed: current.seed,
      ),
      DailyChallengeEntry(
        day: '',
        variant: current.variant,
        tier: current.tier,
        seed: current.seed,
      ),
    ];
    for (final entry in forged) {
      expect(win(book, entry), 0);
    }
    expect(book.tokens, 0);
    expect(win(book, current), 3);
  });

  test('reload preserves claim and token conservation through exchanges', () {
    var book = today();
    for (var tier = 0; tier < 3; tier++) {
      win(book, book.begin(tier)!);
    }
    expect(book.exchange(0)!.plans, 2);
    expect(book.exchange(2)!.collectionKeys, 1);
    expect(book.tokens, 5);
    book = DailyChallengeBook.restore(jsonDecode(jsonEncode(book.toJson())));
    expect(book.cleared, {0, 1, 2});
    expect(book.purchases, [1, 0, 1, 0]);
    final before = book.toJson();
    expect(book.exchange(2), isNull, reason: 'limited offer already taken');
    expect(book.exchange(3), isNull, reason: 'insufficient tokens');
    expect(book.exchange(-1), isNull);
    expect(book.exchange(4), isNull);
    expect(book.toJson(), before);
    expect(book.exchange(1)!.food, 15);
    expect(book.tokens, 0);
    expect(win(book, book.begin(2)!), 0);
  });

  test(
    'shop daily limits reset without creating tokens or refunding purchases',
    () {
      final book = today()..tokens = 100;
      var spent = 0;
      for (var id = 0; id < DailyChallengeBook.exchanges.length; id++) {
        final offer = DailyChallengeBook.exchanges[id];
        for (var count = 0; count < offer.limit; count++) {
          expect(book.exchange(id), isNotNull);
          spent += offer.cost;
        }
        expect(book.exchange(id), isNull);
      }
      expect(book.tokens, 100 - spent);
      book.advance(DateTime.utc(2026, 10, 18));
      expect(book.tokens, 100 - spent);
      expect(book.exchange(0), isNotNull);
      expect(book.tokens, 100 - spent - 3);
    },
  );

  test('token cap cannot overflow even after a valid first clear', () {
    final book = today()..tokens = DailyChallengeBook.tokenCap - 1;
    expect(win(book, book.begin(2)!), 1);
    expect(book.tokens, DailyChallengeBook.tokenCap);
    expect(win(book, book.begin(2)!), 0);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets(
      'daily menu launches captured entries and exchanges safely at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        p.dailyChallenge.tokens =
            16; // Earned-token fixture, not a production grant.
        final credits = p.credits;
        final plans = p.blueprints;
        DailyChallengeEntry? launched;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: DailyChallengeScreen(
              profile: p,
              onLaunch: (entry) async => launched = entry,
              onExchange: p.exchangeDailyChallenge,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('일일 순환 도전'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('daily-launch-0')),
          200,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('daily-launch-0')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('daily-launch-0')));
        await tester.pumpAndSettle();
        expect(launched!.day, p.dailyChallenge.day);
        expect(launched!.seed, p.dailyChallenge.begin(0)!.seed);
        expect(p.credits, credits);
        expect(
          p.dailyChallenge.tokens,
          16,
          reason: 'launch alone pays no reward',
        );
        await tester.drag(find.byType(ListView), const Offset(0, 1000));
        await tester.pumpAndSettle();
        await tester.tap(tabWithText('토큰 교환'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('daily-exchange-0')),
          200,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('daily-exchange-0')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('daily-exchange-0')));
        await tester.pumpAndSettle();
        expect(p.dailyChallenge.tokens, 13);
        expect(p.blueprints, plans + 2);
        expect(p.dailyChallenge.purchases[0], 1);
        expect(p.credits, credits);
        await p.save();
        final restored = await Profile.load();
        expect(restored.dailyChallenge.tokens, 13);
        expect(restored.dailyChallenge.purchases[0], 1);
        expect(restored.blueprints, plans + 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
        restored.dispose();
      },
    );
  }
}
