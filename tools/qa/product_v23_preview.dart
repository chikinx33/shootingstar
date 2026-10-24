// Isolated accessibility/render fixture. Production never reads these inputs.
import 'package:flutter/material.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/art/game_art.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart' show ShootingstarApp;
import 'package:shootingstar/ui/home.dart';
import 'package:shootingstar/ui/battle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  final source = await Profile.load();
  final p = Profile.presentationCopy(source)..soundEnabled = false;
  final world = int.tryParse(Uri.base.queryParameters['world'] ?? '');
  GameEngine? game;
  if (world != null) {
    await GameArt.loadBattle();
    game = GameEngine(
      stageIndex: world.clamp(0, 9) * 10,
      shipIndex: 0,
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: 0,
      seed: 23,
    )..developerInvincible = true;
    p.runs = 10; // World comparison is separate from the new-player coach.
  }
  runApp(_Preview(p, game));
}

class _Preview extends StatelessWidget {
  const _Preview(this.profile, this.game);
  final Profile profile;
  final GameEngine? game;
  @override
  Widget build(BuildContext context) {
    final app = ShootingstarApp(profile: profile).build(context) as MaterialApp;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: app.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            double.tryParse(Uri.base.queryParameters['textScale'] ?? '') ?? 1,
          ),
        ),
        child: Builder(builder: (context) => app.builder!(context, child)),
      ),
      home: game == null
          ? HomeScreen(profile: profile)
          : BattleScreen(profile: profile, engineFactory: () => game!),
    );
  }
}
