import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/houses.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/flight_record.dart';
import 'package:shootingstar/data/world_briefing.dart';
import 'package:shootingstar/game/world_fields.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/item_slots.dart';
import 'package:shootingstar/ui/flight_history_screen.dart';
import 'package:shootingstar/ui/campaign_selector.dart';
import 'package:shootingstar/ui/content_hub.dart';

import 'ui_actions.dart';

GameEngine sortie() =>
    GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 25,
      )
      ..elapsed = 45
      ..kills = 30
      ..level = 3
      ..lastDamageSource = '환경 위험'
      ..damageByWeapon['gun'] = 100
      ..abandon();
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('local learning history is bounded, immutable, survives restart and never exports to cloud', () async {
    final p = await Profile.load();
    for (var i = 0; i < 12; i++) p.recordFlight('run-$i', sortie());
    expect(p.flightHistory.length, 8);
    expect(p.flightHistory.first.id, 'run-11');
    p.recordFlight('run-11', sortie());
    expect(p.flightHistory.length, 8);
    expect(() => p.flightHistory.clear(), throwsUnsupportedError);
    expect(() => p.flightHistory.first.damage.clear(), throwsUnsupportedError);
    expect(p.flightHistory.first.nextStep, contains(worldTactics.first));
    await p.save();
    expect(p.exportProgress().containsKey('_flights'), false);
    final reloaded = await Profile.load();
    expect(
      reloaded.flightHistory.map((r) => r.id),
      p.flightHistory.map((r) => r.id),
    );
    expect(Profile.presentationCopy(p).flightHistory, isEmpty);
    expect(Profile.developerCopy(p).flightHistory, isEmpty);
    final raw = p.flightHistory.first.toJson();
    raw['seconds'] = -1;
    expect(FlightRecord.restore(raw), null);
    final bad = p.flightHistory.first.toJson();
    bad['damage'] = {'gun': double.nan};
    expect(FlightRecord.restore(bad), null);
    expect(jsonEncode(p.exportProgress()), isNot(contains('run-11')));
    await reloaded.replaceProgress(Profile.freshProgress());
    expect(reloaded.flightHistory, isEmpty);
    reloaded.dispose();
    p.dispose();
  });
  test('ten world objectives and counterplay are distinct and nonempty', () {
    expect(worldObjectives.length, 10);
    expect(worldApproaches.length, 10);
    expect(worldObjectives.toSet().length, 10);
    expect(worldApproaches.toSet().length, 10);
    for (final s in [...worldObjectives, ...worldApproaches])
      expect(s.length, greaterThan(18));
  });
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'learning history and preflight tactics reachable $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = await Profile.load();
          p.recordFlight('last-run', sortie());
          Widget wrap(Widget screen) => MaterialApp(
            theme: ThemeData.dark(),
            builder: (c, ch) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: ch!,
            ),
            home: screen,
          );
          await tester.pumpWidget(wrap(FlightHistoryScreen(profile: p)));
          await tester.pumpAndSettle();
          await tapUi(tester, find.byType(GameItemSlot).first);
          await revealUi(tester, find.text(p.flightHistory.first.nextStep));
          await tapUi(tester, find.bySemanticsLabel('영구 연구 보기').last);
          await tester.pumpAndSettle();
          expect(find.text('영구 연구'), findsWidgets);
          expect(p.credits, 150);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            wrap(Scaffold(body: CampaignSelector(profile: p))),
          );
          await tester.pumpAndSettle();
          await tapUi(tester, find.byKey(const ValueKey('house-node-0')));
          await revealUi(tester, find.text('“냥이야, 내 트램펄린 지켜 줘!”'));
          await revealUi(tester, find.text(houseBossStyles.first));
          await tapUi(tester, find.bySemanticsLabel('이 집 지키기').last);
          expect(p.selectedStage, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
  }
  testWidgets(
    'removed equipment detail keeps an explanation and a working close action',
    (tester) async {
      final p = await Profile.load();
      p.grantItem(0);
      final item = p.inventory.last;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: ContentHub(profile: p)),
        ),
      );
      await tester.pumpAndSettle();
      // Equipped slot is available without hidden inventory navigation.
      final equipped = p.gearAt(0);
      final slot = find
          .byWidgetPredicate(
            (w) =>
                w is Semantics && (w.properties.label ?? '').startsWith('주무장 '),
          )
          .first;
      await tapUi(tester, slot);
      p.equipItem(item.id);
      p.inventory.removeWhere((g) => g.id == equipped.id);
      p.contentChanged();
      await tester.pumpAndSettle();
      expect(find.text('장비 정보 변경'), findsOneWidget);
      await tapUi(tester, find.byTooltip('닫기').last);
      await tester.pumpAndSettle();
      expect(find.text('장비 정보 변경'), findsNothing);
      expect(p.item(item.id), isNotNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
