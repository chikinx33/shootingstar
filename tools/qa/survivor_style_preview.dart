// Isolated visual fixtures; never deploy this entrypoint as the game.
// Build into .local/survivor-style-fixtures and serve on a separate local port.
import 'package:flutter/material.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/data/daily_challenge.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/home.dart';
import 'package:shootingstar/ui/armament_hangar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RasterAssets.load();
  final profile = await Profile.load();
  profile.onboarded = true;
  profile.soundEnabled = false;
  if (Uri.base.queryParameters['scene'] == 'armaments') {
    // Isolated currency fixture to exercise actual paid decisions and reloads.
    profile.credits = 2000;
    profile.blueprints = 20;
  }
  profile.refreshContentClock(DateTime.now());
  // Optional real account client, with transport isolated by browser QA routes.
  if (Uri.base.queryParameters['online'] == '1') {
    await CloudSync(profile).initialize();
  }
  runApp(StylePreview(profile: profile));
}

class StylePreview extends StatelessWidget {
  const StylePreview({super.key, required this.profile});
  final Profile profile;
  GameEngine create() {
    final query = Uri.base.queryParameters;
    final isDaily = (query['scene'] ?? '').startsWith('daily');
    final dailyEntry = isDaily
        ? profile.dailyChallenge.begin(
            (int.tryParse(query['tier'] ?? '') ?? 0).clamp(0, 2),
          )
        : null;
    final stage = isDaily
        ? 0
        : (int.tryParse(query['stage'] ?? '') ?? 0).clamp(0, 99);
    final ship = (int.tryParse(query['ship'] ?? '') ?? 0).clamp(0, 2);
    final game = GameEngine(
      stageIndex: stage,
      shipIndex: ship,
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: 0,
      petKind: int.tryParse(query['pet'] ?? '') ?? -1,
      petLevel: query.containsKey('pet') ? 3 : 0,
      seed: 17,
      dailyEntry: dailyEntry,
      armament: query['scene'] == 'wing-phase5'
          ? (query['weapon'] ?? 'kunai')
          : 'pulse',
      armamentLevel: query['scene'] == 'wing-phase5' ? 4 : 0,
      techRanks: query['scene'] == 'wing-phase5' ? {'gun': 2} : const {},
      mainPrecisionLink: query['scene'] == 'wing-phase5',
      mainCycleLink: query['scene'] == 'wing-phase5',
    );
    game.hp = game.maxHp = 99999; // Screenshot fixture; not survival evidence.
    if (query['scene'] == 'wing-phase6') {
      // Local visual fixture: natural scheduling with unrelated actors removed.
      // No production route or save is changed by this preview.
      game.viewportHeight = 420;
      game.upgrades.clear();
      game.xpNeeded = 1e9;
      final pattern = query['formation'] == 'assault'
          ? FlightFormation.assault
          : FlightFormation.bulwark;
      for (var i = 0; i < 1100; i++) {
        game.update(.05);
        game.enemies.removeWhere((e) => e.formationPattern != pattern);
        if (game.enemies.any((e) => e.formationPattern == pattern)) break;
      }
      const hold = 1.3;
      while (game.enemies.first.phase < hold) {
        game.update(.02);
        game.enemies.removeWhere((e) => e.formationPattern != pattern);
      }
      game.shots.clear();
    } else if (query['scene'] == 'wing-phase5') {
      // Posed local branch/gear fixture, not evidence of earned upgrades.
      game.xp = game.xpNeeded;
      game.update(.001);
      game.enemies.clear();
      game.enemies.addAll([
        for (var i = 0; i < 9; i++)
          Foe(
            game.position + Offset((i % 3 - 1) * 65.0, -80 - (i ~/ 3) * 55.0),
            99999,
            0,
            12,
            0,
          ),
      ]);
    } else if (query['scene'] == 'wing-phase3') {
      // Isolated layout fixture, not a real run or progression evidence.
      game.upgrades.clear();
      game.xpNeeded = 1e9;
      for (var i = 0; i < 1005; i++) {
        game.update(.02);
        game.enemies.clear();
        game.shots.clear();
        game.supplies.clear();
      }
      game.mainBranch = MainBranch.pulseFocus;
      game.upgrades.addAll({'gun': 1, 'laser': 1, 'guardian': 3});
      game.passives['armor'] = 1;
    } else if (query['scene'] == 'pause') {
      game.setPaused(true);
    } else if (query['scene'] == 'daily-victory') {
      // Settlement UI fixture; not evidence of a legitimately won battle.
      game.elapsed = DailyChallengeEntry.duration;
      game.combatTime = 210;
      game.kills = 120;
      game.bossesDefeated = 1;
      game.finished = game.victory = true;
    } else if (query['scene'] == 'choices') {
      game.choices = const [
        UpgradeChoice('gun', '펄스 블래스터', '기체 전방으로 주포를 연사합니다.', 'gun'),
        UpgradeChoice('missile', '추적 로켓', '강한 적을 추적하는 범위 폭발입니다.', 'missile'),
        UpgradeChoice('attack', '고출력 탄두', '모든 무기의 피해량이 증가합니다.', 'attack'),
      ];
    } else if (query['scene'] == 'art-v10') {
      // Deliberately posed art fixture. This is not a real encounter/win.
      for (var i = 0; i < EnemyRole.values.length; i++) {
        game.enemies.add(
          Foe(
            game.position + Offset((i % 4 - 1.5) * 70, -145 + (i ~/ 4) * 65),
            99999,
            0,
            17,
            0,
            role: EnemyRole.values[i],
          ),
        );
      }
      game.upgrades.addAll({
        'missile': 3,
        'guardian': 3,
        'drone': 3,
        'ball': 3,
        'laser': 3,
      });
      game.passives.addAll({
        'attack': 2,
        'hull': 2,
        'magnet': 2,
        'speed': 2,
        'cooldown': 2,
        'armor': 2,
      });
    } else {
      final count = query['scene'] == 'stress' ? 450 : 25;
      for (int i = 0; i < count; i++) {
        game.enemies.add(
          Foe(
            game.position + Offset((i % 15 - 7) * 26.0, (i ~/ 15 - 12) * 24.0),
            5000,
            30,
            13,
            0,
            role: EnemyRole.values[i % EnemyRole.values.length],
          ),
        );
      }
      game.upgrades.addAll({'missile': 3, 'guardian': 3, 'drone': 3});
      if (query['scene'] == 'boss') game.elapsed = game.nextBossAt;
    }
    return game;
  }

  @override
  Widget build(BuildContext context) {
    // Reuse the actual app's theme and viewport without adding fixture routes
    // or query handling to the production application.
    final app = ShootingstarApp(profile: profile).build(context) as MaterialApp;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: app.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            (double.tryParse(Uri.base.queryParameters['textScale'] ?? '') ?? 1)
                .clamp(1, 2),
          ),
        ),
        child: Builder(builder: (scaled) => app.builder!(scaled, child)),
      ),
      home: Uri.base.queryParameters['scene'] == 'armaments'
          ? ArmamentHangar(profile: profile)
          : Uri.base.queryParameters['scene'] == 'menus'
          ? HomeScreen(profile: profile)
          : BattleScreen(
              profile: profile,
              engineFactory: create,
              dailyEntry:
                  (Uri.base.queryParameters['scene'] ?? '').startsWith('daily')
                  ? profile.dailyChallenge.begin(
                      (int.tryParse(Uri.base.queryParameters['tier'] ?? '') ??
                              0)
                          .clamp(0, 2),
                    )
                  : null,
            ),
    );
  }
}
