import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/ui/game_pages.dart';

/// Use the visible page controls for fixed content, and scroll only item lists.
Future<void> revealUi(WidgetTester tester, Finder target) async {
  bool hasTarget() {
    try {
      return target.evaluate().isNotEmpty;
    } on StateError {
      return false;
    }
  }

  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
  }
  if (hasTarget() && target.hitTestable().evaluate().isNotEmpty) {
    return;
  }
  Future<bool> pageStep(String key) async {
    final pagers = find.byType(GamePages);
    if (pagers.evaluate().isEmpty) return false;
    final pager = pagers.last;
    final control = find.descendant(of: pager, matching: find.byKey(Key(key)));
    if (control.evaluate().isEmpty ||
        tester.widget<IconButton>(control).onPressed == null) {
      return false;
    }
    final counter = find.descendant(
      of: pager,
      matching: find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d+ / \d+$').hasMatch(w.data ?? ''),
      ),
    );
    final before = tester.widget<Text>(counter).data;
    // The explicit Semantics wrapper owns the hit region. Send a real pointer
    // at its center, then prove the page changed instead of invoking callbacks.
    await tester.tapAt(tester.getCenter(control));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
      tester.widget<Text>(counter).data,
      isNot(before),
      reason: 'Enabled page control must change the visible page',
    );
    return true;
  }

  for (var n = 0; n < 80 && await pageStep('game-page-previous'); n++) {
    if (hasTarget() && target.hitTestable().evaluate().isNotEmpty) {
      return;
    }
  }
  for (var n = 0; n < 80 && await pageStep('game-page-next'); n++) {
    if (hasTarget() && target.hitTestable().evaluate().isNotEmpty) {
      return;
    }
  }
  if (find.byType(Scrollable).evaluate().isNotEmpty) {
    if (hasTarget()) {
      await Scrollable.ensureVisible(
        tester.element(target.first),
        alignment: .5,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    } else {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 10000));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(
        target,
        180,
        scrollable: find.byType(Scrollable).last,
      );
    }
  }
  if (find.byType(Scrollable).evaluate().isNotEmpty && hasTarget()) {
    await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }
  expect(
    target.hitTestable(),
    findsWidgets,
    reason: 'Control must be reachable by real page/list navigation: $target',
  );
}

Future<void> tapUi(WidgetTester tester, Finder target) async {
  await revealUi(tester, target);
  await tester.tap(target.hitTestable().first);
  await tester.pump(const Duration(milliseconds: 300));
}
