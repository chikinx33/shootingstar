// QA-only entrypoint: actual production replay pages with read-only telemetry.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart' show ShootingstarApp;
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/ui/developer_screen.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/battle_painter.dart';
import 'package:shootingstar/game/combat_cues.dart';

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
  GameEngine? current;
  bool hit = false,
      evolution = false,
      ultimate = false,
      block = false,
      counter = false;
  GameEngine? paintedGame() {
    GameEngine? found;
    void visit(Element e) {
      final w = e.widget;
      if (w is CustomPaint && w.painter is BattlePainter) {
        found = (w.painter! as BattlePainter).game;
      }
      e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      final g = paintedGame();
      if (!identical(g, current)) {
        current = g;
        hit = evolution = ultimate = block = counter = false;
      }
      if (g != null) {
        hit |= g.hp < g.maxHp && g.hurtFlash > 0;
        evolution |=
            g.evolved.contains('missile') &&
            g.visuals.active.any((c) => c.kind == CombatCueKind.evolution);
        ultimate |=
            g.ultimateRemaining > 0 &&
            (g.damageByWeapon['common-ultimate'] ?? 0) > 0;
        block |= g.synergyTriggers('shield-counter') > 0;
        counter |= g.shots.any(
          (s) =>
              s.kind == 0 &&
              (s.damage - 17 * g.damageFactor * 1.5).abs() < .001,
        );
      }
      setState(() {});
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
    final scale =
        double.tryParse(Uri.base.queryParameters['textScale'] ?? '1') ?? 1;
    final g = current;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: app.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Stack(
          children: [
            Builder(builder: (context) => app.builder!(context, child)),
            Positioned(
              left: 0,
              top: 0,
              child: Semantics(
                container: true,
                label:
                    'QA_STATE ${jsonEncode({'active': g != null, 'elapsed': g?.elapsed, 'paused': g?.paused, 'hp': g?.hp, 'maxHp': g?.maxHp, 'hit': hit, 'evolution': evolution, 'ultimate': ultimate, 'block': block, 'counter': counter, 'evolved': g?.evolved.toList(), 'ultimateRemaining': g?.ultimateRemaining, 'hurtFlash': g?.hurtFlash, 'counterPending': g?.shieldCounterPending})}',
                child: const SizedBox(width: 1, height: 1),
              ),
            ),
          ],
        ),
      ),
      home: DeveloperTestScreen(profile: widget.p),
    );
  }
}
