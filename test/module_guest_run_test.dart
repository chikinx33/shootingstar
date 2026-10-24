import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';

import 'module_campaign_run_test.dart' as run;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real fresh-profile launch configuration completes a natural stage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      final g = GameEngine(
        stageIndex: p.selectedStage,
        shipIndex: p.selectedShip,
        aircraft: p.aircraftAssembly,
        supportLevels: p.aircraftSupportLevels,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: p.magnetLevel,
        equipmentIndex: -1,
        gearDamage: p.pilotDamage,
        gearHull: p.pilotHull,
        armament: p.moduleLoadout.signature,
        armamentLevel: p.moduleLoadout.airframeLevel - 1,
        techRanks: p.battleTech,
        seed: 667,
      );
      final config = g.checkpoint()['config'];
      final result = run.campaignRun(
        0,
        1,
        'actual-fresh-profile',
        667,
        true,
        game: g,
      );
      Directory('.local/module-v69').createSync(recursive: true);
      File('.local/module-v69/fresh-profile.json')
          .writeAsStringSync(jsonEncode({'config': config, 'result': result}));
      print('FRESH ${jsonEncode(result)}');
      expect(result['victory'], isTrue);
      expect(result['bossesDefeated'], 1);
      p.dispose();
    },
  );
}
