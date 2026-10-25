import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/content_hub.dart';

import 'support/tabs.dart';
import 'ui_actions.dart';

void main() {
  // v12.10: the growth hub has three tabs (장비 · 무기 · 병아리). Equipment and
  // weapons share the slot screen; pets show their details inline. The old
  // merge review, 테크 tab and 관리 shortcuts were removed.
  testWidgets('360px growth tabs swap slots and pet feeding works inline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.petFood = 100;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ContentHub(profile: p)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final slot in ['nose', 'armor', 'wings', 'engines']) {
      expect(find.byKey(Key('cat-gear-slot-$slot')), findsOneWidget);
    }
    await tester.tap(tabWithText('무기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cat-gear-slot-nose')), findsNothing);
    for (final m in ['main', 'W1', 'W2', 'W3', 'S1']) {
      expect(find.byKey(Key('weapon-slot-$m')), findsOneWidget, reason: m);
    }
    expect(tester.takeException(), isNull);
    await tester.tap(tabWithText('병아리'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pet-detail')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    final level = p.petLevels[0];
    await tapUi(tester, find.byKey(const Key('pet-feed')));
    await tester.pumpAndSettle();
    expect(p.petLevels[0], level + 1);
    expect(tester.takeException(), isNull);
    await tester.tap(tabWithText('장비'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cat-gear-slot-nose')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });
}
