// Isolated-origin QA only; production never reads these parameters.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/art/game_art.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/battle_painter.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  if (Uri.base.queryParameters['mode'] == 'magnet') await GameArt.loadBattle();
  final p = await Profile.load();
  p.soundEnabled = false;
  p.onboarded = true;
  p.selectedStage = 99;
  p.clearedStages.addAll(List.generate(100, (i) => i));
  runApp(_Preview(p));
}

class _Preview extends StatefulWidget {
  const _Preview(this.p);
  final Profile p;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview>
    with SingleTickerProviderStateMixin {
  GameEngine? game;
  late final Timer timer;
  var ticks = 0, saves = 0, saveFailures = 0;
  var saving = false;
  double saveMs = 0, maxSaveMs = 0;
  String? saveError;
  final paintClock = ValueNotifier<int>(0);
  late final ticker = createTicker((time) {
    final g = game;
    if (g == null || !magnet) return;
    final dt = (time - previous).inMicroseconds / 1e6;
    previous = time;
    // Fixed empty arena isolates rendering, with production simulation clocks.
    g.elapsed = 0;
    g.update(dt.clamp(0, .05), presentationDelta: dt.clamp(0, .05));
    paintClock.value++;
  });
  Duration previous = Duration.zero;
  bool get magnet => Uri.base.queryParameters['mode'] == 'magnet';
  GameEngine create() {
    final g = GameEngine(
      stageIndex: 99,
      shipIndex: 0,
      attackLevel: 3,
      hullLevel: 3,
      magnetLevel: 0,
      equipmentIndex: 0,
      seed: 34,
      gearDamage: .65,
      gearHull: .8,
    )..xpNeeded = 1e9;
    g.developerInvincible = true;
    if (magnet) {
      g.upgrades.clear();
      final data = g.checkpoint(), s = data['state'] as Map;
      for (final k in [
        '_spawn',
        '_flightFormationClock',
        '_formationClock',
        '_supplyClock',
        '_mainClock',
        '_magnetClock',
      ]) {
        s[k] = 1e9;
      }
      s['_lastEncounter'] = 0;
      game = BattleCheckpoint.restore(jsonDecode(jsonEncode(data)))
        ..developerInvincible = true;
    } else {
      g.mainRate = 5;
      g.mainPower = 5;
      g.mainCount = 4;
      g.upgrades.addAll({
        'gun': 5,
        'drone': 5,
        'missile': 5,
        'trail': 5,
        'lightning': 5,
        'durian': 5,
      });
      g.evolved.addAll(g.upgrades.keys);
      g.passives.addAll({
        'attack': 5,
        'area': 5,
        'cooldown': 5,
        'duration': 5,
        'magnet': 5,
        'armor': 5,
      });
      game = g;
    }
    return game!;
  }

  @override
  void initState() {
    super.initState();
    if (magnet) {
      create();
      ticker.start();
    }
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final g = game;
      if (g == null || !mounted) return;
      ticks++;
      if (magnet) {
        if (ticks % 16 == 1 && !g.collectingMagnet) {
          g.crystals.addAll(
            List.generate(
              1400,
              (i) =>
                  g.position +
                  Offset((i % 35 - 17) * 16.0, (i ~/ 35 - 20) * 14.0),
            ),
          );
          g.supplies.add(Supply(g.position, 1));
        }
      } else {
        if (g.boss != null && g.boss!.maxHp < 1e11) {
          g.boss!.hp = g.boss!.maxHp = 1e11;
        }
        if (g.choices.isNotEmpty) g.chooseUpgrade(g.choices.first.id);
        g.input = Offset(
          math.cos(g.combatTime * .4),
          math.sin(g.combatTime * .4),
        );
        if (ticks % 20 == 0 && !saving && !g.finished) {
          saving = true;
          final watch = Stopwatch()..start();
          final ok = await widget.p.checkpointBattle('endurance-qa', g);
          saveMs = watch.elapsedMicroseconds / 1000;
          maxSaveMs = math.max(maxSaveMs, saveMs);
          saves++;
          if (!ok) saveFailures++;
          try {
            BattleCheckpoint.restore(jsonDecode(jsonEncode(g.checkpoint())));
            saveError = null;
          } catch (e) {
            saveError = e.toString();
          }
          saving = false;
        }
      }
      if (mounted && ticks % 10 == 0) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    if (magnet) ticker.dispose();
    paintClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app =
        ShootingstarApp(profile: widget.p).build(context) as MaterialApp;
    final g = game;
    return MaterialApp(
      theme: app.theme,
      debugShowCheckedModeBanner: false,
      home: Stack(
        children: [
          if (magnet)
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 390,
                  height: 600,
                  child: CustomPaint(
                    painter: _MagnetPainter(
                      game!,
                      paintClock,
                      Uri.base.queryParameters['reference'] != '1',
                    ),
                  ),
                ),
              ),
            )
          else
            BattleScreen(
              profile: widget.p,
              engineFactory: create,
              presentationAutoplay: true,
            ),
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: Semantics(
                container: true,
                label:
                    'QA_ENDURANCE ${jsonEncode(g == null ? {} : {'combat': g.combatTime, 'elapsed': g.elapsed, 'enemies': g.enemies.length, 'shots': g.shots.length, 'crystals': g.crystals.length, 'motes': g.absorbingCrystals.length, 'cues': g.visuals.active.length, 'sparks': g.sparks.length, 'finished': g.finished, 'paused': g.paused, 'choices': g.choices.length, 'checkpointBytes': utf8.encode(jsonEncode(g.checkpoint())).length, 'saves': saves, 'saveFailures': saveFailures, 'lastSaveMs': saveMs, 'maxSaveMs': maxSaveMs, 'restoreError': saveError})}',
                child: const SizedBox(width: 1, height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MagnetPainter extends CustomPainter {
  _MagnetPainter(this.game, Listenable clock, this.cached)
    : super(repaint: clock);
  final GameEngine game;
  final bool cached;
  @override
  void paint(Canvas canvas, Size size) =>
      BattlePainter(game, cacheProjectiles: cached).paint(canvas, size);
  @override
  bool shouldRepaint(_MagnetPainter old) =>
      old.cached != cached || old.game != game;
}
