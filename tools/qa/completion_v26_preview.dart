// Isolated-origin integration fixture. Production never reads QA parameters.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/account_screen.dart';
import 'package:shootingstar/ui/campaign_selector.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/developer_battle.dart';
import 'package:shootingstar/ui/battle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  final p = await Profile.load();
  p.soundEnabled = false;
  p.reducedEffects = Uri.base.queryParameters['reduced'] == 'true';
  p.onboarded = true;
  p.clearedStages.addAll(List.generate(100, (i) => i));
  final mode = Uri.base.queryParameters['mode'];
  if (mode != 'world' && mode != 'stress') {
    final cloud = CloudSync(p);
    await cloud.initialize();
    await cloud.login(
      Uri.base.queryParameters['user']!,
      'qa-v26-password-only',
      nickname: '격리 검증',
    );
  }
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
            double.tryParse(Uri.base.queryParameters['textScale'] ?? '1') ?? 1,
          ),
        ),
        child: Builder(builder: (context) => app.builder!(context, child)),
      ),
      home: Uri.base.queryParameters['mode'] == 'world'
          ? Scaffold(body: CampaignSelector(profile: p))
          : Uri.base.queryParameters['mode'] == 'stress'
          ? _Stress(Profile.developerCopy(p)..selectedStage = 95)
          : AccountScreen(profile: p),
    );
  }
}

class _Stress extends StatefulWidget {
  const _Stress(this.p);
  final Profile p;
  @override
  State<_Stress> createState() => _StressState();
}

class _StressState extends State<_Stress> {
  final config = DeveloperBattleConfig()
    ..scene = 6
    ..startSeconds = 120
    ..invincible = true
    ..autoChoose = true
    ..enemyCount = 260
    ..shotCount = 1000
    ..sparkCount = 160
    ..level = 50
    ..rate = 5
    ..power = 5
    ..count = 4
    ..skills.addAll({
      'drone': 5,
      'trail': 5,
      'guardian': 5,
      'lightning': 5,
      'durian': 5,
      'ball': 5,
    })
    ..evolutions.addAll([
      'drone',
      'trail',
      'guardian',
      'lightning',
      'durian',
      'ball',
    ]);
  GameEngine? game;
  late final Timer timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      BattleScreen(
        profile: widget.p,
        developerConfig: config,
        presentationAutoplay: true,
        engineFactory: () => game = config.build(widget.p),
      ),
      Positioned(
        left: 0,
        top: 0,
        child: IgnorePointer(
          child: Semantics(
            container: true,
            label:
                'QA_STATE ${jsonEncode(game == null ? {} : {'elapsed': game!.elapsed, 'combatTime': game!.combatTime, 'enemies': game!.enemies.length, 'shots': game!.shots.length, 'sparks': game!.sparks.length, 'crystals': game!.crystals.length, 'finished': game!.finished, 'paused': game!.paused, 'choices': game!.choices.length, 'checkpointBytes': utf8.encode(jsonEncode(game!.checkpoint())).length})}',
            child: const SizedBox(width: 1, height: 1),
          ),
        ),
      ),
    ],
  );
}
