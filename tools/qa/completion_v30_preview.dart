// QA origin only: production widgets and real file picker/download, no account.
import 'package:flutter/material.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/home.dart';
import 'package:shootingstar/ui/progress_backup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  final profile = await Profile.load();
  profile.soundEnabled = false;
  profile.onboarded = true;
  runApp(_Preview(profile));
}

class _Preview extends StatelessWidget {
  const _Preview(this.profile);
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    final app = ShootingstarApp(profile: profile).build(context) as MaterialApp;
    return MaterialApp(
      theme: app.theme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            double.tryParse(Uri.base.queryParameters['scale'] ?? '1') ?? 1,
          ),
        ),
        child: app.builder!(context, child),
      ),
      home: switch (Uri.base.queryParameters['mode']) {
        'backup' => ProgressBackupScreen(profile: profile),
        'battle' => BattleScreen(profile: profile),
        _ => HomeScreen(profile: profile),
      },
    );
  }
}
