import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/game/engine.dart';

/// The support device (S1) parts (v12.10.2 check, user 2026-10-26): each one
/// really changes the flight engine by the amount its card text promises.
/// v12.11: one support slot, so only the part fitted there works.
GameEngine flight(Map<String, String> supports, {int level = 1}) {
  var n = 0;
  return GameEngine(
    stageIndex: 0,
    shipIndex: 0,
    aircraft: AircraftAssembly(
      hull: 0,
      modules: ModuleSnapshot(0, 1, {
        'W1': const OwnedModulePart('w1', 'gun_vulcan', 1),
        for (final e in supports.entries)
          e.key: OwnedModulePart('s${n++}', e.value, level),
      }),
    ),
    attackLevel: 0,
    hullLevel: 0,
    magnetLevel: 0,
    equipmentIndex: -1,
    seed: 7,
  )..xpNeeded = 1e8;
}

void run(GameEngine g, double seconds, [void Function()? each]) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    g.update(1 / 60);
    each?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('armor: 6% less damage taken, growing with level (cap 18%)', () {
    expect(flight({}).moduleArmorReduction, 0);
    expect(flight({'S1': 'armor'}).moduleArmorReduction, closeTo(.06, 1e-9));
    expect(
      // Lv.40 support power 2.56: 15.36%, under the 18% cap
      flight({'S1': 'armor'}, level: 40).moduleArmorReduction,
      closeTo(.1536, 1e-9),
    );
  });

  test('capacitor: ultimate charges 15% faster', () {
    final base = flight({}), cap = flight({'S1': 'capacitor'});
    run(base, 1);
    run(cap, 1);
    expect(base.ultimateCharge, greaterThan(0));
    expect(cap.ultimateCharge / base.ultimateCharge, closeTo(1.15, .02));
  });

  test('sensor: marks an enemy every 6 seconds for 2 seconds', () {
    final plain = flight({}), sensor = flight({'S1': 'sensor'});
    var marked = 0, plainMarked = 0;
    run(sensor, 14, () {
      if (sensor.enemies.any((e) => e.vulnerable > 0)) marked++;
    });
    run(plain, 14, () {
      if (plain.enemies.any((e) => e.vulnerable > 0)) plainMarked++;
    });
    expect(plainMarked, 0);
    expect(marked, greaterThan(60)); // at least one second of marks
  });

  test('shield: fills 2.5% of hull per 2 seconds up to 22%', () {
    final g = flight({'S1': 'shield'});
    g.update(1 / 60);
    expect(g.moduleShield, greaterThan(0));
    run(g, 60);
    expect(g.moduleShield, lessThanOrEqualTo(g.maxHp * .22 + 1e-6));
    expect(flight({}).moduleShield, 0);
  });

  test('repair: heals 1.8% of base hull every 12 seconds', () {
    final g = flight({'S1': 'repair'})..hp = 50;
    g.update(1 / 60);
    expect(g.hp, greaterThan(50));
  });

  test('magnet and thruster are retired: no flight effect', () {
    // v12.17: gem intake belongs to the wings and the magnet skill, and
    // movement speed is no longer a stat, so both devices are gone.
    expect(retiredSupportIds, {'magnet', 'thruster'});
    expect(supportPartIds, hasLength(5));
    expect(supportPartIds.toSet().intersection(retiredSupportIds), isEmpty);
    // the slot no longer takes them at all
    for (final id in retiredSupportIds) {
      expect(mountAccepts('S1', modulePart(id)), isFalse);
      expect(() => flight({'S1': id}), throwsFormatException);
    }
    expect(flight({}).moveSpeed, GameEngine.followSpeed);
  });

  test('supply never offers a retired support device', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    p.petEggs = supportPartIds.length * 2 + 2;
    final granted = <String>[];
    while (p.petEggs > 0) {
      expect(p.openModuleSupply(support: true), isTrue);
      granted.add(moduleParts.firstWhere((m) => m.name == p.lastLoot).id);
    }
    expect(granted.where(retiredSupportIds.contains), isEmpty);
    expect(granted.toSet(), supportPartIds.toSet());
    expect(p.updateNotices, isEmpty);
    p.dispose();
  });

  test('owned magnets and thrusters leave the fleet, refunded with a notice', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await Profile.load();
    // An old save: a magnet fitted in S1 and a spare thruster in storage.
    final fleet = p.shipModules, ship = p.selectedShip;
    final kept = fleet.loadouts[ship]!['S1']!;
    final magnet = fleet.add('magnet', level: 7),
        thruster = fleet.add('thruster', level: 1);
    fleet.loadouts[ship]!['S1'] = magnet.instanceId;
    final credits = p.credits,
        dust = p.blueprints,
        notices = p.updateNotices.length;
    final after = p.shipModules;
    expect(after.owned.keys, isNot(contains(magnet.instanceId)));
    expect(after.owned.keys, isNot(contains(thruster.instanceId)));
    expect(
      after.owned.values.where((o) => retiredSupportIds.contains(o.partId)),
      isEmpty,
    );
    // S1 is cleared (not refilled with something the player never chose)
    expect(after.loadouts[ship]!.containsKey('S1'), isFalse);
    expect(p.moduleLoadout.parts['S1'], isNull);
    expect(after.owned.containsKey(kept), isTrue); // the old armor stays
    // churu 20 + level * 5, stardust 1 + level ~/ 3, per device
    const churu = (20 + 7 * 5) + (20 + 1 * 5), stardust = (1 + 7 ~/ 3) + 1;
    expect(p.credits, credits + churu);
    expect(p.blueprints, dust + stardust);
    expect(p.updateNotices, hasLength(notices + 1));
    expect(p.updateNotices.last, contains('2개'));
    expect(p.updateNotices.last, contains('츄르 $churu'));
    expect(p.updateNotices.last, contains('별가루 $stardust'));
    // a second look refunds nothing more
    p.shipModules;
    expect(p.credits, credits + churu);
    expect(p.blueprints, dust + stardust);
    expect(p.updateNotices, hasLength(notices + 1));
    p.dispose();
  });
}
