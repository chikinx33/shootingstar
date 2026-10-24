import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/campaign_selector.dart';
import 'package:shootingstar/ui/house_tree.dart';

import 'ui_actions.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('house map fits $size at $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        p.clearedStages.add(0);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(body: CampaignSelector(profile: p)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('민지네 집'), findsOneWidget);
        final locked = tester.widget<HouseNode>(
          find.byKey(const ValueKey('house-node-2')),
        );
        expect(locked.available, isFalse);
        await tester.ensureVisible(find.byKey(const ValueKey('house-node-1')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('house-node-1')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('“허허, 감나무만은 안 된다.”'), findsOneWidget);
        await tapUi(tester, find.text('이 집 지키기'));
        expect(p.selectedStage, 1);
        p.dispose();
      });
    }
  }

  testWidgets('neighbourhood 2 map opens once neighbourhood 1 is guarded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.clearedStages.addAll(List.generate(10, (i) => i));
    p.selectStage(10);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(body: CampaignSelector(profile: p)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('2. 노을 언덕'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('house-node-10')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('house-node-10')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('“츄르 진열대만은 꼭 지켜 줘!”'), findsOneWidget);
    expect(tester.takeException(), isNull);
    p.dispose();
  });
}
