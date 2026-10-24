import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/l10n/app_language.dart';
import 'package:shootingstar/ui/battle_hud.dart';

void main() {
  testWidgets(
    '320px HUD keeps physical modular mounts in the on-demand details',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final g = GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        aircraft: AircraftAssembly.initial(0),
      );
      await t.pumpWidget(
        LanguageScope(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: BattleHud(
                  game: g,
                  title: '항로1-1',
                  timer: '00:00 / 03:00',
                  onPause: () {},
                  onDetails: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(find.byKey(const ValueKey('combat-module-main')), findsNothing);
      expect(t.getSize(find.byType(BattleHud)).height, lessThan(90));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: BattleLoadoutDetails(game: g),
            ),
          ),
        ),
      );
      for (final mount in const [
        AircraftMount.main,
        AircraftMount.auxiliary,
        AircraftMount.wings,
        AircraftMount.rear,
        AircraftMount.ground,
        AircraftMount.armor,
      ]) {
        expect(
          find.byKey(ValueKey('combat-module-${mount.name}')),
          findsOneWidget,
        );
      }
      expect(t.takeException(), isNull);
    },
  );
}
