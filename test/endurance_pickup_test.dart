import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/game/engine.dart';

GameEngine arena() =>
    GameEngine(
        stageIndex: 99,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 34,
      )
      ..upgrades.clear()
      ..xpNeeded = 1e9;
GameEngine reload(GameEngine g) =>
    BattleCheckpoint.restore(jsonDecode(jsonEncode(g.checkpoint())));

void main() {
  test(
    'a kill at the crystal budget can always be checkpointed without XP loss',
    () {
      final g = arena();
      g.crystals.addAll(List.filled(1400, g.position + const Offset(500, 0)));
      final e = Foe(g.position + const Offset(0, -150), 1, 0, 12, 0);
      g.enemies.add(e);
      g.shots.add(Shot(e.position, Offset.zero, 10, 0));
      g.update(.01);
      expect(g.kills, 1);
      final copy = reload(g);
      expect(copy.checkpoint(), g.checkpoint());
      expect(g.crystals.length, lessThanOrEqualTo(1400));
      final value = g.crystals.fold<double>(
        0,
        (sum, c) => sum + ExperienceCrystal.valueOf(c),
      );
      expect(g.xp + value, inInclusiveRange(2800, 2804));
    },
  );
  test(
    'overlapping nearby magnets retain every XP mote and remain restorable',
    () {
      final g = arena();
      g.crystals.addAll(List.filled(1400, g.position + const Offset(250, 0)));
      g.supplies.add(Supply(g.position, 1));
      g.update(.01);
      g.crystals.addAll(List.filled(20, g.position + const Offset(250, 0)));
      g.supplies.add(Supply(g.position, 1));
      g.update(.01);
      final copy = reload(g);
      expect(copy.checkpoint(), g.checkpoint());
      for (var frame = 0; frame < 200; frame++) copy.update(.01);
      expect(copy.collectingMagnet, false);
      expect(copy.xp, 2840);
    },
  );
  test('legacy overflow is recovered with XP intact, oversized records still reject', () {
    final g = arena();
    g.crystals.addAll(List.filled(1401, g.position + const Offset(500, 0)));
    final copy = reload(g);
    expect(copy.crystals.length, 1400);
    expect(copy.xp, 0);
    expect(
      copy.crystals.fold<double>(0, (v, c) => v + ExperienceCrystal.valueOf(c)),
      2802,
    );
    final legacy = arena();
    legacy.crystals.addAll(
      List.filled(1400, legacy.position + const Offset(250, 0)),
    );
    legacy.supplies.add(Supply(legacy.position, 1));
    legacy.update(.01);
    final data =
        jsonDecode(jsonEncode(legacy.checkpoint())) as Map<String, dynamic>;
    final motes = data['absorption'] as List;
    motes.addAll(
      List.generate(20, (_) => Map<String, dynamic>.from(motes.first as Map)),
    );
    final recovered = BattleCheckpoint.restore(data);
    expect(recovered.absorbingCrystals.length, 1400);
    expect(
      recovered.absorbingCrystals.fold<double>(0, (v, m) => v + m.value),
      2840,
    );
    for (var i = 0; i < 200; i++) recovered.update(.01);
    expect(recovered.xp, 2840);
    final huge = arena().checkpoint();
    huge['crystals'] = List.filled(4097, [0, 0]);
    expect(() => BattleCheckpoint.restore(huge), throwsFormatException);
  });
  test(
    'boss death at the field limit remains a restorable final resolution',
    () {
      final g = arena()
        ..elapsed = 240
        ..bossesDefeated = 2;
      g.crystals.addAll(List.filled(1400, g.position + const Offset(500, 0)));
      final e = Foe(g.position + const Offset(0, -150), 100, 0, 34, 3)..hp = .1;
      g.enemies.add(e);
      final data = g.checkpoint(), state = data['state'] as Map;
      state['_bossWave'] = 3;
      state['_lastBossPhase'] = 2;
      state['bossCycle'] = 3.3;
      final ready = BattleCheckpoint.restore(jsonDecode(jsonEncode(data)));
      ready.shots.add(Shot(ready.boss!.position, Offset.zero, 100, 0));
      ready.update(.01);
      expect(ready.resolvingBoss, true);
      expect(ready.crystals.length, 1400);
      expect(ready.xp, 0);
      expect(
        ready.xp +
            ready.crystals.fold<double>(
              0,
              (sum, c) => sum + ExperienceCrystal.valueOf(c),
            ),
        2840,
      );
      expect(reload(ready).checkpoint(), ready.checkpoint());
    },
  );
}
