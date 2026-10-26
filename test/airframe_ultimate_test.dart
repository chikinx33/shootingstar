import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/game/engine.dart';

/// v12.16 (user 2026-10-27): each cat's own star cannon, and the craft that
/// sheds its parts at take-off and earns them back on level-ups.
GameEngine craft(int ship, {Map<String, OwnedModulePart>? parts}) => GameEngine(
  stageIndex: 0,
  shipIndex: ship,
  aircraft: AircraftAssembly(
    hull: ship,
    modules: ModuleSnapshot(
      ship,
      1,
      parts ??
          {
            'W1': OwnedModulePart('w1', 'gun_vulcan', 1),
            'W2': OwnedModulePart('w2', 'missile_hawk', 1),
          },
    ),
  ),
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: -1,
  seed: 7,
);

void main() {
  test('the star cannon charges slowly: about ninety seconds of flight', () {
    final g = craft(0)..xpNeeded = 1e9;
    for (var i = 0; i < 60 * 30; i++) {
      g.update(1 / 60);
      if (g.finished) break;
    }
    expect(g.ultimateCharge, lessThan(40));
    expect(g.ultimateReady, isFalse);
  });

  test('치즈 fires a fish missile storm that hunts enemies', () {
    final g = craft(0)..xpNeeded = 1e9;
    g.developerPrepare(
      scene: 6,
      enemyCount: 20,
      shotCount: 30,
      ultimateReady: true,
    );
    expect(g.ultimateKind, 0);
    expect(g.activateCommonUltimate(), isTrue);
    expect(g.ultimateBanner, CommonUltimate.ultimateNames[0]);
    // the cut-in slows time first; count every missile that flies
    final seen = <Shot>{};
    for (var i = 0; i < 180; i++) {
      g.update(1 / 60);
      seen.addAll(g.shots.where((s) => s.weapon == 'ult-missile'));
    }
    expect(seen.length, greaterThan(16));
    expect(seen.every((s) => s.kind == 1), isTrue);
  });

  test('구름 brings two clones that fire beside the cat for ten seconds', () {
    final g = craft(1)..xpNeeded = 1e9;
    g.developerPrepare(scene: 0, ultimateReady: true);
    expect(g.activateCommonUltimate(), isTrue);
    expect(g.clonesActive, isTrue);
    for (var i = 0; i < 60; i++) {
      g.update(1 / 60);
    }
    final clones = g.clonePositions;
    expect(clones, hasLength(2));
    expect(clones[0].dx, lessThan(g.position.dx));
    expect(clones[1].dx, greaterThan(g.position.dx));
    final mains = g.shots.where((s) => s.weapon == 'module-main');
    // shots come from the cat and from beside it
    expect(
      mains.any((s) => (s.position.dx - g.position.dx).abs() > 40),
      isTrue,
    );
    for (var i = 0; i < 60 * 12; i++) {
      g.update(1 / 60);
    }
    expect(g.clonesActive, isFalse);
  });

  test('까미 turns invincible: no damage reaches it while the shield holds', () {
    final g = craft(2)..xpNeeded = 1e9;
    g.developerPrepare(scene: 0, ultimateReady: true);
    expect(g.activateCommonUltimate(), isTrue);
    expect(g.invincibleActive, isTrue);
    final hp = g.hp;
    g.shots.add(Shot(g.position, Offset.zero, 50, 4, life: 1));
    g.update(1 / 60);
    expect(g.hp, hp);
  });

  test(
    'a sortie sheds its parts and earns them back one level-up at a time',
    () {
      final g = craft(0)..xpNeeded = 1e9;
      g.startDisassembled();
      expect(g.assembleInFlight, isTrue);
      expect(g.detachedLayers, containsAll(['gun_l', 'missile_l', 'wing_l']));
      // shed weapons do not fire
      for (var i = 0; i < 90; i++) {
        g.update(1 / 60);
      }
      expect(g.shots.any((s) => s.weapon.startsWith('part:')), isFalse);
      // a level-up offers one shed part, picked at random
      final merge = g.mergeChoiceFor('W1');
      expect(g.rollMergeChoice()!.id, startsWith('merge:'));
      g.choices = [merge];
      g.chooseUpgrade(merge.id);
      expect(g.mergingPart, 'W1');
      final hp = g.hp;
      g.shots.add(Shot(g.position, Offset.zero, 50, 4, life: 1));
      g.update(1 / 60);
      expect(g.hp, hp, reason: 'untouchable while soaring to merge');
      // v12.17: the merge runs on the real clock — a lifted finger (5%
      // combat speed) does not slow it; it ends in 1.2 s
      for (var i = 0; i < 75; i++) {
        g.update(.05 / 60, presentationDelta: 1 / 60);
      }
      expect(g.attached, contains('W1'));
      expect(g.mergingPart, isNull);
      expect(g.detachedLayers.contains('gun_l'), isFalse);
      expect(g.shedParts, isNot(contains('W1')));
    },
  );

  test('without wings gems are only taken by touch; magnet skill waits', () {
    final g = craft(0)..xpNeeded = 1e9;
    g.startDisassembled();
    expect(g.collectionRadius, lessThan(30));
    g.attached.add('wings');
    expect(g.collectionRadius, greaterThan(40));
  });

  test('every kill pays a little experience at once', () {
    final g = craft(0)..xpNeeded = 1e9;
    g.developerPrepare(scene: 6, enemyCount: 6, shotCount: 0);
    final before = g.xp;
    for (final e in g.enemies) {
      e.hp = 0;
    }
    g.update(1 / 60);
    expect(g.xp, greaterThan(before));
  });

  test('engines built outside a sortie keep the whole craft', () {
    final g = craft(0);
    expect(g.assembleInFlight, isFalse);
    expect(g.detachedLayers, isEmpty);
    expect(g.rollMergeChoice(), isNull);
  });
}
