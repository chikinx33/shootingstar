import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/art/arcade_aircraft.dart';
import 'package:shootingstar/art/aircraft_assembly_art.dart';
import 'package:shootingstar/art/gear_art.dart';
import 'package:shootingstar/data/aircraft_geometry.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/content_catalog.dart';
import 'package:shootingstar/data/gear_traits.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/combat_cues.dart';
import 'package:shootingstar/ui/lobby_aircraft.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/item_slots.dart';

import 'ui_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'comparison matches actual equipped stat changes, not unrelated perks',
    () async {
      final p = await Profile.load();
      final candidate = GearItem(100, 1, rank: 2, level: 3);
      p.inventory.add(candidate);
      final before = p.gearDamage,
          expected =
              gearBaseContribution(candidate) -
              gearBaseContribution(p.gearAt(0));
      p.equipItem(100);
      expect(p.gearDamage - before, closeTo(expected, 1e-10));
      expect(
        gearBaseContribution(GearItem(1, 0)),
        gearBaseContribution(GearItem(2, 1)),
      );
      p.dispose();
    },
  );
  test(
    'parts follow at different delays, settle and never enter combat state',
    () {
      GameEngine game() => GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        aircraft: AircraftAssembly.initial(0),
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 63,
      );
      final shown = game(), hidden = game()..visuals.enabled = false;
      for (var i = 0; i < 20; i++) {
        shown.input = hidden.input = const Offset(1, 0);
        shown.update(.025);
        hidden.update(.025);
      }
      expect(shown.visuals.followOffset('main').dx, lessThan(0));
      expect(
        shown.visuals.followOffset('supportRear').distance,
        greaterThan(shown.visuals.followOffset('main').distance),
      );
      expect(jsonEncode(shown.checkpoint()), jsonEncode(hidden.checkpoint()));
      final cues = CombatCues();
      for (var i = 0; i < 10; i++)
        cues.followMovement(const Offset(5, 0), .025);
      for (final key in CombatCues.followTimes.keys)
        expect(cues.followOffset(key).distance, lessThan(3.7));
      for (var i = 0; i < 50; i++) cues.followMovement(Offset.zero, .025);
      expect(cues.followOffset('supportRear').distance, lessThan(.001));
    },
  );
  testWidgets('320px eye, owned equipment, traits, arrows, equip and restore', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = await Profile.load();
    p.gearAt(0)
      ..rank = 1
      ..level = 1;
    p.inventory.addAll([GearItem(100, 1, rank: 2, level: 3), GearItem(101, 0)]);
    await tester.runAsync(AircraftAssemblyArt.load);
    Directory('.local/lobby-v65').createSync(recursive: true);
    File('.local/lobby-v65/fixture.json')
        .writeAsStringSync(jsonEncode(p.exportProgress()));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LobbyAircraft(
              profile: p,
              width: 184,
              height: 400,
              onSelectShip: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ArcadeAircraft>(find.byType(ArcadeAircraft)).visualScale,
      1,
    );
    final beforeArt = tester.widget<ArcadeAircraft>(
      find.byType(ArcadeAircraft),
    );
    final beforeRect = tester.getRect(find.byType(ArcadeAircraft));
    expect(find.byKey(const Key('lobby-equipment-slots')), findsNothing);
    await tester.tap(find.byKey(const Key('lobby-slot-eye')));
    await tester.pumpAndSettle();
    final afterArt = tester.widget<ArcadeAircraft>(find.byType(ArcadeAircraft));
    expect(afterArt.assembly!.toJson(), beforeArt.assembly!.toJson());
    expect(afterArt.assembly!.gearSpecs, beforeArt.assembly!.gearSpecs);
    expect(tester.getRect(find.byType(ArcadeAircraft)), beforeRect);
    final view = AssemblyViewport.layout(
      beforeRect.size,
      p.aircraftAssembly,
      targetSize: 48,
    );
    for (final socket in AircraftAssemblyArt.sockets(p.aircraftAssembly)) {
      final actual = tester.getRect(
        find.byKey(ValueKey('socket-outline-${socket.id}')),
      );
      final expected = view.project(socket.rect).shift(beforeRect.topLeft);
      expect((actual.center - expected.center).distance, lessThan(.001));
      expect(actual.width, closeTo(expected.width, .001));
      expect(actual.height, closeTo(expected.height, .001));
    }
    expect(find.byType(PopupMenuButton<int>), findsNothing);
    expect(find.bySemanticsLabel('날개 슬롯'), findsNWidgets(2));
    expect(find.bySemanticsLabel('우측 지원 슬롯'), findsOneWidget);
    final main = find.bySemanticsLabel('주무장 슬롯');
    final beforeChoice = jsonEncode(p.exportProgress());
    await tester.tapAt(tester.getCenter(main));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('slot-overlap-choices')), findsOneWidget);
    expect(find.byKey(const Key('socket-choice-gear-0')), findsOneWidget);
    expect(find.byKey(const Key('socket-choice-main')), findsOneWidget);
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    expect(jsonEncode(p.exportProgress()), beforeChoice);
    await tester.tapAt(tester.getCenter(main));
    await tester.pumpAndSettle();
    await tapUi(tester, find.byKey(const Key('socket-choice-gear-0')));
    await tester.pumpAndSettle();
    expect(find.byType(GameItemSlot), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(GearComparisonMark),
        matching: find.byIcon(Icons.arrow_drop_up),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(GearComparisonMark),
        matching: find.byIcon(Icons.arrow_drop_down),
      ),
      findsOneWidget,
    );
    final higher = find.byWidgetPredicate(
      (w) => w is GameItemSlot && w.title == '유성 추적기',
    );
    await tapUi(tester, higher);
    await tester.pumpAndSettle();
    expect(find.text(gearTraitDescription(1)), findsOneWidget);
    final equip = find.byWidgetPredicate(
      (w) => w is GameActionButton && w.label == '장착',
    );
    await tapUi(tester, equip);
    await tester.pumpAndSettle();
    expect(p.equippedGear[0], 100);
    await p.save();
    final copy = await Profile.load();
    expect(copy.equippedGear[0], 100);
    copy.dispose();
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('socket-wings-0'))),
    );
    await tester.pumpAndSettle();
    if (find.byKey(const Key('slot-overlap-choices')).evaluate().isNotEmpty) {
      await tapUi(tester, find.byKey(const Key('socket-choice-wings')));
      await tester.pumpAndSettle();
    }
    expect(
      find.byWidgetPredicate((w) => w is GameItemSlot && w.title == '날개 포드'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.bySemanticsLabel('우측 지원 슬롯')));
    await tester.pumpAndSettle();
    if (find.byKey(const Key('slot-overlap-choices')).evaluate().isNotEmpty) {
      await tapUi(tester, find.byKey(const Key('socket-choice-supportRight')));
      await tester.pumpAndSettle();
    }
    await tapUi(
      tester,
      find.byWidgetPredicate((w) => w is GameItemSlot && w.title == '축전 포드'),
    );
    await tester.pumpAndSettle();
    await tapUi(
      tester,
      find.byWidgetPredicate((w) => w is GameActionButton && w.label == '장착'),
    );
    await tester.pumpAndSettle();
    expect(p.aircraftAssembly.parts[AircraftMount.supportRight], 'capacitor');
    expect(p.aircraftAssembly.parts[AircraftMount.supportLeft], isNull);
    await p.save();
    final supportCopy = await Profile.load();
    expect(
      supportCopy.aircraftAssembly.parts[AircraftMount.supportRight],
      'capacitor',
    );
    supportCopy.dispose();
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lobby-slot-eye')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('날개 슬롯'), findsNothing);
    expect(find.bySemanticsLabel('주무장 슬롯'), findsNothing);
    expect(find.bySemanticsLabel('우측 지원 슬롯'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });
  test('every hull and equipment variant uses physical painted rectangles', () async {
    await AircraftAssemblyArt.load();
    for (var hull = 0; hull < 3; hull++) {
      for (var spec = 0; spec < gearCatalog.length; spec++) {
        final gear = [0, 2, 4, 6, 8, 10];
        gear[gearCatalog[spec].slot] = spec;
        final assembly = AircraftAssembly.demo(hull).withGear(gear);
        final sockets = AircraftAssemblyArt.sockets(assembly);
        for (final placement in AircraftAssemblyArt.placements(assembly)) {
          final slot = placement.mount == AircraftMount.main
              ? 0
              : placement.mount == AircraftMount.armor
              ? 3
              : -1;
          final src = slot >= 0
              ? GearArt.cells[gear[slot]]
              : AircraftAssemblyArt.partRect(aircraftPart(placement.part));
          final physical = AircraftGeometry.mountedRect(
            placement.anchor,
            placement.width,
            src,
            pivot: placement.pivot,
            mirror: placement.mirror,
          );
          expect(
            sockets.any(
              (s) => s.mount == placement.mount && s.rect == physical,
            ),
            isTrue,
          );
        }
        expect(sockets.where((s) => s.gearSlot == 5), hasLength(2));
        for (final size in [const Size(160, 220), const Size(248, 440)]) {
          final view = AssemblyViewport.layout(size, assembly, targetSize: 48);
          for (final socket in sockets) {
            final rect = view.project(socket.rect);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
          }
          // The fuselage now spans most of the preview width, not a tiny core.
          expect(view.extent / size.width, greaterThan(.7));
        }
      }
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(const Color(0xFF243C51), BlendMode.src);
    for (var hull = 0; hull < 3; hull++) {
      final assembly = AircraftAssembly.demo(hull)
          .withGear(const [0, 2, 4, 6, 8, 10]);
      final view = AssemblyViewport.layout(const Size(320, 460), assembly);
      canvas.save();
      canvas.translate(hull * 320.0, 0);
      AircraftAssemblyArt.paintAssembly(
        canvas,
        view.center,
        view.extent,
        assembly,
      );
      for (final socket in AircraftAssemblyArt.sockets(
        assembly,
      ).where((s) => s.gearSlot != null)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            view.project(socket.rect),
            const Radius.circular(6),
          ),
          Paint()
            ..color = const Color(0xFF92D5E8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(960, 460);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    File('.local/lobby-v65/physical-layout.png')
        .writeAsBytesSync(bytes.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
