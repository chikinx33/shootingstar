import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/data/online_api.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/seeded_random.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/ui/home.dart';

import 'ui_actions.dart';

GameEngine arena({
  int world = 0,
  String armament = 'pulse',
  String pilot = 'common',
}) => GameEngine(
  stageIndex: world * 10,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 24,
  armament: armament,
  pilot: pilot,
);
GameEngine roundTrip(GameEngine game) =>
    BattleCheckpoint.restore(jsonDecode(jsonEncode(game.checkpoint())));
void advance(GameEngine game, int frames) {
  for (var i = 0; i < frames && !game.finished; i++) {
    if (game.choices.isNotEmpty) game.chooseUpgrade(game.choices.first.id);
    game.update(.025, presentationDelta: .05);
  }
}

class NoNetwork extends OnlineApi {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls++;
    throw StateError('Checkpoint must not sync');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('portable RNG resumes after mixed calls', () {
    final r = CombatRandom(24);
    for (var i = 0; i < 101; i++) {
      r.nextInt(i + 1);
      r.nextDouble();
      r.nextBool();
    }
    final copy = CombatRandom.fromState(r.state);
    for (var i = 0; i < 100; i++) {
      expect(copy.nextInt(127), r.nextInt(127));
      expect(copy.nextDouble(), r.nextDouble());
    }
  });
  test('all worlds have distinct geometry, reachable safety, locked cues and no boss overlap', () {
    final signatures = <String>{};
    for (var world = 0; world < 10; world++) {
      final g = arena(world: world)..elapsed = 10;
      g.update(.01);
      final c = g.hazardCenter;
      expect(g.hazardVisible, true);
      expect(g.hazardActive, false);
      signatures.add(
        jsonEncode([
          for (final f in g.fields)
            [
              f.shape.name,
              f.a.dx - c.dx,
              f.a.dy - c.dy,
              f.radius,
              f.b?.dx,
              f.b?.dy,
            ],
        ]),
      );
      var safe = 0;
      for (var x = -150; x <= 150; x += 25) {
        for (var y = -150; y <= 150; y += 25) {
          if (!g.hazardHits(c + Offset(x.toDouble(), y.toDouble()))) safe++;
        }
      }
      expect(safe, greaterThan(5), reason: 'world $world must leave an escape');
      g.input = const Offset(1, 0);
      advance(g, 20);
      expect(g.hazardCenter, c);
      g.elapsed = 13.1;
      expect(g.hazardActive, true);
      g.enemies.add(Foe(c + const Offset(0, -100), 100, 0, 40, 3));
      expect(g.hazardVisible, false);
      expect(g.hazardActive, false);
    }
    expect(signatures.length, 10);
  });
  test('warning is harmless, active geometry deals HP damage, safe position is harmless', () {
    final g = arena()
      ..upgrades.clear()
      ..elapsed = 10;
    g.update(.01);
    final hp = g.hp;
    g.update(.05);
    expect(g.hp, hp);
    g.elapsed = 13.01;
    g.update(.01);
    expect(g.hp, lessThan(hp));
    expect(g.lastDamageSource, '환경 위험');
    final safe = arena()
      ..upgrades.clear()
      ..elapsed = 10;
    safe.update(.01);
    safe.position += const Offset(120, 0);
    safe.elapsed = 13.01;
    safe.update(.01);
    expect(safe.hp, safe.maxHp);
  });
  test(
    'every world and main weapon continues identically after checkpoint',
    () {
      for (var world = 0; world < 10; world++) {
        final a = arena(
          world: world,
          armament: armaments[world].id,
          pilot: pilots[world].id,
        );
        a.hp = a.maxHp = 100000;
        a.upgrades.addAll({
          'missile': 3,
          'drone': 2,
          'guardian': 3,
          'lightning': 2,
        });
        a.passives.addAll({'armor': 2, 'magnet': 2});
        a.input = const Offset(.4, -.2);
        advance(a, 650);
        final b = roundTrip(a);
        expect(b.checkpoint(), a.checkpoint(), reason: 'world $world initial');
        advance(a, 250);
        advance(b, 250);
        expect(b.checkpoint(), a.checkpoint(), reason: 'world $world future');
      }
    },
  );
  test(
    'object identity survives homing, pierce hit history and retired targets',
    () {
      final a = arena();
      final live = Foe(const Offset(910, 1000), 100, 40, 20, 1)
        ..formationId = 7
        ..formationPattern = FlightFormation.bulwark
        ..formationDestination = const Offset(900, 1100);
      final retired = Foe(const Offset(500, 600), 0, 10, 12, 0)..retired = true;
      a.enemies.add(live);
      a.shots.add(
        Shot(
          const Offset(900, 1200),
          const Offset(0, -80),
          5,
          1,
          target: live,
          pierce: 2,
        )..hitTargets.addAll([live, retired]),
      );
      final b = roundTrip(a);
      expect(identical(b.shots.first.target, b.enemies.first), true);
      expect(b.shots.first.hitTargets.contains(b.enemies.first), true);
      expect(b.shots.first.hitTargets.any((f) => f.retired), true);
      expect(b.checkpoint(), a.checkpoint());
    },
  );
  test('pending growth choices and reroll RNG survive', () {
    final a = arena()..xp = 18;
    // v12.4.1: the draft opens on the frame a gem reaches the cat
    a.crystals.add(ExperienceCrystal.at(a.position, 1));
    a.update(.01);
    final b = roundTrip(a);
    expect(b.choices.map((c) => c.id), a.choices.map((c) => c.id));
    a.rerollChoices();
    b.rerollChoices();
    expect(b.checkpoint(), a.checkpoint());
    a.chooseUpgrade(a.choices.first.id);
    b.chooseUpgrade(b.choices.first.id);
    advance(a, 25);
    advance(b, 25);
    expect(b.checkpoint(), a.checkpoint());
  });
  test('magnet XP in flight arrives exactly once after resume', () {
    final a = arena()
      ..upgrades.clear()
      ..xpNeeded = 10000;
    a.crystals.addAll([
      a.position + const Offset(170, 0),
      a.position + const Offset(-130, 0),
    ]);
    a.supplies.add(Supply(a.position, 1));
    a.update(.01);
    expect(a.absorbingCrystals, isNotEmpty);
    final b = roundTrip(a);
    advance(a, 60);
    advance(b, 60);
    expect(b.xp, 4);
    expect(b.checkpoint(), a.checkpoint());
    advance(b, 60);
    expect(b.xp, 4);
  });
  test('boss phases, intermediate/final destruction and victory survive', () {
    for (final stage in [0, 4, 9]) {
      final a =
          GameEngine(
              stageIndex: stage,
              shipIndex: 0,
              attackLevel: 0,
              hullLevel: 0,
              magnetLevel: 0,
              equipmentIndex: 0,
              seed: 24,
            )
            ..hp = 100000
            ..maxHp = 100000
            ..xpNeeded = 1e9;
      a.elapsed = a.nextBossAt;
      a.update(.01);
      var b = roundTrip(a);
      advance(a, 50);
      advance(b, 50);
      expect(b.checkpoint(), a.checkpoint());
      a.boss!.hp = 0;
      a.update(.01);
      expect(a.resolvingBoss, true);
      b = roundTrip(a);
      advance(a, 230);
      advance(b, 230);
      expect(b.checkpoint(), a.checkpoint());
      expect(b.victory, stage == 0);
    }
  });
  test('checkpoint rejects unsupported, oversized and nonfinite states', () {
    final s = arena().checkpoint();
    s['schema'] = 900;
    expect(() => BattleCheckpoint.restore(s), throwsFormatException);
    final bad = arena().checkpoint();
    (bad['state'] as Map)['hp'] = double.nan;
    expect(() => BattleCheckpoint.restore(bad), throwsFormatException);
    final huge = arena().checkpoint();
    huge['enemies'] = List.filled(261, 0);
    expect(() => BattleCheckpoint.restore(huge), throwsFormatException);
  });
  test('local restart restores same run, cloud export excludes state, payout retires it atomically', () async {
    var p = await Profile.load();
    final a = arena()
      ..elapsed = 40
      ..kills = 20;
    expect(await p.checkpointBattle('persistent-run', a), true);
    expect(p.exportProgress().containsKey('_battle'), false);
    p.dispose();
    p = await Profile.load();
    final resume = p.restoreBattle()!;
    expect(resume.runId, 'persistent-run');
    expect(resume.game.elapsed, 40);
    expect(resume.game.paused, true);
    expect(resume.game.input, Offset.zero);
    final before = p.credits;
    p.completeRun(
      runId: resume.runId,
      victory: false,
      stageIndex: 0,
      kills: 20,
      level: 2,
      seconds: 40,
      training: false,
    );
    await p.save();
    expect(p.hasSuspendedBattle, false);
    expect(p.credits, greaterThan(before));
    final paid = p.credits;
    p.dispose();
    p = await Profile.load();
    expect(p.hasSuspendedBattle, false);
    p.completeRun(
      runId: 'persistent-run',
      victory: false,
      stageIndex: 0,
      kills: 20,
      level: 2,
      seconds: 40,
      training: false,
    );
    expect(p.credits, paid);
    p.dispose();
  });
  test('cloud replacement, different owner, expired daily and corrupt record cannot restore', () async {
    var p = await Profile.load();
    await p.checkpointBattle('one', arena());
    await p.replaceProgress(Profile.freshProgress());
    expect(p.hasSuspendedBattle, false);
    await p.checkpointBattle('two', arena());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('online.bound', 'another-account');
    expect(p.restoreBattle(), null);
    expect(p.battleSaveNotice, isNotNull);
    await prefs.setString('online.bound', '');
    p.refreshContentClock(DateTime.now());
    final entry = p.dailyChallenge.begin(0)!;
    final daily = GameEngine(
      stageIndex: 0,
      shipIndex: 0,
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: 0,
      dailyEntry: entry,
    );
    await p.checkpointBattle('daily', daily);
    p.dailyChallenge.advance(
      DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    expect(p.restoreBattle(), null);
    await p.checkpointBattle('corrupt', arena());
    await p.save();
    final raw = jsonDecode(
      prefs.getString(Profile.storageKey)!,
    ) as Map<String, dynamic>;
    (raw['_battle'] as Map)['checksum'] = 0;
    await prefs.setString(Profile.storageKey, jsonEncode(raw));
    p.dispose();
    p = await Profile.load();
    expect(p.hasSuspendedBattle, false);
    expect(p.credits, 150);
    p.dispose();
  });
  test(
    'pending battle blocks background cloud replacement; rehearsal never saves',
    () async {
      final p = await Profile.load(), api = NoNetwork();
      final cloud = CloudSync(p, api: api)
        ..account = {'id': 'a'}
        ..boundId = 'a'
        ..ready = true;
      await p.checkpointBattle('one', arena());
      await cloud.sync();
      expect(api.calls, 0);
      expect(
        await Profile.presentationCopy(p).checkpointBattle('demo', arena()),
        false,
      );
      expect(
        await Profile.developerCopy(p).checkpointBattle('dev', arena()),
        false,
      );
      cloud.dispose();
      p.dispose();
    },
  );
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('resume and save return reachable at $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = await Profile.load()
          ..onboarded = true
          ..reducedEffects = true
          ..soundEnabled = false;
        await p.checkpointBattle(
          'ui-run',
          arena()
            ..elapsed = 35
            ..kills = 10,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: HomeScreen(profile: p),
          ),
        );
        await tester.pumpAndSettle();
        await tapUi(tester, find.byKey(const Key('launch')));
        await tapUi(tester, find.bySemanticsLabel('이전 전투 이어하기').last);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('일시정지'), findsOneWidget);
        await tapUi(tester, find.byKey(const Key('save-battle-return')));
        await tester.pumpAndSettle();
        expect(find.byType(BattleScreen), findsNothing);
        expect(p.restoreBattle()!.runId, 'ui-run');
        expect(p.credits, 150);
        expect(p.runs, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      });
    }
  }
}
