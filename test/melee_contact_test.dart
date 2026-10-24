import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine arena(String weapon) => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  armament: weapon,
  seed: 26,
);
void main() {
  test(
    'a large enemy overlapping the far end of a melee strike takes damage',
    () {
      for (final weapon in ['katana', 'bat', 'lightchaser']) {
        final g = arena(weapon);
        final range = weapon == 'bat' ? 120.0 : 190.0;
        final target = Foe(g.position + Offset(0, -range), 1000, 0, 34, 0);
        g.enemies.add(target);
        g.update(.001);
        expect(
          target.hp,
          lessThan(1000),
          reason: '$weapon must include the overlapping hull',
        );
        expect(g.damageByWeapon['gun'], greaterThan(0));
      }
    },
  );
  test('short strikes cannot hit a distant or sideways target beyond the swept volume', () {
    for (final weapon in ['katana', 'bat', 'lightchaser']) {
      final g = arena(weapon);
      final far = Foe(g.position + const Offset(0, -400), 1000, 0, 18, 0),
          side = Foe(g.position + const Offset(150, -60), 1000, 0, 18, 0);
      g.enemies.addAll([far, side]);
      g.update(.001);
      expect(far.hp, 1000);
      expect(side.hp, 1000);
    }
  });
  test(
    'branch contact and post-hit healing agree on the same end-cap geometry',
    () {
      final g = arena('katana')
        ..mainBranch = MainBranch.bladeLong
        ..hp = 50
        ..evolved.add('gun');
      final target = Foe(g.position + const Offset(0, -275), 1000, 0, 34, 0);
      g.enemies.add(target);
      g.update(.001);
      expect(target.hp, lessThan(1000));
      expect(g.hp, greaterThan(50));
    },
  );
  test('retired actors are not valid melee hit confirmations', () {
    final g = arena('bat');
    final target = Foe(g.position + const Offset(0, -70), 1000, 0, 34, 0)
      ..retired = true;
    g.enemies.add(target);
    g.update(.001);
    expect(target.hp, 1000);
    expect(g.damageByWeapon, isEmpty);
  });
}
