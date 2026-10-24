// Isolated QA states. Production never reads these query parameters.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart' show ShootingstarApp;
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/home.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/arcade_home_widgets.dart';
import 'package:shootingstar/ui/reward_popup.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/resolution_vfx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  final p = await Profile.load();
  p.soundEnabled = false;
  p.onboarded = true;
  runApp(_Preview(p));
}

class _Preview extends StatelessWidget {
  const _Preview(this.profile);
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    final app = ShootingstarApp(profile: profile).build(context) as MaterialApp;
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
      home: q['scene'] == 'home'
          ? HomeScreen(profile: profile)
          : _Stage(profile, q),
    );
  }
}

class _Engine extends GameEngine {
  _Engine()
    : super(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 623,
      );
  bool running = true;
  double? holdAt;
  @override
  void update(double dt, {double? presentationDelta}) {
    if (!running ||
        holdAt != null &&
            bossResolution != null &&
            bossResolution!.time >= holdAt!)
      return;
    super.update(dt, presentationDelta: presentationDelta);
  }
}

class _Stage extends StatefulWidget {
  const _Stage(this.profile, this.q);
  final Profile profile;
  final Map<String, String> q;
  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  late final _Engine g;
  Timer? timer;
  bool started = false;
  int claimed = 0, purchases = 0;
  String get scene => widget.q['scene'] ?? 'magnet';
  @override
  void initState() {
    super.initState();
    g = _Engine()..developerInvincible = true;
    if (scene == 'boss' || scene == 'intermediate') {
      g.xpNeeded = 1e9;
      final rounds = scene == 'intermediate' ? 1 : g.requiredBosses;
      for (var i = 0; i < rounds; i++) {
        g.elapsed = g.nextBossAt;
        g.update(.001);
        if (i < rounds - 1) {
          g.boss!.hp = 0;
          g.update(.001);
          while (g.resolvingBoss) {
            g.update(.025);
          }
          g.supplies.clear();
          g.crystals.clear();
          g.choices = [];
        }
      }
      g.holdAt = double.tryParse(widget.q['hold'] ?? '');
    } else {
      g.crystals.addAll(
        List.generate(
          56,
          (i) => g.position + Offset((i % 8 - 3.5) * 46, (i ~/ 8 - 4) * 42.0),
        ),
      );
      g.xpNeeded = 12;
    }
    g.running = false;
    widget.profile.credits = 1500;
    widget.profile.gearKeys = 1;
    timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void start() {
    setState(() {
      started = true;
      g.running = true;
      if (scene == 'boss' || scene == 'intermediate')
        g.boss!.hp = 0;
      else
        g.supplies.add(Supply(g.position, 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (scene == 'reward') return _rewards(context);
    return Stack(
      children: [
        BattleScreen(profile: widget.profile, engineFactory: () => g),
        if (!started)
          Align(
            alignment: Alignment.center,
            child: Semantics(
              button: true,
              label: '연출 시작',
              child: GestureDetector(
                onTap: start,
                child: Container(
                  color: Colors.amber,
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    '연출 시작',
                    style: TextStyle(color: Colors.black, fontSize: 22),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          top: 0,
          child: Semantics(
            container: true,
            label:
                'QA_STATE ${jsonEncode({'motes': g.absorbingCrystals.length, 'collecting': g.collectingMagnet, 'xp': g.xp, 'level': g.level, 'choices': g.choices.length, 'time': g.bossResolution?.time ?? 0, 'heroY': ResolutionVfx.heroPosition(g).dy - g.camera.dy, 'finished': g.finished, 'credits': widget.profile.credits})}',
            child: const SizedBox(width: 1, height: 1),
          ),
        ),
      ],
    );
  }

  Widget _rewards(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ResourceCounter(
            icon: Icons.hexagon,
            label: '크레딧',
            value: widget.profile.credits,
            color: Colors.amber,
            onTap: () {},
          ),
          ResourceCounter(
            icon: Icons.vpn_key,
            label: '장비 보급권',
            value: widget.profile.gearKeys,
            color: Colors.amber,
            onTap: () {},
          ),
          const SizedBox(height: 24),
          GameActionButton(
            label: '보상 수령',
            primary: true,
            icon: Icons.card_giftcard,
            onPressed: claimed > 0
                ? null
                : () => claimWithRewardPopup(context, widget.profile, () {
                    claimed++;
                    widget.profile.credits += 77;
                    widget.profile.gearKeys += 1;
                    widget.profile.contentChanged();
                    return true;
                  }),
          ),
          const SizedBox(height: 12),
          GameActionButton(
            label: '장비 구매',
            primary: true,
            icon: Icons.inventory_2,
            onPressed: () => claimWithRewardPopup(context, widget.profile, () {
              final ok = widget.profile.openGearSupply();
              if (ok) purchases++;
              return ok;
            }, title: '장비 구매 완료'),
          ),
          Text(
            'QA_STATE ${jsonEncode({'credits': widget.profile.credits, 'keys': widget.profile.gearKeys, 'claims': claimed, 'purchases': purchases, 'inventory': widget.profile.inventory.length})}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
