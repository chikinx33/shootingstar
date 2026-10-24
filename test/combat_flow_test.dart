import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/battle_painter.dart';
import 'package:shootingstar/game/survival_skills.dart';
import 'package:shootingstar/ui/battle.dart';

GameEngine createGame({int seed = 4, int stage = 0}) => GameEngine(
  stageIndex: stage,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: seed,
);

void main() {
  test(
    'skill selection gives a short contact grace period, then damage returns',
    () {
      final g = createGame()..xp = 18;
      g.update(.01);
      g.chooseUpgrade(g.choices.first.id);
      final hp = g.hp;
      final foe = Foe(g.position, 100000, 0, 20, 0);
      g.enemies.add(foe);
      for (int i = 0; i < 10; i++) {
        foe.position = g.position;
        g.update(.05);
      }
      expect(g.hp, hp);
      for (int i = 0; i < 10; i++) {
        foe.position = g.position;
        g.update(.05);
      }
      expect(g.hp, lessThan(hp));
    },
  );
  test(
    'chapter phases change density and formation with every spawn offscreen',
    () {
      final counts = <int>[];
      final labels = <String>{};
      for (final time in [1.0, 36.0, 72.0, 108.0, 144.0, 171.0]) {
        final g = createGame()..elapsed = time;
        g.viewportHeight = 1100;
        g.update(.01);
        labels.add(g.waveLabel);
        counts.add(g.enemies.length);
        for (final enemy in g.enemies) {
          final point = enemy.position - g.camera;
          expect(
            point.dx < 0 || point.dx > 420 || point.dy < 0 || point.dy > 1100,
            isTrue,
          );
        }
        if (g.encounter.grouped) {
          final sides = g.enemies.map((e) {
            final p = e.position - g.camera;
            return p.dy < 0
                ? 2
                : p.dy > 1100
                ? 3
                : p.dx < 0
                ? 0
                : 1;
          }).toSet();
          expect(sides.length, 1);
        }
      }
      expect(labels.length, 6);
      expect(counts[4], greaterThan(counts[0]));
      expect(counts[5], lessThan(counts[4]));
    },
  );
  test(
    'boss telegraph, crowd clear, stopped chapter clock, then next phase',
    () {
      final g = createGame(stage: 4);
      g.elapsed = g.nextBossAt - 2;
      expect(g.bossIncoming, isTrue);
      g.update(.01);
      expect(g.enemies, isEmpty);
      g.enemies.add(Foe(g.position + const Offset(120, 0), 100, 0, 11, 0));
      g.elapsed = g.nextBossAt;
      g.update(.01);
      expect(g.enemies.length, 1);
      expect(g.boss, isNotNull);
      final time = g.elapsed;
      final bossPosition = g.boss!.position;
      g.input = const Offset(1, 0);
      for (int i = 0; i < 20; i++) {
        g.update(.05);
      }
      expect(g.elapsed, time);
      expect(g.bossAim.distance, closeTo(1, .001));
      expect((g.boss!.position - bossPosition).distance, lessThan(4));
      expect(g.enemies.length, 1);
      g.shots.add(Shot(g.position + const Offset(180, 0), Offset.zero, 1, 4));
      g.boss!.hp = 0;
      g.update(.01);
      expect(g.supplies.any((s) => s.kind == 3), isTrue);
      expect(g.shots.any((s) => s.kind == 4), isFalse);
      for (var i = 0; i < 72; i++) {
        g.update(.05);
      }
      expect(g.elapsed, greaterThan(time));
    },
  );
  test('early random skill sets always include an attack option without duplicates', () {
    for (int seed = 0; seed < 80; seed++) {
      final g = createGame(seed: seed)..xp = 18;
      g.update(.01);
      expect(g.choices.length, 3);
      expect(g.choices.map((c) => c.id).toSet().length, 3);
      expect(
        g.choices.any((c) => c.specialization || !skillFor(c.id).passive),
        isTrue,
      );
    }
  });
  test('world hazard stays put when camera and player move', () {
    final g = createGame(stage: 1)..elapsed = 10;
    g.update(.01);
    final center = g.hazardCenter;
    g.input = const Offset(1, 0);
    for (int i = 0; i < 20; i++) {
      g.update(.05);
    }
    expect(g.hazardCenter, center);
    expect(g.position.dx, greaterThan(g.hazardCenter.dx));
  });
  testWidgets(
    'touch reverses after long drag, ignores second finger, freezes for skill choice',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.soundEnabled = false;
      await tester.pumpWidget(MaterialApp(home: BattleScreen(profile: p)));
      await tester.pump(const Duration(milliseconds: 50));
      final field = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BattlePainter,
      );
      final g =
          (tester.widget<CustomPaint>(field).painter! as BattlePainter).game;
      final finger = await tester.startGesture(
        const Offset(70, 650),
        pointer: 1,
      );
      await finger.moveTo(const Offset(310, 650));
      await tester.pump(const Duration(milliseconds: 50));
      expect(g.input.dx, greaterThan(.9));
      final other = await tester.startGesture(
        const Offset(120, 700),
        pointer: 2,
      );
      await other.moveTo(const Offset(40, 700));
      await other.up();
      expect(g.input.dx, greaterThan(.9));
      await finger.moveTo(const Offset(250, 650));
      await tester.pump(const Duration(milliseconds: 50));
      expect(g.input.dx, lessThan(0));
      g.crystals.addAll(List.filled(9, g.position));
      await tester.pump(const Duration(milliseconds: 50));
      expect(g.level, 2);
      expect(g.choices.length, 3);
      expect(g.input, Offset.zero);
      final time = g.elapsed, hp = g.hp;
      final position = g.position;
      await finger.moveTo(const Offset(100, 600));
      await finger.up();
      await tester.pump(const Duration(seconds: 2));
      expect(g.elapsed, time);
      expect(g.hp, hp);
      expect(g.position, position);
      final choice = g.choices.first.id;
      await tester.tap(find.byKey(Key('upgrade-$choice')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(g.choices, isEmpty);
      expect(g.input, Offset.zero);
      final next = await tester.startGesture(const Offset(100, 650));
      await next.moveTo(const Offset(145, 650));
      await tester.pump(const Duration(milliseconds: 50));
      expect(g.position.dx, greaterThan(position.dx));
      await next.cancel();
      expect(g.input, Offset.zero);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
