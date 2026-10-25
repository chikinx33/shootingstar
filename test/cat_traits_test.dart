import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/combat_loadout.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine flight(int ship, int traitLevel) => GameEngine(
  stageIndex: 0,
  shipIndex: ship,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  pilot: catTraitFor(ship).id,
  traitLevel: traitLevel,
  seed: 3,
);

void main() {
  test('every cat flies its own fixed trait (v12.9.2)', () {
    expect(catTraits.length, ships.length);
    expect([for (final t in catTraits) t.name], ['신참의 패기', '고양이 눈', '꼬리 방패']);
    for (final trait in catTraits) {
      expect(pilots.any((p) => p.id == trait.id), isTrue, reason: trait.id);
    }
  });

  test('trait steps follow the cat level, 1 to 5', () {
    expect(catTraitLevel(0), 1);
    expect(catTraitLevel(9), 1);
    expect(catTraitLevel(10), 2);
    expect(catTraitLevel(40), 5);
    expect(catTraitLevel(200), 5);
  });

  test('a trait takes no card slot and grows with its step', () {
    for (var ship = 0; ship < ships.length; ship++) {
      final g = flight(ship, 3);
      expect(g.pilotIsCatTrait, isTrue);
      expect(g.pilotSkillLevel, 3);
      expect(g.upgrades.containsKey('pilot'), isFalse, reason: '$ship');
      expect(g.passives.containsKey('pilot'), isFalse, reason: '$ship');
      // the tail shield is passive: no extra ability button
      expect(g.pilotHasActive, isFalse, reason: '$ship');
    }
    expect(flight(0, 5).damageFactor, greaterThan(flight(0, 1).damageFactor));
  });

  test('the trait step survives a checkpoint', () {
    final g = flight(1, 4);
    expect(BattleCheckpoint.restore(g.checkpoint()).traitLevel, 4);
  });

  test('pilots themed on outside works are gone', () {
    const removed = [
      'sponge', 'squid', 'patrick', 'sandy', 'plankton', 'leo', 'raph', //
      'mikey', 'don', 'splinter', 'april',
    ];
    for (final id in removed) {
      expect(pilots.any((p) => p.id == id), isFalse, reason: id);
    }
    expect(pilots.length, 16);
  });
}
