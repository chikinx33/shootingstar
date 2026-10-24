// Real production screens, isolated profile and read-only clock telemetry.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart' show ShootingstarApp;
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/ui/developer_screen.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/game/engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  final normal = await Profile.load();
  normal.soundEnabled = false;
  runApp(_Preview(Profile.developerCopy(normal)));
}

class _Preview extends StatefulWidget {
  const _Preview(this.p);
  final Profile p;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  Timer? timer;
  final g =
      GameEngine(
          stageIndex: 0,
          shipIndex: 0,
          attackLevel: 0,
          hullLevel: 0,
          magnetLevel: 0,
          equipmentIndex: 0,
          seed: 623,
        )
        ..developerInvincible = true
        ..xpNeeded = 1e9;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app =
        ShootingstarApp(profile: widget.p).build(context) as MaterialApp;
    final q = Uri.base.queryParameters;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: app.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            double.tryParse(q['textScale'] ?? '1') ?? 1,
          ),
        ),
        child: Builder(builder: (context) => app.builder!(context, child)),
      ),
      home: q['scene'] == 'flight'
          ? Stack(
              children: [
                BattleScreen(profile: widget.p, engineFactory: () => g),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Semantics(
                    container: true,
                    label:
                        'QA_STATE ${jsonEncode({'elapsed': g.elapsed, 'paused': g.paused, 'x': g.position.dx, 'y': g.position.dy})}',
                    child: const SizedBox(width: 1, height: 1),
                  ),
                ),
              ],
            )
          : DeveloperTestScreen(profile: widget.p),
    );
  }
}
