import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/account_screen.dart';
import 'package:shootingstar/ui/collection_screen.dart';
import 'package:shootingstar/ui/content_hub.dart';
import 'package:shootingstar/ui/control_settings_screen.dart';
import 'package:shootingstar/ui/delete_account_screen.dart';
import 'package:shootingstar/ui/guild_screen.dart';
import 'package:shootingstar/ui/module_workshop.dart';
import 'package:shootingstar/ui/pet_bond_screen.dart';
import 'package:shootingstar/ui/progress_backup_screen.dart';
import 'package:shootingstar/ui/settings_screen.dart';
import 'package:shootingstar/ui/storage_help_screen.dart';
import 'package:shootingstar/ui/supporter_screen.dart';

void main() {
  final screens = <String, Widget Function(Profile)>{
    'Account': (p) => AccountScreen(profile: p),
    'Collection': (p) => CollectionScreen(profile: p),
    'ContentHub0': (p) => ContentHub(profile: p),
    'ContentHub1': (p) => ContentHub(profile: p, initialPage: 1),
    'ContentHub2': (p) => ContentHub(profile: p, initialPage: 2),
    'ContentHub3': (p) => ContentHub(profile: p, initialPage: 3),
    'ControlSettings': (p) => ControlSettingsScreen(profile: p),
    'DeleteAccount': (p) => DeleteAccountScreen(profile: p),
    'Guild': (p) => GuildScreen(profile: p),
    'ModuleWorkshop': (p) => ModuleWorkshop(profile: p, embedded: true),
    'PetBond': (p) => PetBondScreen(profile: p, pet: 0),
    'ProgressBackup': (p) => ProgressBackupScreen(profile: p),
    'Settings': (p) => FlightSettings(profile: p),
    'StorageHelp': (p) => StorageHelpScreen(profile: p),
    'Supporter': (p) => SupporterScreen(profile: p),
  };
  // v12.4.3 (user 2026-10-25): lobby screens fit one page on a phone; long
  // rules and descriptions open in popups instead of page arrows/scrolling.
  for (final (w, h) in const [(360.0, 720.0), (390.0, 844.0)]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits one page at $w x $h', (tester) async {
        tester.view.physicalSize = Size(w, h);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        p.soundEnabled = false;
        p.reducedEffects = true;
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: entry.value(p))),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('game-page-next')),
          findsNothing,
          reason: '${entry.key} must not split into pages',
        );
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      });
    }
  }
}
