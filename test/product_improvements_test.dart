import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/art/armament_art.dart';
import 'package:shootingstar/art/game_art.dart';
import 'package:shootingstar/art/menu_art.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/flight_coach.dart';
import 'package:shootingstar/ui/hangar_board.dart';
import 'package:shootingstar/ui/battle.dart';

import 'ui_actions.dart';

GameEngine arena() => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 23,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'damage explanation reports real hull loss, never shield-only absorption',
    () {
      final shielded = arena()..pilotShield = 1000;
      final hp = shielded.hp;
      shielded.shots.add(Shot(shielded.position, Offset.zero, 10, 4));
      shielded.update(.01);
      expect(shielded.hp, hp);
      expect(shielded.lastDamageSource, isEmpty);
      expect(shielded.damageTakenBySource, isEmpty);
      final defeated = arena()..hp = 2;
      defeated.shots.add(Shot(defeated.position, Offset.zero, 100, 4));
      defeated.update(.01);
      expect(defeated.finished, true);
      expect(defeated.lastDamageSource, '적탄');
      expect(defeated.damageTakenBySource['적탄'], 2);
      expect(defeated.damageAdvice, contains('손을 떼어'));
    },
  );
  test('coach requires real hold, release, movement and choice; never grants progress', () {
    final g = arena(), coach = FlightCoach();
    coach.observe(g, 1, pressed: false);
    expect(coach.lesson, FlightLesson.hold);
    g.setPaused(true);
    coach.observe(g, 1, pressed: true);
    expect(coach.lesson, FlightLesson.hold);
    g.setPaused(false);
    coach.observe(g, .8, pressed: true);
    expect(coach.lesson, FlightLesson.release);
    coach.observe(g, .1, pressed: false);
    expect(coach.lesson, FlightLesson.move);
    coach.observe(g, 1, pressed: true);
    expect(coach.lesson, FlightLesson.move);
    g.input = const Offset(1, 0);
    coach.observe(g, .6, pressed: true);
    expect(coach.lesson, FlightLesson.collect);
    expect(g.level, 1);
    expect(g.xp, 0);
    g.level = 2;
    coach.observe(g, .1, pressed: true);
    expect(coach.lesson, FlightLesson.draft);
    coach.selected = true;
    coach.observe(g, .1, pressed: true);
    expect(coach.lesson, FlightLesson.ultimate);
    expect(g.mainRate + g.mainPower + g.mainCount, 0);
  });

  // Keep this before the widget tests: an asset load first started inside
  // fake time would never complete here and the test would hang.
  testWidgets(
    'boot omits enemy payloads and the shared main cannon icon draws',
    (tester) async {
      await tester.runAsync(() async {
        await RasterAssets.load();
        expect(GameArt.ready, true);
        expect(
          MenuArt.images.keys.where((k) => k.startsWith('game/enemy-')),
          isEmpty,
        );
      });
      final signatures = <int>{};
      for (final weapon in armaments) {
        await tester.pumpWidget(
          MaterialApp(home: Center(child: ArmamentArt(weapon.id, size: 100))),
        );
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(ArmamentArt),
            matching: find.byType(CustomPaint),
          ),
        );
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          paint.painter!.paint(Canvas(recorder), const Size(100, 100));
          final picture = recorder.endRecording(),
              image = await picture.toImage(100, 100);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          expect(data.where((value) => value > 0).length, greaterThan(100));
          signatures.add(Object.hashAll(data));
          image.dispose();
          picture.dispose();
        });
      }
      // v12.4.3: every main-gun family is fired by the same forward cannon,
      // so all armament icons draw that one part (ArmamentArt).
      expect(signatures.length, 1);
      await tester.runAsync(() async {
        await GameArt.loadBattle();
        expect(GameArt.battleReady, true);
        expect(
          MenuArt.images.keys.where((k) => k.startsWith('game/enemy-')).length,
          11,
        );
      });
    },
  );
  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'preparation board keeps airframe and module slots reachable $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 104),
                      Expanded(child: HangarBoard(profile: p)),
                      const SizedBox(height: 88),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // v12.9.2: the cat is the pilot, so there is no pilot choice; the
          // board is the module workshop with the airframe's mounts (v12.11).
          for (final label in ['기체 선택', '기체 정보']) {
            await revealUi(tester, find.text(label));
            expect(find.text(label).hitTestable(), findsOneWidget);
          }
          for (final mount in moduleProfiles) {
            final slot = find.bySemanticsLabel('${mount.id} 모듈 편집');
            await revealUi(tester, slot.last);
            expect(slot.last.hitTestable(), findsOneWidget);
          }
          await tapUi(tester, find.bySemanticsLabel('W1 모듈 편집').last);
          await tester.pumpAndSettle();
          expect(find.text('W1 · ${moduleProfiles.first.name}'), findsWidgets);
          expect(p.credits, 150);
          expect(p.blueprints, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
  }
  testWidgets(
    'defeat cause and next action remain reachable at 320px and 130 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load()
        ..soundEnabled = false;
      final defeated = arena()..hp = 2;
      defeated.shots.add(Shot(defeated.position, Offset.zero, 100, 4));
      defeated.update(.01);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: BattleScreen(profile: p, engineFactory: () => defeated),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // v12.4.3: the one-page result names the last hit; the advice lives in
      // the reward/record popup.
      await revealUi(tester, find.text('마지막 피격 · 적탄'));
      expect(find.text('마지막 피격 · 적탄').hitTestable(), findsOneWidget);
      await tapUi(tester, find.byKey(const Key('result-rewards')));
      await tester.pump(const Duration(milliseconds: 400));
      await revealUi(tester, find.textContaining(defeated.damageAdvice));
      expect(
        find.textContaining(defeated.damageAdvice).hitTestable(),
        findsOneWidget,
      );
      expect(p.credits, 150);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
