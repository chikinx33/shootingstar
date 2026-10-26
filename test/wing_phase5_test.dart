import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/battle_statistics.dart';

GameEngine arena(
  String weapon, {
  bool tech = false,
  bool precision = false,
  bool cycle = false,
  int level = 0,
}) =>
    GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        armament: weapon,
        armamentLevel: level,
        techRanks: tech ? {'gun': 2} : const {},
        mainPrecisionLink: precision,
        mainCycleLink: cycle,
        seed: 57,
      )
      ..xpNeeded = 1e9
      ..hp = 100000
      ..maxHp = 100000;
Foe foe(GameEngine g, double x, double y, {double hp = 100000}) =>
    Foe(g.position + Offset(x, y), hp, 0, 10, 0);
void advance(GameEngine g, double time) {
  for (var t = 0.0; t < time; t += .02) g.update(.02);
}

List<Shot> fire(GameEngine g) {
  g.update(.001);
  return g.shots.where((s) => !s.hostile).toList();
}

void main() {
  test('gun technical special reaches all three cat guns and precision aims the rail at a nearby heavy target', () {
    for (final w in ['pulse', 'shotgun', 'revolver']) {
      final g = arena(w, tech: true);
      g.enemies.add(foe(g, 0, -120));
      final shots = fire(g).where((s) => s.damage > 0).toList();
      expect(shots.any((s) => s.pierce >= 1), true, reason: w);
    }
    // 구름 정밀 냥냥포 is the aimed cat gun: precision picks a nearby heavy foe.
    for (final precision in [false, true]) {
      final g = arena('revolver', tech: true, precision: precision);
      final close = foe(g, 0, -60, hp: 100),
          heavy = foe(g, 200, -260),
          far = foe(g, 0, -800, hp: 200000);
      g.enemies.addAll([close, heavy, far]);
      final rail = fire(g).firstWhere((s) => s.weapon == 'gun');
      expect(rail.velocity.dx > 1, precision);
    }
  });
  test('cycle defense needs four real volleys, clears one valid shot, respects pause and never triggers guardian counter', () {
    final g = arena('pulse', tech: true, cycle: true);
    g.enemies.add(foe(g, 0, -120));
    g.upgrades['guardian'] = 3;
    g.passives['armor'] = 1;
    // Guardian is outside its own active interval, while link remains available.
    g.combatTime = 2;
    final bullets = [
      for (var i = 0; i < 4; i++)
        Shot(
          g.position + Offset(80.0, i.toDouble()),
          Offset.zero,
          10,
          4,
          life: 10,
        ),
    ];
    g.shots.addAll(bullets);
    advance(g, 1.05);
    expect(bullets.where((s) => g.shots.contains(s)).length, 3);
    expect(g.mainLoadoutDescription, contains('· 1회'));
    expect(g.synergyTriggers('shield-counter'), 0);
    expect(g.shieldCounterPending, false);
    g.setPaused(true);
    final frozen = g.combatTime;
    advance(g, 3);
    expect(g.combatTime, frozen);
  });
  test('link flags are derived from equipped rare tech and exact ranked gear; changing gear cannot alter a battle snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.techStock[0][2] = 1;
    p.equippedTech = {0};
    expect(p.mainPrecisionLink, false);
    p.gearAt(1).rank = 1;
    expect(p.mainPrecisionLink, true);
    expect(p.mainCycleLink, false);
    final id = p.grantItem(5)!.id;
    p.item(id)!.rank = 1;
    p.equipItem(id);
    expect(p.mainCycleLink, true);
    final g = arena(
      'pulse',
      tech: true,
      precision: p.mainPrecisionLink,
      cycle: p.mainCycleLink,
    );
    final snap = BattleStatisticsSnapshot.fromGame(g);
    p.equippedTech.clear();
    expect(p.mainPrecisionLink, false);
    expect(p.mainCycleLink, false);
    expect(g.precisionLinkActive, true);
    expect(snap.mainLoadout, contains('정밀 연계 · 활성'));
    await p.save();
    p.dispose();
  });
}
