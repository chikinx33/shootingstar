import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/content_catalog.dart';
import 'package:shootingstar/data/gear_traits.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/combat_cues.dart';

// v12.6: the lobby no longer shows an aircraft or armament buttons, and the
// old LobbyAircraft eye/slot overlay now only wraps ModuleAircraftPreview,
// whose sockets are covered by ship_modules_test.dart.
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
}
