// Production-entrypoint resume fixtures; never writes a real user's storage.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/game/engine.dart';
import '../../test/support/run_driver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export an acquired starter boss run and isolated mine encounter', () async {
    final out = Directory('.local/run-v62/web-fixtures')..createSync(recursive:true);
    for (final world in [0,5]) {
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.onboarded = true;
      p.selectedStage = world * 10;
      if (world > 0) p.clearedStages.addAll(List.generate(world*10, (i)=>i));
      final g = GameEngine(stageIndex: world*10, shipIndex:0,
        aircraft: AircraftAssembly.initial(0), attackLevel:0, hullLevel:0,
        magnetLevel:0, equipmentIndex:0, seed:11);
      if (world == 0) {
        for (var i=0; i<16000 && g.boss==null && !g.finished; i++) {
          if (g.choices.isNotEmpty) {
            final choices=g.choices.toList()..sort((a,b)=>choiceScore(g,b).compareTo(choiceScore(g,a)));
            g.chooseUpgrade(choices.first.id);
          }
          g.input=steer(g);
          g.update(.025);
        }
        expect(g.boss, isNotNull);
        expect(g.level, inInclusiveRange(8,14));
      } else {
        // Isolated geometry fixture, not a claim of acquiring a late-game build.
        g.elapsed=g.nextBossAt;
        g.update(.025);
      }
      expect(g.developerInvincible, false);
      expect(await p.checkpointBattle('qa-v62-$world', g), true);
      final prefs=await SharedPreferences.getInstance();
      final raw=jsonDecode(prefs.getString(Profile.storageKey)!);
      File('${out.path}/world-$world.json').writeAsStringSync(jsonEncode(raw));
      p.dispose();
    }
  });
}
