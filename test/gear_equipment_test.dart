import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/cat_gear.dart';
import 'package:shootingstar/data/gear_traits.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/l10n/app_language.dart';
import 'package:shootingstar/ui/content_hub.dart';

const utility = [0, 3, 5, 7, 9, 11];
GameEngine arena(List<int> specs, {bool safe = true}) =>
    GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
        seed: 91,
        aircraft: AircraftAssembly(parts: const {AircraftMount.main: 'cannon'})
            .withGear(specs),
        regeneration: specs[3] == 7,
      )
      ..xpNeeded = 1e8
      ..developerInvincible = safe;
void advance(GameEngine g, int n) {
  for (var i = 0; i < n; i++) {
    g.update(.025);
  }
}

List<int> variant(int slot, int spec) => List<int>.of(utility)..[slot] = spec;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  test(
    'primary equipment changes pierce versus forward air-only seeker delivery',
    () {
      final focus = arena(utility)..gearVolleys = 7;
      focus.update(.001);
      expect(focus.shots.first.pierce, 1);
      final seeker = arena(variant(0, 1))..gearVolleys = 7;
      seeker.update(.001);
      final rocket = seeker.shots.singleWhere((s) => s.kind == 28);
      expect(rocket.velocity.dy, lessThan(0));
      final ground = Foe(
        rocket.position,
        100,
        0,
        8,
        0,
        plane: AircraftTarget.ground,
      );
      seeker.enemies.add(ground);
      expect(seeker.modularSourceCanHit('gear-seeker', ground), false);
      advance(seeker, 55);
      expect(ground.hp, 100);
    },
  );
  test('precision marks a target while scanner pulls only four gems without awarding XP', () {
    final mark = arena(variant(1, 2));
    final target = Foe(mark.position + const Offset(150, 0), 1000, 0, 10, 0);
    mark.enemies.add(target);
    mark.update(.025);
    expect(target.vulnerable, greaterThan(1.9));
    final scanner = arena(utility);
    for (var i = 0; i < 8; i++) {
      scanner.crystals.add(
        ExperienceCrystal.at(
          scanner.position + Offset(150 + (i ~/ 2) * 3, 0),
          [4.0, 8.0, 16.0][i % 3],
        ),
      );
    }
    final value = scanner.crystals.fold<double>(
      0,
      (sum, c) => sum + ExperienceCrystal.valueOf(c),
    );
    final xp = scanner.xp;
    scanner.update(.025);
    expect(
      scanner.crystals.where(
        (p) => (p - scanner.position).distance < scanner.collectionRadius,
      ),
      hasLength(4),
    );
    expect(scanner.xp, xp);
    expect(scanner.crystals, hasLength(8));
    expect(
      scanner.crystals.fold<double>(
        0,
        (sum, c) => sum + ExperienceCrystal.valueOf(c),
      ),
      value,
    );
  });
  test(
    'output burst changes actual damage; cycle core instead produces charge',
    () {
      final power = arena(variant(2, 4)), cycle = arena(utility);
      for (final g in [power, cycle]) {
        g.enemies.add(Foe(g.position + const Offset(0, -100), 10000, 0, 10, 0));
        advance(g, 15);
      }
      final a = power.damageByWeapon['module-main']!,
          b = cycle.damageByWeapon['module-main']!;
      expect(a / b, closeTo(1.1, .001));
      final charge = arena(utility)
        ..gearVolleys = 7
        ..pilotAbilityCooldown = 5;
      charge.update(.025);
      expect(charge.ultimateCharge, greaterThan(2));
      expect(charge.pilotAbilityCooldown, lessThan(4.51));
    },
  );
  test(
    'hull guard and life belt protect only after a surviving qualifying hit',
    () {
      final g = arena(variant(3, 6), safe: false)..hp = 50;
      g.shots.add(Shot(g.position, Offset.zero, g.maxHp * .2, 4, life: 1));
      g.update(.025);
      expect(g.hp, lessThan(50));
      expect(g.moduleShield, closeTo(g.maxHp * .08, .001));
      final shield = g.moduleShield;
      g.shots.add(Shot(g.position, Offset.zero, g.maxHp, 4, life: 1));
      advance(g, 30);
      expect(g.hp, 0);
      expect(g.finished, true);
      expect(g.moduleShield, lessThan(shield));
    },
  );
  test(
    'barrier intercepts one bullet and does not grant permanent immunity',
    () {
      final g = arena(variant(4, 8), safe: false);
      g.shots.add(Shot(g.position, Offset.zero, 12, 4, life: 1));
      g.update(.025);
      expect(g.hp, g.maxHp);
      g.shots.add(Shot(g.position, Offset.zero, 12, 4, life: 1));
      g.update(.025);
      expect(g.hp, lessThan(g.maxHp));
    },
  );
  test('thrusters change motion versus collection-triggered charge', () {
    final booster = arena(variant(5, 10));
    final base = booster.moveSpeed;
    booster.input = const Offset(1, 0);
    booster.update(.025);
    expect(booster.moveSpeed / base, closeTo(1.12, .0001));
    advance(booster, 45);
    expect(booster.moveSpeed, base);
    final salvage = arena(utility);
    salvage.crystals.addAll(List.filled(16, salvage.position));
    salvage.update(.025);
    expect(salvage.gearSalvage, 16);
    expect(salvage.ultimateCharge, greaterThan(3));
    final rich = arena(utility);
    rich.crystals.addAll(
      List.generate(2, (_) => ExperienceCrystal.at(rich.position, 16)),
    );
    rich.update(.025);
    expect(rich.gearSalvage, 16);
    expect(rich.ultimateCharge, closeTo(salvage.ultimateCharge, .001));
  });
  test('gear effects and in-flight seeker resume identically without changing legacy runs', () {
    final g = arena(variant(0, 1))..gearVolleys = 7;
    g.input = const Offset(.3, 0);
    advance(g, 5);
    final saved = jsonDecode(jsonEncode(g.checkpoint()));
    final copy = BattleCheckpoint.restore(saved)
      ..setPaused(false)
      ..developerInvincible = true;
    expect(copy.gearSpecs, g.gearSpecs);
    expect(copy.shots.any((s) => s.kind == 28), true);
    copy.input = g.input;
    advance(g, 80);
    advance(copy, 80);
    expect(jsonEncode(copy.checkpoint()), jsonEncode(g.checkpoint()));
    final bad = jsonDecode(jsonEncode(saved));
    bad['config']['gearSpecs'] = [0, 2, 4, 6, 8, 1];
    expect(() => BattleCheckpoint.restore(bad), throwsFormatException);
    final old = jsonDecode(jsonEncode(saved));
    old['config'].remove('gearSpecs');
    old['state']['modular'].remove('gearVolleys');
    old['state']['modular'].remove('gearSalvage');
    expect(BattleCheckpoint.restore(old).gearSpecs, isEmpty);
  });
  test('equipment art and perk changes preserve item IDs investments loadouts and boss sets', () async {
    final p = await Profile.load();
    for (var i = 0; i < 32; i++) {
      p.grantItem(i, rank: 2);
    }
    final gun = p.inventory.firstWhere((g) => g.spec == 1);
    p.equipItem(gun.id);
    gun.level = 9;
    gun.spentCredits = 1234;
    gun.spentPlans = 9;
    gun.locked = true;
    Directory('.local/gear-v52').createSync(recursive: true);
    File('.local/gear-v52/profile-fixture.json')
        .writeAsStringSync(jsonEncode(p.exportProgress()));
    final before = p.exportProgress();
    await p.save();
    final copy = await Profile.load();
    expect(
      copy.inventory.map((g) => g.toJson()).toList(),
      (before['content'] as Map)['inventory'],
    );
    expect(copy.equippedGear, p.equippedGear);
    expect(copy.credits, p.credits);
    expect(copy.aircraftAssembly.toJson(), p.aircraftAssembly.toJson());
    // v11+: the flown airframe takes its body gear from catGear, so the
    // legacy GearItem loadout survives only as saved profile data.
    expect(copy.gearSpecs[0], 1);
    expect(copy.item(gun.id)!.spentCredits, 1234);
    expect(copy.item(gun.id)!.locked, true);
    final hull = copy.inventory.firstWhere((g) => g.spec == 12),
        engine = copy.inventory.firstWhere((g) => g.spec == 13);
    copy.equipItem(hull.id);
    copy.equipItem(engine.id);
    expect(copy.activeBossSetWorld, 0);
    expect(validGearSpecs(copy.gearSpecs), true);
  });
  test('six minute combat keeps equipment triggers projectiles and checkpoint timers bounded', () {
    for (final specs in [
      const [1, 2, 4, 6, 9, 10],
      const [0, 3, 5, 7, 8, 11],
    ]) {
      final g = arena(specs);
      var peak = 0;
      for (var i = 0; i < 14400 && !g.finished; i++) {
        g.input = Offset(
          i % 400 < 200 ? 0.4 : -0.4,
          i % 600 < 300 ? -0.2 : 0.2,
        );
        g.update(.025);
        if (g.shots.length > peak) peak = g.shots.length;
      }
      expect(peak, lessThan(1000));
      expect(g.moduleShield, lessThanOrEqualTo(g.maxHp * .22));
      final timers =
          ((g.checkpoint()['state'] as Map)['modular'] as Map)['timers'] as Map;
      expect(timers.length, lessThanOrEqualTo(32));
      expect(g.gearVolleys, greaterThan(8));
      print(
        'GEAR_ENDURANCE specs=$specs time=${g.combatTime} peakShots=$peak timers=${timers.length}',
      );
    }
  });
  // v12.10: the old inventory filter / card list is gone; each growth slot
  // opens a popup listing the owned pieces with their own art and the picked
  // piece's set traits.
  testWidgets('320px gear slot popup shows per-item art and set traits', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final p = await Profile.load();
    final night = p.catGear.add('night', CatGearSlot.nose, 2);
    p.catGear.add('bloom', CatGearSlot.nose, 3);
    await t.pumpWidget(
      LanguageScope(
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'NotoSansKR',
            ),
          ),
          home: Scaffold(body: ContentHub(profile: p)),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cat-gear-slot-nose')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final list = find.byKey(const Key('cat-gear-list-nose'));
    expect(list, findsOneWidget);
    final art = find
        .descendant(of: list, matching: find.byType(Image))
        .evaluate()
        .map((e) => ((e.widget as Image).image as AssetImage).assetName)
        .toSet();
    expect(art, {
      for (final set in ['sunshine', 'night', 'bloom'])
        catGearSet(set).asset(CatGearSlot.nose),
    });
    // the wide test font may push the item card onto a later page
    Future<void> turn(String key) async {
      final arrow = find.byKey(Key(key));
      if (arrow.evaluate().isEmpty) return;
      await t.tap(arrow);
      await t.pumpAndSettle();
    }

    Future<bool> reach(Finder f) async {
      for (var i = 0; i < 4 && f.evaluate().isEmpty; i++) {
        await turn('game-page-next');
      }
      return f.evaluate().isNotEmpty;
    }

    // the equipped starter is picked first
    expect(
      await reach(find.textContaining(catGearSet('sunshine').two)),
      isTrue,
    );
    for (var i = 0; i < 4 && list.evaluate().isEmpty; i++) {
      await turn('game-page-previous');
    }
    await t.tap(find.byKey(ValueKey('cat-gear-item-${night.id}')));
    await t.pumpAndSettle();
    expect(await reach(find.textContaining(catGearSet('night').two)), isTrue);
    expect(t.takeException(), isNull);
    await t.tap(find.byTooltip('닫기').last);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
