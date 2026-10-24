import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/battle_painter.dart';
import 'package:shootingstar/game/combat_cues.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/presentation_replay.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/developer_screen.dart';
import 'package:shootingstar/ui/presentation_replay_screen.dart';

import 'ui_actions.dart';

const added = [
  PresentationReplay.damage,
  PresentationReplay.evolution,
  PresentationReplay.ultimate,
  PresentationReplay.shieldCounter,
];
Future<void> frames(WidgetTester t, int count) async {
  for (var i = 0; i < count; i++) {
    await t.pump(const Duration(milliseconds: 25));
  }
}

GameEngine paintedGame(WidgetTester t) => t
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<BattlePainter>()
    .last
    .game;

class Seen {
  bool hit = false,
      evolution = false,
      ultimate = false,
      block = false,
      armed = false,
      counterVolley = false;
  void sample(GameEngine g) {
    hit |= g.hp < g.maxHp && g.hurtFlash > 0;
    evolution |=
        g.evolved.contains('missile') &&
        g.visuals.active.any(
          (c) => c.kind == CombatCueKind.evolution && c.source == 'missile',
        );
    ultimate |=
        g.ultimateRemaining > 0 &&
        (g.damageByWeapon['common-ultimate'] ?? 0) > 0;
    block |= g.visuals.active.any((c) => c.kind == CombatCueKind.shield);
    armed |= g.shieldCounterPending;
    counterVolley |= g.shots.any(
      (s) => s.kind == 0 && (s.damage - 17 * g.damageFactor * 1.5).abs() < .001,
    );
  }

  void verify(PresentationReplay kind, GameEngine g) {
    switch (kind) {
      case PresentationReplay.damage:
        expect(hit, true);
        expect(g.hp, greaterThan(0));
      case PresentationReplay.evolution:
        expect(evolution, true);
        expect(g.chests, 1);
        expect(g.choices, isEmpty);
      case PresentationReplay.ultimate:
        expect(ultimate, true);
      case PresentationReplay.shieldCounter:
        expect(block && armed && counterVolley, true);
        expect(g.synergyTriggers('shield-counter'), 1);
        expect(g.shieldCounterPending, false);
      default:
        fail('Unexpected replay');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  for (final kind in added) {
    test(
      'real ${kind.name} path is isolated from source progression',
      () async {
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        final before = jsonEncode(p.exportProgress());
        final g = buildPresentationReplay(p, kind);
        triggerPresentationReplay(g, kind);
        final seen = Seen()..sample(g);
        for (var i = 0; i < 70; i++) {
          g.update(.025);
          seen.sample(g);
        }
        seen.verify(kind, g);
        expect(jsonEncode(p.exportProgress()), before);
        p.dispose();
      },
    );
  }
  testWidgets('pending replay waits for resume and cancels on exit', (t) async {
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.soundEnabled = false;
    final app = ShootingstarApp(
      profile: p,
    ).build(t.element(find.byType(View).first)) as MaterialApp;
    await t.pumpWidget(
      MaterialApp(
        theme: app.theme,
        home: PresentationReplayScreen(
          source: p,
          kind: PresentationReplay.ultimate,
        ),
      ),
    );
    await frames(t, 8);
    final g = paintedGame(t);
    g.setPaused(true);
    await frames(t, 40);
    expect(g.ultimateRemaining, 0);
    g.setPaused(false);
    await frames(t, 24);
    expect(g.ultimateRemaining, greaterThan(0));
    await t.pumpWidget(
      MaterialApp(
        theme: app.theme,
        home: PresentationReplayScreen(
          source: p,
          kind: PresentationReplay.evolution,
        ),
      ),
    );
    await frames(t, 2);
    final abandoned = paintedGame(t);
    await t.pumpWidget(const SizedBox());
    await frames(t, 40);
    expect(abandoned.supplies, isEmpty);
    expect(abandoned.evolved, isEmpty);
    expect(t.takeException(), isNull);
    p.dispose();
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('new four replays, restart and both saves $size / $scale', (
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
            devRaw = prefs.getString(Profile.developerStorageKey),
            before = jsonEncode(dev.exportProgress()),
            config = jsonEncode(dev.developerSettings['battle']);
        for (final kind in added) {
          final slot = find.byKey(ValueKey('replay-${kind.name}'));
          await revealUi(t, slot);
          expect(t.getSize(slot).width, lessThan(size.width / 2));
          await t.tap(slot);
          await frames(t, 16);
          var g = paintedGame(t);
          expect(
            t
                .widget<BattleScreen>(find.byType(BattleScreen))
                .presentationAutoplay,
            true,
          );
          expect(
            g.hp,
            g.maxHp,
          ); // no short effect hidden during route transition
          expect(g.evolved, isEmpty);
          final seen = Seen();
          for (var i = 0; i < 80; i++) {
            await frames(t, 1);
            seen.sample(g);
          }
          seen.verify(kind, g);
          expect(g.combatTime, greaterThan(1)); // no hold needed
          expect(t.takeException(), isNull, reason: kind.name);
          await t.tap(find.byKey(const Key('replay-again')));
          await frames(t, 16);
          final fresh = paintedGame(t);
          expect(identical(fresh, g), false);
          expect(fresh.evolved, isEmpty);
          final again = Seen();
          for (var i = 0; i < 80; i++) {
            await frames(t, 1);
            again.sample(fresh);
          }
          again.verify(kind, fresh);
          await t.tap(find.byTooltip('테스트로 돌아가기'));
          await t.pumpAndSettle();
          expect(find.byKey(const Key('presentation-replays')), findsOneWidget);
          expect(jsonEncode(dev.exportProgress()), before);
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
