import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/game/engine.dart';

// Controlled target audit: same stats, stationary target, no reinforcement or
// pickup growth. This measures damage/range, not human win rate or total utility.
void main() {
  test('all main weapons reconcile target damage and expose baseline/evolution range profiles', () {
    final rows = <Map<String, dynamic>>[];
    for (final weapon in armaments)
      for (final evolved in [false, true])
        for (final range in [60.0, 180.0, 320.0]) {
          final initial = GameEngine(
            stageIndex: 0,
            shipIndex: 0,
            attackLevel: 0,
            hullLevel: 0,
            magnetLevel: 0,
            equipmentIndex: 0,
            armament: weapon.id,
            seed: 26,
          );
          if (evolved) {
            initial.upgrades['gun'] = 5;
            initial.evolved.add('gun');
          }
          final checkpoint = initial.checkpoint(),
              state = checkpoint['state'] as Map;
          for (final key in [
            '_spawn',
            '_flightFormationClock',
            '_formationClock',
            '_supplyClock',
            '_mainClock',
            '_magnetClock',
          ])
            state[key] = 1000000.0;
          state['_lastEncounter'] = 0;
          final g = BattleCheckpoint.restore(jsonDecode(jsonEncode(checkpoint)))
            ..hp = 500000
            ..maxHp = 500000
            ..xpNeeded = 1e9;
          final at = g.position + Offset(0, -range),
              target = Foe(g.position + Offset(0, -range), 1e9, 0, 18, 0);
          g.enemies.add(target);
          var peak = 0;
          for (var i = 0; i < 800; i++) {
            target.position = at;
            target.phase = 0;
            g.update(.025);
            if (g.shots.length > peak) peak = g.shots.length;
            expect(g.enemies.length, 1);
            expect(g.finished, false);
            expect(g.shots.length, lessThan(1000));
          }
          final dealt = 1e9 - target.hp,
              reported = g.damageByWeapon.values.fold(0.0, (a, b) => a + b);
          expect(
            reported,
            closeTo(dealt, .1),
            reason: '${weapon.id}/$evolved/$range damage conservation',
          );
          if (range == 60)
            expect(
              dealt,
              greaterThan(0),
              reason: '${weapon.id} must be usable at close range',
            );
          rows.add({
            'weapon': weapon.id,
            'name': weapon.name,
            'evolved': evolved,
            'range': range,
            'seconds': g.combatTime,
            'damage': dealt,
            'dps': dealt / g.combatTime,
            'peakShots': peak,
            'sources': g.damageByWeapon,
          });
        }
    final flags = <Map<String, dynamic>>[];
    for (final weapon in armaments) {
      for (final range in [60.0, 180.0, 320.0]) {
        final base = rows.singleWhere(
              (r) =>
                  r['weapon'] == weapon.id &&
                  r['evolved'] == false &&
                  r['range'] == range,
            ),
            evo = rows.singleWhere(
              (r) =>
                  r['weapon'] == weapon.id &&
                  r['evolved'] == true &&
                  r['range'] == range,
            );
        if ((base['dps'] as double) > 0 &&
            (evo['dps'] as double) < (base['dps'] as double) * .9)
          flags.add({
            'weapon': weapon.id,
            'range': range,
            'baseDps': base['dps'],
            'evolvedDps': evo['dps'],
            'review': 'Evolution damage regression or range/utility tradeoff to inspect',
          });
      }
    }
    final out = Directory('.local/complete-v26')..createSync(recursive: true);
    File('${out.path}/weapon-range-audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'scope': 'stationary target, same permanent stats, 20s, gun rank1 vs rank5+EVO, no auxiliary or kill stacks',
        'rows': rows,
        'reviewFlags': flags,
      }),
    );
  });
}
