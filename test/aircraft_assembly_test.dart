import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/art/aircraft_assembly_art.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/l10n/app_language.dart';
import 'package:shootingstar/ui/aircraft_design_screen.dart';

void main() {
  testWidgets(
    '320px modular design preserves mounts and never creates combat state',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await AppLanguage.instance.load();
      await t.runAsync(() async {
        await (FontLoader(
          'NotoSansKR',
        )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
        await AircraftAssemblyArt.load();
      });
      var base = AircraftAssembly.demo();
      expect(base.parts, hasLength(9));
      for (final hull in [0, 1, 2]) {
        final candidate = base.withHull(hull);
        final placements = AircraftAssemblyArt.placements(candidate);
        expect(placements, hasLength(11));
        expect(
          placements.where((p) => p.mount == AircraftMount.wings),
          hasLength(2),
        );
        expect(
          placements.where((p) => p.mount == AircraftMount.armor),
          hasLength(2),
        );
        expect(candidate.parts, base.parts);
        for (final part in aircraftParts) {
          final r = AircraftAssemblyArt.partRect(part);
          expect(r.width, greaterThan(1));
          expect(r.height, greaterThan(1));
          expect(
            r.right,
            lessThanOrEqualTo(AircraftAssemblyArt.modules!.width),
          );
        }
      }
      expect(aircraftPart('bomb').targets, {AircraftTarget.ground});
      expect(aircraftPart('cannon').targets, {AircraftTarget.air});
      for (final id in ['repair', 'capacitor', 'ward']) {
        expect(aircraftPart(id).attacks, isFalse);
      }
      expect(() => base.equip(AircraftMount.main, 'bomb'), throwsArgumentError);
      expect(
        () => base.equip(AircraftMount.supportRight, 'repair'),
        throwsArgumentError,
      );
      await t.pumpWidget(
        LanguageScope(
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'NotoSansKR',
              ),
            ),
            home: const AircraftDesignScreen(),
          ),
        ),
      );
      // The decoded asset future was completed in the real IO zone.
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pumpAndSettle();
      AircraftAssembly current() => t
          .widget<AircraftAssemblyView>(
            find.byKey(const Key('assembly-preview')),
          )
          .assembly;
      Future<void> tap(String key) async {
        await t.ensureVisible(find.byKey(ValueKey(key)));
        await t.pumpAndSettle();
        await t.tap(find.byKey(ValueKey(key)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }

      expect(current().hull, 0);
      await tap('assembly-hull-1');
      expect(current().hull, 1);
      expect(current().parts, base.parts);
      await tap('assembly-category-1');
      for (var i = 0; i < 5; i++) {
        await tap('assembly-weapon-$i');
      }
      await tap('assembly-part-empty');
      expect(current().parts[AircraftMount.ground], isNull);
      await tap('assembly-part-bomb');
      expect(current().parts[AircraftMount.ground], 'bomb');
      await tap('assembly-weapon-1');
      await tap('assembly-part-auxShield');
      expect(current().parts[AircraftMount.auxiliary], 'auxShield');
      await tap('assembly-category-2');
      await tap('assembly-part-reinforce');
      expect(current().parts[AircraftMount.armor], 'reinforce');
      await tap('assembly-category-3');
      await tap('assembly-support-2');
      await tap('assembly-part-empty');
      expect(current().parts[AircraftMount.supportRear], isNull);
      await tap('assembly-part-ward');
      AppLanguage.instance.select('en');
      await t.pumpAndSettle();
      expect(find.text('Aircraft design'), findsOneWidget);
      expect(find.text('Ward pod'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.byTooltip('Remove all parts'));
      await t.pumpAndSettle();
      expect(current().parts, isEmpty);
      expect(current().hull, 1);
      // Preview writes no assembly/loadout/currency keys to persistence.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key != AppLanguage.storageKey),
        isEmpty,
      );
      AppLanguage.instance.select('ko');
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    '320px live assembly saves changes and respects ownership and mandatory cannon',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final profile = await Profile.load();
      await t.runAsync(() async {
        await AircraftAssemblyArt.load();
      });
      await t.pumpWidget(
        LanguageScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: AircraftDesignScreen(profile: profile),
          ),
        ),
      );
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pumpAndSettle();
      Future<void> tap(String key) async {
        await t.ensureVisible(find.byKey(ValueKey(key)));
        await t.pumpAndSettle();
        await t.tap(find.byKey(ValueKey(key)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }

      await tap('assembly-hull-1');
      expect(profile.selectedShip, 0);
      await tap('assembly-category-1');
      await tap('assembly-weapon-0');
      await tap('assembly-part-empty');
      expect(profile.aircraftAssembly.parts[AircraftMount.main], 'cannon');
      await tap('assembly-weapon-1');
      await tap('assembly-part-auxShield');
      expect(
        profile.aircraftAssembly.parts[AircraftMount.auxiliary],
        'auxShield',
      );
      await tap('assembly-category-3');
      await tap('assembly-support-2');
      await tap('assembly-part-ward');
      expect(profile.aircraftAssembly.parts.values.contains('ward'), false);
      await t.runAsync(() async {
        await profile.save();
        final restored = await Profile.load();
        expect(
          restored.aircraftAssembly.toJson(),
          profile.aircraftAssembly.toJson(),
        );
      });
      expect(find.text('자동 저장 · 다음 출격에 적용'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
