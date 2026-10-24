// Isolated mobile layout fixture. No production account, billing or ad SDK.
import 'package:flutter/material.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/supporter_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  final p = await Profile.load();
  runApp(_Preview(p));
}

class _Preview extends StatelessWidget {
  const _Preview(this.p);
  final Profile p;
  @override
  Widget build(BuildContext context) {
    final app = ShootingstarApp(profile: p).build(context) as MaterialApp;
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
      home: SupporterScreen(profile: p),
    );
  }
}
