// Isolated visual fixture. Never build this entrypoint into build/web.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/portrait_viewport.dart';

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
      home: PortraitViewport(child: FlightProbe(profile: p)),
    ),
  );
}

class FlightProbe extends StatefulWidget {
  const FlightProbe({super.key, required this.profile});
  final Profile profile;
  @override
  State<FlightProbe> createState() => _FlightProbeState();
}

class _FlightProbeState extends State<FlightProbe> {
  late Timer timer;
  GameEngine? g;
  final watched = <Foe>[];
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      g?.enemies.removeWhere((e) => !watched.contains(e));
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  GameEngine create() {
    final mode = Uri.base.queryParameters['mode'] ?? 'scout';
    final engine =
        GameEngine(
            stageIndex: 0,
            shipIndex: 0,
            attackLevel: 0,
            hullLevel: 0,
            magnetLevel: 0,
            equipmentIndex: 0,
            seed: 42,
          )
          ..upgrades.clear()
          ..hp = 100000
          ..maxHp = 100000
          ..xpNeeded = 1e9;
    if (mode == 'formation') {
      final origin = engine.position + const Offset(-90, -310);
      final delta = engine.position - origin, aim = delta / delta.distance;
      for (int i = 0; i < 5; i++) {
        watched.add(
          Foe(
              origin - aim * (i * 48.0),
              10000,
              70,
              11,
              0,
              role: EnemyRole.kamikaze,
            )
            ..aim = aim
            ..heading = math.atan2(aim.dy, aim.dx)
            ..formationId = 0
            ..formationOrder = i,
        );
      }
    } else if (mode == 'ordnance') {
      final roles = [
        EnemyRole.scout,
        EnemyRole.bulwark,
        EnemyRole.spitter,
        EnemyRole.orbiter,
        EnemyRole.lancer,
        EnemyRole.sniper,
      ];
      for (int i = 0; i < roles.length; i++) {
        watched.add(
          Foe(
            engine.position + Offset((i % 3 - 1) * 130.0, -200 + i ~/ 3 * 70),
            10000,
            28,
            14,
            0,
            role: roles[i],
          )..attackClock = enemyDoctrines[roles[i]]!.windup + .5,
        );
      }
    } else {
      final role = EnemyRole.values.firstWhere((e) => e.name == mode);
      watched.add(
        Foe(
          engine.position + const Offset(0, -350),
          10000,
          70,
          14,
          0,
          role: role,
        ),
      );
    }
    engine.enemies.addAll(watched);
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
        bottom: 58,
        child: IgnorePointer(
          child: Semantics(
            label:
                'probe ${jsonEncode({
                  'time': g?.combatTime,
                  'hp': g?.hp,
                  'foes': watched.map((e) => {'role': e.role.name, 'x': e.position.dx, 'y': e.position.dy, 'distance': g == null ? 0 : (e.position - g!.position).distance, 'heading': e.heading, 'state': e.flight.name, 'retired': e.retired}).toList(),
                  'shots': g?.shots.where((s) => s.hostile).map((s) => {'kind': s.kind, 'age': s.age}).toList(),
                })}',
            child: Material(
              color: Colors.black87,
              child: Text(
                'QA 비행 교전 · ${watched.firstOrNull?.role.name} · ${g?.shots.where((s) => s.hostile).length ?? 0}개 적탄',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 10,
        bottom: 95,
        child: TextButton(
          onPressed: () {
            g?.position += const Offset(120, 0);
            setState(() {});
          },
          child: const Text('측면 회피'),
        ),
      ),
    ],
  );
}
