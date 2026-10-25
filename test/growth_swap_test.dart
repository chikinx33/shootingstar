import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/cat_gear_screen.dart';
import 'package:shootingstar/ui/content_hub.dart';

/// v12.10.1 growth screen: the equipment/weapon tabs swap the slots in place,
/// weapon slots open the shared item popup, pets show details below.
void main() {
  Future<Profile> load(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    return Profile.load();
  }

  Widget host(Profile p, bool weapons) => MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: CatGearScreen(profile: p, weapons: weapons),
    ),
  );

  testWidgets('tabs swap gear and weapon slots through the craft', (
    tester,
  ) async {
    final p = await load(tester);
    await tester.pumpWidget(host(p, false));
    await tester.pump(const Duration(milliseconds: 300));
    final nose = find.byKey(const Key('cat-gear-slot-nose'));
    expect(nose, findsOneWidget);
    expect(find.byKey(const Key('weapon-slot-W1')), findsNothing);
    final home = tester.getCenter(nose);

    await tester.pumpWidget(host(p, true));
    await tester.pump(const Duration(milliseconds: 120));
    // mid-sweep: the gear slot is on its way into the craft
    expect(nose, findsOneWidget);
    expect(tester.getCenter(nose).dx, greaterThan(home.dx + 4));
    await tester.pump(const Duration(milliseconds: 600));
    expect(nose, findsNothing);
    expect(find.byKey(const Key('weapon-slot-W1')), findsOneWidget);
    // v12.11: main gun, support device, missile, wing gun, mortar
    for (final m in ['main', 'S1', 'W2', 'W1', 'W3']) {
      expect(find.byKey(Key('weapon-slot-$m')), findsOneWidget, reason: m);
    }
    expect(find.byKey(const Key('weapon-slot-W4')), findsNothing);
    expect(find.byKey(const Key('weapon-slot-S2')), findsNothing);
    expect(find.byKey(const Key('weapon-label')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('weapon-slot-W1')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('weapon-list-W1')), findsOneWidget);
    // the wide test font may push the actions onto the next page
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 3; i++) {
      if (find.byKey(const Key('weapon-equip')).evaluate().isNotEmpty) break;
      await tester.tap(find.byKey(const Key('game-page-next')));
      await tester.pump(const Duration(milliseconds: 300));
    }
    // equip, upgrade and dismantle side by side on one line
    final equip = tester.getCenter(find.byKey(const Key('weapon-equip')));
    final salvage = tester.getCenter(find.byKey(const Key('weapon-salvage')));
    expect((equip.dy - salvage.dy).abs(), lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pet slot shows its details below without a popup', (
    tester,
  ) async {
    final p = await load(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ContentHub(profile: p, initialPage: 2)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('pet-detail')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pet-slot-1')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('pet-detail-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
