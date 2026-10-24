import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/control_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle.dart';

/// v12.4.2 (user 2026-10-24): the cat sits clearly above a following finger,
/// and drag steering stops the moment the finger stops (no joystick drift).
void main() {
  Future<(Profile, GameEngine)> setUpBattle(
    WidgetTester tester, {
    required bool follow,
  }) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.onboarded = true;
    p.soundEnabled = false;
    p.updateControls(ControlPreferences(followTouch: follow));
    final g = GameEngine(
      stageIndex: 0,
      shipIndex: p.selectedShip,
      aircraft: p.aircraftAssembly,
      supportLevels: p.aircraftSupportLevels,
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: -1,
      armament: p.moduleLoadout.signature,
      armamentLevel: p.moduleLoadout.airframeLevel - 1,
      seed: 3,
    )..developerInvincible = true;
    g.xpNeeded = 1e9;
    await tester.pumpWidget(
      MaterialApp(
        home: BattleScreen(profile: p, engineFactory: () => g),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));
    return (p, g);
  }

  Future<void> run(WidgetTester tester, GameEngine g, int frames) async {
    for (var i = 0; i < frames; i++) {
      g.enemies.clear();
      g.shots.clear();
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  testWidgets('follow touch keeps the cat a thumb above the finger', (
    tester,
  ) async {
    final (p, g) = await setUpBattle(tester, follow: true);
    expect(g.screenMode, isTrue);
    final field = tester.getRect(
      find.byKey(const Key('battle-playing-viewport')),
    );
    final finger = field.topLeft + Offset(field.width / 2, field.height * .7);
    final gesture = await tester.startGesture(finger);
    await run(tester, g, 60);
    final scale = field.width / 420;
    final cat = field.topLeft + (g.position - g.camera) * scale;
    expect(cat.dx, closeTo(finger.dx, 2));
    expect(
      finger.dy - cat.dy,
      closeTo(ControlPreferences.followLift * scale, 2),
      reason: 'the cat flies clearly above the thumb',
    );
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets('drag steering moves as far as the finger and stops dead', (
    tester,
  ) async {
    final (p, g) = await setUpBattle(tester, follow: false);
    final field = tester.getRect(
      find.byKey(const Key('battle-playing-viewport')),
    );
    final start = field.center;
    final gesture = await tester.startGesture(start);
    await run(tester, g, 2);
    final from = g.position;
    await gesture.moveBy(const Offset(-60, -40));
    await run(tester, g, 30);
    final moved = g.position - from;
    final expected =
        const Offset(-60, -40) * (420 / field.width) * p.controls.dragScale;
    expect(moved.dx, closeTo(expected.dx, 1));
    expect(moved.dy, closeTo(expected.dy, 1));
    // finger held still: the cat stays exactly there (no drift)
    final rest = g.position;
    await run(tester, g, 30);
    expect(g.position, rest);
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });
}
