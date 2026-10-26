import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/game/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fired mounts recoil against their own shots then settle without moving the pilot or saving visual state', () {
    final g =
        GameEngine(
            stageIndex: 0,
            shipIndex: 0,
            attackLevel: 0,
            hullLevel: 0,
            magnetLevel: 0,
            equipmentIndex: 0,
            seed: 72,
            aircraft: AircraftAssembly.demo().withGear(const [
              0,
              2,
              4,
              6,
              8,
              10,
            ]),
          )
          ..xpNeeded = 1e8
          ..developerInvincible = true;
    for (final delta in [
      const ui.Offset(-210, 0),
      const ui.Offset(210, 0),
      const ui.Offset(0, 210),
    ]) {
      g.enemies.add(Foe(g.position + delta, 10000, 0, 10, 0));
    }
    g.enemies.add(
      Foe(
        g.position + const ui.Offset(0, 140),
        10000,
        0,
        10,
        0,
        plane: AircraftTarget.ground,
      ),
    );
    final pilotPosition = g.position;
    g.update(.001);
    final directions = <String, ui.Offset>{
      for (final name in ['main', 'auxiliary', 'rear'])
        name: g.shots.firstWhere((s) => s.weapon == 'module-$name').velocity,
      'wings': g.shots
          .firstWhere((s) => s.weapon == 'module-wings' && s.velocity.dx < 0)
          .velocity,
      'wings-right': g.shots
          .firstWhere((s) => s.weapon == 'module-wings' && s.velocity.dx > 0)
          .velocity,
    };
    g.update(.025);
    for (final e in directions.entries) {
      final kick = g.visuals.recoil(e.key);
      expect(kick.distance, greaterThan(0), reason: e.key);
      expect(
        kick.dx * e.value.dx + kick.dy * e.value.dy,
        lessThan(0),
        reason: e.key,
      );
    }
    expect(g.visuals.recoil('ground').dy, greaterThan(0));
    expect(g.visuals.recoil('supportLeft'), ui.Offset.zero);
    expect(g.position, pilotPosition);
    final peak = g.visuals.recoil('main');
    g.paused = true;
    g.update(.3);
    expect(g.visuals.recoil('main'), peak);
    g.paused = false;
    for (var i = 0; i < 7; i++) {
      g.update(.025);
    }
    expect(g.visuals.recoil('main'), ui.Offset.zero);
    final saved = jsonEncode(g.checkpoint());
    g.visuals.kick('main', const ui.Offset(0, 6));
    expect(jsonEncode(g.checkpoint()), saved);
    g.visuals.advance(.025);
    g.visuals.enabled = false;
    expect(g.visuals.recoil('main'), ui.Offset.zero);
  });
}
