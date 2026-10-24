// Separate accessibility preview. Production never reads these URL parameters.
import 'package:flutter/material.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart' show ShootingstarApp;
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/ui/developer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  final profile = await Profile.load();
  await profile.restoreDeveloperSession();
  runApp(_Preview(profile));
}

class _Preview extends StatelessWidget {
  const _Preview(this.profile);
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    final app = ShootingstarApp(profile: profile).build(context) as MaterialApp;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: app.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            double.tryParse(Uri.base.queryParameters['textScale'] ?? '') ?? 1.3,
          ),
        ),
        child: Builder(builder: (context) => app.builder!(context, child)),
      ),
      home: DeveloperSessionHost(profile: profile),
    );
  }
}
