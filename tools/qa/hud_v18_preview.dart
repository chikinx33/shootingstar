// Compact HUD presentation fixtures; production does not read these URL parameters.
import 'package:flutter/material.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart' show ShootingstarApp;
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/ui/developer_screen.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/developer_battle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  final p = await Profile.load();
  await p.restoreDeveloperSession();
  runApp(_Preview(p));
}

class _Preview extends StatelessWidget {
  const _Preview(this.profile);
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    final app = ShootingstarApp(profile: profile).build(context) as MaterialApp;
    final q = Uri.base.queryParameters, scene = q['scene'];
    final config = DeveloperBattleConfig()
      ..invincible = true
      ..autoChoose = true;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: app.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            double.tryParse(q['textScale'] ?? '') ?? 1.3,
          ),
        ),
        child: Builder(builder: (context) => app.builder!(context, child)),
      ),
      home: scene == null
          ? DeveloperSessionHost(profile: profile)
          : BattleScreen(
              profile: profile,
              developerConfig: config,
              engineFactory: () => _fixture(scene, q),
            ),
    );
  }

  GameEngine _fixture(String scene, Map<String, String> q) {
    final g = GameEngine(
      stageIndex: int.tryParse(q['world'] ?? '') ?? 0,
      shipIndex: 0,
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: 0,
      armament: q['weapon'] ?? 'pulse',
      seed: 623,
      pilot: 'yang',
      petKind: 0,
      petLevel: 5,
    );
    g.developerInvincible = true;
    g.level = 60;
    g.xpNeeded = 999999;
    g.mainRate = 3;
    g.mainPower = 3;
    g.mainCount = 2;
    if (scene == 'hud' || scene == 'boss') {
      g.mainBranch = MainBranch.pulseFocus;
      g.evolved.add('missile');
      g.upgrades.addAll({
        'missile': 5,
        'guardian': 3,
        'drone': 3,
        'ball': 3,
        'laser': 3,
        'mine': 3,
      });
      g.passives.addAll({
        'attack': 2,
        'hull': 2,
        'magnet': 2,
        'speed': 2,
        'cooldown': 2,
        'armor': 2,
      });
    }
    if (scene == 'evolution') {
      g.upgrades['missile'] = 5;
      g.passives['area'] = 1;
      g.choices = [
        const UpgradeChoice('missile', '', '', 'missile', evolution: true),
      ];
      g.chooseUpgrade('missile');
    }
    if (scene == 'boss') {
      g.developerPrepare(scene: 1, phase: int.tryParse(q['phase'] ?? '') ?? 0);
      if (g.boss != null) {
        g.boss!.hp *= 100;
        g.boss!.maxHp *= 100;
      }
    } else {
      g.developerPrepare(
        scene: scene == 'assault'
            ? 3
            : scene == 'shield'
            ? 2
            : 6,
        enemyCount: scene == 'stress' ? 200 : 50,
        shotCount: scene == 'stress' ? 500 : 0,
        sparkCount: 0,
        ultimateReady: true,
        supplyKind: scene == 'heal'
            ? 0
            : scene == 'magnet'
            ? 1
            : -1,
      );
      // Durable targets let normal weapon/skill timers produce readable effects.
      for (final e in g.enemies) {
        e.hp = e.maxHp = 500;
      }
    }
    return g;
  }
}
