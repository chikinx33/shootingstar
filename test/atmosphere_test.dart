import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

void main() {
  test(
    'cloud clock drifts during boss battle but freezes for pause and choices',
    () {
      final game = GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 4,
      );
      game.enemies.add(
        Foe(game.position + const Offset(0, -300), 10000, 0, 34, 3),
      );
      game.update(.05);
      expect(game.elapsed, 0);
      expect(game.atmosphereTime, .05);
      game.setPaused(true);
      game.update(.05);
      expect(game.atmosphereTime, .05);
      game.setPaused(false);
      game.xp = game.xpNeeded;
      // Drafts open when a gem reaches the cat (v12.4.1).
      game.crystals.add(game.position);
      game.update(.05);
      expect(game.choices, isNotEmpty);
      final before = game.atmosphereTime;
      game.update(.05);
      expect(game.atmosphereTime, before);
      game.chooseUpgrade(game.choices.first.id);
      game.update(.05);
      expect(game.atmosphereTime, greaterThan(before));
    },
  );
}
