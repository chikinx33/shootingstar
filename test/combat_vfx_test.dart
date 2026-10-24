import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/combat_cues.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/data/combat_loadout.dart';
import 'package:shootingstar/game/battle_painter.dart';

GameEngine game(String armament) => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  armament: armament,
  seed: 623,
);
void main() {
  test('bounded cues expire and cannot alter combat RNG/results', () {
    for (final a in armaments.map((a) => a.id)) {
      final on = game(a), off = game(a)..visuals.enabled = false;
      for (var frame = 0; frame < 1200; frame++) {
        for (final g in [on, off]) {
          if (g.choices.isNotEmpty) g.chooseUpgrade(g.choices.first.id);
          g.update(.025);
        }
        expect(on.hp, off.hp);
        expect(on.kills, off.kills);
        expect(on.xp, off.xp);
        expect(on.shots.length, off.shots.length);
        expect(on.enemies.length, off.enemies.length);
        expect(on.visuals.active.length, lessThanOrEqualTo(CombatCues.limit));
      }
      expect(on.random.nextDouble(), off.random.nextDouble());
    }
  });
  test(
    'all cues and reduced effects paint without advancing simulation',
    () async {
      final g = game('pulse');
      for (final kind in CombatCueKind.values)
        g.visuals.emit(
          kind,
          g.position,
          from: g.position - const Offset(70, 100),
          amount: 32,
          radius: 50,
        );
      for (final reduced in [false, true]) {
        final recorder = PictureRecorder(), canvas = Canvas(recorder);
        BattlePainter(
          g,
          reducedEffects: reduced,
        ).paint(canvas, const Size(420, 720));
        final picture = recorder.endRecording(),
            image = await picture.toImage(420, 720);
        expect((await image.toByteData())!.lengthInBytes, greaterThan(0));
        image.dispose();
        picture.dispose();
      }
      final age = g.visuals.active.first.age;
      g.setPaused(true);
      g.update(.05);
      expect(g.visuals.active.first.age, age);
      g.setPaused(false);
      g.visuals.advance(2);
      expect(g.visuals.active, isEmpty);
    },
  );
}
