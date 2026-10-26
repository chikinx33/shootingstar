import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/l10n/app_language.dart';
import 'package:shootingstar/ui/item_slots.dart';
import 'package:shootingstar/ui/module_workshop.dart';

void main() {
  testWidgets('assembly parts survive hull swaps and keep mount rules', (
    t,
  ) async {
    var base = AircraftAssembly.demo();
    expect(base.parts, hasLength(9));
    for (final hull in [0, 1, 2]) {
      final candidate = base.withHull(hull);
      expect(candidate.parts, base.parts);
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
  });
  testWidgets('320px module workshop opens without saving', (t) async {
    // v12.11: the live hangar edits module slots (W1/W2/W3/S1).
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final profile = await Profile.load();
    final before = jsonEncode(profile.exportProgress());
    await t.pumpWidget(
      LanguageScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: ModuleWorkshop(profile: profile),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(GameItemSlot), findsNWidgets(moduleProfiles.length));
    for (final mount in moduleProfiles) {
      expect(find.bySemanticsLabel('${mount.id} 모듈 편집'), findsOneWidget);
    }
    expect(jsonEncode(profile.exportProgress()), before);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    profile.dispose();
  });
}
