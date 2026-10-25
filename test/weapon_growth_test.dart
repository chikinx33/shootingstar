import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/upgrade_slots.dart';

/// v12 weapon growth: enhance 3 + evolve 3 + ultimate for every weapon
/// (docs/WEAPON_EVOLUTION_DESIGN.md).
Future<GameEngine> armed({String armament = 'pulse', int seed = 9}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await Profile.load();
  return GameEngine(
      stageIndex: 0,
      shipIndex: p.selectedShip,
      aircraft: p.aircraftAssembly,
      supportLevels: p.aircraftSupportLevels,
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: p.magnetLevel,
      equipmentIndex: -1,
      armament: armament,
      armamentLevel: 0,
      seed: seed,
    )
    ..viewportHeight = 760
    ..xpNeeded = 1e9;
}

void fight(GameEngine g, double seconds) {
  for (var i = 0; i < seconds * 40; i++) {
    g.input = Offset(math.sin(i / 60), i % 400 < 200 ? -.6 : .4);
    g.update(.025);
  }
}

double dealt(GameEngine g, String prefix) => g.damageByWeapon.entries
    .where((e) => e.key.startsWith(prefix))
    .fold(0.0, (a, e) => a + e.value);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh fleet carries the rear self-propelled gun on W3', () async {
    final g = await armed();
    expect(g.moduleLoadout!.parts['W3']!.partId, 'mortar_cat');
  });

  test('cards: enhance and evolve tracks, then a forced ultimate', () async {
    final g = await armed();
    final ids = g.growthChoices().map((c) => c.id).toSet();
    // a fresh weapon starts on enhance cards; evolve n follows enhance n
    expect(ids, containsAll(['enh|part:W1', 'enh|part:W3']));
    expect(ids.where((id) => id.startsWith('evo|')), isEmpty);
    expect(ids, contains('paw:orbit')); // a new item attack
    // v12.4: bullets (main gun) and missiles grow only from field drops
    expect(ids.where((id) => id.endsWith('|gun')), isEmpty);
    for (final missile in g.missileGrowth) {
      expect(ids.where((id) => id.endsWith('|$missile')), isEmpty);
    }
    for (var i = 0; i < 6; i++) {
      expect(g.dropGrowthStep('gun'), isTrue);
    }
    expect(g.enh('gun'), 3);
    expect(g.evo('gun'), 3);
    expect(g.ult('gun'), isFalse);
    expect(g.dropGrowthStep('gun'), isTrue);
    expect(g.ult('gun'), isTrue);
    expect(g.dropGrowthStep('gun'), isFalse);
    expect(g.ultimateShow, greaterThan(0));
    expect(g.ultimateBanner, '태양 냥냥 개틀링');
    // progress survives a save and resume
    final copy = BattleCheckpoint.restore(g.checkpoint());
    expect(copy.enh('gun'), 3);
    expect(copy.ult('gun'), isTrue);
  });

  test('every main gun ultimate fights', () async {
    for (final armament in ['pulse', 'revolver', 'shotgun']) {
      final g = await armed(armament: armament);
      g.growthEnhance['gun'] = 3;
      g.growthEvolve['gun'] = 3;
      g.growthUltimates.add('gun');
      fight(g, 25);
      expect(dealt(g, 'module-main'), greaterThan(0), reason: armament);
    }
  });

  test('every mounted weapon grows and its ultimate fights', () async {
    // v12.11: wing gun, missile pair and mortar (the W4 turret is gone)
    for (final mount in ['W1', 'W2', 'W3']) {
      final g = await armed(seed: 4);
      final id = 'part:$mount';
      final before = g.partStats(mount);
      g.growthEnhance[id] = 3;
      g.growthEvolve[id] = 3;
      final grown = g.partStats(mount);
      expect(
        grown.damage > before.damage ||
            grown.fireRate > before.fireRate ||
            grown.count > before.count,
        isTrue,
        reason: mount,
      );
      g.growthUltimates.add(id);
      g.damageByWeapon.clear();
      fight(g, 25);
      expect(dealt(g, id), greaterThan(0), reason: '$mount ultimate');
    }
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('growth cards render at 320px / $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final g = await armed();
      // the main gun and missiles grow from drops (v12.4), not from cards
      g.growthEnhance['part:W1'] = 3;
      g.growthEvolve['part:W1'] = 3;
      // evolve cards need the enhance step of their rank first (v12.9)
      g.growthEnhance['part:W3'] = 1;
      for (final set in [
        ['ult|part:W1', 'enh|part:W3', 'paw:orbit'],
        ['paw:orbit', 'evo|part:W3', 'paw:yarn'],
      ]) {
        final all = {for (final c in g.growthChoices()) c.id: c};
        g.choices = [for (final id in set) all[id]!];
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: UpgradeSlots(game: g, onChoose: (_) {}, onReroll: () {}),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull, reason: '$set');
      }
      expect(find.text('궁극'), findsNothing); // second set has no ultimate
    });
  }
}
