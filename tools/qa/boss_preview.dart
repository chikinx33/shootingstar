// Separate QA entrypoint. Never referenced by lib/main.dart or deployed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/portrait_viewport.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final p = await Profile.load();
  p.soundEnabled = false;
  p.onboarded = true;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'NotoSansKR'),
      home: PortraitViewport(child: BossProbe(profile: p)),
    ),
  );
}

class BossProbe extends StatefulWidget {
  const BossProbe({super.key, required this.profile});
  final Profile profile;
  @override
  State<BossProbe> createState() => _BossProbeState();
}

class _BossProbeState extends State<BossProbe> {
  GameEngine? game;
  late final Timer timer;
  final phases = <int>{};
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (game?.boss != null) phases.add(game!.bossPhase);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  GameEngine create() {
    final stage = int.tryParse(Uri.base.queryParameters['stage'] ?? '0') ?? 0;
    final strong = Uri.base.queryParameters['strong'] == '1';
    final g = GameEngine(
      stageIndex: stage.clamp(0, 2),
      shipIndex: 0,
      attackLevel: strong ? 3 : 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: 0,
      seed: 1,
      gearDamage: strong ? .65 : .05,
    );
    g.elapsed = g.nextBossAt - .2;
    // Outgoing damage and visual probe, not a player survival measurement.
    g.hp = g.maxHp = 100000;
    g.upgrades
      ..clear()
      ..addAll(
        strong
            ? {
                'gun': 5,
                'missile': 5,
                'drone': 5,
                'lightning': 5,
                'guardian': 5,
                'trail': 5,
              }
            : {'gun': 3, 'missile': 3},
      );
    if (strong) {
      g.evolved.addAll(g.upgrades.keys);
      g.passives.addAll({
        'attack': 5,
        'area': 5,
        'cooldown': 5,
        'xp': 5,
        'duration': 5,
        'magnet': 5,
      });
    }
    g.setPaused(true);
    phases.clear();
    game = g;
    return g;
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      BattleScreen(profile: widget.profile, engineFactory: create),
      Positioned(
        bottom: 45,
        left: 8,
        right: 8,
        child: IgnorePointer(
          child: Material(
            color: Colors.black87,
            child: Text(
              'QA · 공격 ${game?.bossAttacks ?? 0} · 격파 ${game?.bossesDefeated ?? 0} · 단계 ${phases.join(",")} · 주기 ${(game?.bossCycle ?? 0).toStringAsFixed(2)} · ${game?.bossCue ?? ''}',
              style: const TextStyle(fontSize: 10, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ],
  );
}
