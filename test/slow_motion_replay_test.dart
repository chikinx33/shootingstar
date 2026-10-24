import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/battle_painter.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/developer_screen.dart';
import 'package:shootingstar/ui/presentation_replay_screen.dart';
import 'package:shootingstar/ui/reward_popup.dart';

import 'ui_actions.dart';

GameEngine arena() => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 623,
)..developerInvincible = true;
Future<void> frames(WidgetTester t, int count) async {
  for (var i = 0; i < count; i++) {
    await t.pump(const Duration(milliseconds: 25));
  }
}

GameEngine paintedGame(WidgetTester t) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<BattlePainter>()
    .first
    .game;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  test(
    'slow simulation scales hostile projectiles and encounter time together',
    () {
      final g = arena()..xpNeeded = 1e9;
      final shot = Shot(
        g.position + const Offset(100, -100),
        const Offset(0, 100),
        1,
        4,
        life: 5,
      );
      final before = shot.position;
      g.shots.add(shot);
      for (var i = 0; i < 40; i++) {
        g.update(.025 * .05, presentationDelta: .025);
      }
      expect(g.elapsed, closeTo(.05, 1e-8));
      expect(shot.position.dy - before.dy, closeTo(5, 1e-8));
    },
  );
  test(
    'magnet and boss resolution use real presentation time during slow flight',
    () {
      final g = arena()..xpNeeded = 1e9;
      g.crystals.addAll(
        List.generate(20, (i) => g.position + Offset(i * 12, -160)),
      );
      g.supplies.add(Supply(g.position, 1));
      for (var i = 0; i < 70; i++) {
        g.update(.025 * .05, presentationDelta: .025);
      }
      expect(g.absorbingCrystals, isEmpty);
      expect(g.xp, 40);
      expect(g.elapsed, lessThan(.1));
      g.elapsed = g.nextBossAt;
      g.update(.001);
      g.boss!.hp = 0;
      g.update(.001);
      for (var i = 0; i < 220; i++) {
        g.update(.025 * .05, presentationDelta: .025);
      }
      expect(g.finished, true);
      expect(g.victory, true);
    },
  );
  testWidgets(
    'hold, release, leave, cancel, keyboard and background respect clocks',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.soundEnabled = false;
      final g = arena()..xpNeeded = 1e9;
      final app = ShootingstarApp(
        profile: p,
      ).build(t.element(find.byType(View).first)) as MaterialApp;
      await t.pumpWidget(
        MaterialApp(
          theme: app.theme,
          home: BattleScreen(profile: p, engineFactory: () => g),
        ),
      );
      await frames(t, 16);
      final idle = g.elapsed;
      expect(idle, lessThan(.03));
      final field = t.getRect(find.byKey(const Key('battle-touch-field')));
      final finger = await t.startGesture(field.center);
      await frames(t, 16);
      final held = g.elapsed - idle;
      expect(held, greaterThan(.35));
      await finger.up();
      await frames(t, 16);
      expect(g.elapsed - idle - held, lessThan(.03));
      final outside = await t.startGesture(field.center);
      await frames(t, 2);
      await outside.moveTo(const Offset(0, 0));
      final leftAt = g.elapsed;
      await frames(t, 16);
      expect(g.elapsed - leftAt, greaterThan(.35));
      expect(g.input.distance, greaterThan(0));
      await outside.moveTo(field.center);
      final returnedAt = g.elapsed;
      await frames(t, 8);
      expect(g.elapsed - returnedAt, greaterThan(.17));
      await outside.cancel();
      final cancelledAt = g.elapsed;
      await frames(t, 8);
      expect(g.elapsed - cancelledAt, lessThan(.015));
      await t.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      final keyAt = g.elapsed;
      await frames(t, 16);
      expect(g.elapsed - keyAt, greaterThan(.35));
      await t.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      t.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      final paused = g.elapsed;
      await frames(t, 16);
      expect(g.elapsed, paused);
      expect(g.paused, true);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('four instant replays preserve both saves $size / $scale', (
        t,
      ) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final normal = await Profile.load();
        normal.soundEnabled = false;
        await normal.save();
        final dev = await normal.startDeveloperSession();
        dev.soundEnabled = false;
        dev.developerSettings = {
          'battle': {'level': 37, 'speed': 4},
          'ui': {'group': 0, 'menu': 0},
        };
        final app = ShootingstarApp(
          profile: dev,
        ).build(t.element(find.byType(View).first)) as MaterialApp;
        await t.pumpWidget(
          MaterialApp(
            theme: app.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: DeveloperTestScreen(profile: dev),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('developer-presentations')));
        await t.pumpAndSettle();
        await dev.save();
        final prefs = await SharedPreferences.getInstance();
        final normalRaw = prefs.getString(Profile.storageKey),
            devRaw = prefs.getString(Profile.developerStorageKey);
        final source = jsonEncode(dev.exportProgress()),
            config = jsonEncode(dev.developerSettings['battle']);
        for (final kind in ['magnet', 'boss', 'reward', 'purchase']) {
          final slot = find.byKey(ValueKey('replay-$kind'));
          await t.ensureVisible(slot);
          final rect = t.getRect(slot);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          await t.tap(slot);
          await frames(t, 16);
          expect(find.byType(PresentationReplayScreen), findsOneWidget);
          if (kind == 'magnet') {
            final g = paintedGame(t);
            expect(g.collectingMagnet, true);
            await frames(t, 65);
            expect(g.choices, isNotEmpty);
            expect(g.absorbingCrystals, isEmpty);
          } else if (kind == 'boss') {
            final g = paintedGame(t);
            expect(g.resolvingBoss, true);
            await frames(t, 220);
            expect(g.finished, true);
            expect(g.victory, true);
          } else {
            expect(find.byType(RewardPopup), findsOneWidget);
            if (kind == 'reward') expect(find.text('×120'), findsOneWidget);
            await revealUi(t, find.text('확인'));
            await t.tap(find.text('확인'));
            await frames(t, 16);
            expect(
              find.byKey(const Key('reward-flight-layer')),
              findsOneWidget,
            );
          }
          expect(t.takeException(), isNull, reason: 'replay $kind');
          await t.tap(find.byTooltip('테스트로 돌아가기'));
          await t.pumpAndSettle();
          expect(find.byKey(const Key('presentation-replays')), findsOneWidget);
          expect(jsonEncode(dev.exportProgress()), source);
          expect(jsonEncode(dev.developerSettings['battle']), config);
          expect(prefs.getString(Profile.storageKey), normalRaw);
          expect(prefs.getString(Profile.developerStorageKey), devRaw);
        }
        await t.pumpWidget(const SizedBox());
        normal.dispose();
        dev.dispose();
      });
    }
  }
}
