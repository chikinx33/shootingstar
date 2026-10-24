// Local-only entrypoint using the production BattleScreen/Engine/Painter.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/portrait_viewport.dart';
import 'package:shootingstar/art/raster_assets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  final p = await Profile.load();
  p.onboarded = true;
  p.soundEnabled = false;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'NotoSansKR'),
      home: PortraitViewport(child: CampaignProbe(profile: p)),
    ),
  );
}

class CampaignProbe extends StatefulWidget {
  const CampaignProbe({super.key, required this.profile});
  final Profile profile;
  @override
  State<CampaignProbe> createState() => _CampaignProbeState();
}

class _CampaignProbeState extends State<CampaignProbe> {
  GameEngine? g;
  late Timer timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  GameEngine create() {
    final query = Uri.base.queryParameters;
    final stage = (int.tryParse(query['stage'] ?? '0') ?? 0).clamp(0, 99);
    final mode = query['mode'] ?? 'world';
    final engine = GameEngine(
      stageIndex: stage,
      shipIndex: 0,
      attackLevel: 2,
      hullLevel: 2,
      magnetLevel: 0,
      equipmentIndex: 0,
      seed: 42,
      armament: query['weapon'] ?? 'pulse',
      pilot: query['pilot'] ?? 'common',
    );
    engine.hp = engine.maxHp =
        100000; // Visual/damage fixture; not survival proof.
    engine.elapsed = 35;
    if (mode == 'drops') {
      engine.crystals.addAll(
        List.generate(
          30,
          (i) =>
              engine.position +
              Offset((i % 6 - 3) * 100.0, (i ~/ 6 - 2) * 150.0),
        ),
      );
      for (int kind = 1; kind <= 6; kind++) {
        if (kind != 2 && kind != 3) {
          engine.supplies.add(Supply(engine.position, kind));
        }
      }
    } else {
      for (int i = 0; i < EnemyRole.values.length; i++) {
        engine.enemies.add(
          Foe(
            engine.position + Offset((i % 3 - 1) * 115.0, (i ~/ 3 - 2) * 90.0),
            5000,
            38,
            14,
            0,
            role: EnemyRole.values[i],
          ),
        );
      }
      engine.upgrades.addAll({'drone': 3, 'guardian': 3, 'laser': 3});
      if (mode == 'weapon') {
        for (int i = 0; i < 3; i++) {
          for (int kind = 4; kind <= 6; kind++) {
            engine.supplies.add(Supply(engine.position, kind));
          }
        }
        engine.upgrades.removeWhere((id, _) => id != 'gun' && id != 'pilot');
      }
      if (mode == 'skills') {
        engine.upgrades.addAll({
          for (final id in [
            'missile',
            'ball',
            'drill',
            'boomerang',
            'durian',
            'forcefield',
          ])
            id: 5,
        });
        engine.upgrades.remove('drone');
        engine.upgrades.remove('guardian');
        engine.upgrades.remove('laser');
        engine.evolved.addAll(engine.upgrades.keys.where((id) => id != 'gun'));
      }
    }
    if (mode == 'boss') {
      engine.enemies.clear();
      engine.shots.clear();
      engine.upgrades.removeWhere((id, _) => id != 'gun');
      engine.elapsed = engine.nextBossAt;
    }
    if (mode == 'stress') {
      engine.enemies.clear();
      engine.upgrades
        ..clear()
        ..addAll({
          'gun': 5,
          'drone': 5,
          'trail': 5,
          'guardian': 5,
          'lightning': 5,
          'durian': 5,
          'ball': 5,
        });
      engine.evolved.addAll(engine.upgrades.keys);
      engine.passives.addAll({
        'cooldown': 5,
        'gold': 5,
        'duration': 5,
        'area': 5,
        'speed': 5,
        'xp': 5,
      });
      engine.mainRate = 5;
      engine.mainPower = 5;
      engine.mainCount = 4;
      engine.level = 50;
      engine.xpNeeded = 1e9;
      for (int i = 0; i < 260; i++) {
        engine.enemies.add(
          Foe(
            engine.position +
                Offset((i % 20 - 10) * 18.0, (i ~/ 20 - 6) * 22.0),
            1000000,
            30,
            11,
            0,
            role: i < 12
                ? EnemyRole.spitter
                : [
                    EnemyRole.scout,
                    EnemyRole.weaver,
                    EnemyRole.bulwark,
                    EnemyRole.orbiter,
                    EnemyRole.splitter,
                  ][i % 5],
          ),
        );
      }
    }
    if (query['pilot'] == 'taloxa') engine.pilotSync = 210;
    engine.setPaused(true);
    g = engine;
    return engine;
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      BattleScreen(profile: widget.profile, engineFactory: create),
      Positioned(
        left: 8,
        right: 8,
        bottom: 45,
        child: IgnorePointer(
          child: Material(
            color: Colors.black87,
            child: Text(
              'QA · R${g?.mainRate ?? 0} P${g?.mainPower ?? 0} N${g?.mainCount ?? 0} · 자세 ${g?.pilotStance ?? 0} · 기갑 ${g?.pilotMech ?? false} · HP ${g?.hp.toInt() ?? 0} · 결정 ${g?.crystals.length ?? 0} · 적 ${g?.enemies.length ?? 0} · 탄 ${g?.shots.length ?? 0} · ${g?.magnetPulse != null && g!.magnetPulse > 0 ? '자석 회수' : ''}',
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ],
  );
}
